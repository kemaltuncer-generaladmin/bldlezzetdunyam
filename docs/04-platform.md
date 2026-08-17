# 04 — Platform (Backend + Admin)

TastyIgniter kurulumu, eklenti geliştirme ve backend görevlerinin tamamı.

## 1. Kurulum

```bash
cd platform
composer create-project tastyigniter/tastyigniter . --stability=stable
cp .env.example .env
php artisan key:generate
php artisan igniter:install   # etkileşimli; DB bilgileri .env'den
```

`.env` kritik alanlar:
```
APP_URL=https://api.benimlezzetdunyam.com.tr
DB_CONNECTION=mysql
DB_HOST=db
DB_DATABASE=catering
SANCTUM_STATEFUL_DOMAINS=benimlezzetdunyam.com.tr
FRONTEND_URL=https://benimlezzetdunyam.com.tr
```

`FRONTEND_URL` **çözülebilir bir adres olmalıdır.** Ödeme dönüşü buradan
kurulur; yanlışsa müşteri ödemeyi tamamladıktan sonra ölü bir adrese
düşer ve hiçbir uç hata vermez. Ayrıca açık yönlendirme koruması bu
değere dayanır: istemcinin verdiği `?return=` yalnızca aynı host ise
kabul edilir. Bu yüzden `www.` yazmak, site apex'te duruyorsa hatadır.

## 2. Kurulum sonrası zorunlu yapılandırma

1. **Tek vitrin oluştur:** `Benim Lezzet Dünyam` (id 1, slug `catering`). Ayarlar → Locations.
2. **Tek müşteri grubu:** `Catering Müşterisi`.
3. **Durumları bizim koda göre yapılandır.** Varsayılan TastyIgniter durumlarını sil/düzenle; `docs/02-veri-modeli.md` §3'teki 7 durum kodu birebir olacak: `yeni`, `onaylandi`, `hazirlaniyor`, `hazir`, `yolda`, `teslim_edildi`, `iptal`. Bu bir seeder ile yapılır (`VeykemtuStatusSeeder`), elle değil.
4. **Admin rolleri:** `Yönetici` (tam yetki), `Operatör` (sipariş görüntüleme + durum ilerletme; menü/fiyat/ayar yetkisi yok).

## 2.5 BLD Ayarları sayfası (05.08.2026)

> **Bu ekran bugün erişilemez.** Admin paneli kapatıldı (§2.7); ayarlar
> Kontrol Merkezi'nden yönetiliyor (`docs/control/settings.md`). Bölüm
> duruyor çünkü panel bir yedek yüzey ve şalter açıldığında sayfa aynen
> çalışıyor.

**Ayarlar → Eklentiler → BLD Ayarları** — yan menüde de var
(Restoran → BLD Ayarları).

On alan buradan yönetilir: yoğunluk, yoğunluk metni, sipariş alım şalteri,
kesim saati, asgari sepet, teslimat ücreti, ödeme yöntemleri ve teslim
süresi tahmininin üç dakika alanı (hazırlık, teslimat, yoğunluk eki).

> **Değerlerin tek kaynağı `LocationGate`'tir.** Sayfa `location_options`
> tablosuna doğrudan tek sorgu atmaz. İkinci bir kaynak açılsaydı,
> panelden değişen ayar API'ye hiç yansımayabilirdi.

> **Çekirdeğin `SettingsModel` davranışı KULLANILMADI.** O davranış
> `extension_settings` tablosuna yazar; bizim değerlerimiz
> `location_options`'ta yaşıyor ve mutfak ekranı da oraya yazıyor.

Para alanları arayüzde **TL**, veritabanında **kuruş `int`**. Dönüşüm tek
yerde (`Admin/LiraField`) ve tamamen tam sayı aritmetiğiyle:
`(float) "45,50"` PHP'de `45.0`'dır ve virgülle yazan bir yöneticinin
asgari sepeti sessizce 50 kuruş eksilirdi.

> **Para alanları `number` değil `text` tipinde.** `Igniter\Admin\Widgets\Form::getSaveData()`
> `number` tipini postback'te `(int)` ile daraltıyor — "45.50" kaydedilmeden
> önce 45'e düşüyor ve kuruşlar tamamen kayboluyor. Bir test bunu sabitliyor.

