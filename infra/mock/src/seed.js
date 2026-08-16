/*
 * ÜRÜN GÖRSELLERİ BİLİNÇLİ OLARAK `null`.
 *
 * Burada rastgele stok fotoğraf (picsum.photos) döndürülüyordu ve catering
 * menüsünde üzüm, tren rayı, yağmurdaki insan gibi alakasız kareler
 * çıkıyordu — site bozuk görünüyordu ve "bu yemekler bunlar mı?" sorusunu
 * doğuruyordu.
 *
 * `null` gelince arayüz marka renginde çizilmiş bir yer tutucu gösteriyor
 * (`website/components/product-image.tsx`); bu, alakasız bir fotoğraftan çok
 * daha dürüst ve düzenli duruyor. Gerçek ürün fotoğrafları admin panelden
 * yüklendiğinde `image_url` dolu gelecek ve yer tutucu kendiliğinden
 * devreden çıkacak.
 *
 * Aynı karar `DailyMenu.image_urls` için de geçerli: dizi boş dönüyor.
 * Erişilemeyen bir adres koymak, kırık resim ikonu üretmekten başka bir işe
 * yaramazdı. Galeri yolunu denemek isteyen test `/__mock/daily-menu` kancası
 * ile o günün adreslerini kendisi yazabiliyor.
 */
// Örnek veri. Tutarlar kuruş cinsinden tam sayıdır (docs/03 §1.3).
//
// 3 kategori, 12 ürün, 5 sipariş — siparişler durum makinesinin farklı
// noktalarına ve iki teslimat tipine yayılmış durumda ki istemciler her hali
// mock'ta görebilsin.

import { addDays, businessToday, isoWeekday } from './business-date.js';

/** ISO hafta günleri (1 Pazartesi .. 7 Pazar) — mutfağın çalıştığı günler. */
export const SERVICE_WEEKDAYS = [1, 2, 3, 4, 5];

export const LOCATION = {
  id: 1,
  name: 'Benim Lezzet Dünyam',
  slug: 'catering',
  is_open: true,
  ordering_enabled: true,
  /*
   * SABAH KESİMİ. Eski model gün sonunda (16:00) kapanıyordu; günlük menü
   * modelinde mutfak sabah pişirmeye başladığı için gün KENDİ sabahında
   * kapanır. Sonuç: gün içinde bakan müşteri bugünü kapalı, yarını açık
   * görür — ekranların bunu doğal karşılaması gerekiyor.
   */
  order_cutoff: '08:00',
  daily_menu_enabled: true,
  service_weekdays: SERVICE_WEEKDAYS,
  /*
   * En fazla 7 gün ileri sipariş. Sözleşmedeki varsayılan 30'du; günlük
   * menü modelinde mutfak bir haftadan öteye taahhüt vermiyor.
   */
  max_lookahead_days: 7,
  min_order_total: 25000,
  delivery_fee: 4000,
  // Cari hesap kalktı: geriye online ve kapıda nakit kaldı.
  payment_methods: ['online', 'cash'],
  /*
   * Teslim süresi tahmini (docs/openapi.yaml `LocationEta`). Gerçek sunucu
   * bunu siparişlerden ölçüyor; mock'ta ölçecek geçmiş yok, bu yüzden
   * `configured` ve gerçek sunucunun ilk kurulumdaki değerleriyle aynı.
   * Gel-al'da yol süresi olmadığı için aralık daha dar.
   */
  eta: {
    delivery: { min_minutes: 60, max_minutes: 85, source: 'configured', busy: false },
    pickup: { min_minutes: 40, max_minutes: 55, source: 'configured', busy: false },
  },
};

export const DELIVERY_FEE = 4000;

