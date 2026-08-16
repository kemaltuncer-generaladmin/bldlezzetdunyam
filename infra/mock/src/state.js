// Mock'un bellek içi durumu ve iş kuralları.
//
// Bu dosya sözleşmenin **davranışını** taklit eder, gerçek backend'i değil.
// Amaç: istemci hatlarının artımlı polling, durum geçişi ve idempotentlik
// gibi zor kısımları backend'i beklemeden gerçekten test edebilmesi (X-04).

import {
  addDays,
  businessToday,
  daysBetween,
  instantAt,
  isoWeekday,
} from './business-date.js';
import {
  CUSTOMERS,
  DELIVERY_FEE,
  LOCATION,
  MENU,
  PACKAGE_PRODUCT,
  seedAnnouncements,
  seedClosedDays,
  seedContractSubscription,
  seedDailyMenus,
  seedOrders,
} from './seed.js';

// docs/02-veri-modeli.md §3 — geçiş matrisi.
const TRANSITIONS = {
  yeni: ['onaylandi', 'iptal'],
  onaylandi: ['hazirlaniyor', 'iptal'],
  hazirlaniyor: ['hazir', 'iptal'],
  hazir: ['yolda', 'teslim_edildi', 'iptal'],
  yolda: ['teslim_edildi', 'iptal'],
  teslim_edildi: [],
  iptal: [],
};

/// Fişteki imzalı bağlantıların mock karşılıkları (K-20).
///
/// Sabit değerler: mock'un işi kriptografi değil, "bağlantı var mı yok mu"
/// dallarını KDS'e sunmak.
const MOCK_SITE_URL = 'http://localhost:3000';
const MOCK_API_URL = 'http://localhost:4010';
const MOCK_LINK_EXPIRES = 1786512000;
const MOCK_SIGNATURE = 'mock-imza';

export class MockState {
  constructor() {
    this.reset();
  }

  reset() {
    const now = new Date();
    this.location = structuredClone(LOCATION);
    this.menu = structuredClone(MENU);
    this.packageProduct = structuredClone(PACKAGE_PRODUCT);
    this.customers = structuredClone(CUSTOMERS);
    this.orders = seedOrders(now);
    this.nextOrderId = 5013;

    /*
     * ── Günün menüsü (B-19 / günlük menü satış modeli) ──────────────────
     *
     * Satılan şey artık katalog değil O GÜNÜN menüsü. Menüler bellekte
     * gün gün duruyor; stok da burada, çünkü "kaç porsiyon kaldı" sorusu
     * siparişle birlikte değişen bir durum — statik bir tohum yanıtı
     * veremezdi.
     */
    this.dailyMenus = seedDailyMenus(now);
    this.closedDays = seedClosedDays(now);

    /** token -> { kind: 'customer'|'kitchen', customerId?, deviceId? } */
    this.tokens = new Map();
    this.nextDeviceId = 1;
    this.revokedDevices = new Set();

    /** "orderId:type" -> printed_at — ack idempotentliği için. */
    this.printJobs = new Map();

    /*
     * ── v2.0 yüzeyleri (W-11 / W-13) ───────────────────────────────────
     *
     * Telefonla giriş ve abonelik uçları sözleşmede var ve site artık
     * onları çağırıyor; mock bunları taşımazsa Playwright akışları ilk
     * istekte 404 alır.
     */

    /** phone -> son üretilen kod. Testler bunu `/__mock/otp/:phone` ile okur. */
    this.otpCodes = new Map();

    const seeded = seedContractSubscription(now);
    this.subscriptions = [seeded.subscription];
    this.nextSubscriptionId = seeded.subscription.id + 1;

    /** token -> abonelik sözleşmesi (imzalı bağlantının açtığı belge). */
    this.contracts = new Map([[seeded.contract.token, seeded.contract]]);

    /** paymentId -> abonelik ödeme niyeti. */
    this.subscriptionPayments = new Map();
    this.nextSubscriptionPaymentId = 1;

    /** Uygulama içi duyurular — FCM kalktığı için tek bildirim kanalı. */
    this.announcements = seedAnnouncements(now);

    /** İstemcilerden gelen hata raporları (`POST /client-errors`). */
    this.clientErrors = [];

    /** customerId -> kayıtlı adresler (W-15). */
    this.addresses = new Map();
    this.nextAddressId = 1;
  }