**Yoğunluk yarışı:** mutfak ekranındaki tuş da aynı değeri değiştiriyor.
Form, sayfa çizildiği andaki değeri gizli alanda taşır ve `busy` yalnızca
gönderilen değer ondan **farklıysa** yazılır. Yönetici sayfayı açık
bırakıp yarım saat sonra ilgisiz bir alanı kaydederse mutfağın bu arada
bastığı tuş ezilmez.

### Teslim süresi tahmini bölümü (07.08.2026)

Sayfanın en altındaki **Teslim süresi tahmini** bölümünde üç alan var:

| Alan | Varsayılan | Ne yapar |
|---|---|---|
| Hazırlık süresi (dakika) | 40 | Siparişin mutfakta hazır olması. Her iki teslim türünde de sayılır. |
| Teslimat süresi (dakika) | 20 | Hazır siparişin adrese ulaşması. **Gel-alda uygulanmaz** — müşteri gelip aldığı için yol süresi yoktur. |
| Yoğunluk ek süresi (dakika) | 15 | "Mutfak yoğun" açıkken tahminin hem alt hem üst ucuna eklenir. |

Bölüm bilinçli olarak yoğunluk bölümünün **hemen altındadır**: ek süre ancak
oradaki anahtar açıkken işler, araya başka bir konu girseydi bu bağ
görünmezdi.

> **Bu üç değer BAŞLANGIÇ NOKTASIDIR, nihai kaynak değildir.** Son 14 günde
> en az 8 tamamlanmış sipariş biriktiğinde `Services\EtaService` bu alanları
> kullanmayı bırakır ve gerçekleşen süreleri ölçer (medyan → 80. yüzdelik).
> Sebep: elle girilen süre iyimser girilir ve kimse güncellemeyi hatırlamaz;
> mutfak hızlanır ya da yavaşlar, panel aynı kalır. Bölüm açıklaması bunu
> yöneticiye de söyler — yoksa "değeri değiştirdim, tahmin değişmedi" diye
> hata bildirimi gelirdi.

Değerler API'de `Location.eta` olarak açılır (`docs/03-api-sozlesmesi.md`
§3). Tek sayı değil **aralık** döner: "45 dakika" bir taahhüttür ve 47.
dakikada ihlal edilir.

> **Bu alanlar `number` tipinde — para alanlarının aksine.** Yukarıdaki
> `(int)` daraltmasının kaybettirdiği tek şey ondalık kısımdır; dakikalar
> zaten tam sayı olduğu için kaybedilecek bir şey yok. Karşılığında tarayıcı
> sayısal klavyeyi ve `min`/`max` sınırlarını bedava veriyor. Doğrulama
> kuralı `1-480` arası tam sayı: alt sınır "0 dakikada teslim" sözünü, üst
> sınır günlerle ifade edilen tahminleri engelliyor. Aynı sınır
> `LocationGate::positiveMinutes()` içinde de var — form yöneticiye hata
> gösterir, gate API'yi korur.

## 2.6 İçerikler bölümü — kurumsal site yönetimi (06.08.2026)

> **Bu ekranlar da bugün erişilemez** (§2.7). İçerik Kontrol Merkezi'nden
> yönetiliyor (`docs/control/cms.md`); aşağıdaki tablo, alan kuralları ve
> `body_html` temizliği panelden bağımsız olarak geçerli kalmaya devam
> ediyor — ikisi de aynı modellere yazıyor.

Kurumsal web sitesinin **tüm** içeriği panelden yönetilir; site metnini
değiştirmek için kod yazmak gerekmez.

Yan menüde **İçerikler** başlığı altında üç ekran:

| Ekran | Ne yönetilir |
|---|---|
| Site İçeriği | Marka (ad, slogan, logo, ana renk), iletişim, kurumsal metinler, SSS, sektörler, menü çözümleri, kalite zinciri |
| Hizmetler | Hizmet kayıtları — kendi adresi, sırası, taslak/yayın durumu |
| Bilgi Merkezi | Blog yazıları — kendi adresi, kategorisi, yayın tarihi |

Site bunları `GET /api/site-content` ile tek pakette çeker
(`docs/03-api-sozlesmesi.md` §6).

### Neden üç tablo, tek tablo değil?

