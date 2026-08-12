// BLD mock API — docs/openapi.yaml sözleşmesinin durum tutan uygulaması.
//
// Neden hazır bir mock (Prism) değil: istemci hatlarının en zor kısımları
// artımlı polling (after/since/max_id), durum geçiş reddi ve fiş ack
// idempotentliği. Statik bir mock bunların hiçbirini üretemez; ekipler o
// kodu ancak backend hazır olunca test edebilirdi. Takvimi kurtaran şey bu.
//
// UYARI: bellek içi durum. Yeniden başlatınca örnek veriye döner.
// Oran sınırları uygulanmaz — sözleşmedeki §8 yalnızca gerçek sunucuda geçerli.

import express from 'express';

import { PAIRING_CODE } from './seed.js';
import * as out from './serializers.js';
import { MockState } from './state.js';

const PORT = Number(process.env.PORT ?? 4010);
const state = new MockState();
const app = express();

app.use(express.json());
app.disable('x-powered-by');

// ─────────────────────────────── Yardımcılar ───────────────────────────────

const ERROR_STATUS = {
  UNAUTHENTICATED: 401,
  FORBIDDEN: 403,
  DEVICE_REVOKED: 403,
  NOT_FOUND: 404,
  VALIDATION_FAILED: 422,
  INVALID_TRANSITION: 422,
  LOCATION_CLOSED: 422,
  ITEM_UNAVAILABLE: 422,
  RATE_LIMITED: 429,
  SERVER_ERROR: 500,
};

function fail(res, code, message, details) {
  return res.status(ERROR_STATUS[code] ?? 500).json({
    error: { code, message, ...(details ? { details } : {}) },
  });
}

const nowIso = () => new Date().toISOString();

/** Zorunlu başlıklar — docs/03 §1.1. Gerçek sunucu da bunları arar. */
function requireHeaders(req, res, next) {
  if (req.path.startsWith('/__mock')) return next();

  const appId = req.get('X-App-Id');
  const appVersion = req.get('X-App-Version');
  const missing = [];
  if (!appId) missing.push('X-App-Id');
  if (!appVersion) missing.push('X-App-Version');

  if (missing.length > 0) {
    return fail(
      res,
      'VALIDATION_FAILED',
      'Zorunlu başlık eksik. Sözleşme her istekte X-App-Id ve X-App-Version bekler.',
      { missing_headers: missing },
    );
  }
  if (!['website', 'musteriapp', 'mutfakapp'].includes(appId)) {
    return fail(res, 'VALIDATION_FAILED', 'Geçersiz X-App-Id değeri.', {
      'X-App-Id': appId,
    });
  }
  return next();
}

function principalOf(req) {
  const header = req.get('Authorization') ?? '';
  if (!header.startsWith('Bearer ')) return null;
  return state.resolveToken(header.slice(7));
}

/** `customer` kapsamı zorunlu. Mutfak token'ı buraya giremez (docs/10 S5). */
function requireCustomer(req, res, next) {
  const principal = principalOf(req);
  if (!principal) {
    return fail(res, 'UNAUTHENTICATED', 'Oturum bulunamadı, tekrar giriş yapın.');
  }
  if (principal.kind !== 'customer') {
    return fail(res, 'FORBIDDEN', 'Bu uca erişim yetkiniz yok.');
  }
  req.customerId = principal.customerId;
  return next();
}

/** `kitchen` kapsamı zorunlu. Müşteri token'ı buraya giremez (docs/10 S5). */
function requireKitchen(req, res, next) {
  const principal = principalOf(req);
  if (!principal) {
    return fail(res, 'UNAUTHENTICATED', 'Cihaz eşlenmemiş.');
  }
  if (principal.kind === 'revoked') {
    return fail(res, 'DEVICE_REVOKED', 'Bu cihazın yetkisi iptal edilmiş.');
  }
  if (principal.kind !== 'kitchen') {
    return fail(res, 'FORBIDDEN', 'Bu uca erişim yetkiniz yok.');
  }
  req.deviceId = principal.deviceId;
  return next();
}