export const MENU = [
  {
    id: 1,
    name: 'Ana Yemekler',
    sort: 1,
    items: [
      {
        id: 101,
        name: 'Tavuk Sote',
        description: 'Pilav ile servis edilir',
        price: 18500,
        currency: 'TRY',
        image_url: null,
        is_available: true,
        allergens: ['gluten'],
        options: [
          {
            id: 9,
            name: 'Porsiyon',
            type: 'radio',
            required: true,
            values: [
              { id: 31, name: 'Normal', price_delta: 0 },
              { id: 32, name: 'Büyük', price_delta: 4000 },
            ],
          },
        ],
      },
      {
        id: 102,
        name: 'Etli Kuru Fasulye',
        description: 'Pirinç pilavı ve turşu ile',
        price: 19500,
        currency: 'TRY',
        image_url: null,
        is_available: true,
        allergens: [],
        options: [
          {
            id: 9,
            name: 'Porsiyon',
            type: 'radio',
            required: true,
            values: [
              { id: 31, name: 'Normal', price_delta: 0 },
              { id: 32, name: 'Büyük', price_delta: 4000 },
            ],
          },
        ],
      },
      {
        id: 103,
        name: 'Fırın Tavuk But',
        description: 'Sebzeli, fırında',
        price: 21000,
        currency: 'TRY',
        image_url: null,
        is_available: true,
        allergens: [],
        options: [],
      },
      {
        id: 104,
        name: 'Karnıyarık',
        description: 'Kıymalı patlıcan, pilav ile',
        price: 20000,
        currency: 'TRY',
        image_url: null,
        is_available: true,
        allergens: [],
        options: [],
      },
      {
        id: 105,
        name: 'Izgara Köfte',
        description: 'Közlenmiş biber ve pilav ile',
        price: 24500,
        currency: 'TRY',
        image_url: null,
        // Bilinçli olarak tükendi: istemciler soluk gösterim ve
        // ITEM_UNAVAILABLE hatasını mock'ta deneyebilsin.
        is_available: false,
        allergens: ['gluten'],
        options: [],
      },
    ],
  },
  {
    id: 2,
    name: 'Çorbalar ve Salatalar',
    sort: 2,
    items: [
      {
        id: 118,
        name: 'Mercimek Çorbası',
        description: 'Limon ve kruton ile',
        price: 8500,
        currency: 'TRY',
        image_url: null,
        is_available: true,
        allergens: ['gluten'],
        options: [],
      },
      {
        id: 119,
        name: 'Ezogelin Çorbası',
        description: 'Naneli tereyağı ile',
        price: 8500,
        currency: 'TRY',
        image_url: null,
        is_available: true,
        allergens: [],
        options: [],
      },
      {
        id: 120,
        name: 'Mevsim Salata',
        description: 'Zeytinyağlı, mevsim yeşillikleri',
        price: 9500,
        currency: 'TRY',
        image_url: null,
        is_available: true,
        allergens: [],
        options: [
          {
            id: 12,
            name: 'Ekstra',
            type: 'checkbox',
            required: false,
            values: [
              { id: 41, name: 'Beyaz peynir', price_delta: 2500 },
              { id: 42, name: 'Ceviz', price_delta: 3000 },
            ],
          },
        ],
      },
      {
        id: 121,
        name: 'Çoban Salata',
        description: 'Domates, salatalık, biber',
        price: 8000,
        currency: 'TRY',
        image_url: null,
        is_available: true,
        allergens: [],
        options: [],
      },
    ],
  },
  {
    id: 3,
    name: 'Tatlılar ve İçecekler',
    sort: 3,
    items: [
      {
        id: 130,
        name: 'Sütlaç',
        description: 'Fırında, tarçınlı',
        price: 7500,
        currency: 'TRY',
        image_url: null,
        is_available: true,
        allergens: ['süt'],
        options: [],
      },
      {
        id: 131,
        name: 'Kemalpaşa Tatlısı',
        description: 'Şerbetli, kaymak ile',
        price: 9000,
        currency: 'TRY',
        image_url: null,
        is_available: true,
        allergens: ['gluten', 'süt'],
        options: [],
      },
      {
        id: 132,
        name: 'Ayran',
        description: '300 ml',
        price: 3000,
        currency: 'TRY',
        image_url: null,
        is_available: true,
        allergens: ['süt'],
        options: [],
      },
    ],
  },
];

/**
 * Paketin sipariş edilebilir ürün karşılığı (`LocationGate::dailyPackageMenuId`).
 *
 * KATEGORİLERİN DIŞINDA duruyor: `/locations/{id}/menu` katalogu, mutfağın
 * pişirdiği yemeklerin listesi. Paket bir yemek değil, o günün bütünü —
 * katalogda görünseydi vitrinde fiyatsız bir "Günün Menüsü" kartı çıkardı,
 * çünkü paketin fiyatı ürüne değil GÜNE ait.
 */
export const PACKAGE_PRODUCT = {
  id: 100,
  name: 'Günün Menüsü',
  description: 'O günün menüsünün tamamı.',
  // Fiyat güne aittir; buradaki sıfır asla ekrana çıkmaz (bkz. state.unitPriceOf).
  price: 0,
  currency: 'TRY',
  image_url: null,
  is_available: true,
  allergens: [],
  options: [],
};