  // ── Adres defteri ─────────────────────────────────────────────────────

  addressesOf(customerId) {
    return this.addresses.get(customerId) ?? [];
  }

  saveAddress(customerId, input) {
    const list = this.addressesOf(customerId);

    const saved = {
      id: this.nextAddressId++,
      label: input.label ?? null,
      line1: String(input.line1 ?? ''),
      district: String(input.district ?? ''),
      city: String(input.city ?? ''),
      note: input.note ?? null,
      // İKİSİ BİRDEN ya da HİÇBİRİ — sözleşme kuralı; yarısı dolu bir
      // koordinat haritada gösterilemez.
      latitude: input.latitude ?? null,
      longitude: input.longitude ?? null,
      is_default: input.is_default === true || list.length === 0,
    };

    if (saved.is_default) {
      for (const item of list) item.is_default = false;
    }

    list.push(saved);
    this.addresses.set(customerId, list);

    return saved;
  }

  updateAddress(customerId, id, input) {
    const list = this.addressesOf(customerId);
    const found = list.find((item) => item.id === id);
    if (!found) return null;

    for (const key of ['label', 'line1', 'district', 'city', 'note', 'latitude', 'longitude']) {
      if (key in input) found[key] = input[key];
    }

    // Aynı anda en fazla bir varsayılan; sunucu bunu kendi garanti ediyor.
    if (input.is_default === true) {
      for (const item of list) item.is_default = item.id === id;
    }

    return found;
  }

  deleteAddress(customerId, id) {
    const list = this.addressesOf(customerId);
    const index = list.findIndex((item) => item.id === id);
    if (index === -1) return false;

    const [removed] = list.splice(index, 1);

    // Varsayılan silindiyse ilk kalan varsayılan olur; defterde varsayılansız
    // adres bırakmak ödeme adımında hiçbirini önceden seçmemek demekti.
    if (removed.is_default && list.length > 0) list[0].is_default = true;

    return true;
  }

  // ── Katalog ───────────────────────────────────────────────────────────

  findMenuItem(menuId) {
    // Paket ürünü kategorilerin dışında duruyor ama SİPARİŞ EDİLEBİLİR:
    // `DailyMenuPackage.menu_id` tam olarak bu kimliği gösteriyor.
    if (menuId === this.packageProduct.id) return this.packageProduct;

    for (const category of this.menu) {
      const item = category.items.find((i) => i.id === menuId);
      if (item) return item;
    }
    return null;
  }

  /** Seçenek farklarının toplamı (kuruş). */
  optionDelta(item, optionValueIds) {
    let delta = 0;
    for (const option of item.options ?? []) {
      for (const value of option.values) {
        if ((optionValueIds ?? []).includes(value.id)) delta += value.price_delta;
      }
    }
    return delta;
  }

  /** Seçenek farkları dahil birim fiyat (kuruş) — günün fiyatı hesaba katılmaz. */
  unitPrice(item, optionValueIds) {
    return item.price + this.optionDelta(item, optionValueIds);
  }

  /** Sipariş kaleminin görünen seçenek adları. */
  optionNames(item, optionValueIds) {
    const names = [];
    for (const option of item.options ?? []) {
      for (const value of option.values) {
        if ((optionValueIds ?? []).includes(value.id)) names.push(value.name);
      }
    }
    return names;
  }

  // ── Günün menüsü ──────────────────────────────────────────────────────

  isServiceDay(date) {
    return (this.location.service_weekdays ?? []).includes(isoWeekday(date));
  }

  closedDayFor(date) {
    return this.closedDays.find((day) => day.date === date) ?? null;
  }

  /** O günün YAYINLANMIŞ menüsü; taslak gün yokmuş gibi davranır. */
  dailyMenuFor(date) {
    return this.dailyMenus.find((day) => day.date === date && day.published) ?? null;
  }

  /** Günün kesim anı (mutlak). Kesim saati tanımsızsa `null`. */
  cutoffAt(date) {
    const cutoff = this.location.order_cutoff;
    return cutoff ? instantAt(date, cutoff) : null;
  }