app.use(requireHeaders);

// ─────────────────────────────── Sağlık ────────────────────────────────────

app.get('/api/health', (_req, res) =>
  res.json({ status: 'ok', server_time: nowIso() }),
);

// ─────────────────────────────── Kimlik ────────────────────────────────────

app.post('/api/auth/register', (req, res) => {
  const b = req.body ?? {};
  const missing = [
    'first_name',
    'last_name',
    'email',
    'telephone',
    'password',
  ].filter((f) => !b[f]);

  if (missing.length > 0) {
    return fail(res, 'VALIDATION_FAILED', 'Eksik alanlar var.', {
      missing: missing,
    });
  }
  if (b.kvkk_accepted !== true) {
    return fail(res, 'VALIDATION_FAILED', 'KVKK onayı zorunludur.', {
      kvkk_accepted: 'Onaylanmalı.',
    });
  }
  if (state.customers.some((c) => c.email === b.email)) {
    return fail(res, 'VALIDATION_FAILED', 'Bu e-posta zaten kayıtlı.', {
      email: 'Kullanımda.',
    });
  }

  const customer = {
    id: Math.max(...state.customers.map((c) => c.id)) + 1,
    first_name: b.first_name,
    last_name: b.last_name,
    email: b.email,
    telephone: b.telephone,
    password: b.password,
    default_location_id: state.location.id,
  };
  state.customers.push(customer);

  return res.status(201).json({
    token: state.issueCustomerToken(customer.id),
    customer: { id: customer.id, first_name: customer.first_name },
  });
});

app.post('/api/auth/login', (req, res) => {
  const { email, password } = req.body ?? {};
  const customer = state.customers.find(
    (c) => c.email === email && c.password === password,
  );
  if (!customer) {
    return fail(res, 'VALIDATION_FAILED', 'E-posta veya şifre hatalı.', {
      email: 'Doğrulanamadı.',
    });
  }
  return res.json({
    token: state.issueCustomerToken(customer.id),
    customer: { id: customer.id, first_name: customer.first_name },
  });
});

app.post('/api/auth/logout', requireCustomer, (req, res) => {
  const header = req.get('Authorization') ?? '';
  state.tokens.delete(header.slice(7));
  return res.status(204).end();
});

app.get('/api/auth/me', requireCustomer, (req, res) =>
  res.json(out.customerOut(state.customerById(req.customerId))),
);

app.post('/api/me/push-token', requireCustomer, (req, res) => {
  const { fcm_token: fcmToken } = req.body ?? {};
  if (!fcmToken) {
    return fail(res, 'VALIDATION_FAILED', 'fcm_token zorunludur.', {
      fcm_token: 'Boş olamaz.',
    });
  }
  state.pushTokens.set(req.customerId, fcmToken);
  return res.status(204).end();
});

// ─────────────────────── Kurumsal site içeriği ─────────────────────────────
//
// Uç sözleşmede var ama mock'ta yoktu: site her sayfa çiziminde 404 alıp
// paketlenmiş yedek içeriğe düşüyordu. Yedek çalıştığı için kimse fark
// etmiyordu — ama sunucu günlüğü her istekte hata basıyor ve gerçek bir
// arıza bu gürültünün içinde kaybolurdu.
//
// İçerik MİNİMUM: site zaten yedeğe sahip; buradaki amaç 404'ü kesmek ve
// panelden gelen alanların (marka, iletişim) yolunu doğrulamak.
app.get('/api/site-content', (_req, res) =>
  res.json({
    brand: {
      name: 'Benim Lezzet Dünyam',
      short_name: 'BLD',
      description: 'Kurumsal catering ve toplu yemek hizmeti.',
      logo_url: null,
      color: '#EA580C',
    },
    contact: {
      phone: '05551112233',
      whatsapp: '905551112233',
      email: 'bilgi@ornek.com',
      address: 'Selçuklu / Konya',
    },
    services: [],
    posts: [],
  }),
);