/**
 * Gün şablonları. Yayınlanan her iş günü sırayla birini alır.
 *
 * `is_required` paketin bileşenini belirler (zorunlu kalem tükenirse paket
 * de düşer). `sellable_alone` yanlış olan kalem — ekmek, ayran — YALNIZ
 * paketin içinde verilir; tek başına sepete eklenemez.
 */
const DAILY_MENU_TEMPLATES = [
  {
    title: 'Ev Yemeği Menüsü',
    description: 'Tavuk sote, mercimek çorbası ve yanında ayran.',
    package_price: 31000,
    items: [
      { menu_id: 101, is_required: true, sellable_alone: true, price_override_kurus: 17500 },
      { menu_id: 118, is_required: true, sellable_alone: true, price_override_kurus: null },
      { menu_id: 132, is_required: true, sellable_alone: false, price_override_kurus: null },
      { menu_id: 130, is_required: false, sellable_alone: true, price_override_kurus: null },
    ],
  },
  {
    title: 'Kuru Fasulye Günü',
    description: 'Etli kuru fasulye, ezogelin çorbası, çoban salata.',
    package_price: 32500,
    items: [
      { menu_id: 102, is_required: true, sellable_alone: true, price_override_kurus: 18500 },
      { menu_id: 119, is_required: true, sellable_alone: true, price_override_kurus: null },
      { menu_id: 121, is_required: true, sellable_alone: true, price_override_kurus: null },
      { menu_id: 132, is_required: true, sellable_alone: false, price_override_kurus: null },
    ],
  },
  {
    title: 'Fırın Günü',
    description: 'Fırın tavuk but, mercimek çorbası, mevsim salata.',
    package_price: 41500,
    items: [
      { menu_id: 103, is_required: true, sellable_alone: true, price_override_kurus: null },
      { menu_id: 118, is_required: true, sellable_alone: true, price_override_kurus: null },
      { menu_id: 120, is_required: true, sellable_alone: true, price_override_kurus: null },
      { menu_id: 131, is_required: false, sellable_alone: true, price_override_kurus: null },
    ],
  },
  {
    title: 'Karnıyarık Günü',
    description: 'Karnıyarık, ezogelin çorbası ve ayran.',
    package_price: 26500,
    items: [
      { menu_id: 104, is_required: true, sellable_alone: true, price_override_kurus: 19000 },
      { menu_id: 119, is_required: true, sellable_alone: true, price_override_kurus: null },
      { menu_id: 132, is_required: true, sellable_alone: false, price_override_kurus: null },
    ],
  },
  {
    // Paket fiyatı GİRİLMEMİŞ gün: `package` alanı `null` döner ve kalemler
    // tek tek satılır. İstemcinin "bu gün paket satışı yok" dalı ancak
    // böyle bir gün varsa denenebiliyor.
    title: 'Serbest Gün',
    description: 'Bugün paket yok; yemekler tek tek satılıyor.',
    package_price: null,
    items: [
      { menu_id: 102, is_required: true, sellable_alone: true, price_override_kurus: null },
      { menu_id: 120, is_required: true, sellable_alone: true, price_override_kurus: null },
      { menu_id: 130, is_required: false, sellable_alone: true, price_override_kurus: null },
    ],
  },
];

/**
 * Stok kurgusu — iş günü sırasına göre.
 *
 * Testlerin üç durumu birbirinden ayırabilmesi için üç gün BİLEREK farklı:
 * tavanlı gün kalan porsiyonu gösterir, tükenmiş gün satışa kapanır,
 * ürün tavanlı günde yalnız o kalem düşer ama gün açık kalır.
 */
const DAY_STOCK = [
  // 0 — bugün (iş günüyse). Stok sınırsız; günü kapatan şey kesim saati.
  { capacity: null, sold: 0 },
  // 1 — ilk tam açık gün. Site testlerinin mutlu yolu burası.
  { capacity: null, sold: 0 },
  // 2 — gün toplamı tavanlı: 40 porsiyonun 28'i (abonelik rezervi) gitti.
  { capacity: 40, sold: 28 },
  // 3 — gün tamamen tükendi.
  { capacity: 30, sold: 30 },
  // 4 — gün açık ama İKİNCİ kalemin kendi tavanı doldu.
  { capacity: null, sold: 0, itemIndex: 1, itemCapacity: 20, itemSold: 20 },
];

/** Menü kaç gün ileriye yayınlanmış olsun. Azami ileri görüşten (7) uzun:
 *  istemciler `too_far` dalını da mock'ta görebilsin. */