İçeriğin iki farklı doğası var. **Kayıt olanlar** (hizmet, yazı) zamanla
çoğalır, kendi adresi olur, taslakta bekler. Bunlar satır olmalı — tek bir
devasa alan içinde düzenlenselerdi taslak/yayın ayrımı yapılamaz ve iki kişi
aynı anda kaydettiğinde biri diğerinin yazısını ezerdi. **Sınırlı listeler**
(iletişim, SSS, sektörler) sabit sayıda ve birlikte okunur; dört maddelik bir
SSS için panele ayrı bir bölüm koymak gereksizdi.

### Yapılandırılmış alan + serbest metin, ikisi birden

Kartları ve ızgaraları besleyen alanlar yapılandırılmıştır (başlık, özet,
madde listesi) — sitenin görsel düzeni oradan doğuyor. Her kaydın ayrıca bir
`body_html` alanı var: zengin metin editöründen serbest anlatım.

> **Her şey serbest HTML olsaydı site görselliğini KAYBEDERDİ.** Kart, ızgara
> ve renk bantları yapılandırılmış veriden üretiliyor; hepsi tek bir metin
> kutusuna indirgenseydi sayfa "başlık + paragraf" yığınına dönerdi.

### `body_html` kayıt anında temizlenir

Editörden gelen HTML `Services/HtmlSanitizer` ile **izin listesinden**
geçirilir. `<script>`, olay öznitelikleri (`onerror=`), `style`, `class`,
`<div>`, `<img>` ve `javascript:` bağlantıları düşer; **etiketin içindeki
metin korunur** — yöneticinin yazdığı cümle kaybolmaz, yalnızca biçimi düşer.

Yasaklananları saymak yerine izin verilenleri saymanın sebebi: yasak listesi
kaybedilen bir yarıştır. Temizlik okuma anında değil kayıt anında yapılır —
okuma her istekte olur, kayıt nadiren; ayrıca veritabanında temiz veri durması
siteyi tek savunma hattı olmaktan çıkarır.

En sık karşılaşılan durum saldırı değil **Word yapıştırması**: yüzlerce satır
`style="font-family:Calibri"` sitede tasarım sistemi dışına çıkan yazı tipleri
üretir.

### Marka rengi kaydedilmeden önce ölçülür

Ana renk panelden seçilebilir. Bu güzel bir özgürlük ama tehlikeli: açık bir
ton seçildiğinde butonlardaki beyaz yazı okunamaz olur ve site erişilebilirlik
gerekliliğini (`docs/06-website.md` §5) sessizce kaybeder — rengi seçen kişi
kontrast oranı hesaplamaz.

`Admin/BrandGuard` beyaz metinle kontrastı ölçer ve WCAG AA eşiğini (4,5:1)
geçmeyen rengi **reddeder**, ölçülen oranı yöneticiye söyler.

> **Kırpmıyoruz, "en yakın uygun tona" çevirmiyoruz.** Yönetici seçtiği rengin
> değiştirildiğini fark etmez ve markasının rengini yanlış bilir.

Ölçülmüş örnekler: `#C2410C` → 5,18:1 kabul · `#EA580C` → 3,56:1 red ·
`#F97316` → 2,80:1 red. Ayrıştırılamayan girdi 0 döner, yani reddedilir.

### Telefon tek alan

Site `{display, href}` çifti bekliyor ama panelde iki kutu göstermek
("0212 000 00 00" ve "tel:+902120000000") yöneticiyi bir biçim kuralını elle
uygulamaya zorlardı; ilk yazım hatasında bağlantı çalışmazdı. Yönetici numarayı
okunur yazar, `href` sunucuda türetilir.

### Boş alan = gösterme

Doldurulmamış iletişim kanalı sitede **hiç görünmez** — yer tutucu, boş satır
veya "—" çıkmaz. Bu bir eksiklik değil, arayüzün anladığı bir durum: değer
girildiği anda ilgili blok kendiliğinden belirir.

Aynı ilke sertifikalarda da geçerli ve orada **hukuki** bir gerekçesi var:
belge listesi boşken site sertifika iddiası içermeyen bir açıklama gösterir.
Gıda sektöründe sahip olunmayan belgeyi beyan etmenin yaptırımı vardır.