// ──────────────────────── Telefonla giriş (B-18 / W-11) ────────────────────
//
// GERÇEK SUNUCUYLA AYNI DAVRANIŞ: kayıtlı olmayan numara da 202 alır ve SMS
// gitmez (numara sayımına kapı bırakmamak için). Test kodu okumak zorunda
// olduğu için `/__mock/otp/:phone` ucu var — üretimde böyle bir şey yok.

function normalizePhone(input) {
  const digits = String(input ?? '').replace(/\D+/g, '');
  if (digits.startsWith('90') && digits.length === 12) return digits.slice(2);
  if (digits.startsWith('0') && digits.length === 11) return digits.slice(1);
  return digits;
}

app.post('/api/auth/otp/request', (req, res) => {
  const phone = normalizePhone(req.body?.phone);

  if (phone.length !== 10) {
    return fail(res, 'VALIDATION_FAILED', 'Telefon numarası geçersiz.', {
      phone: 'On hane olmalı.',
    });
  }

  const customer = state.customers.find((c) => normalizePhone(c.telephone) === phone);
  if (customer) {
    // Sabit kod DEĞİL: rastgele üretiliyor ki test "kodu tahmin etme"
    // yoluna sapmasın ve gerçek akışı (kodu oku, gir) izlesin.
    state.otpCodes.set(phone, String(Math.floor(100000 + Math.random() * 900000)));
  }

  return res.status(202).json({
    message: 'Kod gönderildi. SMS birkaç saniye içinde ulaşır.',
    expires_in: 300,
    resend_after: 60,
  });
});

app.post('/api/auth/otp/verify', (req, res) => {
  const phone = normalizePhone(req.body?.phone);
  const code = String(req.body?.code ?? '');
  const expected = state.otpCodes.get(phone);

  if (!expected || expected !== code) {
    return fail(res, 'VALIDATION_FAILED', 'Kod hatalı.', { code: 'Doğrulanamadı.' });
  }

  const customer = state.customers.find((c) => normalizePhone(c.telephone) === phone);
  if (!customer) {
    return fail(res, 'VALIDATION_FAILED', 'Kod geçersiz ya da süresi dolmuş.', {
      code: 'Yeni bir kod isteyin.',
    });
  }

  // Tek kullanımlık: doğrulanan kod hemen tüketilir.
  state.otpCodes.delete(phone);

  return res.json({
    token: state.issueCustomerToken(customer.id),
    customer: { id: customer.id, first_name: customer.first_name },
  });
});

// ──────────────────────────── Adres defteri (W-15) ─────────────────────────
//
// Uçlar sözleşmede baştan beri vardı ve mobil kullanıyordu; mock hiç
// taşımıyordu çünkü site de kullanmıyordu. Site artık kullanıyor.

app.get('/api/addresses', requireCustomer, (req, res) =>
  res.json({ data: state.addressesOf(req.customerId) }),
);

app.post('/api/addresses', requireCustomer, (req, res) => {
  const saved = state.saveAddress(req.customerId, req.body ?? {});

  return res.status(201).json(saved);
});

app.patch('/api/addresses/:id', requireCustomer, (req, res) => {
  const updated = state.updateAddress(req.customerId, Number(req.params.id), req.body ?? {});
  if (!updated) return fail(res, 'NOT_FOUND', 'Adres bulunamadı.');

  return res.json(updated);
});

app.delete('/api/addresses/:id', requireCustomer, (req, res) => {
  const removed = state.deleteAddress(req.customerId, Number(req.params.id));
  if (!removed) return fail(res, 'NOT_FOUND', 'Adres bulunamadı.');

  return res.status(204).end();
});

// ──────────────────────────── Cari hesap (W-12) ────────────────────────────

app.get('/api/account/summary', requireCustomer, (req, res) =>
  res.json({
    balance: state.balanceOf(req.customerId),
    currency: 'TRY',
    as_of: nowIso(),
  }),
);