const PUBLISH_HORIZON_DAYS = 14;

/** Kapalı gün BUGÜNDEN bu kadar sonraki ilk iş gününe düşer. */
const CLOSED_DAY_MIN_OFFSET = 10;

/**
 * Önümüzdeki iş günlerinin yayınlanmış menüleri.
 *
 * Hafta sonuna menü GİRİLMEZ (mutfak çalışmıyor) ama satış kanalı açık
 * kalır: cumartesi bakan müşteri pazartesinin menüsünü görüp sipariş
 * verebilir. Bu yüzden hafta sonu günleri burada hiç üretilmiyor; takvim
 * onları `weekend: true` olarak ayrıca işaretliyor.
 */
export function seedDailyMenus(now = new Date()) {
  const today = businessToday(now);
  const days = [];
  let index = 0;

  for (let offset = 0; offset <= PUBLISH_HORIZON_DAYS; offset += 1) {
    const date = addDays(today, offset);
    if (!SERVICE_WEEKDAYS.includes(isoWeekday(date))) continue;

    days.push(
      buildDailyMenu(date, {
        id: 9001 + index,
        template: index % DAILY_MENU_TEMPLATES.length,
        stock: DAY_STOCK[index],
      }),
    );

    index += 1;
  }

  return days;
}

/**
 * Tek bir günün menüsünü kurar.
 *
 * Tohumun dışında da çağrılıyor: `/__mock/daily-menu/:date` kancası, hafta
 * sonuna ya da tohumda menüsü olmayan bir güne menü açmak için bunu
 * kullanıyor. Testin belirlenimci bir "sipariş verilebilir gün"e ihtiyacı
 * olduğunda tek yol bu — tohum, koşulduğu haftanın gününe göre değişiyor.
 */
export function buildDailyMenu(date, { id = 9900, template = 0, stock } = {}) {
  const chosen = DAILY_MENU_TEMPLATES[template % DAILY_MENU_TEMPLATES.length];
  const plan = stock ?? { capacity: null, sold: 0 };

  return {
    id,
    date,
    title: chosen.title,
    description: chosen.description,
    image_urls: [],
    published: true,
    // Günün kalemleri tek tek satılabilir mi? Yönetici bunu kapatınca gün
    // yalnız paket olarak satılır.
    components_sellable: true,
    package_price: chosen.package_price,
    day_capacity: plan.capacity ?? null,
    day_sold: plan.sold ?? 0,
    items: chosen.items.map((item, itemIndex) => ({
      menu_id: item.menu_id,
      quantity: 1,
      is_required: item.is_required,
      sellable_alone: item.sellable_alone,
      price_override_kurus: item.price_override_kurus,
      label: null,
      capacity: plan.itemIndex === itemIndex ? plan.itemCapacity : null,
      sold: plan.itemIndex === itemIndex ? plan.itemSold : 0,
    })),
  };
}

/** Kapalı günler (`veykemtu_closed_days`). Kapalı gün menüye her zaman üstündür. */
export function seedClosedDays(now = new Date()) {
  const today = businessToday(now);

  for (let offset = CLOSED_DAY_MIN_OFFSET; offset <= PUBLISH_HORIZON_DAYS; offset += 1) {
    const date = addDays(today, offset);
    if (!SERVICE_WEEKDAYS.includes(isoWeekday(date))) continue;

    return [{ date, note: 'Kurban Bayramı — mutfak kapalı' }];
  }

  return [];
}

/**
 * Uygulama içi duyurular (FCM'in yerine geçen kanal).
 *
 * Üçüncü kayıt BİLEREK süresi dolmuş: `GET /announcements` yalnız yürürlükte
 * olanları döndürüyor ve bu filtrenin çalıştığı ancak süresi geçmiş bir
 * kayıt varsa görülebiliyor.
 */
export function seedAnnouncements(now = new Date()) {
  const at = (minutes) => new Date(now.getTime() + minutes * 60_000).toISOString();

  return [
    {
      id: 1,
      level: 'info',
      title: 'Sipariş saati sabah 08:00',
      body: 'Her günün siparişi o sabah 08:00’de kapanır. Sonrasında ertesi güne sipariş verebilirsiniz.',
      url: null,
      starts_at: at(-60 * 24 * 3),
      ends_at: null,
      published_at: at(-60 * 24 * 3),
    },
    {
      id: 2,
      level: 'warning',
      title: 'Hafta sonu mutfak kapalı',
      body: 'Cumartesi ve pazar menü çıkmıyor; bu günlerde pazartesi menüsüne sipariş verebilirsiniz.',
      url: null,
      starts_at: at(-60),
      ends_at: at(60 * 24 * 30),
      published_at: at(-60),
    },
    {
      id: 3,
      level: 'info',
      title: 'Geçen ayın zam duyurusu',
      body: 'Süresi dolmuş duyuru — listede görünmemeli.',
      url: null,
      starts_at: at(-60 * 24 * 45),
      ends_at: at(-60 * 24 * 5),
      published_at: at(-60 * 24 * 45),
    },
  ];
}