### Başlangıç verisi

`php artisan veykemtu:siteIceriginiAktar` sitenin mevcut içeriğini
veritabanına aktarır; yönetici panele girdiğinde boş ekran değil, düzenlemeye
hazır içerik bulur. Komut tekrar çalıştırılabilir ve **panelde yapılan
düzenlemeleri ezmez** (üzerine yazmak için `--force`).

### Önbellek ve tazeleme

Paket sunucuda 60 dakika önbelleklenir. Kaydet'e basıldığında önbellek anında
temizlenir ve siteye tazeleme isteği gider; yönetici değişikliği süre dolmasını
beklemeden görür.

## 2.7 Admin paneli KAPALIDIR (17.08.2026)

> **Bu bölüm §2.5 ve §2.6'nın önüne geçer.** Orada anlatılan ekranlar hâlâ
> kodda duruyor ama **normal işletmede erişilemez.** Yönetim yüzeyi
> Kontrol Merkezi'dir.

`/admin/*` yollarının tamamı — ekranlar, gösterge paneli, **giriş formu,
çıkış ve parola sıfırlama** dahil — `404` döner. Kapatma
`Extension::closeAdminPanel()` içinde, uygulama `RequireAdminPanel` ara
katmanındadır.

### Neden kapatıldı

Kontrol Merkezi tek yönetim yüzeyi oldu. Panel ayakta durduğu sürece iki şey
getiriyordu:

1. **Parola denemesine açık bir giriş formu.** Kullanılmayan ama internete
   açık duran bir oturum kapısı, en ucuz saldırı hedefidir.
2. **İkinci bir yazma yolu.** Aynı ayarın hem panelden hem KM'den
   değiştirilebilmesi, hangisinin doğru olduğunu kimsenin bilmediği bir
   durum üretir; KM'nin denetim izi (`veykemtu_control_audit`) panelden
   yapılan değişikliği görmez.

### Neden kod silinmedi

Panel **yedek yüzey** olarak duruyor: KM çöktüğünde ya da imza anahtarı
kaybolduğunda yönetim tek bir ortam değişkeniyle geri gelmeli. Silinmiş bir
panel için tek yol yeni bir sürüm yayınlamaktır ve o an, tam da yayın
yapılamayan andır. Ayrıca 13 admin denetleyicisini silmek `AdminRegistrar`,
izinler, blade'ler ve dil dosyalarında geniş bir kazıma demek; admin
sınıfları TastyIgniter'ın kayıt akışına bağlı olduğu için yarısını silmek
açılışı kırabilir.

Yedeğin değeri eksiksiz açılmasında olduğu için **admin testleri silinmedi**:
`AdminSettingsTest`, `AdminDailyMenuTest`, `AdminPhoneOrderTest` ve
kardeşleri şalteri `setUp()` içinde açıp koşmaya devam ediyor. Kapalı hâlin
kendi testi `AdminPanelClosedTest`.

### Paneli geçici olarak açma

```bash
# platform/.env
BLD_ADMIN_ENABLED=true
```

```bash
docker compose restart app        # ya da: php artisan config:clear
```

- Değişken **açılışta bir kez** okunur; `.env`'e yazmak tek başına yetmez,
  uygulama yeniden başlatılmalıdır.
- Kabul edilen değerler: `true`, `1`, `on`, `yes`. **Tanınmayan her değer
  ve değişkenin hiç yazılmamış olması KAPALI sayılır** — yanlış yazılmış bir
  satır paneli açmamalı.
- İş bitince satırı **silin**, `false` yazıp bırakmayın: silinmiş bir satır
  varsayılana döner, `false` ise "birileri burayı bilerek açtı" izlenimi
  bırakır.
- Panel açıkken de girişler `docs/RUNBOOK.md` §9'daki personel rolleriyle
  yapılır; kapatma yetkileri sıfırlamaz.

### Kapatmanın etkilemediği şeyler