app.get('/api/account/statement', requireCustomer, (req, res) => {
  const rows = state.ledger.get(req.customerId) ?? [];

  let running = 0;
  const entries = rows.map((row) => {
    running += row.entry_type === 'debit' ? row.amount : -row.amount;
    return { ...row, running_balance: running };
  });

  return res.json({
    opening_balance: 0,
    closing_balance: running,
    currency: 'TRY',
    from: rows[0]?.date ?? nowIso().slice(0, 10),
    to: nowIso().slice(0, 10),
    entries,
  });
});

app.post('/api/account/payments', requireCustomer, (req, res) => {
  const balance = state.balanceOf(req.customerId);

  if (balance <= 0) {
    return fail(res, 'VALIDATION_FAILED', 'Ödenecek borç bulunmuyor.', { balance });
  }

  const full = req.body?.full === true;
  const amount = full ? balance : Number(req.body?.amount ?? 0);

  if (!Number.isInteger(amount) || amount <= 0) {
    return fail(res, 'VALIDATION_FAILED', 'Ödenecek tutar belirtilmeli.', {
      amount: 'Tutar girin veya borcun tamamını seçin.',
    });
  }
  if (amount > balance) {
    return fail(res, 'VALIDATION_FAILED', 'Tutar borcunuzdan büyük olamaz.', {
      amount,
      balance,
    });
  }

  const id = state.nextAccountPaymentId++;
  const hash = `mockpay${id}`;
  state.accountPayments.set(hash, { id, customerId: req.customerId, amount, status: 'pending' });

  return res.status(201).json({
    payment_id: id,
    amount,
    balance,
    currency: 'TRY',
    status: 'pending',
    redirect_url: `${req.protocol}://${req.get('host')}/__mock/cari-odeme/${hash}`,
  });
});

// ──────────────────────────── Abonelik (W-13) ──────────────────────────────

app.get('/api/subscriptions', requireCustomer, (req, res) =>
  res.json({
    data: state.subscriptions.filter((s) => s.customer_id === req.customerId),
  }),
);

app.get('/api/subscriptions/:id', requireCustomer, (req, res) => {
  const found = state.subscriptions.find(
    (s) => s.id === Number(req.params.id) && s.customer_id === req.customerId,
  );
  if (!found) return fail(res, 'NOT_FOUND', 'Abonelik bulunamadı.');
  return res.json(found);
});

function transitionSubscription(req, res, from, to, message) {
  const found = state.subscriptions.find(
    (s) => s.id === Number(req.params.id) && s.customer_id === req.customerId,
  );
  if (!found) return fail(res, 'NOT_FOUND', 'Abonelik bulunamadı.');
  if (from && found.status !== from) {
    return fail(res, 'VALIDATION_FAILED', message, { status: found.status });
  }
  found.status = to;
  return res.json(found);
}

app.post('/api/subscriptions/:id/pause', requireCustomer, (req, res) =>
  transitionSubscription(req, res, 'active', 'paused', 'Yalnızca aktif abonelik duraklatılabilir.'),
);

app.post('/api/subscriptions/:id/resume', requireCustomer, (req, res) =>
  transitionSubscription(
    req,
    res,
    'paused',
    'active',
    'Yalnızca duraklatılmış abonelik devam ettirilebilir.',
  ),
);

app.post('/api/subscriptions/:id/cancel', requireCustomer, (req, res) =>
  transitionSubscription(req, res, null, 'cancelled', 'Abonelik zaten iptal.'),
);

app.post('/api/subscriptions/:id/exceptions', requireCustomer, (req, res) => {
  const found = state.subscriptions.find(
    (s) => s.id === Number(req.params.id) && s.customer_id === req.customerId,
  );
  if (!found) return fail(res, 'NOT_FOUND', 'Abonelik bulunamadı.');

  const date = String(req.body?.service_date ?? '');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    return fail(res, 'VALIDATION_FAILED', 'Tarih geçersiz.', { service_date: 'YYYY-AA-GG' });
  }

  found.exceptions = (found.exceptions ?? []).filter((e) => e.service_date !== date);
  found.exceptions.push({
    service_date: date,
    skip: req.body?.skip === true,
    quantity_override: req.body?.quantity_override ?? null,
  });

  return res.json(found);
});

// ─────────────────────────────── Katalog ───────────────────────────────────

