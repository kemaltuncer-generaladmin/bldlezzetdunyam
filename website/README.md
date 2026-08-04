# website — Müşteri Sipariş Sitesi

Next.js 15 (App Router) + TypeScript `strict` + Tailwind CSS.
Spesifikasyon: [`docs/06-website.md`](../docs/06-website.md)

## Çalıştırma

```bash
# 1) Mock API'yi ayağa kaldır (backend beklenmez)
docker compose -f infra/docker-compose.dev.yml up mock-api

# 2) Ortam dosyası
cp website/.env.example website/.env.local   # zaten mock'a bakıyor

# 3) Geliştirme
cd website && npm install && npm run dev
```

| Komut                         | İş                                                          |
| ----------------------------- | ----------------------------------------------------------- |
| `npm run dev`                 | Geliştirme sunucusu                                         |
| `npm run build` / `npm start` | Üretim derlemesi ve sunucusu                                |
| `npm run lint`                | ESLint (flat config, `eslint-config-next` + Prettier uyumu) |
| `npm run typecheck`           | `tsc --noEmit`                                              |
| `npm run format`              | Prettier                                                    |
| `npm run api:generate`        | `docs/openapi.yaml` → `lib/api/schema.ts`                   |

## Değişmez kısıtlar

- TypeScript `strict: true`, **`any` yasak** — bilinmeyen tip için `unknown` +
  daraltma (`AGENTS.md` §4). ESLint bunu hata olarak zorluyor.
- `/`, `/menu`, `/urun/[slug]` **SSR/ISR** — SEO gereksinimi. Derleme
  çıktısında bu üçü `○`/`●` (statik/SSG) ve `Revalidate: 1m` görünmelidir.
  Bu yüzden **kök düzen cookie okumaz**; sepet rozeti ve oturum adı istemcide
  okunur (`components/header-actions.tsx`).
- API tipleri **elle yazılmaz**: `npm run api:generate` `docs/openapi.yaml`'dan
  `lib/api/schema.ts` üretir, `lib/api/types.ts` yalnızca ad verir.
- Sepet `localStorage`'da değil **cookie + server action** ile tutulur.
  Cookie yalnızca `menu_id`/adet/seçenek taşır; **fiyat taşımaz** — tutar her
  render'da canlı menüden, sipariş anında da sunucuda hesaplanır.
- Para **kuruş** cinsinden tam sayıdır. Tek yardımcı: `lib/format.ts`
  → `formatPrice(41000) === "410,00 ₺"`. Float aritmetiği yok.
- Kanal kavramı yoktur: `channel`, `pickup_code`, `ogrenci`, `/kantin` diye bir
  şey bulunmaz. Sipariş çeşitliliği yalnızca `delivery_type`.

## Klasör düzeni

```
app/                Rotalar (App Router)
  actions/          Server action'lar (cart, auth, order)
  api/siparis/[id]/ Takip ekranının yoklama ucu (httpOnly token sunucuda kalsın diye)
components/         Paylaşılan bileşenler
lib/
  api/              Üretilen sözleşme tipleri + HTTP istemcisi + uç sarmalayıcıları
  validation/       Zod şemaları (istemci ve sunucu ortak)
  action-state.ts   Form durumları — 'use server' dosyaları yalnızca async fonksiyon ihraç edebilir
messages/tr.json    next-intl sözlüğü (tek dil)
middleware.ts       Korumalı rotalar
```

## Sipariş alımı kapalıyken

`ordering_enabled=false` veya `is_open=false` ise menü **görünmeye devam eder**
(SEO), yalnızca sepete ekleme ve `/odeme` engellenir, açıklayıcı bant gösterilir.
Sepet/ödeme/sipariş oluşturma yolları vitrin durumunu **önbelleksiz** okur
(`fetchCatalog('fresh')`); katalog sayfaları ISR ile 60 sn önbellekli kalır.

## Ödeme

`/odeme` yalnızca vitrinin `payment_methods` listesindeki yöntemleri gösterir.
Faz 1'de bu liste `["cash","account"]`. Arayüz `online` için de yazıldı ama
şalter sunucudadır — sanal POS hazır olunca istemci sürümü değişmez.
`payment.redirect_url` doluysa kullanıcı oraya, boşsa `/siparis/{id}`'ye gider.

## Bilinen açıklar

`docs/BILINMEYENLER.md` → "Kol C — Website" başlığı. Özetle: sözleşmede ürün
`slug`'ı ve sipariş öncesi teslimat ücreti yok, profil/adres güncelleme ucu yok,
yasal metinlerdeki işletme kimlik bilgileri henüz verilmedi.

Ayrıntı: [`infra/mock/README.md`](../infra/mock/README.md)
