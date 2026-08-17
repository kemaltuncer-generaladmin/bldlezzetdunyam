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
| `/` | SSR/ISR | Ana sayfa: tanıtım, hizmetler, "Sipariş Ver" |
| `/menu` | **`force-dynamic`** | **Günün menüsü** — gün seçici, paket + kalem kartları, stok rozeti, kesim geri sayımı |
| `/sepet` | Client | Sepet, adet düzenleme, tutar |
| `/odeme` | Client + korumalı | Teslimat bilgisi, saat, ödeme yöntemi, kayıtlı adresler, harita |
| `/siparis/[id]` | `force-dynamic` + korumalı | Sipariş takip (canlı durum) |
| `/siparislerim` | `force-dynamic` + korumalı | Sipariş geçmişi |
| `/takip/[id]` | `force-dynamic` | Fişteki **imzalı** QR ile açılan, giriş istemeyen takip |
| `/giris`, `/kurumsal-kayit` | Client | Kimlik (telefon OTP + e-posta) |
| `/hesabim` | Korumalı, `force-dynamic` | Profil + kısayollar (siparişler, abonelikler, adresler) |
| `/hesabim/abonelikler` | Korumalı, `force-dynamic` | Abonelik kartları: duraklat/devam/iptal, gün atlama, adet istisnası |
| `/hesabim/adresler` | Korumalı, `force-dynamic` | Adres defteri + harita iğnesi |
| `/sozlesme/[token]` | `force-dynamic` | **İmzalı sözleşme bağlantısı** — donmuş metin + SMS OTP onayı |
| `/kurumsal`, `/iletisim`, `/teklif-al` | SSR/ISR | Tanıtım |
| `/bilgi-merkezi`, `/bilgi-merkezi/[slug]` | ISR (300 sn) | **Blog** — panelden yönetilen yazılar |
| `/kvkk`, `/gizlilik`, `/cerez-politikasi`, `/mesafeli-satis`, `/sozlesme` | Statik | Yasal metinler |

**SEO zorunlu:** `/`, `/menu` ve tanıtım sayfaları sunucuda render edilir,
`metadata` export'u vardır, `sitemap.xml` ve `robots.txt` üretilir, JSON-LD
(`Restaurant`, menü için `Offer`) bulunur.

> **`/urun/[slug]` KALDIRILDI ve `/menu`'ye 308'lendi (B-19).** Satış artık
> güne bağlı: bir yemek yalnızca menüsünde yer aldığı gün ve o günün fiyatıyla
> satılıyor. Güne bağlı olmayan bir ürün sayfası, sepete eklenemeyen bir fiyat
> gösterirdi. Ürün KAYITLARI duruyor (menünün kalemleri onlar), müşteriye
> açılan ADRES kalkıyor. Kalıcı yönlendirme çünkü o adresler site
> haritasındaydı ve dizinde; geçici yönlendirme biriken değeri `/menu`'ye
> aktarmaz.

## 3. Sipariş akışı

```
/menu → gün seç → paket ya da kalem ekle → /sepet → giriş (yoksa)
   → /odeme → POST /api/orders
   → online ödeme ise redirect_url'e git → dönüşte /siparis/[id]
   → durum takibi (5 sn polling, Faz 1.5'te WebSocket)
```

**Sepet:** İstemci tarafında `localStorage` yerine **cookie + server action** ile tutulur (SSR uyumu için).

**Ödeme yöntemleri:** `/odeme` ekranı yalnızca vitrinin `payment_methods`
listesindeki yöntemleri gösterir. Liste bugün `online` ve `cash` ile sınırlı;
**`account` (cari hesap) kaldırıldı** ve sunucu gönderilirse `422` veriyor
(`docs/03` §12.2).

