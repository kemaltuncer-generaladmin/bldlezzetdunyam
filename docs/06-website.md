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

## Hizmet alanı

Ödeme formunda il **sabittir** (Konya, salt okunur girdi) ve ilçe iki
seçenekli bir listeden gelir (Selçuklu, Karatay). Değerler
`website/lib/service-area.ts` içindedir; zod şeması aynı denetimi yapar ve
sunucu kuralı yeniden uygular. Gerekçe ve kutu kenarları:
`docs/00-genel-bakis.md` §4.1.

> **KURAL DEĞİŞTİ (W-16, 12.08.2026).** Bu paragraf eskiden "web sitesinde
> harita ile nokta seçimi yoktur, bu yüzden web siparişlerinin fişinde konum
> QR'ı basılmaz" diyordu. Artık var — bkz. §Adres defteri ve harita.

## B2B (kurumsal) geçiş

Sistem tamamen kurumsala döndü: yalnız `can_order = true` (kurumsal onaylı)
hesaplar sipariş verebilir. Menü/keşif herkese açık kalır; kapı sepet ve
ödemeye konur (`docs/03` §12.1). Sunucu bayrağı esastır — iş kuralı istemciye
gömülmez.

Kayıt akışı additive kurumsal alanlar toplar (`company_name`, `contact_person`
ve opsiyonel vergi bilgileri; `docs/03` §12.1). Alanlar SUNUCUDA hâlâ
opsiyonel — eski istemciler kırılmasın diye. Sitedeki `/kurumsal-kayit`
formu ise unvan, vergi dairesi ve vergi numarasını ZORUNLU tutar: unvanı
olmayan bir "kurumsal" kayıt, faturalandırılamayan bir müşteri demek.

### v2.0 değişikliği: abonelik ve cari self-servisi web'e açıldı (12.08.2026)

Önceki karar bu ikisini **mobil uygulamaya** özgü kılıyordu. Değişti.

**Gerekçe:** kurumsal müşterinin çoğu siparişi masaüstünden veriyor ve
borcunu görmek için telefon uygulaması indirmek zorunda kalması anlamsızdı.
Sözleşmede uçlar zaten vardı (`/account/*`, `/subscriptions/*`); iş yalnızca
arayüz tarafındaydı.

| Sayfa | İçerik |
|---|---|
| `/hesabim` | Profil + üç kısayol (siparişler, cari, abonelik). Borç varsa kart uyarı renginde |
| `/hesabim/cari` | Bakiye, 90 günlük ekstre, ödeme (tamamı ya da istenen tutar) |
| `/hesabim/abonelikler` | Abonelik kartları: duraklat/devam/iptal, gün atlama ve adet istisnası |

Üçü de `force-dynamic`: ödeme yaptıktan sonra eski bakiyeyi görmek, ikinci
kez ödemeye kalkmak demekti.

**Yeni abonelik BU EKRANDAN açılmıyor.** `POST /subscriptions` bir talep
açıyor ama talebin içeriği (ürünler, günler, adres, porsiyon) telefonla
konuşulan bir anlaşma; formda toplamaya çalışmak yarım bir sözleşme
üretirdi. Talep "Teklif Al" üzerinden geliyor, aboneliği yönetici kuruyor.

### v2.0 bilgi mimarisi (W-08)

Tanıtım sayfaları 10+ adetten dörde indi: `/`, `/kurumsal`, `/iletisim`,
`/teklif-al`. Kaldırılanlar (`/hizmetler`, `/hizmetler/[slug]`,
`/menu-cozumleri`, `/kalite-hijyen`, `/calistigimiz-alanlar`,
`/bilgi-merkezi`) **308 ile kalıcı olarak yönlendiriliyor** — o adresler
arama motorlarında kayıtlı ve müşterilere e-postayla gönderildi.
Yönlendirme tablosu `website/next.config.ts` içinde; `/hizmetler/:slug`
kuralı `/hizmetler`'den ÖNCE gelmek zorunda, yoksa alt sayfaları da yutar.

