# 11 — Yol Haritası (Faz 2)

Bu dosya **planı** tutar, kararı değil. Buradaki bir madde kodlanmadan önce
`docs/openapi.yaml` ve ilgili spesifikasyon güncellenir; sözleşme her zaman
önce gelir (`AGENTS.md` §2.3).

Hedef, kullanıcının cümlesiyle: *"bir nevi kendi yemeksepeti uygulamamızı
yazıyoruz."* Bu, Faz 1'in "tek vitrin, sabit ücret, kuponsuz" varsayımlarının
tamamının değişeceği anlamına geliyor. Aşağıdaki sıra bunu **kırmadan**
yapmanın sırasıdır.

---

## 0. Değişmeyen kurallar

Faz 2'de de geçerli, tartışmaya kapalı:

- **Para her yerde `int` kuruştur.** Hiçbir katmanda `float` para
  tutulmaz — kampanya ve kupon hesapları ondalık hataya en açık yerdir ve
  bir kuruşluk sapma raporları tutmaz hâle getirir.
- **Fiyatı sunucu hesaplar.** İstemcinin gönderdiği tutar yok sayılır
  (`docs/03` §4). Kupon ve kampanya bunu değiştirmez: indirim de sunucuda
  hesaplanır, istemci yalnızca **gösterir**.
- **Tek kaynak veritabanıdır.** Ürün, fiyat, görsel, stok, kampanya —
  hepsi admin panelden girilir, API'den okunur. Hiçbir istemci kendi
  kopyasını gömmez.
- **Şema kırılmaz.** Yalnızca ekleme yapılır.

---

## 1. Sıra ve bağımlılıklar

```
F2-01 Adres modeli + Maps
   └─ F2-02 Teslimat bölgeleri (poligon)
        ├─ F2-03 Bölgeye göre asgari sepet + teslimat ücreti
        └─ F2-04 Gel-al noktaları ve saatleri
F2-05 Fiyat motoru (tek yerde hesap)
   ├─ F2-06 Kampanyalar
   ├─ F2-07 Kupon kodları
   └─ F2-09 Abonelik (kurumsal öğle yemeği)  ← catering'in asıl iş modeli
F2-08 Admin: yoğunluk ve şalterler tek ekranda
```

`F2-05` **kritik yol üzerindedir**: kampanya ve kuponu ayrı ayrı, her biri
kendi indirim mantığıyla yazmak, iki indirimin çakıştığı gün toplamın
yanlış çıkmasıyla biter. Önce tek bir hesap motoru, sonra kuralları ona
takmak.

---

## 2. F2-01 — Adres modeli ve Google Maps

**Bugün:** adres serbest metin (`line1`, `district`, `city`). Koordinat yok.

**Hedef:** her adresin `lat`/`lng`'si olacak; bölge, ücret ve asgari tutar
buradan türeyecek.

| Parça | Karar |
|---|---|
| Adres tamamlama | Places Autocomplete (müşteri yazarken) |
| Koordinat | Geocoding — **sunucuda**, istemcide değil |
| Harita gösterimi | Maps JavaScript API (web), `google_maps_flutter` (mobil) |

> **Geocoding neden sunucuda:** anahtar istemciye gömülürse kotayı
> yabancılar harcar. Ayrıca teslimat ücretini belirleyen koordinatı
> istemcinin göndermesi, istemcinin ücreti seçmesi demektir — sunucu
> adresi kendisi çözmeli.

**Anahtar yönetimi:** `GOOGLE_MAPS_SERVER_KEY` (IP kısıtlı, sunucu) ve
`GOOGLE_MAPS_BROWSER_KEY` (HTTP referer kısıtlı, yalnızca Autocomplete).
İkisi de `.env`, repoya girmez.

**Maliyet tuzağı:** Autocomplete oturum başına ücretlendirilir. `sessiontoken`
kullanılmazsa her tuş vuruşu ayrı istek sayılır ve fatura 10-20 katına çıkar.
Bu, plan aşamasında not edilmezse sahada fark edilmez.