/// Admin panelden üretilmiş sayılan, mock'ta sabit eşleme kodu.
export const PAIRING_CODE = 'BLD1-MOCK';

/// Abonelik sözleşmesinin imzalı bağlantısındaki sabit anahtar.
export const CONTRACT_TOKEN = 'SOZLESME-MOCK';

/**
 * Sözleşme bekleyen bir abonelik + ona bağlı sözleşme.
 *
 * MÜŞTERİ 13'E BAĞLI, 12'ye değil: site testleri 12 numaralı müşteriyle
 * giriş yapıyor ve "aboneliğiniz yok" ekranını doğruluyor. 12'ye abonelik
 * tohumlamak o testi sessizce çürütürdü.
 */
export function seedContractSubscription(now = new Date()) {
  const today = businessToday(now);

  const subscription = {
    id: 1,
    customer_id: 13,
    status: 'pending',
    location_id: LOCATION.id,
    delivery_type: 'delivery',
    start_date: addDays(today, 7),
    end_date: null,
    service_days: [...SERVICE_WEEKDAYS],
    delivery_time_from: '12:00',
    delivery_time_to: '13:00',
    default_quantity: 25,
    agreed_unit_price: 29000,
    payment_mode: 'prepaid_monthly',
    menu_mode: 'daily_menu',
    lines: [],
    delivery_points: [],
    exceptions: [],
    created_at: now.toISOString(),
  };

  const contract = {
    token: CONTRACT_TOKEN,
    subscription_id: subscription.id,
    customer_id: subscription.customer_id,
    status: 'pending',
    title: 'Abonelik Sözleşmesi',
    body: [
      'Bu sözleşme, günün menüsünden düzenli porsiyon teslimi için düzenlenmiştir.',
      'Porsiyon başı anlaşmalı fiyat 290,00 TL olup, aylık dönemlerde peşin tahsil edilir.',
      'Abone, servis gününden bir gün önce saat 08:00’e kadar gün atlayabilir.',
      'Taraflar, sözleşmeyi otuz gün önceden yazılı bildirimle feshedebilir.',
    ].join('\n\n'),
    signer_name: 'Mehmet Kara',
    signer_phone: '5559876543',
    signed_at: null,
    signed_ip: null,
    created_at: now.toISOString(),
  };

  return { subscription, contract };
}