  /** Gün toplamından kalan porsiyon; tavan yoksa `null` (sınırsız). */
  dayRemaining(day) {
    if (day.day_capacity === null || day.day_capacity === undefined) return null;
    return Math.max(0, day.day_capacity - day.day_sold);
  }

  /**
   * Bir kalemden kalan porsiyon.
   *
   * GÜN TOPLAMI VE ÜRÜN TAVANI BİRLİKTE: hangisi önce dolarsa kalemi kapatır.
   * Yalnız ürün tavanına bakılsaydı, günün son on porsiyonu kaldığında her
   * kalem "bol bol var" görünür ve on birinci sipariş kasada patlardı.
   */
  itemRemaining(day, item) {
    const dayLeft = this.dayRemaining(day);
    const itemLeft =
      item.capacity === null || item.capacity === undefined
        ? null
        : Math.max(0, item.capacity - item.sold);

    if (dayLeft === null) return itemLeft;
    if (itemLeft === null) return dayLeft;

    return Math.min(dayLeft, itemLeft);
  }

  /** Paketten kalan porsiyon — zorunlu kalemlerin en darı belirler. */
  packageRemaining(day) {
    let remaining = this.dayRemaining(day);

    for (const item of day.items) {
      if (!item.is_required) continue;

      const itemLeft = this.itemRemaining(day, item);
      if (itemLeft === null) continue;

      remaining = remaining === null ? itemLeft : Math.min(remaining, itemLeft);
    }

    return remaining;
  }

  /** O gün için geçerli birim fiyat: gün istisnası varsa o, yoksa ürünün fiyatı. */
  dailyUnitPrice(day, item) {
    const product = this.findMenuItem(item.menu_id);
    return item.price_override_kurus ?? product?.price ?? 0;
  }

  /** Kalemlerin tek tek alınması hâlindeki toplam (`DailyMenu.items_total`). */
  itemsTotal(day) {
    return day.items.reduce(
      (total, item) => total + this.dailyUnitPrice(day, item) * Math.max(1, item.quantity),
      0,
    );
  }

  /**
   * Bir günün satılabilirlik kararı — takvim, menü ve sipariş aynı kaynağı
   * okur ki müşteri takvimde açık gördüğü güne sipariş verip 422 almasın.
   *
   * SIRA ÖNEMLİ: en dıştaki, en kalıcı sebep önce söylenir. Hafta sonuna
   * "menü yayınlanmamış" demek, yöneticiyi olmayan bir işi yapmaya
   * yönlendirirdi.
   */
  verdict(date) {
    const today = businessToday();
    const offset = daysBetween(today, date);
    const closedRow = this.closedDayFor(date);
    const weekend = !this.isServiceDay(date);
    const day = this.dailyMenuFor(date);
    /*
     * KESİM ANI YALNIZ SERVİS GÜNÜNDE ANLAMLI. Hafta sonuna ya da bayrama
     * saat yazmak, "08:00'e kadar sipariş verebilirim" beklentisi kurardı;
     * o gün hiç açılmıyor.
     */
    const cutoffAt = weekend || closedRow !== null ? null : this.cutoffAt(date);
    const remaining = day === null ? null : this.dayRemaining(day);

    const cutoffPassed = cutoffAt !== null && Date.now() > Date.parse(cutoffAt);

    const reason =
      offset < 0
        ? 'past'
        : offset > this.location.max_lookahead_days
          ? 'too_far'
          : closedRow !== null
            ? 'closed_day'
            : weekend
              ? 'no_service_day'
              : day === null
                ? 'not_published'
                : cutoffPassed
                  ? 'cutoff_passed'
                  : remaining === 0
                    ? 'sold_out'
                    : null;

    return {
      day,
      date,
      closed: closedRow !== null,
      closed_note: closedRow?.note ?? null,
      weekend,
      cutoff_at: cutoffAt,
      remaining,
      orderable: reason === null,
      reason,
    };
  }