**Sözleşme etkisi (additive):**
- `Address` şemasına `lat`, `lng`, `place_id` (hepsi opsiyonel)
- Yeni uç: `POST /addresses/resolve` → serbest metni koordinata çevirir,
  bölge ve ücret önizlemesi döner

---

## 3. F2-02 / F2-03 — Teslimat bölgeleri ve bölgeye göre kurallar

**Bugün:** tek `delivery_fee`, tek `min_order_total` — tüm şehir için aynı.

**Hedef:** bölge bazlı. TastyIgniter'ın **kendi `location_areas` tablosu
bunu zaten yapıyor** (poligon ya da mesafe tabanlı) — yeni tablo açmıyoruz.

| Bölge alanı | Ne |
|---|---|
| poligon / yarıçap | Sınır |
| `min_order_total` | O bölgenin asgari sepeti |
| `delivery_fee` | O bölgenin ücreti |
| `eta_minutes` | Tahmini süre |

**Sözleşme etkisi:**
- `Location.min_order_total` ve `delivery_fee` **kalır** (kırmıyoruz) ama
  artık "varsayılan bölge" değeri anlamına gelir
- Yeni: `GET /locations/{id}/zones` ve `POST /addresses/resolve` yanıtında
  `zone` nesnesi

> **Kırılma riski:** istemciler bugün `Location.delivery_fee`'yi ekranda
> gösteriyor. Bölge geldiğinde bu değer "adres girilene kadar geçerli
> tahmin" olur. İstemcilerin adres seçilince **yeniden hesaplatması**
> şart; yoksa müşteriye 40 ₺ gösterip 60 ₺ tahsil ederiz.

---

## 4. F2-04 — Gel-al noktaları

**Bugün:** `delivery_type=pickup` var ama nereden alınacağı sabit (tek vitrin).

**Hedef:** birden fazla gel-al noktası, her birinin kendi saatleri ve
hazırlık süresi. Poligon gerekmez; nokta + çalışma takvimi yeter.

---

## 5. F2-05 — Fiyat motoru

**Bunu önce yazmadan kampanya/kupon yazılmaz.**

> **Kapsam kararı (07.08.2026):** Tam fiyat motoru (kampanya/kupon) **hâlâ
> kapsam dışı.** Abonelik turu (F2-09) bunu önkoşul yapmadı: abonelik anlaşmalı
> fiyatı için gereken tek şey fiyatı abonelik/satırda saklayıp sipariş
> üretilirken **kopyalamaktı**. Kampanya/kupon motoru F2-06/F2-07 ile birlikte
> ayrı ele alınacak; o zamana dek `total` = ödenecek tutar, tek toplam.

Tek bir sınıf, tek bir sıra:

```
1. Kalem ara toplamı        (adet × birim fiyat + seçenek farkları)
2. Ürün/kategori kampanyaları
3. Sepet kampanyaları        (X al Y öde, kademeli indirim)
4. Kupon                     (en fazla BİR tane)
5. Teslimat ücreti           (bölgeden; kampanya bunu sıfırlayabilir)
6. Yuvarlama                 (kuruş, tek yerde)
```

Çıktı **döküm** olmalı, tek bir toplam değil: müşteri "neden bu fiyat"
sorusunu ekranda görebilmeli ve destek çağrısı gelmemeli.

**Sözleşme etkisi:** `OrderDetail`'e `discounts: [{code, label, amount}]`
ve `discount_total`. `total` alanının **anlamı değişmez** (ödenecek tutar);
bu yüzden eski istemciler kırılmaz.

---

## 6. F2-06 — Kampanyalar

| Tür | Örnek |
|---|---|
| Yüzde / tutar indirimi | Çorbalarda %20 |
| X al Y öde | 3 al 2 öde |
| Kademeli | 500 ₺ üstü ücretsiz teslimat |
| Zaman kısıtlı | Hafta içi 14:00-16:00 |
| Kanal kısıtlı | Yalnızca mobil uygulama |

Her kampanyanın: başlangıç/bitiş, öncelik, **birleşebilir mi** bayrağı.

> **En sık hata:** iki kampanyanın üst üste binmesi ve toplamın eksiye
> düşmesi. Motor, indirim toplamını ara toplamla sınırlamalı ve bunun
> testi olmalı.