app.get('/api/locations', (_req, res) =>
  res.json({ data: [out.locationOut(state.location)] }),
);

app.get('/api/locations/:id/menu', (req, res) => {
  if (Number(req.params.id) !== state.location.id) {
    return fail(res, 'NOT_FOUND', 'Vitrin bulunamadı.');
  }
  return res.json({ data: state.menu });
});

// ─────────────────────────────── Sipariş ───────────────────────────────────

app.post('/api/orders', requireCustomer, (req, res) => {
  const b = req.body ?? {};

  if (Number(b.location_id) !== state.location.id) {
    return fail(res, 'NOT_FOUND', 'Vitrin bulunamadı.');
  }
  if (!state.location.is_open || !state.location.ordering_enabled) {
    return fail(res, 'LOCATION_CLOSED', 'Şu anda sipariş alınmıyor.');
  }
  if (!Array.isArray(b.items) || b.items.length === 0) {
    return fail(res, 'VALIDATION_FAILED', 'Sepette en az bir ürün olmalı.', {
      items: 'Boş olamaz.',
    });
  }
  if (!['delivery', 'pickup'].includes(b.delivery_type)) {
    return fail(res, 'VALIDATION_FAILED', 'Teslimat tipi geçersiz.', {
      delivery_type: 'delivery veya pickup olmalı.',
    });
  }
  if (b.delivery_type === 'delivery' && !b.address?.line1) {
    return fail(res, 'VALIDATION_FAILED', 'Teslimat adresi zorunludur.', {
      address: 'Eksik.',
    });
  }
  if (!state.location.payment_methods.includes(b.payment_method)) {
    return fail(
      res,
      'VALIDATION_FAILED',
      'Bu ödeme yöntemi şu anda kullanılamıyor.',
      { payment_method: state.location.payment_methods },
    );
  }

  for (const line of b.items) {
    const item = state.findMenuItem(line.menu_id);
    if (!item) {
      return fail(res, 'ITEM_UNAVAILABLE', 'Ürün menüde bulunamadı.', {
        menu_id: line.menu_id,
      });
    }
    if (!item.is_available) {
      return fail(res, 'ITEM_UNAVAILABLE', `${item.name} şu anda tükendi.`, {
        menu_id: line.menu_id,
      });
    }
    if (!Number.isInteger(line.quantity) || line.quantity < 1) {
      return fail(res, 'VALIDATION_FAILED', 'Adet en az 1 olmalı.', {
        menu_id: line.menu_id,
      });
    }
  }

  const order = state.createOrder({
    customerId: req.customerId,
    deliveryType: b.delivery_type,
    items: b.items,
    address: b.address ?? null,
    requestedAt: b.requested_at ?? null,
    paymentMethod: b.payment_method,
    customerNote: b.customer_note ?? null,
  });

  const { total } = state.totals(order);
  if (total < state.location.min_order_total) {
    // Sipariş oluşturulmuş olsaydı sözleşme ihlali olurdu; geri al.
    state.orders.pop();
    return fail(
      res,
      'VALIDATION_FAILED',
      'Asgari sipariş tutarının altındasınız.',
      { min_order_total: state.location.min_order_total, total },
    );
  }

  return res.status(201).json(out.orderCreatedOut(state, order));
});

app.get('/api/orders', requireCustomer, (req, res) => {
  const page = Math.max(1, Number(req.query.page ?? 1));
  const perPage = Math.min(100, Math.max(1, Number(req.query.per_page ?? 25)));

  const mine = state.orders
    .filter((o) => o.customer_id === req.customerId)
    .sort((a, b) => b.created_at.localeCompare(a.created_at));

  const start = (page - 1) * perPage;
  return res.json({
    data: mine
      .slice(start, start + perPage)
      .map((o) => out.orderSummaryOut(state, o)),
    meta: {
      page,
      per_page: perPage,
      total: mine.length,
      last_page: Math.max(1, Math.ceil(mine.length / perPage)),
    },
  });
});

