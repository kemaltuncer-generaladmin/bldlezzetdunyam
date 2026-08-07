# 06 — Müşteri Web Sitesi

## 1. Teknoloji

- Next.js 15 (App Router), TypeScript `strict`
- Tailwind CSS
- Veri: Server Component'lerde `fetch` (SSR/ISR), istemci etkileşimi için TanStack Query
- Form: React Hook Form + Zod
- API istemcisi: `platform/openapi.json`'dan üretilir → `lib/api/`
- Test: Playwright (e2e)

## 2. Sayfa haritası

| Yol | Render | İçerik |
|---|---|---|
| `/` | SSR/ISR | Ana sayfa: tanıtım, öne çıkan ürünler, "Sipariş Ver" |
| `/menu` | SSR/ISR (60 sn) | Catering menüsü, kategori filtreleri |
| `/urun/[slug]` | SSR | Ürün detayı, seçenekler, sepete ekle |
| `/sepet` | Client | Sepet, adet düzenleme, tutar |
| `/odeme` | Client + korumalı | Teslimat bilgisi, saat, ödeme yöntemi |
| `/siparis/[id]` | Client + korumalı | Sipariş takip (canlı durum) |
| `/siparislerim` | SSR + korumalı | Sipariş geçmişi |
| `/giris`, `/kayit` | Client | Kimlik |
| `/hesabim` | Korumalı | Profil, adresler |
| `/kvkk`, `/mesafeli-satis`, `/iletisim` | Statik | Yasal metinler |

**SEO zorunlu:** `/`, `/menu`, `/urun/[slug]` sunucuda render edilir, `metadata` export'u vardır, `sitemap.xml` ve `robots.txt` üretilir, ürün sayfalarında JSON-LD (`Product`, `Restaurant`) yapılandırılmış verisi bulunur.

## 3. Sipariş akışı

```
/menu → ürün seç → /sepet → giriş (yoksa) → /odeme → POST /api/orders
   → online ödeme ise redirect_url'e git → dönüşte /siparis/[id]
   → durum takibi (5 sn polling, Faz 1.5'te WebSocket)
```

**Sepet:** İstemci tarafında `localStorage` yerine **cookie + server action** ile tutulur (SSR uyumu için).

**Ödeme yöntemleri:** `/odeme` ekranı yalnızca vitrinin `payment_methods` listesindeki yöntemleri gösterir. Faz 1'de bu liste `["cash","account"]` gelir — arayüz `online` için de yazılır ama sunucu göndermediği sürece görünmez.

**Sipariş alımı kapalıysa:** `ordering_enabled=false` veya `is_open=false` ise menü **görünmeye devam eder** (SEO), sepete ekleme ve `/odeme` engellenir, sayfada açıklayıcı bir bant gösterilir.

## 4. Durum takip ekranı

`/siparis/[id]` — sipariş durumunu görsel adım çubuğuyla gösterir:

```
 ✓ Alındı ──── ✓ Onaylandı ──── ● Hazırlanıyor ──── ○ Hazır ──── ○ Yolda
```

- 5 saniyede bir `GET /api/orders/{id}` (Faz 1.5'te WebSocket).
- `delivery_type=pickup` siparişinde adım çubuğunda `Yolda` adımı gösterilmez: `Hazır` → `Teslim edildi`.
- Sipariş `yeni`/`onaylandi` durumundayken "Siparişi iptal et" butonu görünür.

## 5. Tasarım kuralları

- Mobil öncelikli. Siparişlerin çoğu telefondan gelecek.
- Ürün kartında görsel, ad, kısa açıklama, fiyat, "Ekle" butonu.
- Fiyatlar kuruştan TL'ye biçimlenir: `41000` → `410,00 ₺` (tek yardımcı fonksiyon `formatPrice`).
- Türkçe içerik; `next-intl` kurulur ama tek dil (tr) ile başlanır.
- Erişilebilirlik: klavye ile tam gezinme, görünür odak halkası, form hatalarında `aria-describedby`, kontrast AA.
- Yükleniyor durumları skeleton ile; hata durumları kullanıcı diliyle ("Menü yüklenemedi, tekrar deneyin").

## 6. Ortam değişkenleri (`.env.example`)

```
NEXT_PUBLIC_API_URL=https://api.benimlezzetdunyam.com.tr/api
NEXT_PUBLIC_SITE_URL=https://benimlezzetdunyam.com.tr
REVALIDATE_SECONDS=60
```
Sır içeren değer yoktur; ödeme sağlayıcı anahtarları yalnızca `platform/` tarafındadır.

Geliştirmede `NEXT_PUBLIC_API_URL` **ayaktaki platforma** bakar
(`http://localhost:8080/api`). Prism mock'u (`:4010`) yalnızca sözleşme
testleri içindir: `/site-content` gibi uçları hiç sunmaz, site sessizce yedek
içeriğe düşer ve ekranda her şey dolu göründüğü için fark edilmez.

## 6.1 Görseller

Kurumsal sayfaların fotoğrafları `public/gorseller/` altında durur ve
`lib/site-images.ts` içinde **slug üzerinden** eşleşir; API sözleşmesinde
görsel alanı yoktur. Dosyayı aynı adla değiştirmek yeterlidir, kod
düzenlenmez. Oranlar, lisans ve "iddia taşımayan kullanım" kuralı
`public/gorseller/KAYNAK.md` dosyasındadır.

Menü ürünlerinin fotoğrafı burada DEĞİLDİR: `MenuItem.image_url` ile API'den
gelir, panelden yönetilir, ilk dolgusu `php artisan veykemtu:menuGorselleri`
ile yapılır. `next/image` izin listesine API konağı `next.config.ts` içinde
`NEXT_PUBLIC_API_URL`'den türetilerek eklenir.

## 7. Performans hedefleri

- LCP < 2.0 sn (4G, orta seviye telefon)
- Görseller `next/image` ile, uygun boyut ve `priority` yalnızca hero'da
- Menü sayfası ISR ile 60 sn önbellekli
- Lighthouse Performance ≥ 90, Accessibility ≥ 95

## 8. Testler (Playwright)

1. Menü → ürün seç → sepete ekle → sepet doğru tutar
2. Kayıt → giriş → sipariş oluştur → sipariş numarası döner
3. Gel-al siparişi → teslimat adresi adımı atlanır, teslimat ücreti eklenmez
4. Sipariş takip sayfası durum değişimini yansıtır (API mock ile)
5. `ordering_enabled=false` iken sipariş denemesi → uygun hata mesajı, menü hâlâ görünür