| Yüzey | Durum |
|---|---|
| `/api/*` (istemci, KDS, BBD, Kontrol Merkezi) | **Etkilenmez.** Ayrı bir rota yığını (`api`), ayrı ara katman kümesi. `AdminPanelClosedTest` bunu `/api/health` ve imzalı bir `/api/control/*` ucuyla sabitliyor. |
| Zamanlanmış işler ve konsol komutları | Etkilenmez; hiçbiri HTTP yüzeyinden geçmiyor. |
| Vitrin teması | Zaten kapalı (`Igniter::disableThemeRoutes(true)`, I-07). |
| `/admin/_assets/*` birleştiricisi | Panelle birlikte kapanır. Yalnız panelin CSS/JS'ini sunuyordu; şalter açılınca geri gelir. |

### Yeni bir admin ekranı eklenirse

Menü girdisi, yetki kutusu ve gösterge parçacığı `AdminRegistrar`'a **yine
yazılır.** Panel kapalıyken de bu tanımların doğru kalması şart: eksik
bırakılırlarsa şalter açıldığında yan menüsü boş, yetkileri personel
rollerinden düşmüş bir panel açılır — yani "geri alınabilir" dediğimiz şey
geri alınamaz olur.

## 3. Eklenti yapısı

Tüm özel kod: `platform/extensions/veykemtu/<modul>/`

Standart iskelet (**v4.3.4'te gerçek yapıdan doğrulandı** — `extension.json` diye
bir dosya yoktur, meta veri `composer.json` içindedir):
```
veykemtu/bridgeapi/
├── composer.json          # "type": "tastyigniter-package"
│                          # extra.tastyigniter-extension.code = "veykemtu.bridgeapi"
│                          # autoload.psr-4: { "Veykemtu\\BridgeApi\\": "src/" }
├── src/
│   ├── Extension.php      # Igniter\System\Classes\BaseExtension'dan türer
│   ├── Console/
│   ├── Http/Controllers/
│   ├── Http/Requests/
│   ├── Http/Resources/    # API yanıt biçimleri
│   ├── Models/
│   ├── Services/
│   └── Middleware/
├── database/migrations/   # `php artisan igniter:up` ile koşar
├── routes/api.php
└── tests/
```

`Extension.php` içinde route dosyası, komutlar ve olay dinleyicileri kaydedilir;
migration'lar `database/migrations/` altında otomatik bulunur. Yeni eklenti
eklendikten sonra `php artisan igniter:package-discover` çalıştırılır.

**`vendor/` altına asla dokunulmaz** — çekirdek davranışı değiştirmek gerekirse
Laravel event listener veya TastyIgniter hook kullanılır. Mevcut bir çekirdek
tablosuna **eklemeli** migration yazmak ihlal değildir (`bridgeapi`'nin
`statuses.status_code` kolonu böyledir).

### `igniter.api` devre dışıdır

TastyIgniter, `tastyigniter/ti-ext-api` eklentisiyle gelir ve `/api` önekinde
82 rota kaydeder — `GET /api/locations`, `/api/orders`, `/api/menus` dahil.
Bunlar bizim sözleşmemizle **aynı yolları farklı gövdelerle** işgal ediyordu.