> **Sitede ödeme hâlâ `redirect_url` ile dış sayfaya gidiyor** — mobil
> uygulama bunu bıraktı (`docs/07` §3), site bırakmadı ve bu bir tutarsızlık
> değil: tarayıcıda "geri dönüş" zaten çalışıyor (aynı sekme, aynı oturum,
> `FRONTEND_URL`'e dönüş), oysa mobilde sistem tarayıcısından uygulamaya
> dönecek bir yol yoktu. `next_action` alanı sitede de okunabilir hâle
> geldiğinde karar tek yere taşınır; bugün gerek yok.

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

Dosyalar `website/e2e/` altında; `docs/10` §2 Website satırıyla birlikte
okunur.

| Dosya | Kapsadığı |
|---|---|
| `siparis.spec.ts` | Menü → sepet → ödeme kapısı; fişteki takip bağlantısı **giriş istemiyor**, imzasız bağlantı sipariş göstermiyor; kurumsal kayıt sonrası sipariş verilebiliyor, eksik vergi bilgisi kaydı durduruyor |
| `giris.spec.ts` | Telefon OTP: kod alma, yazım biçiminden bağımsızlık, yanlış kod, **kayıtlı olmayan numaranın da aynı ekrana geçmesi** (numara sayımına karşı) |
| `hesap.spec.ts` | Adres defteri (ekle/seç/sil) ve abonelik self-servisi (duraklat/devam, gün atlama, fiyatsız talep) |
| `kurallar.spec.ts` | **Stok aritmetiğinin altın veri kümesi** — `docs/contract/sales-rules.cases.json` üç dilde aynı sonucu vermeli; eksik alan (`undefined`) da sınırsız sayılmalı |
| `navigasyon.spec.ts` | Mobil menü davranışı; `/kayit` → `/kurumsal-kayit` yönlendirmesi; **site haritası kaldırılan sayfaları ilan etmiyor** |

Hâlâ yazılmamış olanlar: gel-al siparişinde teslimat adımının atlanması,
takip sayfasının durum değişimini yansıtması ve `ordering_enabled=false`
altında menünün görünmeye devam etmesi.

## Hizmet alanı

Ödeme formunda il **sabittir** (Konya, salt okunur girdi) ve ilçe iki
seçenekli bir listeden gelir (Selçuklu, Karatay). Değerler
`website/lib/service-area.ts` içindedir; zod şeması aynı denetimi yapar ve
sunucu kuralı yeniden uygular. Gerekçe ve kutu kenarları:
`docs/00-genel-bakis.md` §4.1.

> **KURAL DEĞİŞTİ (W-16, 12.08.2026).** Bu paragraf eskiden "web sitesinde
> harita ile nokta seçimi yoktur, bu yüzden web siparişlerinin fişinde konum
> QR'ı basılmaz" diyordu. Artık var — bkz. §Adres defteri ve harita.

## Satış ekranı: günün menüsü (B-19 ve sonrası)

`/menu` sitenin **tek satış ekranıdır** ve `force-dynamic` çiziliyor. İki
sebeple ISR bırakıldı: seçili gün adreste (`?gun=`), yani içerik zaten isteğe
bağlı; ve **sipariş kararı burada veriliyor** — yönetici menüyü yayından
kaldırdığında ya da kesim saati geçtiğinde altmış saniye boyunca "sepete ekle"
düğmesi çalışmaya devam edemez. SEO kaybı yok: sayfa yine sunucuda tam
içerikle üretiliyor.

Kategori gezgini, arama ve ürün detay bağlantıları kaldırıldı: satılan şey bir
katalog değil, o günün menüsü.

### Kalan porsiyon rozeti

Kartlar `remaining_portions` alanını **kendileri yorumlamıyor**; bandı
`lib/stock-policy.ts` hesaplıyor ve o dosya mobil uygulamayla ortak kuralı
uyguluyor (`docs/contract/sales-rules.cases.json`). Rozet yalnız `low` ve
`soldOut` bandında çiziliyor: "Son 40 porsiyon" yazan bir etiket aciliyet
değil gürültü üretir.

**`null` SINIRSIZ demektir, sıfır değil.** Tavanı hiç konmamış bir günü
tükenmiş göstermek, satışı kapatmanın en sessiz yoludur.

### Kesim geri sayımı

`components/menu/order-cutoff-countdown.tsx`. Sözleşme kesimi `cutoff_at`
alanında **mutlak an** olarak veriyor ve sayaç yalnızca çıkarma yapıyor —
kesim kuralını üç dilde yeniden hesaplamak (TS `Intl`, Dart'ta sabit UTC+3,
PHP'de `Europe/Istanbul`) yaz saatinde ve yanlış saat dilimli cihazlarda üç
ayrı sonuç üretir.

- **KARAR KAPISI BURASI DEĞİL.** Sayaç sıfırlandığında ekran kilitlenmiyor;
  sayfa yeniden çekiliyor ve karar yine sunucunun `is_orderable` alanından
  geliyor. Sayacın kendi başına "sepete ekle"yi kapatması, saati iki dakika
  ileri olan bir cihazda hâlâ açık bir günü kapatmak olurdu.
- **İlk geçişte hiç çizilmiyor.** `now` sunucuda okunsaydı iki taraf farklı
  dakikayı yazar ve React sitenin en önemli sayfasında hidratlama uyuşmazlığı
  bildirirdi.
- **Cihaz saati yalan söyler.** Sunucunun çizim anı ile cihazın anı arasındaki
  fark on dakikayı geçiyorsa geri sayım **hiç gösterilmiyor**: yanlış bir
  "son 3 dakika" uyarısı, hiç uyarı olmamasından kötüdür.

### Hafta sonu bandı

`components/menu/service-days-banner.tsx`. Servis günü olmadığını anlatan
metin bugüne kadar yalnız hafta sonu bir güne **tıklayınca** görünüyordu;
cumartesi siteye giren biri o tıklamayı yapmadan da "bugün yemek var mı"
sorusunun cevabını görmeli, göremeyince siteyi kapalı sanıp çıkıyor.

**Bant satış kanalını KAPATMAZ ve bunu açıkça söyler:** cumartesi pazartesinin
menüsü sipariş edilebiliyor. "Kapalıyız" deyip bırakmak, açık olan bir kanalı
kapalı göstermek olurdu; sipariş alımının gerçekten durduğu hâli
`OrderingClosedBanner` anlatıyor ve ikisi ayrı sorulardır.

Günler `Location.service_weekdays`'ten (ISO 1–7) geliyor; `6` ve `7` koda
**gömülmüyor** — hafta sonu servise açılırsa metin kendiliğinden doğrulanır.
Sunucu alanı hiç göndermiyorsa bant susuyor: uydurulmuş bir "hafta içi
çalışıyoruz" cümlesi, cumartesi servis veren bir işletmede müşteriyi geri
çevirirdi.

## B2B (kurumsal) geçiş

Sistem tamamen kurumsala döndü, ama **sipariş kapısı kaldırıldı**: `can_order`
her zaman `true` dönüyor ve site bu bayrağa bakmıyor. Siparişin
verilebilirliği vitrinin (`is_open`, `ordering_enabled`) ve günün
(`DailyMenu.is_orderable`) durumundan okunur; bağlayıcı olan
`POST /api/orders`'ın kendisidir (`docs/03` §12.1). İş kuralı yine istemciye
gömülmez — değişen, kuralın hangi alandan okunduğu.

Kayıt akışı additive kurumsal alanlar toplar (`company_name`, `contact_person`
ve opsiyonel vergi bilgileri; `docs/03` §12.1). Alanlar SUNUCUDA hâlâ
opsiyonel — eski istemciler kırılmasın diye. Sitedeki `/kurumsal-kayit`
formu ise unvan, vergi dairesi ve vergi numarasını ZORUNLU tutar: unvanı
olmayan bir "kurumsal" kayıt, faturalandırılamayan bir müşteri demek.

### v2.0 değişikliği: abonelik self-servisi web'e açıldı (12.08.2026)

Önceki karar bunu **mobil uygulamaya** özgü kılıyordu. Değişti.

**Gerekçe:** kurumsal müşterinin çoğu işini masaüstünden yapıyor ve
aboneliğini yönetmek için telefon uygulaması indirmek zorunda kalması
anlamsızdı. Sözleşmede uçlar zaten vardı (`/subscriptions/*`); iş yalnızca
arayüz tarafındaydı.

| Sayfa | İçerik |
|---|---|
| `/hesabim` | Profil + kısayollar (siparişler, abonelikler, adresler) |
| `/hesabim/abonelikler` | Abonelik kartları: duraklat/devam/iptal, gün atlama ve adet istisnası |
| `/sozlesme/[token]` | İmzalı sözleşme bağlantısı: donmuş metin + SMS OTP onayı |

Hepsi `force-dynamic`: bir işlem yaptıktan sonra eski durumu görmek, aynı
işlemi ikinci kez denemek demekti.

> **`/hesabim/cari` KALDIRILDI (17.08.2026).** Cari hesap iş modelinden çıktı;
> bakiye, ekstre ve borç ödeme sayfası diye bir şey yok, arkasındaki
> `/api/account/*` uçları da kalktı (`docs/02` §7.2, `docs/03` §12.2).
> **Yayın sırası bağlayıcıydı ve tutuldu: site sunucudan ÖNCE yayınlandı.**
> Ters olsaydı sahadaki sürüm hâlâ çizdiği ekranı doldurmak için o üç yolu
> çağırır ve ziyaretçi sebebini anlayamayacağı boş bir hata ekranı görürdü.
> `/hesabim` kartındaki "borç varsa uyarı rengi" kuralı da bununla birlikte
> gitti — gösterecek borç yok.

**Yeni abonelik BU EKRANDAN açılmıyor.** `POST /subscriptions` bir talep
açıyor ama talebin içeriği (ürünler, günler, adres, porsiyon) telefonla
konuşulan bir anlaşma; formda toplamaya çalışmak yarım bir sözleşme
üretirdi. Talep "Teklif Al" üzerinden geliyor, aboneliği yönetici kuruyor.

### v2.0 bilgi mimarisi (W-08) ve bilgi merkezinin geri dönüşü (M4)

Tanıtım sayfaları 10+ adetten dörde indi: `/`, `/kurumsal`, `/iletisim`,
`/teklif-al`. Kaldırılanlar (`/hizmetler`, `/hizmetler/[slug]`,
`/menu-cozumleri`, `/kalite-hijyen`, `/calistigimiz-alanlar`) **308 ile kalıcı
olarak yönlendiriliyor** — o adresler arama motorlarında kayıtlı ve
müşterilere e-postayla gönderildi. Yönlendirme tablosu
`website/next.config.ts` içinde; `/hizmetler/:slug` kuralı `/hizmetler`'den
ÖNCE gelmek zorunda, yoksa alt sayfaları da yutar. `/urun/:slug` de aynı
tabloda (§2).

**`/bilgi-merkezi` geri geldi (M4).** Blog v2.0'da kaldırılmış ve
`/bilgi-merkezi` ile `/bilgi-merkezi/:slug` `/kurumsal`'a 308'leniyordu;
yönlendirmeler silindi, sayfalar yeniden yayında ve içerik panelden
yönetiliyor (`fetchSiteContent`, ISR 300 sn).

> **308 GERİ ALINAMAZ ve bu maddenin tamamı o yüzden var.** Kalıcı
> yönlendirmeyi tarayıcı **kalıcı önbelleğe alır**: adresi yönlendirme
> yürürlükteyken bir kez açmış bir tarayıcı, bundan sonra sunucuya HİÇ
> SORMADAN `/kurumsal`'a gider. Aynı yola yeniden yayın yapmak bunu geri
> almıyor ve önbelleği uzaktan temizlemenin bir yolu yok — kullanıcının kendi
> tarayıcı verisini silmesi gerekir. Bu yüzden `/kurumsal` sayfasında bilgi
> merkezine **belirgin bir bağlantı** duruyor: etkilenen ziyaretçi tam olarak
> oraya düşüyor ve geri dönüş yolu o bağlantı. Arama motorları ise yeni 200
> yanıtını bir sonraki taramada görüp dizini düzeltir.
>
> **Ders:** bir adresi 308'lemek, o adresi geri getirme hakkından vazgeçmektir.
> Geri gelmesi ihtimali olan bir sayfa için 307/302 doğru araçtır.

**Boş yazı listesi bir arıza değildir.** Yedek içerik (`content/posts.ts`)
bilerek boş: panelde silinmiş bir yazıyı repodan yeniden yayınlamak içerik
yalanı olurdu. Hem "panelde henüz yazı yok" hem "API kapalı" durumunda sayfa
dürüst bir boş durum çiziyor — uydurma bir arşiv değil.

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