app.get('/api/orders/:id', requireCustomer, (req, res) => {
  const order = state.orderById(Number(req.params.id));
  // Başkasının siparişi de 404 döner — varlık sızdırılmaz (docs/10 S5 adım 4).
  if (!order || order.customer_id !== req.customerId) {
    return fail(res, 'NOT_FOUND', 'Sipariş bulunamadı.');
  }
  return res.json(out.orderDetailOut(state, order));
});

app.post('/api/orders/:id/cancel', requireCustomer, (req, res) => {
  const order = state.orderById(Number(req.params.id));
  if (!order || order.customer_id !== req.customerId) {
    return fail(res, 'NOT_FOUND', 'Sipariş bulunamadı.');
  }
  if (!['yeni', 'onaylandi'].includes(order.status)) {
    return fail(res, 'INVALID_TRANSITION', 'Sipariş bu aşamada iptal edilemez.', {
      from: order.status,
      to: 'iptal',
    });
  }
  state.applyTransition(order, 'iptal');
  return res.json(out.orderDetailOut(state, order));
});

// ─────────────────────────────── Mutfak ────────────────────────────────────

app.post('/api/kitchen/pair', (req, res) => {
  const { pairing_code: code, device_name: name } = req.body ?? {};
  if (code !== PAIRING_CODE) {
    return fail(res, 'NOT_FOUND', 'Eşleme kodu geçersiz veya süresi dolmuş.');
  }
  if (!name) {
    return fail(res, 'VALIDATION_FAILED', 'Cihaz adı zorunludur.', {
      device_name: 'Boş olamaz.',
    });
  }
  const { token, deviceId } = state.issueKitchenToken();
  return res.json({
    device_id: deviceId,
    token,
    server_time: nowIso(),
  });
});

app.get('/api/kitchen/orders', requireKitchen, (req, res) => {
  const after = req.query.after ? Number(req.query.after) : null;
  const since = req.query.since ? String(req.query.since) : null;
  const includeCompleted = req.query.include_completed === 'true';

  let orders = state.orders.filter((o) => {
    if (includeCompleted) return true;
    return o.status !== 'teslim_edildi' && o.status !== 'iptal';
  });

  if (after !== null) orders = orders.filter((o) => o.id > after);
  if (since !== null) orders = orders.filter((o) => o.updated_at > since);

  orders.sort((a, b) => a.id - b.id);

  // max_id daima tüm aktif kümenin en büyüğüdür; filtre boş dönse bile
  // istemci geriye kaymasın.
  const allIds = state.orders.map((o) => o.id);

  return res.json({
    data: orders.map((o) => out.kitchenOrderOut(state, o)),
    server_time: nowIso(),
    max_id: allIds.length > 0 ? Math.max(...allIds) : 0,
  });
});

app.post('/api/kitchen/orders/:id/status', requireKitchen, (req, res) => {
  const order = state.orderById(Number(req.params.id));
  if (!order) return fail(res, 'NOT_FOUND', 'Sipariş bulunamadı.');

  const to = req.body?.status;
  if (typeof to !== 'string') {
    return fail(res, 'VALIDATION_FAILED', 'status alanı zorunludur.', {
      status: 'Eksik.',
    });
  }
  if (!state.canTransition(order, to)) {
    return fail(res, 'INVALID_TRANSITION', 'Sipariş bu duruma geçirilemez.', {
      from: order.status,
      to,
      delivery_type: order.delivery_type,
    });
  }

  state.applyTransition(order, to);
  return res.json(out.kitchenOrderOut(state, order));
});

app.get('/api/kitchen/orders/:id/receipt', requireKitchen, (req, res) => {
  const order = state.orderById(Number(req.params.id));
  if (!order) return fail(res, 'NOT_FOUND', 'Sipariş bulunamadı.');

  const type = req.query.type;
  if (type === 'mutfak') return res.json(out.kitchenReceiptOut(state, order));
  if (type === 'musteri') return res.json(out.customerReceiptOut(state, order));

  return fail(res, 'VALIDATION_FAILED', 'Fiş tipi geçersiz.', {
    type: 'mutfak veya musteri olmalı.',
  });
});

