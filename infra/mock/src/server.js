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

import {
  addDays,
  businessDateOf,
  businessToday,
  daysBetween,
  isBusinessDate,
} from './business-date.js';
import { buildDailyMenu, CONTRACT_TOKEN, PAIRING_CODE } from './seed.js';
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

/** Takvim ucunun kabul ettiği azami aralık (`DailyMenuService::MAX_CALENDAR_DAYS`). */
const MAX_CALENDAR_DAYS = 92;

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
    // Kurum alanları serbest metin: fatura başlığına yazılıyor, hiçbir
    // kapıyı açıp kapamıyor (sipariş kapısı kalktı).
    company_name: b.company_name ?? null,
    contact_person: b.contact_person ?? null,
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

/*
 * `POST /me/push-token` KALDIRILDI. Push (FCM) kurulmuyor; bildirim kanalı
 * uygulama içi duyuru (`GET /announcements`) ve SMS. Ucun mock'ta durması,
 * istemci hatlarını kurulmayacak bir altyapıya kod yazmaya davet ediyordu.
 */

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

/** Altı haneli SMS kodu. Sabit değil: test kodu okusun, tahmin etmesin. */
function newOtpCode() {
  return String(Math.floor(100000 + Math.random() * 900000));
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
    state.otpCodes.set(phone, newOtpCode());
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

// ──────────────────────────── Duyurular ────────────────────────────────────
//
// FCM KALKTI. Push yerine uygulama içi duyuru var: müşteri uygulamayı
// açtığında görüyor. Uç girişsiz, çünkü duyuru herkese aynı — girişli
// kullanıcıya özel bildirim yok.

app.get('/api/announcements', (_req, res) =>
  res.json({
    data: state.activeAnnouncements().map(out.announcementOut),
    server_time: nowIso(),
  }),
);

// ──────────────────────── İstemci hata raporları ───────────────────────────
//
// GİRİŞSİZ ve 204. Rapor gönderen istemci çoğu zaman zaten bozuk bir
// durumda; oturum arayıp 401 döndürmek, en çok ihtiyaç duyulan raporu
// kaybetmek olurdu. Gövde de doğrulanmıyor: yarım bir rapor, hiç rapor
// olmamasından iyidir.

app.post('/api/client-errors', (req, res) => {
  const b = req.body ?? {};

  state.recordClientError({
    app_id: req.get('X-App-Id') ?? null,
    app_version: req.get('X-App-Version') ?? null,
    message: typeof b.message === 'string' ? b.message : '(mesajsız)',
    stack: typeof b.stack === 'string' ? b.stack : null,
    context: b.context ?? null,
    occurred_at: typeof b.occurred_at === 'string' ? b.occurred_at : nowIso(),
  });

  return res.status(204).end();
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
  if (!isBusinessDate(date)) {
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

// ───────────────────── Abonelik ödemesi (peşin dönem) ──────────────────────
//
// Cari hesap kalktığı için abonelik artık DÖNEM BAŞINDA ödeniyor. `online`
// dalı 3D Secure'a düşüp `next_action: 'otp'` döndürüyor; mobilin OTP
// ekranı ancak bu dal varsa denenebiliyor.

/** Aylık varsayılan tutar: porsiyon fiyatı × günlük adet × 20 iş günü. */
function monthlyAmountOf(subscription) {
  return (subscription.agreed_unit_price ?? 0) * subscription.default_quantity * 20;
}

function ownSubscription(req) {
  return (
    state.subscriptions.find(
      (s) => s.id === Number(req.params.id) && s.customer_id === req.customerId,
    ) ?? null
  );
}

app.post('/api/subscriptions/:id/payments', requireCustomer, (req, res) => {
  const subscription = ownSubscription(req);
  if (!subscription) return fail(res, 'NOT_FOUND', 'Abonelik bulunamadı.');

  const method = req.body?.payment_method ?? 'online';
  if (!state.location.payment_methods.includes(method)) {
    return fail(res, 'VALIDATION_FAILED', 'Bu ödeme yöntemi şu anda kullanılamıyor.', {
      payment_method: state.location.payment_methods,
    });
  }

  const period = String(req.body?.period ?? nowIso().slice(0, 7));
  if (!/^\d{4}-\d{2}$/.test(period)) {
    return fail(res, 'VALIDATION_FAILED', 'Dönem YYYY-AA biçiminde olmalı.', { period });
  }

  const amount = req.body?.amount === undefined
    ? monthlyAmountOf(subscription)
    : Number(req.body.amount);

  if (!Number.isInteger(amount) || amount <= 0) {
    return fail(res, 'VALIDATION_FAILED', 'Ödenecek tutar belirtilmeli.', {
      amount: 'Kuruş cinsinden pozitif tam sayı olmalı.',
    });
  }

  const payment = state.openSubscriptionPayment(subscription, { amount, period, method });

  return res.status(201).json(out.subscriptionPaymentOut(payment));
});

app.post('/api/subscriptions/:id/payments/confirm', requireCustomer, (req, res) => {
  const subscription = ownSubscription(req);
  if (!subscription) return fail(res, 'NOT_FOUND', 'Abonelik bulunamadı.');

  const payment = state.subscriptionPayments.get(Number(req.body?.payment_id));
  if (!payment || payment.subscription_id !== subscription.id) {
    return fail(res, 'NOT_FOUND', 'Ödeme bulunamadı.');
  }

  // İDEMPOTENT: ağ koptuğu için ikinci kez onaylayan istemci hata değil,
  // aynı sonucu görmeli.
  if (payment.status === 'paid') {
    return res.json(out.subscriptionPaymentOut(payment));
  }

  if (payment.otp_code !== String(req.body?.code ?? '')) {
    return fail(res, 'VALIDATION_FAILED', 'Kod hatalı.', { code: 'Doğrulanamadı.' });
  }

  payment.status = 'paid';
  payment.next_action = 'none';
  payment.paid_at = nowIso();
  payment.otp_code = null;

  return res.json(out.subscriptionPaymentOut(payment));
});

// ───────────────────── Abonelik sözleşmesi (imzalı link) ───────────────────
//
// GİRİŞSİZ: sözleşmeyi imzalayan kişi, aboneliği kuran kişiden başkası
// olabiliyor (muhasebe, yetkili imza). Yetki bağlantının içindeki
// anahtarda; onay SMS koduyla veriliyor.

app.get('/api/contracts/:token', (req, res) => {
  const contract = state.contractByToken(req.params.token);
  if (!contract) return fail(res, 'NOT_FOUND', 'Sözleşme bulunamadı ya da bağlantı geçersiz.');

  return res.json(out.contractOut(state, contract));
});

app.post('/api/contracts/:token/otp', (req, res) => {
  const contract = state.contractByToken(req.params.token);
  if (!contract) return fail(res, 'NOT_FOUND', 'Sözleşme bulunamadı ya da bağlantı geçersiz.');

  if (contract.status === 'signed') {
    return fail(res, 'VALIDATION_FAILED', 'Sözleşme zaten imzalanmış.', {
      signed_at: contract.signed_at,
    });
  }

  /*
   * Kod GİRİŞ KODLARIYLA AYNI HAVUZDA duruyor (`/__mock/otp/:phone` onu da
   * okuyor). Gerçekte de öyle: bir telefona aynı anda tek SMS gidiyor ve
   * testin ayrı bir kanca öğrenmesine gerek kalmıyor.
   */
  state.otpCodes.set(normalizePhone(contract.signer_phone), newOtpCode());

  return res.status(202).json({
    message: 'Onay kodu gönderildi.',
    expires_in: 300,
    resend_after: 60,
  });
});

app.post('/api/contracts/:token', (req, res) => {
  const contract = state.contractByToken(req.params.token);
  if (!contract) return fail(res, 'NOT_FOUND', 'Sözleşme bulunamadı ya da bağlantı geçersiz.');

  if (contract.status === 'signed') {
    return fail(res, 'VALIDATION_FAILED', 'Sözleşme zaten imzalanmış.', {
      signed_at: contract.signed_at,
    });
  }

  const phone = normalizePhone(contract.signer_phone);
  const expected = state.otpCodes.get(phone);
  const code = String(req.body?.code ?? '');

  if (!expected || expected !== code) {
    return fail(res, 'VALIDATION_FAILED', 'Kod hatalı.', { code: 'Doğrulanamadı.' });
  }

  // Tek kullanımlık.
  state.otpCodes.delete(phone);
  state.signContract(contract, req.ip ?? null);

  return res.json(out.contractOut(state, contract));
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

// ───────────────────────────── Günün menüsü ────────────────────────────────
//
// SATILABİLİR OLAN YALNIZ BUDUR. `/locations/{id}/menu` katalogu döndürmeye
// devam ediyor (SEO ve ürün sayfaları) ama sipariş yalnız o günün
// menüsünden verilebiliyor; `POST /orders` bunu yeniden denetliyor.

/** Sorgudaki günü çözer; geçersiz biçim `422`, boş ise bugün. */
function resolveQueryDate(res, raw, field, fallback) {
  if (raw === undefined || raw === null || String(raw).trim() === '') return fallback;

  const date = String(raw).trim();
  if (!isBusinessDate(date)) {
    fail(res, 'VALIDATION_FAILED', 'Tarih YYYY-AA-GG biçiminde ve geçerli olmalı.', {
      [field]: date,
    });
    return null;
  }

  return date;
}

app.get('/api/locations/:id/daily-menu', (req, res) => {
  if (Number(req.params.id) !== state.location.id) {
    return fail(res, 'NOT_FOUND', 'Vitrin bulunamadı.');
  }

  const date = resolveQueryDate(res, req.query.date, 'date', businessToday());
  if (date === null) return undefined;

  return res.json({ data: out.dailyMenuOut(state, state.verdict(date)) });
});

app.get('/api/locations/:id/menu-calendar', (req, res) => {
  if (Number(req.params.id) !== state.location.id) {
    return fail(res, 'NOT_FOUND', 'Vitrin bulunamadı.');
  }

  const from = resolveQueryDate(res, req.query.from, 'from', businessToday());
  if (from === null) return undefined;

  const to = resolveQueryDate(res, req.query.to, 'to', addDays(from, 30));
  if (to === null) return undefined;

  if (daysBetween(from, to) < 0) {
    return fail(res, 'VALIDATION_FAILED', 'Bitiş günü başlangıçtan önce olamaz.', { from, to });
  }
  if (daysBetween(from, to) + 1 > MAX_CALENDAR_DAYS) {
    return fail(
      res,
      'VALIDATION_FAILED',
      `Takvim aralığı en fazla ${MAX_CALENDAR_DAYS} gün olabilir.`,
      { from, to },
    );
  }

  return res.json({
    data: state.calendar(from, to).map((verdict) => out.menuCalendarDayOut(state, verdict)),
  });
});

// ─────────────────────────────── Sipariş ───────────────────────────────────

/** Günün satılamama sebebini sözleşmedeki hata koduna çevirir. */
function failForDay(res, verdict) {
  const details = { service_date: verdict.date, reason: verdict.reason };

  switch (verdict.reason) {
    case 'closed_day':
      return fail(
        res,
        'LOCATION_CLOSED',
        verdict.closed_note !== null
          ? `O gün kapalıyız: ${verdict.closed_note}`
          : 'O gün kapalıyız.',
        details,
      );
    case 'no_service_day':
      return fail(
        res,
        'LOCATION_CLOSED',
        'Hafta sonu menü çıkmıyor. Hafta içi bir gün seçin.',
        details,
      );
    case 'cutoff_passed':
      return fail(
        res,
        'LOCATION_CLOSED',
        'Bu günün sipariş kabul saati doldu. Sonraki güne sipariş verebilirsiniz.',
        details,
      );
    case 'sold_out':
      return fail(res, 'ITEM_UNAVAILABLE', 'Bu günün porsiyonları tükendi.', details);
    case 'past':
      return fail(res, 'VALIDATION_FAILED', 'Geçmiş bir güne sipariş verilemez.', details);
    case 'too_far':
      return fail(res, 'VALIDATION_FAILED', 'Bu tarih için henüz sipariş alınmıyor.', details);
    default:
      return fail(res, 'VALIDATION_FAILED', 'O gün için menü yayınlanmadı.', details);
  }
}

/**
 * Bir sipariş kalemini günün menüsüne karşı denetler.
 *
 * `LineResolver::assertInDailyMenu` ile aynı sıra: menüde mi, gün tek tek
 * satışa açık mı, kalem tek başına satılıyor mu, stok var mı.
 */
function failForLine(res, day, line) {
  if (line.menu_id === state.packageProduct.id) {
    if (day.package_price === null || day.package_price === undefined) {
      return fail(res, 'ITEM_UNAVAILABLE', 'O gün paket satılmıyor.', {
        menu_id: line.menu_id,
      });
    }
    if (state.packageRemaining(day) === 0) {
      return fail(res, 'ITEM_UNAVAILABLE', 'Günün menüsü tükendi.', {
        menu_id: line.menu_id,
      });
    }
    return null;
  }

  const product = state.findMenuItem(line.menu_id);
  const dayItem = day.items.find((item) => item.menu_id === line.menu_id) ?? null;

  if (product === null || dayItem === null) {
    return fail(res, 'ITEM_UNAVAILABLE', 'Ürün o günün menüsünde yok.', {
      menu_id: line.menu_id,
    });
  }
  if (!day.components_sellable) {
    return fail(res, 'ITEM_UNAVAILABLE', 'O günün menüsü yalnız bütün olarak satılıyor.', {
      menu_id: line.menu_id,
    });
  }
  if (!dayItem.sellable_alone) {
    return fail(
      res,
      'ITEM_UNAVAILABLE',
      `${product.name} yalnız menünün içinde veriliyor, tek başına satılmıyor.`,
      { menu_id: line.menu_id },
    );
  }
  if (!product.is_available || state.itemRemaining(day, dayItem) === 0) {
    return fail(res, 'ITEM_UNAVAILABLE', `${product.name} şu anda tükendi.`, {
      menu_id: line.menu_id,
    });
  }

  return null;
}

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
    if (!Number.isInteger(line.quantity) || line.quantity < 1) {
      return fail(res, 'VALIDATION_FAILED', 'Adet en az 1 olmalı.', {
        menu_id: line.menu_id,
      });
    }
  }

  // ── Servis günü ────────────────────────────────────────────────────────
  const serviceDate = resolveQueryDate(res, b.service_date, 'service_date', businessToday());
  if (serviceDate === null) return undefined;

  /*
   * İSTENEN TESLİM ZAMANI SERVİS GÜNÜNE AİT OLMALI. "Cuma menüsünü perşembe
   * 12:00'ye" gibi bir sipariş mutfağın karşılayamayacağı bir şey; sessizce
   * birini seçmek ya yanlış gün pişirir ya yanlış saatte gönderir.
   */
  if (b.requested_at) {
    const requestedDay = businessDateOf(new Date(b.requested_at));
    if (requestedDay !== serviceDate) {
      return fail(res, 'VALIDATION_FAILED', 'İstenen teslim zamanı, seçilen servis gününe ait değil.', {
        service_date: serviceDate,
        requested_at: requestedDay,
      });
    }
  }

  if (state.location.daily_menu_enabled) {
    const verdict = state.verdict(serviceDate);
    if (!verdict.orderable) return failForDay(res, verdict);

    for (const line of b.items) {
      const failure = failForLine(res, verdict.day, line);
      if (failure) return failure;
    }
  } else {
    // Günlük menü şalteri kapalıyken eski katalog akışı aynen çalışır.
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
    }
  }

  /*
   * ASGARİ TUTAR SİPARİŞ AÇILMADAN ÖNCE denetleniyor. Önce oluşturup sonra
   * geri almak, stoktan düşülen porsiyonları geri koymayı da gerektiriyordu
   * ve bir gün biri o satırı unutup stoğu sızdıracaktı.
   */
  const preview = {
    service_date: serviceDate,
    delivery_type: b.delivery_type,
    items: b.items.map((line) => ({
      menu_id: line.menu_id,
      quantity: line.quantity,
      option_value_ids: line.option_value_ids ?? [],
    })),
  };
  const { total } = state.totals(preview);

  if (total < state.location.min_order_total) {
    return fail(
      res,
      'VALIDATION_FAILED',
      'Asgari sipariş tutarının altındasınız.',
      { min_order_total: state.location.min_order_total, total },
    );
  }

  const order = state.createOrder({
    customerId: req.customerId,
    deliveryType: b.delivery_type,
    items: b.items,
    address: b.address ?? null,
    requestedAt: b.requested_at ?? null,
    paymentMethod: b.payment_method,
    customerNote: b.customer_note ?? null,
    serviceDate,
  });

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

/**
 * Fişteki takip QR'ının açtığı girişsiz uç (K-20).
 *
 * `requireCustomer` YOK — test edilen şey tam olarak bu: kâğıda basılan
 * kareyi okutan müşteri giriş ekranı görmemeli. Yetki `e`/`s` imzasında;
 * mock imzayı sabit tutuyor (kriptografi sunucunun işi, mock'un değil) ama
 * PARAMETRELERİN VARLIĞINI arıyor, yoksa istemcinin imzayı hiç göndermediği
 * bir hata mock'a karşı fark edilmezdi.
 */
app.get('/api/public/orders/:id/tracking', (req, res) => {
  const { e: expires, s: signature } = req.query;
  if (!expires || !signature) {
    return fail(res, 'FORBIDDEN', 'Takip bağlantısı geçersiz.');
  }

  const order = state.orderById(Number(req.params.id));
  if (!order) return fail(res, 'NOT_FOUND', 'Sipariş bulunamadı.');

  return res.json(out.publicTrackingOut(state, order));
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
  // `kurye` K-20'den beri otomatik basılmıyor ama uç duruyor: personel
  // kâğıt sıkışmasında elle yeniden bastırabiliyor.
  if (type === 'kurye') return res.json(out.courierReceiptOut(state, order));

  return fail(res, 'VALIDATION_FAILED', 'Fiş tipi geçersiz.', {
    type: 'mutfak, musteri veya kurye olmalı.',
  });
});

app.post(
  '/api/kitchen/print-jobs/:orderId/ack',
  requireKitchen,
  (req, res) => {
    const order = state.orderById(Number(req.params.orderId));
    if (!order) return fail(res, 'NOT_FOUND', 'Sipariş bulunamadı.');

    const { type, printed_at: printedAt, revision } = req.body ?? {};
    if (!['mutfak', 'musteri', 'kurye'].includes(type)) {
      return fail(res, 'VALIDATION_FAILED', 'Fiş tipi geçersiz.', {
        type: 'mutfak, musteri veya kurye olmalı.',
      });
    }
    // İdempotent: aynı (sipariş, tip, revizyon) üçlüsü için ikinci çağrı da
    // 204 döner, yeni kayıt açmaz. `revision` isteğe bağlı — göndermeyen
    // eski KDS sürümleri `0` kovasına düşer (K-20).
    state.ackPrint(order.id, type, printedAt ?? nowIso(), Number(revision ?? 0));
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
// kapatmak, cihaz iptal etmek, belirlenimci bir menü günü kurmak.

/** Son üretilen SMS kodunu okur — giriş ve sözleşme onayı aynı havuzda. */
app.get('/__mock/otp/:phone', (req, res) => {
  const phone = normalizePhone(req.params.phone);
  const code = state.otpCodes.get(phone);

  return code ? res.json({ code }) : res.status(404).json({ code: null });
});

/** Abonelik ödemesinin banka kodunu okur (3D Secure SMS'inin karşılığı). */
app.get('/__mock/payment-otp/:id', (req, res) => {
  const payment = state.subscriptionPayments.get(Number(req.params.id));
  const code = payment?.otp_code ?? null;

  return code ? res.json({ code }) : res.status(404).json({ code: null });
});

/** Abonelik ekler. */
app.post('/__mock/subscriptions', (req, res) => {
  const today = businessToday();
  const subscription = {
    id: state.nextSubscriptionId++,
    customer_id: Number(req.body?.customer_id ?? 12),
    status: req.body?.status ?? 'active',
    location_id: state.location.id,
    delivery_type: 'delivery',
    start_date: today,
    end_date: null,
    service_days: [...state.location.service_weekdays],
    delivery_time_from: '12:00',
    delivery_time_to: '13:00',
    default_quantity: Number(req.body?.default_quantity ?? 25),
    agreed_unit_price: 29000,
    // Cari kalktı: abonelik dönem başında peşin ödeniyor.
    payment_mode: 'prepaid_monthly',
    // Abonelik günün menüsünü otomatik alır; abone gün atlayabilir.
    menu_mode: 'daily_menu',
    lines: [],
    delivery_points: [],
    exceptions: [],
    created_at: nowIso(),
  };
  state.subscriptions.push(subscription);

  return res.status(201).json(subscription);
});

/** Sözleşme açar — imzalı bağlantı akışını kurmanın tek yolu. */
app.post('/__mock/contracts', (req, res) => {
  const subscriptionId = Number(req.body?.subscription_id ?? 0);
  const subscription = state.subscriptionById(subscriptionId);
  if (!subscription) return res.status(404).json({ error: 'Abonelik bulunamadı.' });

  const customer = state.customerById(subscription.customer_id);
  const token = String(req.body?.token ?? `SOZLESME-${subscriptionId}`);

  const contract = {
    token,
    subscription_id: subscriptionId,
    customer_id: subscription.customer_id,
    status: 'pending',
    title: 'Abonelik Sözleşmesi',
    body: 'Mock sözleşme metni.',
    signer_name: customer ? `${customer.first_name} ${customer.last_name}` : 'Bilinmiyor',
    signer_phone: customer?.telephone ?? '5550000000',
    signed_at: null,
    signed_ip: null,
    created_at: nowIso(),
  };
  state.contracts.set(token, contract);

  return res.status(201).json(out.contractOut(state, contract));
});

/**
 * Bir günün menüsünü kurar ya da düzenler.
 *
 * TOHUM HAFTANIN GÜNÜNE GÖRE DEĞİŞİYOR: cuma koşan bir test ile pazartesi
 * koşan aynı testin gördüğü gün aynı değil. Belirlenimci bir "sipariş
 * verilebilir gün" ya da "tükenmiş gün" isteyen test bu kanca ile kendi
 * zeminini kuruyor.
 */
app.post('/__mock/daily-menu/:date', (req, res) => {
  const date = String(req.params.date);
  if (!isBusinessDate(date)) {
    return res.status(422).json({ error: 'Tarih YYYY-AA-GG olmalı.' });
  }

  let day = state.dailyMenus.find((entry) => entry.date === date) ?? null;

  if (day === null) {
    day = buildDailyMenu(date, {
      id: 9900 + state.dailyMenus.length,
      template: Number(req.body?.template ?? 0),
    });
    state.dailyMenus.push(day);
  }

  const b = req.body ?? {};
  if (typeof b.published === 'boolean') day.published = b.published;
  if (typeof b.components_sellable === 'boolean') day.components_sellable = b.components_sellable;
  if ('package_price' in b) day.package_price = b.package_price;
  if ('day_capacity' in b) day.day_capacity = b.day_capacity;
  if (Number.isInteger(b.day_sold)) day.day_sold = b.day_sold;
  if (Array.isArray(b.image_urls)) day.image_urls = b.image_urls.slice(0, 4);

  for (const patch of b.items ?? []) {
    const item = day.items.find((entry) => entry.menu_id === Number(patch.menu_id));
    if (!item) continue;
    if ('capacity' in patch) item.capacity = patch.capacity;
    if (Number.isInteger(patch.sold)) item.sold = patch.sold;
    if (typeof patch.sellable_alone === 'boolean') item.sellable_alone = patch.sellable_alone;
  }

  return res.json(out.dailyMenuOut(state, state.verdict(date)));
});

/** Kapalı gün ekler/kaldırır — bayram dalını denemenin tek yolu. */
app.post('/__mock/closed-days/:date', (req, res) => {
  const date = String(req.params.date);
  if (!isBusinessDate(date)) {
    return res.status(422).json({ error: 'Tarih YYYY-AA-GG olmalı.' });
  }

  state.closedDays = state.closedDays.filter((day) => day.date !== date);
  if (req.body?.closed !== false) {
    state.closedDays.push({ date, note: req.body?.note ?? 'Kapalı gün' });
  }

  return res.json({ data: state.closedDays });
});

/** Toplanan istemci hata raporlarını okur. */
app.get('/__mock/client-errors', (_req, res) =>
  res.json({ data: state.clientErrors }),
);

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
    serviceDate: req.body?.service_date ?? businessToday(),
  });
  res.status(201).json(out.kitchenOrderOut(state, order));
});

/** Sipariş alım şalteri ve vitrin ayarları — docs/10 S3. */
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
  if (typeof req.body?.daily_menu_enabled === 'boolean') {
    state.location.daily_menu_enabled = req.body.daily_menu_enabled;
  }
  // `null` geçerli bir değer: kesim saati olmayan vitrinde gün hiç kapanmaz.
  if ('order_cutoff' in (req.body ?? {})) {
    state.location.order_cutoff = req.body.order_cutoff;
  }
  if (Array.isArray(req.body?.service_weekdays)) {
    state.location.service_weekdays = req.body.service_weekdays;
  }
  if (Number.isInteger(req.body?.max_lookahead_days)) {
    state.location.max_lookahead_days = req.body.max_lookahead_days;
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
  console.log(`[mock] ${state.dailyMenus.length} günlük menü, sözleşme anahtarı: ${CONTRACT_TOKEN}`);
});