---

## 7. F2-07 — Kupon kodları

TastyIgniter'da **`ti-ext-coupons` zaten kurulu** (`platform/vendor/`).
Kendi kupon tablomuzu açmadan önce onun karşılayıp karşılamadığına
bakılacak — `AGENTS.md` §2.4.

Karşılaması gerekenler: tek kullanımlık / çok kullanımlık, müşteri başına
limit, asgari sepet, ürün-kategori kısıtı, son kullanma, ilk sipariş
kuponu.

**Sözleşme etkisi:** `POST /orders` gövdesine `coupon_code` (opsiyonel),
ve doğrulama için `POST /coupons/validate` — müşteri kodu ödeme ekranında
girer girmez geçerliliğini görmeli, siparişi gönderdiğinde değil.

> **Güvenlik:** kupon doğrulama ucu kaba kuvvete açıktır (geçerli kod
> aramak). `bld-auth` benzeri sıkı bir oran sınırı ve müşteri başına
> deneme limiti gerekir.

---

## 7.5 F2-09 — Abonelik (kurumsal öğle yemeği) — **YAPILDI (07.08.2026)**

> **Durum:** Abonelik motoru + cari hesap defteri + B2B geçişi uygulandı.
> Backend `bridgeapi` (migrations + modeller + `SubscriptionGenerateCommand` +
> `AccountLedger` + admin ekranları/dashboard/scheduler), sözleşme additive
> (`docs/openapi.yaml`), mobil self-servis (Aboneliklerim + Cari hesabım +
> kurumsal kayıt + sipariş kapısı). Şema: `docs/02` §7, uçlar: `docs/03` §12,
> senaryolar: `docs/10` S8/S9.
>
> **F2-05 önkoşulundan bilinçli sapma:** F2-09 notu "F2-05 (fiyat motoru)
> önkoşuldur" diyordu. Sapıldı — gerekçe §5'te. Abonelik anlaşmalı fiyatı için
> tam kampanya/kupon motoru gerekmez; fiyat abonelik/satırda saklanıp sipariş
> üretilirken o günkü değeriyle **kopyalanır** (adres kopyalama gerekçesiyle
> aynı). İki indirimin çakışıp toplamı eksiye düşürme riski (§6) böylece davet
> edilmez.
>
> **YAPILDI (B-19 sonrası):** `menu_mode = daily_menu` artık çalışıyor. Erteleme
> gerekçesi ("günün menüsü kaynağı yok") B-19 ile ortadan kalktı:
> `veykemtu_daily_menus` o kaynağın kendisi. `OrderFactory` o servis gününün
> **yayınlanmış** menüsünü çözüp siparişi tek seferlik menü siparişiyle **aynı
> şekilde** üretiyor — fiyatlı bir paket üst satırı + sıfır fiyatlı bileşen
> satırları — ki `ProductionListService`, `SubscriptionKitchenPlan::totals` ve
> `OrderPresenter::kitchenItems` içindeki `bld_line_role != 'package'` süzgeci
> abonelikte ve tek seferlik siparişte aynı davransın.
>
> Fiyat **her iki modda da** `agreed_unit_price_kurus`: sözleşme "o gün ne
> pişerse pişsin porsiyonu şu kadar" der, fiyatı günün menüsünden almak mutfak
> pahalı bir gün girdiğinde faturayı sessizce büyütürdü. Bu yüzden anlaşmalı
> fiyat `daily_menu`'de de ZORUNLU.
>
> **Menü yoksa sessizce atlanmaz.** `veykemtu:abonelik-uret` hedef gün için
> `daily_menu` aboneliği varken yayınlanmış menü yoksa **tek** ve yüksek sesli
> bir hata satırı basar (abonelik başına bir yığın izi değil), o abonelikleri
> üretime hiç sokmaz ve `FAILURE` döner. `veykemtu_subscription_runs` satırı
> yazılmadığı için menü yayınlandıktan sonra komut yeniden koşturulunca sipariş
> doğar; `UNIQUE(subscription_id, delivery_point_id, service_date)` tek sipariş
> garantisini korur. Mutfak tarafında `SubscriptionKitchenPlan` aynı durumu
> `kind = 'not_generated'` ile bildirir (KDS o türü **kırmızı** çiziyor; yeni
> bir tür mavi/bilgi olarak görünürdü). Gösterge panelindeki BLD kutusu da
> önümüzdeki yedi günün menüsü olmayan günlerini adlarıyla listeler — gece
> üretimi 22:00'de yarın için koştuğundan uyarı yöneticinin zaten baktığı
> yerde durmalı.