app.post(
  '/api/kitchen/print-jobs/:orderId/ack',
  requireKitchen,
  (req, res) => {
    const order = state.orderById(Number(req.params.orderId));
    if (!order) return fail(res, 'NOT_FOUND', 'Sipariş bulunamadı.');

    const { type, printed_at: printedAt } = req.body ?? {};
    if (!['mutfak', 'musteri'].includes(type)) {
      return fail(res, 'VALIDATION_FAILED', 'Fiş tipi geçersiz.', {
        type: 'mutfak veya musteri olmalı.',
      });
    }
    // İdempotent: ikinci çağrı da 204 döner, yeni kayıt açmaz.
    state.ackPrint(order.id, type, printedAt ?? nowIso());
    return res.status(204).end();
  },
);

app.get('/api/kitchen/production-list', requireKitchen, (_req, res) =>
  res.json({ data: state.productionList(), as_of: nowIso() }),
);

app.get('/api/kitchen/heartbeat', requireKitchen, (_req, res) =>
  res.json({ server_time: nowIso(), min_supported_version: '1.0.0' }),
);

// ─────────────────────────────── Sürüm ─────────────────────────────────────

app.get('/api/app-version', (req, res) => {
  const appId = req.query.app_id;
  if (appId === 'mutfakapp') {
    return res.json({
      app_id: 'mutfakapp',
      latest: '1.0.0',
      min_supported: '1.0.0',
      download_url: 'https://mock.invalid/mutfakapp_1.0.0.deb',
      notes: 'Mock sürüm kaydı.',
    });
  }
  if (appId === 'musteriapp') {
    return res.json({
      app_id: 'musteriapp',
      latest: '1.0.0',
      min_supported: '1.0.0',
      download_url: null,
      notes: 'Mock sürüm kaydı.',
    });
  }
  // Geçersiz enum değeri bir DOĞRULAMA hatasıdır, "kayıt yok" değil.
  // (E-01 provasında mock 404, gerçek backend 422 dönüyordu; sözleşme
  //  422'de netleştirildi.)
  return fail(res, 'VALIDATION_FAILED', 'Geçersiz uygulama kimliği.', {
    app_id: 'musteriapp veya mutfakapp olmalı.',
  });
});

// ──────────────────────── Yalnızca mock — test kancaları ───────────────────
//
// Bu uçlar gerçek sunucuda YOKTUR. İstemci hatlarının kabul senaryolarını
// (docs/10) elle koşabilmesi için var: yeni sipariş düşürmek, şalteri
// kapatmak, cihaz iptal etmek.

/*
 * ── v2.0 test kancaları ────────────────────────────────────────────────
 * `/__mock/*` uçları sözleşmenin parçası DEĞİL; yalnızca Playwright'ın
 * gerçek akışı izleyebilmesi için var (kodu oku, borç kur, ödemeyi bitir).
 */

/** Son üretilen giriş kodunu okur — SMS'in test karşılığı. */
app.get('/__mock/otp/:phone', (req, res) => {
  const phone = normalizePhone(req.params.phone);
  const code = state.otpCodes.get(phone);

  return code ? res.json({ code }) : res.status(404).json({ code: null });
});

/** Bir müşteriye borç yazar; cari ekranını test etmenin tek yolu. */
app.post('/__mock/ledger/:customerId', (req, res) => {
  const customerId = Number(req.params.customerId);
  state.addLedgerEntry(customerId, {
    date: nowIso().slice(0, 10),
    entry_type: req.body?.entry_type ?? 'debit',
    amount: Number(req.body?.amount ?? 0),
    source: 'order',
    description: req.body?.description ?? 'Test siparişi',
  });

  return res.json({ balance: state.balanceOf(customerId) });
});