  /**
   * Aralıktaki günler — gün seçiciyi çizmek için.
   *
   * YALNIZ menüsü olan, kapalı olan ya da SERVİS DIŞI olan günler döner.
   * Servis dışı günün listede olması yeni: hafta sonu satış kanalı açık
   * kaldığı için istemcinin "menü yok" ile "bugün hiç pişirmiyoruz"u
   * ayırt edebilmesi gerekiyor — biri yarın açılabilir, öbürü açılmaz.
   */
  calendar(from, to) {
    const days = [];

    for (let cursor = from; daysBetween(cursor, to) >= 0; cursor = addDays(cursor, 1)) {
      const verdict = this.verdict(cursor);

      if (verdict.day === null && !verdict.closed && !verdict.weekend) continue;

      days.push(verdict);
    }

    return days;
  }

  // ── Kimlik ────────────────────────────────────────────────────────────

  issueCustomerToken(customerId) {
    const token = `cus_mock_${customerId}_${this.tokens.size + 1}`;
    this.tokens.set(token, { kind: 'customer', customerId });
    return token;
  }

  issueKitchenToken() {
    const deviceId = this.nextDeviceId++;
    const token = `kdev_mock_${deviceId}`;
    this.tokens.set(token, { kind: 'kitchen', deviceId });
    return { token, deviceId };
  }

  resolveToken(token) {
    const principal = this.tokens.get(token);
    if (!principal) return null;
    if (
      principal.kind === 'kitchen' &&
      this.revokedDevices.has(principal.deviceId)
    ) {
      return { kind: 'revoked' };
    }
    return principal;
  }

  customerById(id) {
    return this.customers.find((c) => c.id === id) ?? null;
  }

  // ── Sipariş ───────────────────────────────────────────────────────────

  orderById(id) {
    return this.orders.find((o) => o.id === id) ?? null;
  }

  /**
   * Bir sipariş kaleminin birim fiyatı (kuruş).
   *
   * Sipariş oluşturulurken fiyat kaleme YAZILIR (`unit_price`); burada
   * hesaplama yalnız tohum siparişleri ve eski kayıtlar için yedek. Menü
   * ertesi gün değiştiğinde geçmiş siparişin tutarı değişmemeli.
   */
  lineUnitPrice(order, line) {
    if (typeof line.unit_price === 'number') return line.unit_price;

    const day = order.service_date ? this.dailyMenuFor(order.service_date) : null;

    if (line.menu_id === this.packageProduct.id) {
      return day?.package_price ?? 0;
    }

    const product = this.findMenuItem(line.menu_id);
    if (!product) return 0;

    const dayItem = day?.items.find((i) => i.menu_id === line.menu_id) ?? null;
    const base = dayItem?.price_override_kurus ?? product.price;

    return base + this.optionDelta(product, line.option_value_ids);
  }

  /** Sipariş kaleminin ekranda görünecek adı. */
  lineName(order, line) {
    if (typeof line.name === 'string' && line.name !== '') return line.name;

    if (line.menu_id === this.packageProduct.id) {
      const day = order.service_date ? this.dailyMenuFor(order.service_date) : null;
      return day?.title ?? this.packageProduct.name;
    }

    return this.findMenuItem(line.menu_id)?.name ?? 'Bilinmeyen ürün';
  }

  /** Sipariş tutarları — her zaman sunucuda hesaplanır. */
  totals(order) {
    let subtotal = 0;
    for (const line of order.items) {
      subtotal += this.lineUnitPrice(order, line) * line.quantity;
    }
    const deliveryFee = order.delivery_type === 'delivery' ? DELIVERY_FEE : 0;
    return { subtotal, deliveryFee, total: subtotal + deliveryFee };
  }