**Catering'in asıl iş modeli bu, tek seferlik sipariş değil.** Müşterinin
tarifi: *"adam aylık abone olacak öğle yemeği için, mesela 20 adet her gün
siparişi olacak, bizden satın almış olacak."*

### Bunun tek seferlik siparişten farkı

Abonelik **bir sipariş değil, sipariş üreten bir kural**. Bu ayrımı
kaçırmak en pahalı hatadır: aboneliği "tekrar eden sipariş" diye
modellersek, bir günü atlamak ya da o günkü adedi değiştirmek geçmişi de
değiştirir. Doğru model:

```
Abonelik (kural)  ──her gün──>  Sipariş (o günün gerçeği)
```

Sipariş üretildikten sonra **kendi hayatını yaşar**: mutfak onaylar,
hazırlar, teslim eder. Abonelik değişse bile üretilmiş sipariş değişmez —
teslim edilmiş bir günün ne olduğu okunabilir kalmalı.

### Veri modeli

| Alan | Ne |
|---|---|
| müşteri | Kurumsal hesap |
| teslimat noktası | Adres defterinden; **birden fazla olabilir** (aynı firmanın iki katı) |
| adet | Günlük porsiyon (20) |
| menü seçimi | "Günün menüsü" ya da sabit ürün listesi |
| takvim | Hangi günler (hafta içi / seçili günler) |
| dönem | Başlangıç–bitiş, ya da süresiz + iptal |
| teslim saati | Her gün aynı saat penceresi |
| fiyat | Porsiyon başı **anlaşmalı fiyat** — liste fiyatından farklı |
| ödeme | Peşin aylık, ya da cari hesaba işlenip ay sonu faturalanır |

### Günlük sipariş üretimi

Zamanlanmış bir iş her gece ertesi günün siparişlerini üretir ve KDS'e
normal sipariş olarak düşer — mutfağın "abonelik" diye ayrı bir akış
öğrenmesi gerekmez.

> **Üretim saati kesim saatinden ÖNCE olmalı** ve aradaki fark
> müşterinin adet değiştirmesine yetmeli. Sabah 06:00'da üretip 07:00'de
> kesim yapmak, "yarın 5 kişi eksiğiz" diyen müşteriye yer bırakmaz.

> **İdempotent olmalı.** İş iki kez koşarsa (yeniden başlatma, elle
> tetikleme) aynı gün için ikinci sipariş üretilmemeli.
> `UNIQUE(subscription_id, service_date)` bunu şemada garanti eder —
> koda güvenmek yetmez.

### Kaçınılması gereken tuzaklar

**Tatil ve kapalı günler.** Resmî tatilde üretim durmalı. Bunu elle
yapmak, bayram sabahı 400 porsiyonun boşa pişmesi demektir. Vitrinin
çalışma takvimi ve bir "kapalı günler" listesi kurala bağlanmalı.

**Ara değişiklikler.** "Yarın 20 değil 12" ve "gelecek haftadan itibaren
25" farklı şeylerdir: birincisi tek günlük istisna, ikincisi kuralın
kendisi. İkisi için ayrı yol gerekir; tek bir "adet" alanını değiştirmek
geçmişi bozar.

**Duraklatma.** Firma iki hafta kapalı. İptal değil, duraklatma — abonelik
geri döndüğünde aynı fiyatla devam etmeli.

**Anlaşmalı fiyat liste fiyatından bağımsızdır.** Menü fiyatı zamla
değişince abonelik fiyatı kendiliğinden değişmemeli; sözleşme dönem
boyunca sabit. Sipariş üretilirken **o günkü anlaşmalı fiyat** siparişe
kopyalanır (adres kopyalamasıyla aynı gerekçe: geçmiş değişmemeli).