/** Abonelik ekler. */
app.post('/__mock/subscriptions', (req, res) => {
  const subscription = {
    id: state.nextSubscriptionId++,
    customer_id: Number(req.body?.customer_id ?? 1),
    status: req.body?.status ?? 'active',
    location_id: state.location.id,
    delivery_type: 'delivery',
    start_date: nowIso().slice(0, 10),
    end_date: null,
    service_days: [1, 2, 3, 4, 5],
    delivery_time_from: '12:00',
    delivery_time_to: '13:00',
    default_quantity: Number(req.body?.default_quantity ?? 25),
    agreed_unit_price: 9500,
    payment_mode: 'account',
    menu_mode: 'fixed_list',
    lines: [{ menu_id: 1, quantity: 1, label: 'Günün menüsü' }],
    delivery_points: [],
    exceptions: [],
    created_at: nowIso(),
  };
  state.subscriptions.push(subscription);

  return res.status(201).json(subscription);
});

/**
 * Cari ödemeyi tamamlar — gerçek sanal POS sayfasının yerini tutar.
 *
 * Deftere ALACAK yazıp siteye geri yönlendiriyor; böylece Playwright
 * "ödedim, bakiye düştü" zincirini uçtan uca izleyebiliyor.
 */
app.get('/__mock/cari-odeme/:hash', (req, res) => {
  const intent = state.accountPayments.get(req.params.hash);
  if (!intent) return res.status(404).send('Ödeme bulunamadı.');

  if (intent.status === 'pending') {
    intent.status = 'succeeded';
    state.addLedgerEntry(intent.customerId, {
      date: nowIso().slice(0, 10),
      entry_type: 'credit',
      amount: intent.amount,
      source: 'payment',
      description: `Online cari ödeme #${intent.id}`,
    });
  }

  const target = req.query.return ?? '/';

  return res.redirect(`${target}?durum=odendi`);
});

app.post('/__mock/reset', (_req, res) => {
  state.reset();
  res.json({ ok: true, orders: state.orders.length });
});

/** Yeni sipariş düşür — KDS'in 3 saniye kuralını ve sesli uyarıyı test etmek için. */
app.post('/__mock/orders', (req, res) => {
  const deliveryType = req.body?.delivery_type ?? 'delivery';
  const order = state.createOrder({
    customerId: req.body?.customer_id ?? 12,
    deliveryType,
    items: req.body?.items ?? [
      { menu_id: 101, quantity: 2, option_value_ids: [31], note: 'Az acılı' },
    ],
    address:
      deliveryType === 'delivery'
        ? {
            line1: 'Örnek Mah. 12. Sk No:3',
            district: 'Çankaya',
            city: 'Ankara',
            note: null,
          }
        : null,
    requestedAt: null,
    paymentMethod: req.body?.payment_method ?? 'cash',
    customerNote: req.body?.customer_note ?? null,
  });
  res.status(201).json(out.kitchenOrderOut(state, order));
});

/** Sipariş alım şalteri — docs/10 S3. */
app.post('/__mock/location', (req, res) => {
  if (typeof req.body?.ordering_enabled === 'boolean') {
    state.location.ordering_enabled = req.body.ordering_enabled;
  }
  if (typeof req.body?.is_open === 'boolean') {
    state.location.is_open = req.body.is_open;
  }
  if (Array.isArray(req.body?.payment_methods)) {
    state.location.payment_methods = req.body.payment_methods;
  }
  res.json(out.locationOut(state.location));
});

/** Cihaz token'ını iptal et — docs/10 S5 adım 5. */
app.post('/__mock/revoke-device/:id', (req, res) => {
  state.revokedDevices.add(Number(req.params.id));
  res.json({ ok: true, revoked: [...state.revokedDevices] });
});

// ─────────────────────────────── Kapanış ───────────────────────────────────

app.use((_req, res) => fail(res, 'NOT_FOUND', 'Böyle bir uç yok.'));

// eslint-disable-next-line no-unused-vars
app.use((err, _req, res, _next) => {
  console.error('[mock] beklenmeyen hata:', err);
  fail(res, 'SERVER_ERROR', 'Beklenmeyen bir hata oluştu.');
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`[mock] BLD mock API http://localhost:${PORT}/api`);
  console.log(`[mock] ${state.orders.length} örnek sipariş, eşleme kodu: ${PAIRING_CODE}`);
});