// Siparişler sunucu açılırken üretilir; zaman damgaları "şimdi"ye göre
// kaydırılır ki KDS'te bugünün siparişleri gibi görünsünler.
export function seedOrders(now) {
  const minutesAgo = (m) => new Date(now.getTime() - m * 60_000).toISOString();
  const minutesAhead = (m) =>
    new Date(now.getTime() + m * 60_000).toISOString();
  const today = businessToday(now);

  return [
    {
      id: 5008,
      customer_id: 12,
      delivery_type: 'delivery',
      status: 'teslim_edildi',
      created_at: minutesAgo(180),
      updated_at: minutesAgo(95),
      requested_at: minutesAgo(120),
      service_date: today,
      customer_note: null,
      address: {
        line1: 'Kızılırmak Mah. 1450. Sk No:7',
        district: 'Çankaya',
        city: 'Ankara',
        note: null,
      },
      payment: { method: 'online', status: 'paid' },
      items: [
        { menu_id: 102, quantity: 4, option_value_ids: [31], note: null },
        { menu_id: 118, quantity: 4, option_value_ids: [], note: null },
      ],
      status_history: [
        { status: 'yeni', at: minutesAgo(180) },
        { status: 'onaylandi', at: minutesAgo(176) },
        { status: 'hazirlaniyor', at: minutesAgo(150) },
        { status: 'hazir', at: minutesAgo(120) },
        { status: 'yolda', at: minutesAgo(110) },
        { status: 'teslim_edildi', at: minutesAgo(95) },
      ],
    },
    {
      id: 5009,
      customer_id: 13,
      delivery_type: 'pickup',
      status: 'hazir',
      created_at: minutesAgo(55),
      updated_at: minutesAgo(6),
      requested_at: null,
      service_date: today,
      customer_note: 'Öğle arası alacağım',
      address: null,
      payment: { method: 'cash', status: 'pending' },
      items: [
        { menu_id: 130, quantity: 2, option_value_ids: [], note: null },
        { menu_id: 132, quantity: 2, option_value_ids: [], note: null },
      ],
      status_history: [
        { status: 'yeni', at: minutesAgo(55) },
        { status: 'onaylandi', at: minutesAgo(50) },
        { status: 'hazirlaniyor', at: minutesAgo(30) },
        { status: 'hazir', at: minutesAgo(6) },
      ],
    },
    {
      id: 5010,
      customer_id: 12,
      delivery_type: 'delivery',
      status: 'hazirlaniyor',
      created_at: minutesAgo(40),
      updated_at: minutesAgo(18),
      requested_at: minutesAhead(60),
      service_date: today,
      customer_note: 'Fatura kurumsal',
      address: {
        line1: 'Örnek Mah. 12. Sk No:3',
        district: 'Çankaya',
        city: 'Ankara',
        note: 'Zili çalmayın',
      },
      payment: { method: 'online', status: 'pending' },
      items: [
        {
          menu_id: 101,
          quantity: 12,
          option_value_ids: [32],
          note: 'Az acılı',
        },
        { menu_id: 118, quantity: 12, option_value_ids: [], note: null },
      ],
      status_history: [
        { status: 'yeni', at: minutesAgo(40) },
        { status: 'onaylandi', at: minutesAgo(36) },
        { status: 'hazirlaniyor', at: minutesAgo(18) },
      ],
      // ── DÜZENLENMİŞ SİPARİŞ (K-12/K-20) ──────────────────────────────
      //
      // Mock revizyon motoru koşturmuyor; bu iki alan elle tohumlanıyor ki
      // KDS'in revizyon yolu — fişin başındaki "GÜNCEL FİŞ / ÖNCEKİ FİŞİ
      // ATIN" bandı ve DEĞİŞİKLİKLER bloğu — mock'a karşı da denenebilsin.
      // Öncesinde mock'ta `revision` hiç yoktu ve o yol hiç görülemiyordu.
      revision_no: 2,
      revision_summary: ['Mercimek Çorbası: 20 -> 10', 'ÇIKARILDI: Ayran ×5'],
    },
    {
      id: 5011,
      customer_id: 13,
      delivery_type: 'pickup',
      status: 'onaylandi',
      created_at: minutesAgo(14),
      updated_at: minutesAgo(11),
      requested_at: null,
      service_date: today,
      customer_note: null,
      address: null,
      payment: { method: 'cash', status: 'pending' },
      items: [
        { menu_id: 104, quantity: 3, option_value_ids: [], note: null },
        { menu_id: 120, quantity: 3, option_value_ids: [41], note: null },
      ],
      status_history: [
        { status: 'yeni', at: minutesAgo(14) },
        { status: 'onaylandi', at: minutesAgo(11) },
      ],
    },
    {
      id: 5012,
      customer_id: 12,
      delivery_type: 'delivery',
      status: 'yeni',
      created_at: minutesAgo(2),
      updated_at: minutesAgo(2),
      requested_at: minutesAhead(180),
      service_date: today,
      customer_note: 'Kapıda arayın, asansör bozuk',
      address: {
        line1: 'Örnek Mah. 12. Sk No:3',
        district: 'Çankaya',
        city: 'Ankara',
        note: null,
      },
      payment: { method: 'cash', status: 'pending' },
      items: [
        { menu_id: 103, quantity: 8, option_value_ids: [], note: 'Az tuzlu' },
        { menu_id: 131, quantity: 8, option_value_ids: [], note: null },
      ],
      status_history: [{ status: 'yeni', at: minutesAgo(2) }],
    },
  ];
}

export const CUSTOMERS = [
  {
    id: 12,
    first_name: 'Ayşe',
    last_name: 'Yılmaz',
    email: 'ayse@ornek.com',
    telephone: '5551234567',
    password: 'parola123',
    default_location_id: 1,
  },
  {
    id: 13,
    first_name: 'Mehmet',
    last_name: 'Kara',
    email: 'mehmet@ornek.com',
    telephone: '5559876543',
    password: 'parola123',
    default_location_id: 1,
  },
];