**Diyet ve alerjen varyantları.** 20 porsiyonun 3'ü vejetaryen olabilir.
Abonelik satırı tek bir ürün değil, **satır listesi** olmalı.

**Fatura.** Ay sonu tek fatura, sipariş başına değil. Cari hesap zaten
var (`payment_method: account`); abonelik onun üstüne oturur. e-Arşiv
ayrı bir süreç (`docs/10` bilinen sınırlar).

### Mutfak tarafı

Ekranda değişen bir şey yok — abonelik siparişleri normal sipariş olarak
düşer. **Üretim şeridi zaten ürün bazında topluyor** ("120 porsiyon tavuk
sote"), ki abonelikte asıl ihtiyaç budur.

Tek ekleme: kartta "abonelik" rozeti. Mutfak, tek seferlik bir siparişle
her gün gelen bir kurumu ayırt edebilmeli — ikincisinde hata yapmak
sözleşme kaybettirir.

### Sözleşme etkisi (additive)

- `Subscription` şeması ve `GET/POST/PATCH /subscriptions`
- `Order`'a `subscription_id` (nullable) — müşteri "bu hangi abonelikten"
  görebilsin
- Mutfak listesindeki `KitchenOrder`'a `is_subscription` (bool)

### Bağımlılık

**F2-05 fiyat motorundan sonra.** Anlaşmalı fiyat, kampanya ve kupon aynı
hesabın içinde yaşayacak; aboneliği ayrı bir fiyat yoluyla yazmak, ikisinin
çakıştığı gün toplamı bozar.

---

## 8. F2-08 — Admin: yoğunluk ve şalterler tek ekranda — **YAPILDI (05.08.2026)**

Sayfa: **Ayarlar → Eklentiler → BLD Ayarları** (yan menüde Restoran → BLD
Ayarları). Yedi şalterin tamamı buradan yönetiliyor ve değerler
`LocationGate` üzerinden okunup yazılıyor — ikinci bir kaynak yok.

Ayrıca bir gösterge paneli parçacığı: iki şalter, kesim saati, bugünkü
sipariş ve ciro, bekleyen sipariş, basılmamış fiş, çevrimiçi kasa sayısı.
Parçacık panele **elle eklenmeli** (Gösterge Paneli → düzenle → parçacık ekle).

Üç tuzak kapatıldı:

- **Para alanları `number` değil `text`.** `Form::getSaveData()` `number`
  tipini postback'te `(int)` ile daraltıyor; "45.50" kaydedilmeden önce
  45'e düşüyor ve kuruşlar tamamen kayboluyordu.
- **Yoğunluk yarışı.** Form, sayfa çizildiği andaki değeri gizli alanda
  taşıyor ve `busy` yalnızca gönderilen değer ondan farklıysa yazılıyor.
  Yönetici sayfayı açık bırakıp yarım saat sonra ilgisiz bir alanı
  kaydederse mutfağın bu arada bastığı tuş ezilmiyor.
- **Renk ayrımı.** Yoğunluk rozeti sarı, kapalı sipariş alımı kırmızı.
  Aynı renk olsalardı yönetici yanlış şalteri arardı.

**Hâlâ eksik:** mutfak cihazları listesi ve fiş kuyruğu ekranları.
TastyIgniter admin denetleyicilerini yalnızca `src/Http/Controllers/`
altından yüklüyor; cihaz eşleme/iptal bugün hâlâ `php artisan veykemtu:kds`
ile yapılıyor.

**Ayrıca:** `Operatör` rolü bu sayfayı göremiyor ama sebebi kısmen
çekirdek — `Extensions` denetleyicisi `edit` için `Site.Settings` istiyor
ve o izin diğer tüm ayar sayfalarını da açıyor. `vendor/`'a dokunmadan
daraltılamaz.

### Özgün plan (kayıt için)

**Bugün:** yoğunluk şalteri mutfak ekranından açılıp kapanıyor ve API'de
görünüyor (`Location.busy`), **ama admin panelde bir yüzü yok.**

Aynı durum diğer şalterler için de geçerli: `ordering_enabled`,
`order_cutoff`, `min_order_total`, `delivery_fee`, `payment_methods` —
hepsi `location_options` tablosunda yaşıyor ve bugün yalnızca
`veykemtu:setup` komutuyla veya doğrudan veritabanından değişiyor.

**Plan:** eklentiye tek bir "BLD Ayarları" admin sayfası. Değerler
`LocationGate` üzerinden okunup yazılır — ikinci bir kaynak açılmaz.

> **Neden TastyIgniter'ın Location formuna eklemiyoruz:** değerler
> `location_options`'ta duruyor ve çekirdek formun kaydetme akışına
> girmek, çekirdek davranışını uzaktan değiştirmek demek. Kendi
> sayfamız `extensions/veykemtu/` sınırının içinde kalıyor (ADR-02).

---

## 9. Bu plan tamamlanınca değişecek belgeler

| Dosya | Ne değişecek |
|---|---|
| `docs/openapi.yaml` | Adres koordinatları, bölge, indirim, kupon uçları |
| `docs/02-veri-modeli.md` | `location_areas` kullanımı, indirim tabloları |
| `docs/03-api-sozlesmesi.md` | Yeni uçların insan tarafı |
| `docs/06/07` | Adres seçimi ve harita ekranları |
| `docs/10-test-kabul.md` | Bölge/kampanya/kupon kabul ölçütleri |

**F2-09 (abonelik) + B2B + cari için güncellendi (07.08.2026):** `docs/02` §7
(yeni tablolar), `docs/03` §12 (kurumsal kayıt + cari + abonelik uçları),
`docs/06`/`07` (B2B kayıt + mobil self-servis), `docs/10` (S8/S9 + "fatura
kesilmez" sınırı), `docs/openapi.yaml` (additive şema/yollar).

---

## 10. Faz 2'ye girmeden kapatılacaklar

Bunlar Faz 1'in açık uçlarıdır ve yeni özellik eklemeden önce kapanmalı:

- [ ] `POS_ALLOW_SIMULATION` kaldırılacak, gerçek sanal POS bağlanacak —
      **açık kaldığı sürece her sipariş bedava**

      > **AÇIK BIRAKILMASI KARARLAŞTIRILDI (12.08.2026).** Sağlayıcı
      > sözleşmesi yapılana kadar kart ödemesi simülasyon kalıyor; işletme
      > sahibinin bilinçli kararı. Risk görünür kılındı: admin panelin her
      > ekranının tepesinde "SİMÜLASYON MODU — kart ödemeleri gerçek
      > değildir" şeridi duruyor (`_partials/admin/simulation_banner`) ve
      > yalnızca `SimulatedPos::isAllowed()` true iken çiziliyor, yani
      > gerçek POS bağlandığı gün kendiliğinden kayboluyor.
      >
      > v2.0'da simülasyonun ikinci bir kullanıcısı doğdu: **cari borç
      > ödemesi** (`/cari-odeme-simulasyon/{hash}`). Gerçek POS'a geçerken
      > iki akış birden taşınacak — sipariş ödemesi ve cari ödeme.

      > **BAĞLANMA NOKTASI HAZIR (K-13, 11.08.2026).** Sağlayıcı-bağımsız
      > `Veykemtu\Payment\Refunds\RefundGateway` arayüzü ve
      > `RefundManager` yazıldı; sipariş düzenleme iadeleri buradan
      > geçiyor. Gerçek POS seçildiğinde yapılacak tek iş: arayüzü
      > uygulayan bir sınıf eklemek ve `.env`'deki `BLD_REFUND_DRIVER`
      > değerine adını yazmak. Sürücü seçimi **ödeme yönteminden**
      > türüyor (`account` → cari defter, `cash` → manuel iade); yalnız
      > `online` bu değişkeni okuyor.
- [ ] GitHub Actions hesap düzeyinde çalışmıyor (18 koşu, hiçbiri
      runner'a atanmadı) — Faz 2'ye CI'sız girilmez
- [ ] `BACKUP_REMOTE` tanımsız; yedekler yalnızca aynı sunucuda
- [ ] iOS derlemesi için Mac + Apple Developer Program