Karar (04.08): eklenti kapatıldı, sözleşme `bridgeapi`'de sıfırdan uygulanıyor.
Paket çekirdeğin zorunlu bağımlılığı olduğu için composer'dan kaldırılamaz;
kapatma `platform/bootstrap/cache/disabled-addons.json` dosyasındadır ve bu
dosya **commitlenir** (`.gitignore`'da istisnası vardır). `laravel/sanctum`
ayrı bir pakettir, durmaya devam eder.

Yeniden açmak `/api` rotalarımızı sessizce gölgeler — açmayın.

## 4. Yazılacak eklentiler

> **İptal:** `veykemtu/channels` eklentisi (kanal kavramı, teslim kodu üreteci, kurum içi sipariş ekranı) **yazılmayacaktır** — bkz. `docs/00-genel-bakis.md` §4.

### 4.1 `veykemtu/bridgeapi`

**Sorumluluk:** Tüm API uçları (`docs/03-api-sozlesmesi.md`).

- Migration: `veykemtu_kitchen_devices`, `veykemtu_print_jobs`.
- **Kimlik:** Laravel Sanctum. Müşteri token'ı `customer` kapsamı, cihaz token'ı `kitchen` kapsamı. Kapsam kontrolü middleware'de.
- **Cihaz eşleme:** `KitchenDeviceService` — admin panelde "Cihaz Ekle" ile 12 karakterlik kod üretilir (10 dk geçerli), `POST /api/kitchen/pair` ile token'a çevrilir. Token hash'lenerek saklanır.
- **Durum geçiş servisi** `OrderStatusTransition`: `docs/02-veri-modeli.md` §3'teki tabloyu uygular. Geçersiz geçişte `InvalidTransitionException` → `422`.
- **Resource sınıfları:** API yanıt biçimleri sözleşmeye birebir uyar. `KitchenOrderResource` fiyat ve iletişim bilgisi **içermez**.
- **Fiş verisi:** `ReceiptBuilder` — iki tip (`mutfak`, `musteri`) için yapılandırılmış veri döner.
- **Sipariş alım şalteri:** `ordering_enabled` vitrin ayarı + admin panelde bir anahtar. Kapalıyken `POST /api/orders` → `422 LOCATION_CLOSED`.
- **Üretim listesi:** `ProductionListService` — `docs/02-veri-modeli.md` §4'teki sorgu.
- **Hata biçimi:** Global exception handler tüm hataları sözleşmedeki tek biçime çevirir.
- **OpenAPI üretimi:** `php artisan veykemtu:openapi` → `platform/openapi.json`.
- **Oran sınırlama:** `docs/03-api-sozlesmesi.md` §8.

**Kabul:** Sözleşmedeki her uç çalışıyor, mutlu yol + bir hata yolu testi var, `openapi.json` üretiliyor.

### 4.2 `veykemtu/push`

- Migration: `veykemtu_device_tokens`.
- FCM entegrasyonu (HTTP v1 API, servis hesabı `.env`'den).
- Durum değişimi olayını dinler, ilgili müşteriye bildirim gönderir.
- Bildirim metinleri Türkçe, durum bazlı: `onaylandi` → "Siparişiniz onaylandı", `hazirlaniyor` → "Siparişiniz hazırlanıyor", `hazir` → "Siparişiniz hazır", `yolda` → "Siparişiniz yola çıktı", `teslim_edildi` → "Siparişiniz teslim edildi".
- Gönderim başarısızsa sessizce loglar, siparişi etkilemez.

### 4.3 `veykemtu/sms`

- Netgsm API entegrasyonu (`.env`: kullanıcı, şifre, başlık).
- Yalnızca iki tetik: sipariş onayı, sipariş yolda.
- Şablonlar ayarlardan düzenlenebilir.
- Rate limit ve hata durumunda kuyruk (Laravel queue) ile tekrar deneme.

### 4.4 `veykemtu/appversion`

- Migration: `veykemtu_app_releases`.
- `GET /api/app-version` ucu.
- Admin ekranı: sürüm kaydı ekleme/düzenleme.

### 4.5 `veykemtu/realtime` (Faz 1.5 — zaman kalırsa)

- Laravel Reverb kurulumu.
- Sipariş olaylarını `private-kitchen` ve `private-customer.{id}` kanallarına yayınlar.
- Kanal yetkilendirmesi cihaz/müşteri token'ıyla.

## 5. Ödeme entegrasyonu

Sanal POS entegrasyonu bir TastyIgniter **payment gateway eklentisi** olarak yazılır: `veykemtu/payment`. Sağlayıcı bilgisi `.env`'den gelir; **anahtarlar repoya girmez**.

Akış: sipariş oluşur (`payment.status = pending`) → istemci `redirect_url`'e gider → sağlayıcı callback'i `POST /payment/callback` ucuna düşer → imza doğrulanır → `payment.status = paid` → sipariş normal akışına devam eder.

Callback **idempotent** olmalı: aynı işlem iki kez gelirse sipariş iki kez ödenmiş sayılmaz.

## 6. Testler

```bash
cd platform && php artisan test
```
Her uç için `tests/Feature/` altında en az: 200 mutlu yol, 401/403 yetki, 422 doğrulama. `OrderStatusTransition` için tüm geçiş matrisini kapsayan unit test zorunlu.

## 7. Yerelleştirme

Tüm kullanıcıya görünen metinler `lang/tr/` altında. Kodda sabit Türkçe metin yasak.

### 7.1 Admin panelinin Türkçesi (05.08.2026)

TastyIgniter çekirdeği ve eklentileri **yalnızca İngilizce** ile geliyor;
marketplace'ten dil paketi çekmek carte anahtarı istiyor ve bizde yok.
Türkçe çeviriler bu yüzden **kendi kaynak kodumuz**:

| Katman | Yer |
|---|---|
| Yerel `tr` olması | `bridgeapi` göçü: `..._create_turkish_language.php` |
| Çeviriler | `platform/lang/vendor/<dizin>/tr/<grup>.php` |
| Denetim | `php artisan veykemtu:ceviri-denetle` |
| Menü temizliği | `bridgeapi/src/Admin/NavigationTrimmer.php` |

**Yerel `.env` ile ayarlanmaz.** `APP_LOCALE=tr` yazılıydı ve hiçbir işe
yaramıyordu: `Igniter\System\ServiceProvider::loadLocalizationConfiguration`
yereli veritabanındaki **varsayılan dil kaydından** okuyor. Tabloda
yalnızca İngilizce olduğu sürece etkin yerel `en` kalır.

**Çevrilmemiş anahtar paneli bozmaz.** Laravel `app.fallback_locale`
(`en`) ile karşılar; sahada ölçüldü. Bu yüzden çeviri parça parça
ilerleyebilir ve kapsam yüzde yüz olmak zorunda değil.

#### Dizin adında NOKTA DEĞİL TİRE

Çeviri ad alanları `igniter.cart` biçiminde ama TastyIgniter Laravel'in
geçersiz kılma çözümlemesini değiştirmiş.
`Flame\Translation\FileLoader::loadNamespaceOverrides` noktayı `/` ya da
`-` yapıp altı aday yola bakıyor; **`igniter.cart` dizinine hiç bakmıyor**.

```
✗ platform/lang/vendor/igniter.cart/tr/default.php   ← hiç okunmaz
✓ platform/lang/vendor/igniter-cart/tr/default.php
```

Sahada tam bu tuzağa düşüldü: dosyalar noktalı dizine yazıldı, denetim
"sorun yok" dedi, panel İngilizce kaldı. Denetime bu yüzden **"dosya
gerçekten yükleniyor mu"** kontrolü eklendi (`TranslationAudit::loadProblems`):
statik karşılaştırma dosyanın doğru YAZILDIĞINI gösterir, çevirmenin onu
BULDUĞUNU göstermez.

#### `.gitignore` tuzağı

Kök `.gitignore` içindeki `vendor/` kuralının başında eğik çizgi yok, yani
**her derinlikteki** `vendor` dizinini dışlıyor — `platform/lang/vendor/`
dahil. Git dışlanmış bir dizine hiç inmediği için, o dizinin içine yazılan
`!` kuralları hiç değerlendirilmez. Kökte `!platform/lang/vendor/`
istisnası olmadan çeviriler yerelde çalışır, commitlenmez ve sunucuda
panel İngilizce kalır. Aynı sınıftan bir hata `public/vendor` yüzünden
panele hiç girilememesine yol açmıştı (RUNBOOK §4.6).

#### Tarih biçimleri

`igniter::system.php` ve `moment` biçimleri de çeviri dosyasında.
Çekirdek `d M Y` ve `hh:mm a` kullanıyor ("05 Aug 2026, 02:30 pm");
Türkçe karşılıkları `d.m.Y` ve `H:i`. Bunlar düzeltilmezse panel Türkçe
görünür ama tarihleri İngilizce ve 12 saatlik okur.

#### Eklenti devre dışı bırakılamaz

"Gereksizleri kaldıralım" isteği eklenti kapatarak çözülemiyor:
bağımlılıklar döngüsel. `ti-ext-local` (şubeler, menüler)
`ti-ext-reservation`'ı zorunlu tutuyor, o da `ti-ext-local`'ı; aynı
şekilde `ti-ext-cart` → `ti-ext-coupons` → `ti-ext-cart`. Rezervasyonu
kapatmak menü yönetimini de düşürür. Bu yüzden kod yüklü kalıyor ve
yalnızca menü girdileri gizleniyor.

Kanca **`admin.navigation.extendItems` olayı**, `registerCallback` değil:
`Navigation::loadItems()` önce callback'leri, sonra eklenti girdilerini
yüklüyor; callback içinde silinen girdi hemen ardından yeniden ekleniyor.