### v2.0 giriş akışı (W-11)

`/giris` sekmeli: **telefon** (varsayılan) ve e-posta. Telefon yolu
`POST /auth/otp/request` → `POST /auth/otp/verify` ile ilerliyor; kod
6 haneli, 5 dakika ömürlü, tek kullanımlık.

**Arayüz kayıtlı/kayıtsız numarayı AYIRT ETMEZ.** Sunucu ayırt etmiyor
(numara sayımına karşı) ve arayüzün yapması o korumayı delerdi: kayıtsız
numara da kod ekranına geçer.

### Adres defteri ve harita — W-15/W-16 (12.08.2026)

Site, mobil uygulamanın gerisinde kalmıştı. `/addresses` uçları sözleşmede
baştan beri vardı ve mobil kullanıyordu; **site hiç çağırmıyordu.** Sonucu iki
katmanlıydı:

1. Siteden sipariş veren müşteri adresini **her seferinde elden yazıyordu.**
2. Site hiç koordinat toplamadığı için **siteden gelen her siparişin kurye
   fişi QR'sızdı** (K-14 harita QR'ı yalnızca iğne varken basılıyor). Kurye
   adresi okuyup elle aramak zorunda kalıyordu — yani bu, arayüz eksiği gibi
   görünen ama mutfağa ve kuryeye kadar uzanan bir boşluktu.

| Yer | Ne yapar |
|---|---|
| `/hesabim/adresler` | Tam defter: ekle, düzenle, sil, varsayılan yap |
| `/odeme` | "Kayıtlı adreslerim" listesi; varsayılan adres önceden seçili gelir |

**Tek form, iki iş.** Ekleme ve düzenleme aynı formu paylaşıyor
(`components/address/address-book.tsx`); `editing` doluyken gizli `id` alanı
gidiyor ve sunucu eylemi `PATCH`'e dönüyor. İki ayrı form, iki ayrı doğrulama
ve iki ayrı harita durumu demekti.

**Silme onay ister.** Geri alınamıyor. Geçmiş siparişler etkilenmiyor (sipariş
adresi oluşturulurken kopyalanıyor), ama tek tıkla gitmesi doğru değil.

#### Harita: Leaflet + OpenStreetMap

Mobil zaten OSM karoları kullanıyor; harita kaynağı kararı verilmişti ve API
anahtarı ya da faturalandırma istemiyor. Google Maps'e geçmek üç istemciyi
birden bağlayan yeni bir maliyet kalemi açardı.

* **`ssr: false` ile dinamik yükleniyor** (`map-picker-lazy.tsx`). Leaflet
  modül düzeyinde `window` ve `document`'a dokunuyor; sunucuda içe aktarıldığı
  anda derleme patlıyor. Yan faydası: ~150 kB harita paketi yalnızca adres
  ekranını açan kullanıcıya iniyor, kurumsal sayfalara inmiyor.
* **Harita hizmet alanına hapsedilmiş** (`maxBounds` + `maxBoundsViscosity: 1`).
  Dışarı kaydırılabilen bir harita "oraya da gidiyoruz" izlenimi verir; müşteri
  iğneyi Ankara'ya koyar, siparişi reddedilir ve sebebini anlamaz. Sınır
  değerleri `lib/service-area.ts` içinde ve `packages/core/lib/src/service_area.dart`
  ile **aynı olmak zorunda** — ikisi birlikte değişir.
* **İğne ikonu gömülü SVG.** Leaflet'in varsayılan ikonu CDN'den geliyor ve
  CSP altında düşebiliyor.
* **İğne isteğe bağlı.** Zorunlu kılmak, konum iznini reddeden ya da haritayı
  kullanamayan müşterinin sipariş veremeyeceği anlamına gelirdi. Koordinat
  yoksa fiş eskisi gibi, QR'sız basılır.
* Koordinatlar **ikisi birden ya da hiç** gidiyor (`lib/validation/address.ts`
  `.transform()`): yalnız enlem taşıyan bir adres, yarım bir harita bağlantısı
  demek.