  createOrder({
    customerId,
    deliveryType,
    items,
    address,
    requestedAt,
    paymentMethod,
    customerNote,
    serviceDate,
  }) {
    const now = new Date().toISOString();
    const date = serviceDate ?? businessToday();
    const day = this.dailyMenuFor(date);

    const order = {
      id: this.nextOrderId++,
      customer_id: customerId,
      delivery_type: deliveryType,
      status: 'yeni',
      created_at: now,
      updated_at: now,
      requested_at: requestedAt ?? null,
      service_date: date,
      customer_note: customerNote ?? null,
      address: deliveryType === 'delivery' ? address : null,
      payment: {
        method: paymentMethod,
        status: 'pending',
        ...(paymentMethod === 'online'
          ? { redirect_url: `https://sanalpos.mock/odeme/${this.nextOrderId}` }
          : {}),
      },
      items: items.map((line) => ({
        menu_id: line.menu_id,
        quantity: line.quantity,
        option_value_ids: line.option_value_ids ?? [],
        note: line.note ?? null,
      })),
      status_history: [{ status: 'yeni', at: now }],
    };

    // Fiyat ve ad SİPARİŞE YAZILIR: menü yarın değişince dünkü siparişin
    // tutarı da değişmesin (gerçek sistemde de kalem kopyası tutuluyor).
    for (const line of order.items) {
      line.unit_price = this.lineUnitPrice(order, line);
      line.name = this.lineName(order, line);
    }

    this.orders.push(order);

    if (day !== null) this.consumeStock(day, order.items);

    return order;
  }

  /**
   * Siparişin porsiyonlarını stoktan düşer.
   *
   * Paket bir porsiyon sayılır ve içindeki HER zorunlu kalemi de tüketir:
   * mutfak paketi satarken çorbayı da pişiriyor, çorbanın tavanı da o kadar
   * azalıyor.
   */
  consumeStock(day, lines) {
    for (const line of lines) {
      const isPackage = line.menu_id === this.packageProduct.id;
      day.day_sold += line.quantity;

      for (const item of day.items) {
        if (isPackage ? item.is_required : item.menu_id === line.menu_id) {
          item.sold += line.quantity * Math.max(1, item.quantity);
        }
      }
    }
  }

  canTransition(order, to) {
    const allowed = TRANSITIONS[order.status] ?? [];
    if (!allowed.includes(to)) return false;

    // docs/02 §3: yolda yalnızca adrese gönderimde, teslim_edildi doğrudan
    // yalnızca gel-al'da.
    if (order.status === 'hazir') {
      if (to === 'yolda' && order.delivery_type !== 'delivery') return false;
      if (to === 'teslim_edildi' && order.delivery_type !== 'pickup') {
        return false;
      }
    }
    return true;
  }

  applyTransition(order, to) {
    const now = new Date().toISOString();
    order.status = to;
    order.updated_at = now;
    order.status_history.push({ status: to, at: now });
    return order;
  }

  // ── Abonelik ödemesi ve sözleşmesi ────────────────────────────────────

  subscriptionById(id) {
    return this.subscriptions.find((s) => s.id === id) ?? null;
  }

  /**
   * Ödeme niyeti açar.
   *
   * `online` ödeme her zaman 3D Secure'a düşer (`next_action: 'otp'`);
   * `cash` anında kapanır. İki dal da gerçek: kart ödemesinde banka SMS'i
   * zorunlu, kapıda ödemede tahsilat kuryede. Mobil akış OTP ekranını
   * ancak birinci dal varsa test edebiliyor.
   */
  openSubscriptionPayment(subscription, { amount, period, method }) {
    const id = this.nextSubscriptionPaymentId++;
    const needsOtp = method === 'online';

    const payment = {
      id,
      subscription_id: subscription.id,
      customer_id: subscription.customer_id,
      amount,
      currency: 'TRY',
      period,
      method,
      status: needsOtp ? 'pending' : 'paid',
      next_action: needsOtp ? 'otp' : 'none',
      // Kod rastgele: test "kodu tahmin etme" yoluna sapmasın, gerçek akışı
      // izlesin (`/__mock/payment-otp/:id` ile okunur).
      otp_code: needsOtp ? String(Math.floor(100000 + Math.random() * 900000)) : null,
      created_at: new Date().toISOString(),
      paid_at: needsOtp ? null : new Date().toISOString(),
    };

    this.subscriptionPayments.set(id, payment);

    return payment;
  }

  contractByToken(token) {
    return this.contracts.get(token) ?? null;
  }

  /** İmza tek yönlü: imzalanmış sözleşme yeniden imzalanamaz. */
  signContract(contract, ip) {
    contract.status = 'signed';
    contract.signed_at = new Date().toISOString();
    contract.signed_ip = ip ?? null;

    const subscription = this.subscriptionById(contract.subscription_id);
    if (subscription !== null && subscription.status === 'pending') {
      subscription.status = 'active';
    }

    return contract;
  }

