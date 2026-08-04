// Örnek veri. Tutarlar kuruş cinsinden tam sayıdır (docs/03 §1.3).
//
// 3 kategori, 12 ürün, 5 sipariş — siparişler durum makinesinin farklı
// noktalarına ve iki teslimat tipine yayılmış durumda ki istemciler her hali
// mock'ta görebilsin.

export const LOCATION = {
  id: 1,
  name: 'Benim Lezzet Dünyam',
  slug: 'catering',
  is_open: true,
  ordering_enabled: true,
  order_cutoff: '16:00',
  min_order_total: 25000,
  payment_methods: ['cash', 'account'],
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
        image_url: 'https://picsum.photos/seed/tavuksote/600/400',
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
        image_url: 'https://picsum.photos/seed/kurufasulye/600/400',
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
        image_url: 'https://picsum.photos/seed/tavukbut/600/400',
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
        image_url: 'https://picsum.photos/seed/karniyarik/600/400',
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
        image_url: 'https://picsum.photos/seed/kofte/600/400',
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
        image_url: 'https://picsum.photos/seed/mercimek/600/400',
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
        image_url: 'https://picsum.photos/seed/ezogelin/600/400',
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
        image_url: 'https://picsum.photos/seed/salata/600/400',
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
        image_url: 'https://picsum.photos/seed/coban/600/400',
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
        image_url: 'https://picsum.photos/seed/sutlac/600/400',
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
        image_url: 'https://picsum.photos/seed/kemalpasa/600/400',
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
        image_url: 'https://picsum.photos/seed/ayran/600/400',
        is_available: true,
        allergens: ['süt'],
        options: [],
      },
    ],
  },
];

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

/// Admin panelden üretilmiş sayılan, mock'ta sabit eşleme kodu.
export const PAIRING_CODE = 'BLD1-MOCK';

// Siparişler sunucu açılırken üretilir; zaman damgaları "şimdi"ye göre
// kaydırılır ki KDS'te bugünün siparişleri gibi görünsünler.
export function seedOrders(now) {
  const minutesAgo = (m) => new Date(now.getTime() - m * 60_000).toISOString();
  const minutesAhead = (m) =>
    new Date(now.getTime() + m * 60_000).toISOString();

  return [
    {
      id: 5008,
      customer_id: 12,
      delivery_type: 'delivery',
      status: 'teslim_edildi',
      created_at: minutesAgo(180),
      updated_at: minutesAgo(95),
      requested_at: minutesAgo(120),
      customer_note: null,
      address: {
        line1: 'Kızılırmak Mah. 1450. Sk No:7',
        district: 'Çankaya',
        city: 'Ankara',
        note: null,
      },
      payment: { method: 'account', status: 'paid' },
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
      customer_note: 'Fatura kurumsal',
      address: {
        line1: 'Örnek Mah. 12. Sk No:3',
        district: 'Çankaya',
        city: 'Ankara',
        note: 'Zili çalmayın',
      },
      payment: { method: 'account', status: 'pending' },
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
    },
    {
      id: 5011,
      customer_id: 13,
      delivery_type: 'pickup',
      status: 'onaylandi',
      created_at: minutesAgo(14),
      updated_at: minutesAgo(11),
      requested_at: null,
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
      customer_note: 'Kapıda arayın, asansör bozuk',
      address: {
        line1: 'Örnek Mah. 12. Sk No:3',
        district: 'Çankaya',
        city: 'Ankara',
        note: null,
      },
      payment: { method: 'account', status: 'pending' },
      items: [
        { menu_id: 103, quantity: 8, option_value_ids: [], note: 'Az tuzlu' },
        { menu_id: 131, quantity: 8, option_value_ids: [], note: null },
      ],
      status_history: [{ status: 'yeni', at: minutesAgo(2) }],
    },
  ];
}