  /** Yürürlükteki duyurular — başlamamış ya da süresi dolmuş olanlar elenir. */
  activeAnnouncements(now = new Date()) {
    const at = now.getTime();

    return this.announcements.filter((item) => {
      const started = item.starts_at === null || Date.parse(item.starts_at) <= at;
      const notEnded = item.ends_at === null || Date.parse(item.ends_at) >= at;
      return started && notEnded;
    });
  }

  /**
   * İstemci hata raporu.
   *
   * SON 100 KAYIT tutuluyor: döngüye giren bir istemci saniyede onlarca
   * rapor gönderebiliyor ve sınırsız dizi mock'un belleğini yiyordu.
   */
  recordClientError(entry) {
    this.clientErrors.push({ ...entry, received_at: new Date().toISOString() });
    if (this.clientErrors.length > 100) this.clientErrors.shift();
  }

  // ── Yazdırma denetimi ─────────────────────────────────────────────────

  /**
   * İdempotent: aynı `(order_id, type, revision)` ÜÇLÜSÜ ikinci kez
   * kaydedilmez (K-20).
   *
   * Revizyon anahtarın parçası olmasaydı, düzenlenen siparişin yeniden
   * basılan fişinin ack'i sessizce yutulur ve `printed_at` hep ilk basımı
   * gösterirdi — elinde iki kâğıt olan kurye hangisinin yeni olduğunu
   * kâğıttaki tek zaman damgasından anlayamazdı.
   *
   * `revision` gönderilmezse `0` sayılır: alanı bilmeyen eski KDS
   * sürümleri çalışmaya devam eder.
   */
  ackPrint(orderId, type, printedAt, revision = 0) {
    const key = `${orderId}:${type}:${revision}`;
    if (this.printJobs.has(key)) return false;
    this.printJobs.set(key, printedAt);
    return true;
  }

  /** Siparişin GÜNCEL revizyonu için basım anı; yoksa `null`. */
  printedAtFor(order, type) {
    return this.printJobs.get(`${order.id}:${type}:${order.revision_no ?? 0}`) ?? null;
  }

  // ── Fişteki imzalı bağlantılar (K-20) ─────────────────────────────────
  //
  // Mock GERÇEK HMAC ÜRETMİYOR ve üretmemeli: burada sınanan şey kriptografi
  // değil, KDS'in bağlantı gelince QR basıp gelmeyince basmaması. Sabit bir
  // imza, golden çıktıyı da belirlenimci tutuyor.

  trackUrl(order) {
    return `${MOCK_SITE_URL}/takip/${order.id}?e=${MOCK_LINK_EXPIRES}&s=${MOCK_SIGNATURE}`;
  }

  payUrl(order) {
    // Ödenmiş siparişin fişine ödeme QR'ı basmak, ikinci kez ödemeye davet
    // etmek olurdu.
    if ((order.payment?.status ?? 'pending') === 'paid') return null;
    return `${MOCK_API_URL}/odeme-simulasyon/mock-${order.id}`
      + `?return=${encodeURIComponent(this.trackUrl(order))}`;
  }

  deliverUrl(order) {
    return `${MOCK_API_URL}/teslimat/${order.id}?e=${MOCK_LINK_EXPIRES}&s=${MOCK_SIGNATURE}`;
  }

  contractUrl(contract) {
    return `${MOCK_SITE_URL}/sozlesme/${contract.token}`;
  }

  // ── Üretim listesi ────────────────────────────────────────────────────

  productionList() {
    const totals = new Map();
    for (const order of this.orders) {
      if (order.status !== 'onaylandi' && order.status !== 'hazirlaniyor') {
        continue;
      }
      for (const line of order.items) {
        const item = this.findMenuItem(line.menu_id);
        if (!item) continue;
        totals.set(item.id, {
          menu_id: item.id,
          name: this.lineName(order, line),
          total: (totals.get(item.id)?.total ?? 0) + line.quantity,
        });
      }
    }
    return [...totals.values()].sort((a, b) => b.total - a.total);
  }
}
