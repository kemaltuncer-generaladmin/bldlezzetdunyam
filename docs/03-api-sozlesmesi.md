# 03 — API Sözleşmesi

**Bu doküman tek doğruluk kaynağıdır.** Sunucu bunu uygular, istemciler buna göre yazılır. Değişiklik önce burada yapılır, sonra kodda.

Taban adres: `https://api.benimlezzetdunyam.com.tr/api`
Tüm istek/yanıtlar `application/json; charset=utf-8`.

## 1. Ortak kurallar

### 1.1 Zorunlu başlıklar

| Başlık | Değer | Kim gönderir |
|---|---|---|
| `X-App-Id` | `website` \| `musteriapp` \| `mutfakapp` | hepsi |
| `X-App-Version` | semver, örn. `1.0.0` | hepsi |
| `Authorization` | `Bearer <token>` | kimlik gerektiren uçlar |
| `Accept-Language` | `tr` | hepsi |

### 1.2 Hata biçimi (tüm hatalar için tek biçim)

```json
{
  "error": {
    "code": "INVALID_TRANSITION",
    "message": "Sipariş bu duruma geçirilemez.",
    "details": { "from": "yeni", "to": "hazir" }
  }
}
```

**Hata kodları:**

| Kod | HTTP | Anlam |
|---|---|---|
| `UNAUTHENTICATED` | 401 | Token yok/geçersiz |
| `FORBIDDEN` | 403 | Kapsam yetersiz |
| `NOT_FOUND` | 404 | Kayıt yok |
| `VALIDATION_FAILED` | 422 | Alan doğrulama hatası (`details` alan bazlı) |
| `INVALID_TRANSITION` | 422 | Geçersiz durum geçişi |
| `LOCATION_CLOSED` | 422 | Vitrin kapalı / sipariş saati dışı |
| `ITEM_UNAVAILABLE` | 422 | Ürün stokta/menüde değil |
| `DEVICE_REVOKED` | 403 | Cihaz token'ı iptal edilmiş |
| `RATE_LIMITED` | 429 | Çok fazla istek |
| `SERVER_ERROR` | 500 | Beklenmeyen |

### 1.3 Tarih ve para

- Tarih/saat: ISO 8601, UTC, örn. `2026-08-04T11:30:00Z`. İstemci yerel saate çevirir (Europe/Istanbul).
- Para: **kuruş cinsinden tam sayı**. `4550` = 45,50 TL. Ondalık float asla kullanılmaz.
- Para birimi alanı: `"currency": "TRY"`.

### 1.4 Uyumluluk kuralı

Alan **eklenebilir**. Alan silinemez, adı/tipi değişemez. İstemciler bilmedikleri alanları yok sayar (asla hata vermez). Kırıcı değişiklik `/api/v2/` ile açılır.

### 1.5 Sayfalama

```
GET /api/...?page=1&per_page=25
```
```json
{ "data": [...], "meta": { "page":1, "per_page":25, "total":132, "last_page":6 } }
```

---

## 2. Kimlik doğrulama

### POST /api/auth/register
Müşteri kaydı.

**İstek**
```json
{
  "first_name": "Ayşe",
  "last_name": "Yılmaz",
  "email": "ayse@ornek.com",
  "telephone": "5551234567",
  "password": "••••••••",
  "kvkk_accepted": true
}
```
**Yanıt 201**
```json
{ "token": "eyJ...", "customer": { "id": 12, "first_name": "Ayşe" } }
```
`kvkk_accepted` false ise → `422 VALIDATION_FAILED`.

### POST /api/auth/login
```json
{ "email": "ayse@ornek.com", "password": "••••••••" }
```
**Yanıt 200** — `register` ile aynı gövde.

### POST /api/auth/logout
Token'ı iptal eder. **Yanıt 204**.

### GET /api/auth/me
**Yanıt 200**
```json
{
  "id": 12,
  "first_name": "Ayşe",
  "last_name": "Yılmaz",
  "email": "ayse@ornek.com",
  "telephone": "5551234567",
  "default_location_id": 1
}
```

---

## 3. Katalog (kimlik gerektirmez)

### GET /api/locations
Faz 1'de tek vitrin döner. Dizi biçimi korunur (ileride vitrin eklenirse kırılmasın).
```json
{ "data": [
  { "id":1, "name":"Benim Lezzet Dünyam", "slug":"catering",
    "is_open":true, "ordering_enabled":true,
    "order_cutoff":"08:00", "min_order_total":25000,
    "service_weekdays":[1,2,3,4,5],
    "max_lookahead_days":7,
    "delivery_fee":4000,
    "payment_methods":["online","cash"],
    "busy": false,
    "busy_message":"Mutfağımız şu anda yoğun. Siparişiniz alınır ancak hazırlanması normalden uzun sürebilir.",
    "eta": {
      "delivery": { "min_minutes":60, "max_minutes":85, "source":"configured", "busy":false },
      "pickup":   { "min_minutes":40, "max_minutes":55, "source":"configured", "busy":false }
    } }
]}
```

| Alan | Anlam |
|---|---|
| `is_open` | Çalışma saatlerinden **türetilir**. Şu an sipariş saati içinde miyiz? |
| `ordering_enabled` | Yöneticinin admin panelden çevirdiği **elle ana şalter**. `false` ise saat uygun olsa bile sipariş alınmaz. |
| `order_cutoff` | Vitrinin **varsayılan** kesim saati (`HH:mm`, Europe/Istanbul) veya `null`. **ARTIK BAĞLAYICI DEĞİL (16.08.2026):** her servis günü kendi sabah kesim saatinde kapanır ve o saat Kontrol Merkezi'nden gün gün ayarlanır. Bağlayıcı olan `DailyMenu.cutoff_at` / `MenuCalendarDay.cutoff_at` alanlarındaki mutlak andır; bu alan yalnız "genelde saat kaçta kapanıyor" cümlesini kurar. |
| `service_weekdays` | Menü çıkan haftanın günleri, ISO numaralarıyla (1 Pazartesi .. 7 Pazar). Bugün `[1,2,3,4,5]`. **Yalnız görüntüleme içindir** — gün seçici menüsüz günleri baştan soluk çizsin diye. Kararı `is_orderable` verir. Hafta sonu menü yok ama **satış kanalı açıktır**: cumartesi pazartesiye sipariş verilebilir. |
| `max_lookahead_days` | Bugünden kaç gün sonrasına sipariş alınabileceği. **Sunucunun bugün döndürdüğü değer `7`.** Şemadaki `default: 30` katalog dönemine ait tarihsel bir annotasyondur ve korunuyor; istemci varsayılana değil yanıttaki gerçek değere bakar. |
| `min_order_total` | Kuruş. Altında sipariş `422 VALIDATION_FAILED`. |
| `delivery_fee` | Kuruş. `delivery` siparişe eklenir, `pickup`'ta uygulanmaz. İstemci toplamı **onaydan önce** gösterebilsin diye ilan edilir; bağlayıcı olan sunucunun sipariş anındaki hesabıdır. |
| `payment_methods` | Bu vitrinde **açık** olan ödeme yöntemleri. İstemci ödeme ekranında yalnızca bunları gösterir. Listede olmayan bir yöntemle sipariş → `422 VALIDATION_FAILED`. |
| `busy` | Mutfak yoğun mu? Mutfak ekranındaki tek tuşla açılır (`POST /kitchen/busy`). **Sipariş almayı ENGELLEMEZ** — istemci yalnızca `busy_message` uyarısını gösterir, sipariş düğmeleri açık kalır. Siparişi gerçekten kesen şalter `ordering_enabled`'dır. **KURAL DEĞİŞTİ (K-11, 11.08.2026):** o şalter eskiden yalnız yöneticinindi ("mutfak personeli tek tuşla cirosu kapatabilmemeli"). Sahada kural tersine işledi — mutfak sipariş almaya devam edip gelenleri telefonla iptal ediyordu ve bu, kapalı bir dükkândan çok daha kötü. Şalter artık `POST /kitchen/ordering` ile mutfaktan da çevriliyor ama **tek tuşla değil**: süre + sebep + kasanın açılış şifresi isteniyor. Ayrıntı: `docs/05-mutfakapp.md` §13. |
| `busy_message` | `busy` doğruyken gösterilecek metin. Yönetici değiştirebilir. **İstemciler kendi metnini gömmemelidir**: metin değişince üç uygulamayı birden yayınlamak gerekirdi. |
| `eta` | Teslim süresi tahmini, teslim türüne göre ayrı: `{ "delivery": {...}, "pickup": {...} }`. Her ikisi de bir `EtaWindow`'dur. Ayrıntı aşağıda. |

#### `eta` — teslim süresi tahmini

Her `EtaWindow` dört alandan oluşur: `min_minutes`, `max_minutes` (dakika,
sipariş anından teslime), `source` (`measured` \| `configured`) ve `busy`.

**Neden tek sayı değil, aralık.** "45 dakika" bir taahhüttür ve 47. dakikada
ihlal edilir; müşteri saatine bakar ve şikâyet eder. "40–55 dakika" hem
dürüsttür hem mutfağa nefes alanı bırakır. Aralık beş dakikaya yuvarlanır —
"37–51 dakika" sahte bir kesinlik iddiasıdır. İstemci bu iki sayıyı **birlikte**
göstermelidir; yalnızca alt ucu göstermek aralığı tekrar taahhüde çevirir.

**Neden ölçüm elle girilen değerden üstün.** Yönetici admin panelde bir
hazırlık ve bir teslimat süresi girer, ama bu değer iki hastalığa yakalanır:
kurulurken iyimser girilir ("15 dakikada hazır olur") ve bir daha kimse
güncellemeyi hatırlamaz. Mutfak hızlanır ya da yavaşlar, panel aynı kalır.
Bu yüzden son 14 günde **en az 8 tamamlanmış sipariş** biriktiğinde sunucu
elle girilen değeri bırakır ve gerçekleşen süreleri kullanır: aralığın alt ucu
medyan (tipik durum), üst ucu 80. yüzdelik (kötü ama olağan durum). Ortalama
kullanılmaz — tek bir çok geç sipariş ortalamayı saatlerce yukarı çeker.
Dört saati aşan kayıtlar (unutulup elle kapatılan, test amaçlı açılan
siparişler) ölçüme hiç girmez. Elle girilen değer yine de gereklidir: yeni
kurulan bir sistemde hiç sipariş yokken de bir cevap verilebilmesi için.
`source` alanı hangi yolun kullanıldığını söyler ve yalnızca teşhis içindir;
istemcinin iki duruma farklı davranması **gerekmez**.

**Gel-alda yol süresi yoktur.** `pickup` penceresi yalnızca hazırlık süresini
içerir, teslimat süresini içermez — müşteri sipariş hazır olduğunda gelip
alır, aradaki yolu kendi katetmektedir. Ölçüm tarafında da fark aynıdır:
adrese teslimde süre `teslim_edildi` durumuna kadar, gel-alda `hazir`
durumuna kadar sayılır. Tek bir tahmin verilseydi gel-al seçen müşteriye
hiç yaşamayacağı bir yol süresi eklenirdi.

**Yoğunlukta aralık uzar.** `busy` doğruyken pencerenin hem alt hem üst ucuna
yöneticinin girdiği yoğunluk ek süresi (varsayılan 15 dakika) eklenir ve
`EtaWindow.busy` de `true` döner. Yoğunluk anahtarı önceden yalnızca uyarı
metni gösteriyordu; süreyi de uzatmazsak müşteri yoğun saatte gerçekçi
olmayan bir teslim saati görür ve gecikme şikâyeti doğar — oysa gecikme yok,
beklenti baştan yanlış kurulmuştur.

> **Tahmin 10 dakika önbelleklenir.** Ölçüm her istekte yeniden
> hesaplanmaz; 14 günlük bir pencerenin sonucu on dakikada bir kayda değer
> biçimde değişmez. Yoğunluk ek süresi ise önbelleğin **dışında** eklenir —
> mutfak tuşa bastığında aralık anında uzar.

> **Yoğunluk tazedir, önbelleklenmez.** Web sitesi menüyü 60 saniyelik ISR
> ile önbelleğe alır ama yoğunluk bandını ayrı ve taze okur
> (`/api/vitrin-durumu`). Bir dakika geciken "yoğunuz" uyarısı işe
> yaramaz: tuşa basan personel müşterinin uyarıldığını sanar.

`is_open` **veya** `ordering_enabled` false ise sipariş oluşturma `422 LOCATION_CLOSED` döner.

### GET /api/locations/{id}/menu
```json
{ "data": [
  { "id":3, "name":"Ana Yemekler", "sort":1,
    "items": [
      { "id":101, "name":"Tavuk Sote", "description":"Pilav ile",
        "price":18500, "currency":"TRY", "image_url":"https://...",
        "is_available":true, "allergens":["gluten"],
        "options": [
          { "id":9, "name":"Porsiyon", "type":"radio", "required":true,
            "values":[ {"id":31,"name":"Normal","price_delta":0},
                       {"id":32,"name":"Büyük","price_delta":4000} ] }
        ] }
    ] }
]}
```
`is_available:false` ürünler yanıtta **kalır** (istemci soluk gösterir), sepete eklenemez.

> **KAPSAM DEĞİŞTİ (B-19, 14.08.2026).** Bu uç **satış yüzeyi değildir** artık.
> Sipariş yalnızca o günün menüsünden verilebilir (aşağıda). Uç sözleşmede
> kalıyor — kaldırmak ADR-09'u çiğnerdi ve panel/rapor tarafı katalogu
> okumaya devam ediyor — ama müşteri istemcileri bunu vitrin olarak
> kullanmaz.

### GET /api/locations/{id}/daily-menu?date=YYYY-MM-DD

Bir günün menüsü. `date` verilmezse **bugün** (Europe/Istanbul).

```json
{ "data": {
  "id": 12, "date": "2026-08-20",
  "title": "Ev Yemeği Menüsü", "description": null, "image_url": null,
  "image_urls": [
    "https://cdn.../mercimek.jpg", "https://cdn.../tavuk-sote.jpg",
    "https://cdn.../pilav.jpg", "https://cdn.../ayran.jpg"
  ],
  "items_total": 20500, "currency": "TRY",
  "closed": false, "is_orderable": true, "unavailable_reason": null,
  "cutoff_at": "2026-08-20T05:00:00Z",
  "remaining_portions": 24,
  "package": {
    "menu_id": 7, "name": "Günün Menüsü", "price": 18000,
    "is_available": true, "sold_out_reason": null,
    "remaining_portions": 12,
    "components": [
      { "menu_id":101, "name":"Mercimek Çorbası", "quantity":1,
        "image_url":null, "allergens":[] },
      { "menu_id":102, "name":"Tavuk Sote", "quantity":1,
        "image_url":null, "allergens":["gluten"] }
    ]
  },
  "items": [
    { "id":101, "name":"Mercimek Çorbası", "price":4000, "currency":"TRY",
      "is_available":true, "remaining_portions":null,
      "allergens":[], "options":[] },
    { "id":102, "name":"Tavuk Sote", "price":9000, "currency":"TRY",
      "is_available":true, "remaining_portions":4,
      "allergens":["gluten"], "options":[] }
  ]
}}
```

Dört kural:

1. **Paket de bir `menu_id` ile sipariş edilir** (`package.menu_id`). Sipariş
   isteğinin biçimi değişmedi; istemci "paket mi ürün mü" ayrımını taşımaz.
   Sunucu o kimliği tanır, fiyatı o günün paket fiyatından alır ve
   içindekileri satırın altına açar (§4).
2. **Yayınlanmamış gün yokmuş gibi döner** (`id:null`, `package:null`,
   `items:[]`, `is_orderable:false`). Yönetici bir ay öncesinden plan
   giriyor; yarım kalmış bir günün sızması, pişmeyecek yemeğin satılması
   demek.
3. **Menü yoksa da `200` döner.** Boş gün bir hata değil, bir cevaptır;
   `404` istemcileri gereksiz hata ekranına sokardı.
4. `items[].price` **o gün için geçerli** birim fiyattır — ürünün kendi
   fiyatı ya da o güne girilmiş istisna. İstemci ayrıca hesap yapmaz.

`items_total` sunucudan geliyor ki "paketle şu kadar avantaj" cümlesini
kuran istemci çıkarma yapmak zorunda kalmasın; para hesabı tek yerde.

**Bugünkü menüde tükenme.** "Bugün tükendi" (K-11) yalnız **bugün** için
anlamlıdır — mutfak gelecek salı köftenin biteceğini bilemez. Servis günü
bugün değilse tükenme işaretleri hiç okunmaz. Bugünse, tükenen bir kalem
kendi listesinde `is_available:false` olur; o kalem **paketin zorunlu bir
parçasıysa paket de düşer**.

#### `cutoff_at` — kesim anı (16.08.2026)

`cutoff_at`, o güne sipariş kabulünün **bittiği mutlak andır** (UTC).
Örnekteki `2026-08-20T05:00:00Z`, Europe/Istanbul'da 20 Ağustos 08:00'dir.

**Neden saat değil de an.** Kesim kuralını üç dilde yeniden hesaplamak —
TypeScript'te `Intl`, Dart'ta sabit `UTC+3`, PHP'de `Europe/Istanbul` —
sapmanın kaynağıdır: yaz saati uygulaması, telefonun yanlış saat dilimi ve
sunucunun UTC'si üç ayrı cevap üretir. Üstüne cihaz saatleri yalan söyler.
Sunucu tek bir an gönderir, istemci onunla **yalnız geri sayım gösterir**.

**Karar kapısı her zaman `is_orderable`'dır.** Geri sayım sıfırlandığında
istemci ekranı kendi kararıyla kilitlemez; menüyü yeniden çeker ve
`is_orderable`'a bakar. Cihaz saati beş dakika ileriyse hâlâ açık bir günü
kapalı göstermek, saati geri olan cihazda kapalı günü açık göstermekten
pahalıdır: biri satış kaybı, öbürü sunucunun zaten reddedeceği bir istek.

#### `remaining_portions` — stok (16.08.2026)

İki ayrı tavan var ve **hangisi önce dolarsa satışı o kapatır**:

| Alan | Ne sayar |
|---|---|
| `remaining_portions` (kök) | O günün **toplam** kalan porsiyonu (gün tavanı). |
| `package.remaining_portions` | Paketten kalan. |
| `items[].remaining_portions` | O kalemden kalan (kalem tavanı). |

**`null` sınırsız demektir, sıfır değil.** `null`'ı `0` sayan istemci,
tavanı hiç konmamış bir günü tükenmiş gösterir. Sepete eklenebilecek azami
adet iki tavanın `min()`'idir ve sepetteki mevcut adet **ikisinden ayrı
ayrı** düşülür.

Aritmetiğin normatif kaynağı **`docs/contract/sales-rules.cases.json`**'dır.
Üç dilde üç ayrı uygulama var (`packages/core`, `website`, `platform`) ve üç
test o dosyayı okur; kural değişirse üçü birden kırılır. Aynı hesabı üç kez
elle yazmanın sahadaki hâli "web sitesinde 3 eklenebiliyor, uygulamada 2"
olurdu.

**Abonelikler stoku önce rezerve eder:** bu sayılar rezervasyon düşülmüş
hâldedir. Abone sabah porsiyonunu garantiler, tek seferlik satış artandan
yürür. Tersi olsaydı bir günü aboneler için ayırmak elle iş olurdu.

#### `unavailable_reason` — iki yeni değer

`no_service_day` ve `sold_out` 16.08.2026'da eklendi.

| Değer | Anlamı |
|---|---|
| `closed_day` | İşletme o gün kapalı (tatil, özel gün). |
| `not_published` | Menü henüz yayınlanmamış (taslak). |
| `cutoff_passed` | O günün kesim saati geçti. |
| `past` | Gün geçmişte. |
| `too_far` | `max_lookahead_days` penceresinin dışında. |
| `no_service_day` | O gün servis yok (hafta sonu). |
| `sold_out` | Stok tükendi. |

`no_service_day` ile `closed_day` ayrı tutuldu çünkü müşteriye kurulacak
cümle ayrı: biri "hafta sonu servisimiz yok", öbürü "o gün kapalıyız". Aynı
değere sıkıştırılsalardı istemci her hafta sonunu tatil gibi anlatırdı.
**Bilinmeyen bir sebep istemciyi çökertmemeli**, genel bir "bu güne sipariş
verilemiyor" metniyle karşılanmalıdır.

#### `image_urls` — 2x2 ızgara

Menünün **ilk dört kaleminin** görselleri, yöneticinin verdiği sırada;
istemci 2x2 bir ızgarada dizer. Görseli olmayan kalem listeye girmez —
dizide boş yer tutulmaz, yoksa üç uygulamada üç farklı yer tutucu çıkardı.

Tekil `image_url` **kalıyor** ve varsa ızgaraya tercih edilir: o, yöneticinin
o güne elle yüklediği kapaktır. Izgara, kapak yüklenmemiş günlerin boş kart
görünmesini engellemek için var; menü listesinde günlerin çoğunun kapağı yok
ve boş kart tıklanmıyor.

### GET /api/locations/{id}/menu-calendar?from=&to=

Gün seçiciyi çizmek için aralık özeti. `from` verilmezse bugün, `to`
verilmezse `from`+30 gün; aralık **en fazla 92 gün** (aşılırsa `422`).

```json
{ "data": [
  { "date":"2026-08-20", "has_menu":true, "closed":false, "is_orderable":true,
    "cutoff_at":"2026-08-20T05:00:00Z", "sold_out":false, "weekend":false,
    "title":"Ev Yemeği Menüsü", "package_price":18000, "note":null },
  { "date":"2026-08-21", "has_menu":true, "closed":false, "is_orderable":false,
    "cutoff_at":null, "sold_out":true, "weekend":false,
    "title":"Kebap Menüsü", "package_price":19000, "note":null },
  { "date":"2026-08-22", "has_menu":false, "closed":false, "is_orderable":false,
    "cutoff_at":null, "sold_out":false, "weekend":true,
    "title":null, "package_price":null, "note":null },
  { "date":"2026-08-23", "has_menu":false, "closed":true, "is_orderable":false,
    "cutoff_at":null, "sold_out":false, "weekend":true,
    "title":null, "package_price":null, "note":"Kurban Bayramı" }
]}
```

Yalnız **menüsü olan ya da kapalı olan** günler döner. Doksan günlük boş bir
dizi, istemciye "her gün bir şey var" izlenimi verip her günü ayrı
sorgulatırdı.

**Üç additive alan (16.08.2026):**

| Alan | Anlamı |
|---|---|
| `cutoff_at` | O günün kesim anı (UTC, mutlak). `DailyMenu.cutoff_at` ile aynı değerdir ve aynı gerekçeyle mutlak andır. Takvimde veriliyor ki gün seçici, her günü ayrı ayrı sorgulamadan "bugün 08:00'e kadar" bandını çizebilsin. |
| `sold_out` | O günün stoku tükendi mi? **Tükenen gün takvimde görünmeye devam eder** — müşteri menüyü yine okuyabilmeli, yalnız sipariş verememelidir. Günü listeden düşürseydik "menü girilmemiş" ile "kapış kapış gitti" aynı boşluğa düşerdi. Kalan porsiyonun sayısı takvimde **verilmez**: takvim doksan güne kadar çizilir ve her gün için stok okumak listeyi gereksiz pahalı yapardı; sayı gün açıldığında `daily-menu` ile gelir. |
| `weekend` | O gün servis günü dışında mı (`Location.service_weekdays`'te yok)? Adı "weekend" ama anlamı "servis yok". Ayrı alan olması istemcinin haftanın gününü kendi hesaplamasını gereksiz kılar. **Sipariş kanalı kapalı değildir** — cumartesi pazartesiye sipariş verilebilir; alan yalnız o hücrenin kendi servis gününü anlatır ve `is_orderable` zaten `false` olur (`unavailable_reason: no_service_day`). |

---

## 4. Sipariş — müşteri tarafı

### POST /api/orders
**Kimlik gerekir.**

**İstek**
```json
{
  "location_id": 1,
  "items": [
    { "menu_id": 101, "quantity": 2, "option_value_ids": [31], "note": "Az acılı" }
  ],
  "delivery_type": "delivery",
  "address": {
    "line1": "Örnek Mah. 12. Sk No:3",
    "district": "Çankaya", "city": "Ankara",
    "note": "Zili çalmayın"
  },
  "requested_at": "2026-08-05T09:30:00Z",
  "payment_method": "online",
  "customer_note": "Fatura kurumsal"
}
```

| Alan | Kural |
|---|---|
| `location_id` | Zorunlu. `is_open` veya `ordering_enabled` false ise `LOCATION_CLOSED`. |
| `items` | En az 1 kalem. Kalem **o günün yayınlanmış menüsünde** değilse `ITEM_UNAVAILABLE`. |
| `service_date` | Opsiyonel. Verilmezse `requested_at`'in işletme günü, o da yoksa bugün. `requested_at` ile günü çelişirse `VALIDATION_FAILED`. |
| `delivery_type` | `delivery` \| `pickup`. |
| `address` | `delivery` ise zorunlu, `pickup` ise yok sayılır. |
| `requested_at` | Opsiyonel; vitrinin `order_cutoff` kuralına takılırsa `LOCATION_CLOSED`. |
| `payment_method` | `online` \| `cash` (kapıda). Vitrinin `payment_methods` listesinde olmayan değer → `VALIDATION_FAILED`. `account` (cari hesap) **kaldırıldı** (§12.2); gönderilirse `VALIDATION_FAILED`, enum'da yalnız tarihsel siparişleri ayrıştırmak için duruyor. |

#### Servis günü kapıları (B-19)

`service_date` sırayla şunlardan geçer; ilk düşen hatayı verir:

| Denetim | Hata |
|---|---|
| Geçmiş bir gün | `VALIDATION_FAILED`, `details.reason = "past"` |
| `max_lookahead_days` aşıldı | `VALIDATION_FAILED`, `details.reason = "too_far"` |
| Kapalı gün (`veykemtu_closed_days`) | `LOCATION_CLOSED` |
| O gün için yayınlanmış menü yok | `VALIDATION_FAILED`, `details.reason = "not_published"` |
| Kesim saati (yalnız gün **bugünse**) | `LOCATION_CLOSED` |

**Yeni hata kodu eklenmedi, bilerek.** `ErrorCode` listesi sözleşmede bir
enum; yeni bir üye eklemek istemcilerdeki kapsayıcı `switch` bloklarını ve
üretilen TypeScript birleşimini kırar (ADR-09'un tam olarak koruduğu şey).
Sebep, `details.reason` içinde makine okunur biçimde taşınıyor.

#### Menü paketi satırı

Paket, `DailyMenu.package.menu_id` ile sıradan bir kalem gibi gönderilir.
Sunucu siparişi **bir paket satırı + içindekiler** olarak yazar:

| Satır | `role` | Fiyat |
|---|---|---|
| Günün Menüsü ×2 | `package` | paket fiyatı × 2 |
| ↳ Mercimek Çorbası ×2 | `component` | **0** |
| ↳ Tavuk Sote ×2 | `component` | **0** |

**Parayı paket satırı taşır, bileşenler sıfırdır.** Bu, aboneliğin baştan
beri kullandığı kalıbın aynısı (`OrderFactory::resolveSubscriptionLines`
bileşenleri sıfır fiyatla yazıyor, para `order_totals`'ta).

Neden bileşenler ayrı satır: **üretim listesi.** `production-list`
`order_menus.menu_id` üzerinden topluyor; paket tek satır olsaydı mutfağın
şeridinde "40 tavuk sote" yerine "40 Günün Menüsü" yazardı — o şerit tam da
bunun için var (`docs/02` §4). Bileşenleri okuma anında menüye join'leyerek
çözmek de yanlış olurdu: menü sonradan düzenlenirse geçmiş bir siparişin
fişi ne pişirildiğini geriye dönük değiştirirdi.

Paket fiyatını bileşenlere oransal dağıtmak da **reddedildi**: müşteri
"Günün Menüsü 180,00 ₺" seçerken fişte hiçbir fiyat listesinde olmayan
41,44 / 66,31 / 49,73 satırlarını görürdü ve iade hesabı o uydurma
tutarların üstünde çalışırdı.

**Yanıt 201**
```json
{
  "id": 5012,
  "order_number": "S-5012",
  "status": "yeni",
  "total": 41000,
  "currency": "TRY",
  "payment": { "method":"online", "status":"pending",
               "redirect_url":"https://sanalpos..." },
  "created_at": "2026-08-04T11:30:00Z"
}
```
`payment.redirect_url` yalnızca `online` yönteminde dolu; istemci kullanıcıyı buraya yönlendirir.

**Faz 1 notu — online ödeme SİMÜLASYON geçidiyle çalışıyor.**

Kuveyt Türk sağlayıcı sözleşmesi tamamlanana kadar `online` yöntemi
`veykemtu/payment` eklentisindeki **simülasyon geçidine** bağlıdır: girilen
her kartı onaylar, **gerçek tahsilat yapmaz**.

İstemciler için önemli olan şudur: **akış gerçek POS ile birebir aynıdır.**
Sipariş `pending` doğar, `payment.redirect_url` dolu gelir, kullanıcı oraya
yönlendirilir, ödeme sonrası dönüş adresine `?durum=odendi` ile döner.
Kuveyt Türk devreye girdiğinde yalnızca o adresin işaret ettiği sayfa
değişir — sözleşme, istemci kodu ve akış aynı kalır.

Simülasyon geçidi `APP_ENV=production` iken **kendini kapatır**;
`POS_ALLOW_SIMULATION=true` verilmedikçe çalışmayı reddeder. Aksi hâlde
üretimde her sipariş bedava olurdu.

### GET /api/orders
Kendi siparişleri, en yeni önce.
```json
{ "data": [
  { "id":5012, "order_number":"S-5012",
    "status":"hazirlaniyor", "total":41000, "currency":"TRY",
    "item_count":2, "created_at":"2026-08-04T11:30:00Z" }
], "meta": {...} }
```

### GET /api/orders/{id}
```json
{
  "id": 5012, "order_number":"S-5012",
  "status":"hazirlaniyor",
  "items":[ { "menu_id":101, "name":"Tavuk Sote", "quantity":2,
              "options":["Normal"], "note":"Az acılı",
              "unit_price":18500, "line_total":37000 } ],
  "subtotal":37000, "delivery_fee":4000, "total":41000, "currency":"TRY",
  "delivery_type":"delivery",
  "address":{ "line1":"...", "district":"Çankaya", "city":"Ankara" },
  "payment":{ "method":"online", "status":"paid" },
  "status_history":[
    {"status":"yeni","at":"2026-08-04T11:30:00Z"},
    {"status":"onaylandi","at":"2026-08-04T11:31:12Z"},
    {"status":"hazirlaniyor","at":"2026-08-04T11:35:40Z"}
  ],
  "created_at":"2026-08-04T11:30:00Z"
}
```

### POST /api/orders/{id}/cancel
Yalnızca `yeni` ve `onaylandi` durumlarında. Sonrasında `422 INVALID_TRANSITION`.
**Yanıt 200** — güncel sipariş nesnesi.

### POST /api/me/push-token — **KULLANIMDAN KALDIRILDI (16.08.2026)**
```json
{ "fcm_token": "cXY...", "platform": "android" }
```
**Yanıt 204.**

Push bildirimi (FCM) kapsam dışına alındı; müşteriye ulaşmanın yolu
**uygulama-içi duyuru** (`GET /api/announcements`, §15.5) ve SMS'tir.

Uç sözleşmede duruyor (§1.4) ve token'ı kabul etmeye devam ediyor ama
**hiçbir bildirim gönderilmiyor**. Sahadaki eski mobil sürümler açılışta bu
ucu çağırıyor; kaldırılsaydı her açılışta `404` alıp hata ekranı
gösterirlerdi. Yeni istemciler bu ucu **çağırmaz**.

---

## 5. Mutfak (KDS) uçları

Tümü `kitchen` kapsamı gerektirir. Bu uçlar fiyat, müşteri iletişim bilgisi ve rapor **döndürmez**.

### POST /api/kitchen/pair
Cihaz kaydı. Admin panelden alınan tek kullanımlık kod ile.
```json
{ "pairing_code": "K7X2-9QMD", "device_name": "Mutfak Kasası" }
```
**Yanıt 200**
```json
{ "device_id": 1, "token": "kdev_eyJ...", "server_time": "2026-08-04T11:30:00Z" }
```
Token süresizdir; admin panelden iptal edilebilir (`403 DEVICE_REVOKED`).

### GET /api/kitchen/orders
Aktif siparişler. Varsayılan: `teslim_edildi` ve `iptal` **hariç** bugünün siparişleri.

**Sorgu parametreleri**

| Param | Açıklama |
|---|---|
| `after` | Bu sipariş kimliğinden büyükleri getir (artımlı polling) |
| `since` | Bu zaman damgasından sonra **güncellenenleri** getir (durum değişimlerini yakalar) |
| `include_completed` | `true` ise bugünün tamamlananları da gelir |

**Yanıt 200**
```json
{
  "data": [
    {
      "id": 5012,
      "order_number": "S-5012",
      "status": "yeni",
      "requested_at": "2026-08-05T09:30:00Z",
      "delivery_type": "delivery",
      "customer_label": "Ayşe Y.",
      "items": [
        { "name":"Tavuk Sote", "quantity":2,
          "options":["Normal"], "note":"Az acılı" }
      ],
      "customer_note": "Fatura kurumsal",
      "created_at": "2026-08-04T11:30:00Z",
      "updated_at": "2026-08-04T11:30:00Z"
    }
  ],
  "server_time": "2026-08-04T11:30:05Z",
  "max_id": 5012
}
```
**Not:** `customer_label` yalnızca ad + soyad baş harfi. Telefon, adres, e-posta **gönderilmez** (adres yalnızca müşteri fişi için ayrı uçtan alınır — bkz. `/api/kitchen/orders/{id}/receipt`).

`max_id` bir sonraki `after` değeridir. `server_time` bir sonraki `since` değeridir.

### POST /api/kitchen/orders/{id}/status
```json
{ "status": "hazirlaniyor" }
```
**Yanıt 200** — güncel sipariş özeti.
Geçersiz geçiş → `422 INVALID_TRANSITION`.

### GET /api/kitchen/orders/{id}/receipt
Fiş içeriği. Yazdırma verisini sunucu hazırlar, KDS yalnızca biçimlendirip basar.

**Sorgu:** `?type=mutfak|musteri`

**Yanıt 200 (type=mutfak)**
```json
{
  "type": "mutfak",
  "order_number": "S-5012",
  "delivery_type": "delivery",
  "requested_at": "2026-08-05T09:30:00Z",
  "lines": [
    { "quantity":2, "name":"Tavuk Sote", "options":["Normal"], "note":"Az acılı" }
  ],
  "customer_phone": "5551234567",
  "customer_note": "Fatura kurumsal",
  "printed_at": null
}
```
> **KURAL DEĞİŞTİ (K-14, 11.08.2026).** Bu paragraf eskiden
> "`GET /api/kitchen/orders` telefon döndürmez ve döndürmeyecektir"
> diyordu. Sipariş düzenleme (K-12) gelene kadar doğruydu: mutfağın
> telefona ihtiyacı yoktu. Artık personel müşteriyle **telefonda
> anlaşıp** siparişi düzenliyor ve numarayı görmek için fiş basmak (ya
> da basılmış fişi aramak) saçma.
>
> `KitchenOrder` artık `customer_phone` ve `customer_name` içeriyor.
> **Fiyat ve adres gizliliği aynen duruyor** — kural kaldırılmadı,
> daraltıldı. Ayrıntı: `docs/05-mutfakapp.md` §14.

**K-20: `type=musteri` ARTIK KURYENİN DE FİŞİ.** Ayrı bir `kurye` fişi
otomatik basılmıyor; `customer_name`, `customer_phone`, `customer_note`,
`collect_amount`, `revision_no`, `revision_summary` ve `deliver_url` alanları
bu yanıta eklendi (hepsi additive, `required` listesi değişmedi). Gel-al
siparişinde ad, telefon, teslim bağlantısı `null` ve `collect_amount` `0`
gelir — kurye yok.

`type=kurye` **uç olarak duruyor** ama otomatik tetiklenmiyor: personelin
KDS'ten elle yeniden bastırabildiği bir kaçış kapısı (kâğıt sıkışması,
kaybolan fiş). Enum değeri sözleşmeden silinmedi (additive-only, §1.4).

**Yanıt 200 (type=musteri)** — ayrıca `items` fiyatlı, `subtotal`, `delivery_fee`, `total`, `payment` ve (`delivery_type=delivery` ise) `address` alanları içerir.

Bu, mutfak kapsamının müşteri adresini görebildiği **tek** uçtur ve yalnızca `type=musteri` içindir; `GET /api/kitchen/orders` adres döndürmez.

**`track_url` ve `pay_url` (K-18/K-19, additive, 12.08.2026)** — müşteri fişine
basılacak iki QR'ın hedefi. İkisi de **nullable**:

| Alan | Değer | `null` olduğu durum |
|---|---|---|
| `track_url` | `<FRONTEND_URL>/takip/<id>?e=…&s=…` | `FRONTEND_URL` **veya** imza sırrı tanımsız |
| `pay_url` | Ödeme sayfası + `?return=<track_url>` | yukarıdakiler, sipariş zaten ödenmiş, **veya sanal POS simülasyonu kapalı** |
| `deliver_url` | `<APP_URL>/teslimat/<id>?e=…&s=…` | imza sırrı tanımsız **veya gel-al siparişi** |

**K-20 (14.08.2026) — `track_url` ADRESİ DEĞİŞTİ, bu bir hata düzeltmesiydi.**
Eskiden `<FRONTEND_URL>/siparis/<id>` idi ve o rota sitede oturum istiyor
(`middleware.ts` + `requireSession`): fişteki kareyi okutan müşteri sipariş
durumunu değil **giriş ekranını** görüyordu. Kâğıda basılan bir QR giriş
isteyemez. Yeni adres imzalı ve girişsiz; girişli `/siparis/{id}` sayfası
olduğu gibi duruyor.

**`deliver_url` yeni (K-20).** Kuryenin okuttuğu "teslim ettim" QR'ı. Kurye
girişi yoktur; yetki URL'deki HMAC imzasındadır ve imza sipariş kimliğine,
amaca ve son geçerlilik anına bağlıdır — bir siparişin bağlantısı komşusunu
açmaz, takip bağlantısı teslim bağlantısı yerine geçmez, `?e=` değiştirilerek
süre uzatılamaz.

Bağlantıyı **sunucu üretir**, KDS değil. KDS'in site adresini bilmesi
gerekmiyor; kasada yanlış ya da eski bir alan adı kalırsa basılan QR sessizce
ölü bir bağlantı taşır ve bunu kimse fark etmez. `null` gelen alanın QR'ı hiç
basılmaz — boş kare, çalışmayan QR'dan iyidir. Basım kuralları:
`docs/05-mutfakapp.md` §5.3.

### POST /api/kitchen/print-jobs/{order_id}/ack
Fiş basıldı bildirimi (denetim için). `type`: `mutfak` \| `musteri`.
```json
{ "type": "mutfak", "printed_at": "2026-08-04T11:30:07Z" }
```
**İdempotent:** aynı `(order_id, type)` çifti için tekrarlanan çağrı yeni kayıt açmaz, `204` döner.
**Yanıt 204.**

### GET /api/kitchen/production-list
```json
{
  "data": [
    { "menu_id":101, "name":"Tavuk Sote", "total":40 },
    { "menu_id":118, "name":"Mercimek Çorbası", "total":25 }
  ],
  "as_of": "2026-08-04T11:30:00Z"
}
```

### GET /api/kitchen/heartbeat
KDS'in canlı olduğunu bildirir; `last_seen_at` güncellenir.
**Yanıt 200** `{ "server_time": "...", "min_supported_version": "1.0.0" }`

### Mutfak turu uçları (K-11 … K-16, 11–12.08.2026)

Ayrıntı ve gövde şemaları `docs/openapi.yaml`'da (normatif); buradaki
liste ne işe yaradıklarını özetler.

| Uç | Ne yapar |
|---|---|
| `GET/POST /api/kitchen/ordering` | Satış şalteri. Kapatma süre + sebep ister; **kasa ayrıca açılış şifresi soruyor** (K-11) |
| `GET/POST /api/kitchen/menu-availability` | "Bugün tükendi" işaretleri. **Fiyatsız** ürün listesi (ADR-08) |
| `GET /api/kitchen/orders/{id}/editable` | Düzenlenebilir sipariş görüntüsü — **fiyatsız**, telefonlu |
| `GET/POST /api/kitchen/orders/{id}/revisions` | Revizyon geçmişi ve yeni revizyon (K-12) |
| `GET /api/public/orders/{id}/tracking` | **Kimlik gerektirmez** — fişteki takip QR'ının açtığı uç (K-20). Yetki `?e=`/`?s=` imzasında. Siparişin DAR yüzü: adres, ad, telefon ve kalem listesi dönmez |
| `GET /api/kitchen/menu` | Düzenleme ekranının ürün seçicisi — **fiyatsız** |
| `GET /api/kitchen/subscription-plan` | Abonelik üretim planı: toplamlar, saatler, **uyarılar** (K-15) |
| `GET /api/kitchen/bbd-orders` + `.../{id}/ack` | BBD fiş kuyruğu (K-16) |
| `POST /api/partner/bbd/orders` | **Ortak uç** — BBD Store webhook'u, HMAC imzalı, token'sız |

**İSTEK BÜTÇESİ.** Kasa başına `bld-kitchen` sınırı **2000/saat**
(§10). Sürekli döngüler ~1140 istek/saat tutuyor; kalanı kullanıcı
kaynaklı ve patlamalı. Yeni bir yoklama döngüsü eklemeden önce bütçe
gözden geçirilmeli — aşıldığında kasa `429` alıyor ve **mutfak sipariş
görmüyor**. Hesap `platform/.../Extension.php` içinde, testi
`mutfakapp/test/request_budget_test.dart`.

---

## 6. Site içeriği ucu (kimlik gerektirmez)

Kurumsal web sitesinin panelden yönetilen içeriği. Admin panelde **İçerikler**
bölümünden düzenlenir; kod değişikliği gerektirmez.

### GET /api/site-content

Tüm içerik **tek pakette** döner. Ayrı uçlar (marka, iletişim, hizmetler…)
bilinçli olarak yapılmadı: sitenin her sayfası aynı çekirdek veriye ihtiyaç
duyuyor ve ayrı uçlarla ana sayfa yedi istek atardı — biri geciktiğinde sayfa
yarım kalırdı.

```json
{
  "brand":    { "name": "Benim Lezzet Dünyam", "logo_url": null, "primary_color": "#C2410C" },
  "contact":  { "phone": { "display": "0212 000 00 00", "href": "tel:+902120000000" },
                "whatsapp": null, "email": null, "address": null,
                "working_hours": [], "social": [] },
  "company":  { "mission": "…", "vision": "…", "values": [], "process_steps": [] },
  "faq":      [{ "question": "…", "answer": "…" }],
  "sectors":  [{ "slug": "sanayi", "title": "Sanayi ve üretim", "icon": "Factory",
                 "need": "…", "answer": "…", "service_slug": "kurumsal-toplu-yemek" }],
  "menus":    { "solutions": [], "seasonal": [] },
  "quality":  { "chain": [], "allergen": [], "certifications": [] },
  "services": [{ "slug": "tasima-yemek", "title": "Taşıma yemek", "icon": "Truck",
                 "body_html": null, "audience": [], "how_it_works": [] }],
  "posts":    [{ "slug": "…", "title": "…", "published_at": "2026-02-18",
                 "reading_minutes": 5, "body_html": "<p>…</p>" }],
  "updated_at": "2026-08-06T20:15:00Z"
}
```

**Doldurulmamış bölüm `null` döner ve bu bir hata değildir.** Yeni kurulan bir
sistemde panel boşken sitenin hiç açılmaması kabul edilemezdi. Site `null`
gelen bölümü çizmez; ayrıca API'ye hiç erişemezse kendi yedek değerlerine
düşer (`website/lib/api/site-content.ts`).

**Telefon `href` alanı panelde ayrı bir kutu değildir.** Yönetici numarayı
okunur biçimde yazar (`0212 000 00 00`); `tel:` / `https://wa.me/` bağlantısı
sunucuda türetilir. İki ayrı alan istemek, ilk yazım hatasında çalışmayan bir
bağlantı bırakırdı.

**`body_html` sunucuda temizlenmiştir.** Zengin metin editöründen gelen HTML
**kayıt anında** izin listesinden geçirilir (`HtmlSanitizer`): `<script>`,
`style`, `<div>`, `<img>` ve olay öznitelikleri düşer, etiketin içindeki metin
korunur. İstemci ek temizlik yapmaz — okuma her istekte olur, kayıt nadiren.

**Marka rengi kaydedilmeden önce ölçülür.** Beyaz metinle kontrastı WCAG AA
eşiğini (4,5:1) geçmeyen renk reddedilir ve yöneticiye ölçülen oran söylenir.
Kırpmak veya "en yakın uygun tona" çevirmek, yöneticinin markasının rengini
yanlış bilmesine yol açardı.

### Önbellek ve tazeleme

Paket sunucuda 60 dakika önbelleklenir. Panelde kaydet'e basıldığında önbellek
**anında** temizlenir ve siteye tazeleme isteği gider; yönetici değişikliği
süre dolmasını beklemeden görür.

---

## 7. Teklif talebi ucu (kimlik gerektirmez)

Kurumsal sitedeki "Teklif Al" formunun gönderim ucu. Talepler panelde
**İçerikler → Teklif Talepleri** ekranına düşer; ayrı bir yetki ister
(`Veykemtu.QuoteRequests`).

### POST /api/quote-requests

```json
{
  "full_name": "Ayşe Yılmaz",
  "organization": "Örnek Sanayi A.Ş.",
  "telephone": "5551234567",
  "email": "ayse@ornek.com",
  "service_type": "kurumsal-toplu-yemek",
  "headcount": 250,
  "frequency": "haftaici",
  "start_date": "2026-09-01",
  "location": "İstanbul / Tuzla",
  "menu_preference": "dort-kap",
  "kitchen_note": null,
  "message": "Öğle servisi, iki vardiya.",
  "kvkk_accepted": true,
  "submitted_at": "2026-08-07T09:15:00.000Z"
}
```

**Yanıt 201**
```json
{ "status": "yeni", "received_at": "2026-08-07T06:15:12Z" }
```

**Kimlik gerektirmez.** Formu dolduran kişi henüz müşteri değil, olması da
beklenmiyor; teklif isteyebilmek için önce hesap açtırmak, formun terk
edilmesinin en yaygın sebebidir. Koruma kimlikte değil oran sınırındadır:
**10 istek / saat / IP**. `/api/auth/*`'ın dakikalık sınırı burada yeniden
kullanılmadı — o sınır saatte 600 gönderime izin verir ve 600 sahte talep
panele düşseydi gerçek talepler o yığının içinde kaybolurdu.

**Doğrulama bilinçli olarak GEVŞEKTİR.** Bu ucun başarısızlığı "hatalı istek"
değil, **kaybedilmiş iştir**: ziyaretçi formu bir kez doldurur ve 422
gördüğünde çoğu zaman tekrar denemez, rakibe gider. Bu yüzden:

| Durum | Davranış |
|---|---|
| Şemada olmayan alan (`utm_source`, `nested` …) | Sessizce yok sayılır, talep kaydedilir |
| Bilinmeyen `service_type` / `frequency` / `menu_preference` | Metin olarak saklanır |
| Çözümlenemeyen `start_date` ("yazın") | `null` kaydedilir, talep durur |
| Rakam olmayan `headcount` ("bin kişi") | `null` kaydedilir, talep durur |
| Sütun sınırını aşan metin | Kesilir, reddedilmez |

**`service_type` bir enum DEĞİLDİR.** Değerler `website/content/services.ts`
slug'larından gelir ve yeni bir hizmet önce orada doğar; enum kısıtı, sitenin
sözleşmeden bir sürüm önde gittiği her anda gelen talebi çöpe atardı.

**Reddedilen iki durum vardır ve ikisi de bilinçli kayıptır:**

1. **KVKK onayı yok** (`kvkk_accepted` `true` değil) → `422`. Onaysız kişisel
   veri saklamak hukuki sorundur. Onay anı **sunucuda** damgalanır; istemcinin
   bildirdiği bir zaman denetimde delil sayılmaz.
2. **Ulaşılacak kanal yok** (`telephone` ve `email` birlikte boş) → `422`.
   Firma teklifi kimseye gönderemez; kayıt yalnızca kişisel veri biriktirir.

**Yanıt kaydın kendisini ve `id`'sini DÖNMEZ.** Uç herkese açık; artan bir
kimlik döndürmek, formu iki kez dolduran herkese firmanın aldığı talep
sayısını sızdırırdı. Site zaten yanıt gövdesini kullanmıyor.

**`status` ve `admin_note` gövdeden ATANAMAZ.** Alanlar beyaz listeyle tek tek
okunuyor; okunmasaydı ziyaretçi kendi talebini "cevaplandı" işaretleyip
listenin dibine gönderebilirdi. Yeni kayıt her zaman `yeni` doğar.

**Tekilleştirme yapılmaz.** Aynı kişinin ikinci gönderimi ikinci bir kayıttır:
aynı firma iki farklı etkinlik için teklif isteyebilir ve ikincisini "kopya"
sayıp yutmak gerçek bir işi sessizce kaybetmek olurdu.

**Takip durumları:** `yeni` → `okundu` → `cevaplandi` → `kapandi`. Panelden
serbestçe değiştirilir, sitede hiç görünmez.

---

## 8. Sürüm ucu

### GET /api/app-version?app_id=mutfakapp
```json
{
  "app_id": "mutfakapp",
  "latest": "1.2.0",
  "min_supported": "1.1.0",
  "download_url": "https://.../mutfakapp_1.2.0.deb",
  "notes": "Yazdırma kuyruğu iyileştirmesi"
}
```
İstemci sürümü `min_supported` altındaysa zorunlu güncelleme ekranı gösterir.

---

## 9. WebSocket (Faz 1.5)

Laravel Reverb. Bağlantı: `wss://api.benimlezzetdunyam.com.tr/app/<key>`

**Yayın kanalı:** `private-kitchen` — cihaz token'ı ile yetkilendirilir.

**Olaylar:**

| Olay | Yük |
|---|---|
| `order.created` | `/api/kitchen/orders` öğesiyle aynı biçimde tek sipariş |
| `order.status_changed` | `{ "id":5012, "status":"hazir", "updated_at":"..." }` |
| `order.cancelled` | `{ "id":5012 }` |

**Yayın kanalı:** `private-customer.{customer_id}` — müşterinin kendi siparişleri.

| Olay | Yük |
|---|---|
| `order.status_changed` | `{ "id":5012, "status":"yolda", "updated_at":"..." }` |

**Kural.** WebSocket kesilirse istemci otomatik polling'e döner ve bağlantı geri gelince `since` ile kaçırdıklarını çeker. Olay kaybı kabul edilemez; WebSocket **hızlandırmadır, tek kaynak değildir.**

---

## 10. Oran sınırları

| Uç grubu | Sınır |
|---|---|
| `/api/auth/*` | 60 istek / dakika / IP |
| `/api/orders` (POST) | 20 istek / saat / hesap |
| `/api/kitchen/*` | **2000 istek / saat / cihaz** |
| `/api/control/kds/*` | **1200 istek / saat / IP** (`bld-control`, §14) |
| `/api/quote-requests` (POST) | 10 istek / saat / IP |
| `/api/addresses/suggest`, `/api/addresses/reverse` | 30 istek / dakika / **hesap** (§13.5) |
| `POST /api/partner/bbd/orders` | 300 istek / saat / IP (`bld-partner`) |
| `POST /api/contracts/{token}/otp` | 5 istek / saat / **belirteç** (§15.4) |
| `POST /api/client-errors` | 60 istek / dakika / IP (§15.6) |
| Diğer | 120 istek / dakika / IP |

**Mutfak sınırı neden 600 değil:** ilk gerekçe "5 sn polling'e yeter" idi —
aritmetik olarak yanlıştı. 5 saniyelik polling tek başına saatte **720** istek
eder (3600 ÷ 5). 600'lük sınır, KDS'i yoğun serviste sessizce `429`'a düşürür
ve mutfak ekranı donar — sahada teşhisi en zor arıza türü.

**Sınır 12.08.2026'da 1200'den 2000'e çıktı** ve bu bölüm o gün
güncellenmeden kalmıştı; §5'teki istek bütçesi 2000 diyor, kaynak
`Extension::registerRateLimiters()` da 2000. Her seferinde kasanın gerçekte
attığı istek sayısı **sayıldı**, "biraz daha yükseltelim" denmedi:

| Döngü | Aralık | Saatlik |
|---|---|---|
| Sipariş yoklaması | 5 sn | 720 |
| BBD kuyruğu (K-16) | 20 sn | 180 |
| Heartbeat | 60 sn | 60 |
| Sağlık bildirimi | 60 sn | 60 |
| Satış şalteri (K-11) | 60 sn | 60 |
| Abonelik listesi | 60 sn | 60 |
| **Sürekli toplam** | | **1140** |

Kalan ~860 kullanıcı kaynaklı ve **patlamalı**: tam yenileme, fiş yeniden
basma, düzenleme ekranı (`editable` + `menu` + `revisions`), satış kontrolü,
abonelik sekmeleri. Sınır **cihaz başınadır**, IP başına değil: kasa ve
yönetici çoğu zaman aynı ağdan çıkar ve IP sınırı ikisini birbirine
kırdırırdı.

**Kontrol Merkezi sınırı neden 1200 ve neden IP başına:** `bld-partner`
(300/saat) yetmez — BBD tek bir uca sipariş yazıyor, Kontrol Merkezi ise
**açık duran bir panel**: cihaz listesi, sipariş listesi ve özet yoklanıyor,
üstüne yöneticinin tıkladığı her şey geliyor. 10 saniyelik bir yoklama tek
başına 360/saat eder ve aynı anda iki yönetici panel açabilir. Mutfak bütçesi
kadar cömert olmaması da bilinçli: kasa sipariş göremezse mutfak durur, panel
yavaşlarsa kimse aç kalmaz. **IP başına**, çünkü o yüzeyin kimliğini istek
başına hesaplanan bir imza taşıyor — sayacı bağlayacak bir hesap kimliği yok
ve Kontrol Merkezi zaten tek sunucudan çıkıyor.

**Sözleşme OTP sınırı neden belirteç başına:** `/api/contracts/{token}/otp`
kimlik istemez, imzalı bağlantıyı elinde tutan herkes çağırabilir. IP başına
sayılsaydı aynı ofisten bakan iki abone birbirini kilitlerdi; hesap başına
sayamıyoruz çünkü henüz oturum yok. Sayacın bağlanabileceği tek kimlik
bağlantının kendisidir ve zaten korunması gereken de odur — bir sözleşme
bağlantısına sınırsız SMS ısmarlanabilmesi doğrudan para kaybıdır.

**`client-errors` sınırı neden bu kadar yüksek:** uç bir hata boşaltma
yeridir ve asıl işi kaybedilen teşhis bilgisini yakalamaktır. Döngüye giren
bir istemci sınırı doldurur ama sınıra takılan istek **sessizce düşer** —
istemci `429` yüzünden ikinci bir hata üretmemelidir, yoksa hata bildirimi
kendi kendini besleyen bir döngüye girer.

## 11. OpenAPI

Makine tarafından okunabilir sözleşme: **`docs/openapi.yaml`** (OpenAPI 3.1). Bu markdown insan için açıklama, `openapi.yaml` ise **normatif** biçimdir; ikisi çelişirse `openapi.yaml` kazanır.

`packages/api_client` ve `website/lib/api` bu dosyadan üretilir. **Elle yazılan istemci kodu kabul edilmez.**

`platform/` aynı sözleşmeyi `openapi.json` olarak üretir (`php artisan veykemtu:openapi`). CI, üretilen `platform/openapi.json` ile `docs/openapi.yaml` arasında **anlamsal fark** olup olmadığını kontrol eder; fark varsa build kırmızıdır. Sunucu sözleşmeden sapamaz.

## 12. Kurumsal kayıt, cari hesap ve abonelik (Faz 2 — UYGULANDI)

> **16.08.2026 — bu bölümün iki kararı değişti.** Kurumsal sipariş kapısı
> kaldırıldı (§12.1) ve cari hesap tamamen kalktı (§12.2). Bölüm numaraları
> **korunuyor**: `docs/` altındaki diğer dosyalar ve görev planı bu
> numaralara atıf yapıyor ve yeniden numaralandırmak o atıfları sessizce
> yanlış yere gönderirdi. Günlük menü satış modelinin tamamı §15'tedir.

Tümü additive: mevcut alanlar değişmedi. Para her yerde kuruş `int`; **tutar/bakiye/anlaşmalı fiyat sunucuda hesaplanır**, istemci yalnız gösterir.

### 12.1 Kurumsal kayıt — `POST /api/auth/register` (additive alanlar)

Sistem tamamen B2B'ye geçti. Yeni her kayıt sunucuda `corporate` işaretlenir (istemci `account_type` gönderemez). Additive istek alanları:

| Alan | Zorunlu | Not |
|---|---|---|
| `company_name` | sunucu opsiyonel¹ | Ticari unvan |
| `contact_person` | sunucu opsiyonel¹ | Yetkili kişi |
| `tax_office` | hayır | Vergi dairesi |
| `tax_number` | hayır | Vergi / TC no |
| `company_phone` | hayır | Kurum telefonu |

¹ Website'in mevcut kayıt akışını kırmamak için sunucu tarafında opsiyonel bırakıldı; **mobil kayıt formu `company_name` ve `contact_person`'ı zorunlu** toplar (istemci doğrulaması).

`GET /api/auth/me` ve `updateMe` additive döner: `account_type`, `can_order`, `company_name`, `contact_person`. `tax_no`/`tax_office` yanıt profilinde salt-okunur. Eski istemci bu alanları yok sayar (uyum kuralı §1.4).

**Sipariş kapısı KALDIRILDI (16.08.2026).** `CustomerGate` artık yok; `account_type` sipariş hakkını belirlemiyor ve **herkes sipariş verebiliyor**. Kurum alanları (`company_name`, `contact_person`, `tax_office`, `tax_number`, `company_phone`) serbest metin **etiket** olarak duruyor: panelde müşteriyi ayırmaya ve faturayı yazmaya yarıyor, bir yetki taşımıyor.

`can_order` alanı **silinmedi** ve artık her zaman `true` döner. Kaldırılsaydı sahadaki istemciler `undefined` görüp sipariş düğmesini hiç çizmezdi. Yeni istemciler bu alanı **okumamalı**; siparişin verilebilirliği vitrinin (`is_open`, `ordering_enabled`) ve günün (`DailyMenu.is_orderable`) durumundan okunur, bağlayıcı olan `POST /api/orders`'ın kendisidir.

### 12.2 Cari hesap — **KALDIRILDI (16.08.2026)**

Günlük menü satış modeline geçişle birlikte cari hesap tamamen kalktı. Ödeme yöntemleri `online` ve `cash` ile sınırlı.

**Silinen yollar:**

| Yol | Yerine |
|---|---|
| `GET /api/account/summary` | — (karşılığı yok) |
| `GET /api/account/statement` | — (karşılığı yok) |
| `POST /api/account/payments` | Abonelik dönem ödemesi: `POST /api/subscriptions/{id}/payments` (§15.3) |

Silinen şemalar: `AccountSummary`, `AccountEntry`, `AccountStatement` ve `/account/payments` yanıtının gövdesi. `Cari hesap` etiketi de kaldırıldı.

**Neden gerçekten silindi, `deprecated` bırakılmadı.** Cari hesap bir ekran değil bir **defterdi**: bakiye, ekstre, ters kayıt, tahsilat mutabakatı. Yolları ayakta bırakmak, arkasındaki defteri de ayakta tutmak demekti; boş dönen bir bakiye ucu ise "borcum yok" diye okunacak ve ilk yanlış anlamada telefonla düzeltilecekti.

> **BU, UYUM KURALININ (§1.4) TEK İSTİSNASIDIR VE BİLİNÇLİDİR.**
>
> **İstemciler sunucudan ÖNCE yayınlanmalıdır.** Sıra ters olursa sahadaki web ve mobil sürümler hâlâ çizdikleri cari hesap ekranını doldurmak için bu üç yolu çağırır ve `404` alır — kullanıcı, sebebini anlayamayacağı boş bir hata ekranı görür. Doğru sıra:
>
> 1. Cari hesap ekranlarını çıkaran istemci sürümleri yayınlanır (web, mobil).
> 2. Zorunlu güncelleme eşiği (`GET /api/app-version` → `min_supported`) yükseltilir; eski mobil sürümler kapıda durdurulur.
> 3. Ancak ondan sonra sunucudaki yollar kapatılır.

**`PaymentMethod` enum'undaki `account` değeri KORUNDU.** Yeni siparişte asla dönmez ve istekte gönderilirse `422 VALIDATION_FAILED` alır; yalnızca cutover öncesi tarihsel siparişlerde görülür. Enum'dan çıkarılsaydı geçmiş sipariş listesini çözen istemci, kendi ürettiği kapalı birleşim tipine uymayan bir değerle karşılaşıp ayrıştırmayı kırardı — kırk sipariş geçmişi olan bir müşterinin listesi tek eski satır yüzünden hiç açılmazdı. Aynı gerekçeyle `Subscription.payment_mode` içindeki `account` da duruyor.

`Location.payment_methods` listesi **hiçbir zaman `account` içermez**.

### 12.4 Telefonla giriş (OTP) — v2.0

Kurumsal müşteri her sipariş için parola hatırlamak zorunda kalmasın diye
ikinci bir giriş kapısı. E-posta + parola yolu **kapanmıyor**.

| Uç | Ne yapar |
|---|---|
| `POST /api/auth/otp/request` | `{ phone }` → `202 { message, expires_in, resend_after }` |
| `POST /api/auth/otp/verify` | `{ phone, code }` → `200 AuthResponse` (şifreli girişle **aynı** gövde) |

**Yanıt, numara kayıtlı olsun olmasın aynıdır.** "Bu numara kayıtlı değil"
demek, kurumsal müşteri listesinin numara numara taranmasına izin vermek
olurdu; kayıtsız numaraya SMS gönderilmez ve bunu yalnızca numaranın gerçek
sahibi fark edebilir. İstemciler de bu ayrımı yapmamalı.

Telefon biçimi **serbest**: `5551112233`, `05551112233`, `+905551112233` ve
boşluklu yazımlar aynı numaraya çözülür (`OtpService::normalize`). Katı bir
biçim, doğru numarayı alışkın olduğu gibi yazan müşteriyi kapıda çevirirdi.

Kod 6 haneli, 5 dakika ömürlü, **tek kullanımlık** ve veritabanında bcrypt'li
duruyor. Doğrulandığı anda aynı numaranın diğer açık kodları da tüketilir.
Beş yanlış denemeden sonra kod ölür — sayaç IP'ye değil **koda** bağlı, yani
IP değiştirmek işe yaramıyor. Yeni kod için 60 saniye beklenir; bu sınır
sunucudadır, arayüzdeki geri sayım yalnızca onun görünür hâlidir.

SMS sağlayıcısı Netgsm (`NETGSM_USERNAME`, `NETGSM_PASSWORD`,
`NETGSM_HEADER`). **Üçü birden tanımlı değilse SMS gönderilmez**, kod yalnızca
sunucu günlüğüne `warning` seviyesinde yazılır ve parola girişi çalışmaya
devam eder.

### 12.3 Abonelik — müşteri self-servis

Anlaşmalı fiyat müşteri tarafından **set edilmez**; `POST` bir **talep** açar (`status = pending`), fiyatı admin belirler.

| Uç | Ne yapar |
|---|---|
| `GET /api/subscriptions` | Müşterinin abonelikleri (`Subscription[]`) |
| `GET /api/subscriptions/{id}` | Tek abonelik |
| `POST /api/subscriptions` | Talep oluştur (`SubscriptionCreate` → `pending`) |
| `POST /api/subscriptions/{id}/pause` | Yalnız `active` iken; aksi `VALIDATION_FAILED` |
| `POST /api/subscriptions/{id}/resume` | Yalnız `paused` iken |
| `POST /api/subscriptions/{id}/cancel` | İptal (append-only; geçmiş silinmez) |
| `POST /api/subscriptions/{id}/exceptions` | Tek-gün istisna (`skip` veya `quantity_override`) |

`Subscription` şeması: `id, status, location_id, delivery_type, start_date, end_date, service_days[] (ISO 1..7), delivery_time_from/to, default_quantity, agreed_unit_price (null=fiyat bekliyor), payment_mode, menu_mode, lines[], delivery_points[], exceptions[], payment, contract, created_at`.

**Additive alanlar (16.08.2026):**

- **`exceptions[]`** — abonenin girdiği tek-günlük istisnalar (`service_date`, `skip`, `quantity_override`, `created_at`). Yalnız **bugün ve sonrası** döner; geçmiş istisnalar tabloda durur (append-only) ama listeye girmez. **Bir açığı kapatıyor:** `POST .../exceptions` istisnayı yazıyordu ama hiçbir uç geri okumuyordu — abone bir günü atladıktan sonra atladığını ekranda göremiyor, emin olmak için aynı günü tekrar tekrar atlıyordu.
- **`payment`** — yürürlükteki dönemin ödeme özeti (`payment_id`, `period` (`YYYY-AA`), `amount`, `currency`, `status`, `due_date`) ya da `null`. Ödemenin **geçmişi burada değildir**; alan "şu an ne bekleniyor" sorusunu yanıtlar. Liste gömseydik abonelik listesi ekranı her satır için aylarca geriye giden bir dizi taşırdı.
- **`contract`** — sözleşme özeti (`status`, `version`, `sent_at`, `approved_at`) ya da `null`. **Metin burada yoktur**, imzalı bağlantının arkasındadır (`GET /api/contracts/{token}`, §15.4) — sayfalarca sürüyor ve abonelik listesinde taşınacak bir şey değil.

**`status` enum'una iki ara durum eklendi:** `awaiting_contract` (fiyat girildi, sözleşme onayı bekleniyor) ve `awaiting_payment` (sözleşme onaylandı, ilk dönem ödemesi bekleniyor). Ayrı tutulmalarının sebebi ekranın kuracağı cümlenin ayrı olması: birinde abonenin yapacağı iş sözleşmeyi onaylamak, öbüründe ödemek. Tek bir `pending` altında toplansalardı istemci "ne bekleniyor" sorusunu yanıtlayamaz, abone de hiçbir şey yapmadan beklerdi. **Eski istemci bu iki değeri tanımaz**; tanımadığı durumu "işleniyor" gibi nötr bir metinle göstermeli ve eylem düğmelerini kapatmalıdır.

**Abonelik = günün menüsü + gün atlama.** Abonelik siparişleri gece üretilir ve KDS'e 07:00'de düşer. Abonelikler stoku **önce rezerve eder**: `remaining_portions` alanları rezervasyon düşülmüş hâldedir.

**`menu_mode` (B-19'dan sonra):** `SubscriptionCreate` içinde **additive** bir alan; gönderilmezse `fixed_list` ve eski davranış birebir korunur.

| Mod | Porsiyonun içeriği | `lines` |
|---|---|---|
| `fixed_list` | Aboneliğin kendi ürün satırları — her gün aynı | Kullanılır |
| `daily_menu` | O günün **yayınlanmış** menüsü (`veykemtu_daily_menus`) | **Gönderilemez** — gönderilirse `VALIDATION_FAILED` |

`daily_menu` aboneliğinde de fiyat **anlaşmalı porsiyon fiyatıdır**: o gün ne pişerse pişsin porsiyon başı tutar değişmez. Üretilen sipariş tek seferlik menü siparişiyle **aynı şekli** taşır — fiyatlı bir `role = "package"` üst satırı ve altında sıfır fiyatlı `role = "component"` satırları. Servis gününün menüsü yayınlanmamışsa o gün **sipariş üretilmez**: `veykemtu:abonelik-uret` hata sayar, `veykemtu_subscription_runs` satırı yazılmaz ve menü yayınlandıktan sonra komut yeniden koşturulunca sipariş doğar.

`Order` şemasına additive `subscription_id` (null=normal sipariş); `KitchenOrder`'a additive `is_subscription` (mutfak rozetine kaynak).

---

## 13. Akıllı adres — öneri ve ters geocoding

**Bugünkü hâl.** Adres tek bir serbest metin kutusu (`line1`) + sabit il
(Konya) + iki seçenekli ilçe + isteğe bağlı harita iğnesi. Müşteri mahalle
adını, sokağı ve bina numarasını aynı kutuya yazıyor; yazım her seferinde
farklı çıkıyor ("Feritpaşa", "Feritpasa", "Ferit Paşa Mh.") ve kurye
tabelası olmayan sokakta adresi okumak zorunda kalıyor.

**Bu bölümün getirdiği iki uç, adres yazmayı bir arama kutusuna çeviriyor.**
Depoda daha önce hiç geocoding yoktu; bu yepyeni bir yetenek.

| Uç | Ne yapar | Kimlik |
|---|---|---|
| `GET /api/addresses/suggest?q=&limit=` | Yazarken öneri listesi | gerekir (`customer`) |
| `GET /api/addresses/reverse?lat=&lng=` | İğneden adres metni | gerekir (`customer`) |

Her ikisi de **salt okunur**, hiçbir şey kaydetmez. Kaydetme işi eskisi gibi
`POST /api/addresses` ve `POST /api/orders` üzerinden.

> **Yol sırası uyarısı (uygulama notu).** İki uç da
> `/api/addresses/{id}` **öncesinde** kaydedilmelidir. Aksi hâlde
> yönlendirici `suggest` kelimesini bir adres kimliği sanar ve uç hiç
> çalışmadan `404` döner — teşhisi zaman alan, sebebi sıradan bir hata.

### 13.1 `GET /api/addresses/suggest`

**İstek**
```
GET /api/addresses/suggest?q=Feritpa%C5%9Fa%20K%C3%BClt%C3%BCr&limit=5
Authorization: Bearer <token>
```

| Alan | Kural |
|---|---|
| `q` | **Zorunlu, en az 3 karakter**, en fazla 120. Kısa ise `422 VALIDATION_FAILED`. |
| `limit` | Opsiyonel. 1–10, varsayılan 5. |

**Yanıt 200**
```json
{
  "data": [
    {
      "label": "Feritpaşa Mah., Kültür Sk. No:12, Selçuklu / Konya",
      "line1": "Feritpaşa Mah. Kültür Sk. No:12",
      "neighbourhood": "Feritpaşa Mah.",
      "street": "Kültür Sk.",
      "district": "Selçuklu",
      "city": "Konya",
      "latitude": 37.8792,
      "longitude": 32.4831,
      "source": "osm_nominatim"
    }
  ]
}
```

**`q` neden en az 3 karakter.** Tek harfe geocoder çağırmak, hiçbir şey ayırt
etmeyen bir sorguya sağlayıcı kotası harcamaktır; üstelik "k", "ka", "kar"
satırları önbelleği de doldurur ve hiçbiri bir daha işe yaramaz. İstemci
yazarken **300 ms debounce** uygular ve 3 karakterin altında hiç çağırmaz;
sunucu kuralı yine de denetler — istemcideki debounce bir kolaylıktır, kota
koruması değildir.

Bu yüzden buradaki `422`, sağlayıcı arızasından **ayrı tutulur**: kısa `q`
bir istemci hatasıdır (debounce kapısı sızdırmış), boş `data` ise sağlayıcı
ya da eşleşme yokluğudur. İkisi tek yanıta karışsaydı bir istemci hatası
sonsuza kadar "sonuç yok" gibi görünürdü.

**Sonuçlar hizmet alanı kutusuna kilitlidir.** Kutu `Services\ServiceArea`
içindeki değerlerdir (Konya; Selçuklu/Karatay; 37.80–38.10 K, 32.35–32.75 D).
Kutu dışındaki eşleşmeler yanıttan **düşürülür** — "buraya teslimat yok"
diye soluk gösterilmez. Müşteriye seçebileceğini sandığı bir satır gösterip
ödeme ekranında reddetmek, o satırı hiç göstermemekten kötüdür.

Eleme **iki kez** yapılır: sağlayıcıya kutu bir arama sınırı olarak verilir
(`viewbox` + `bounded`) ve dönen her aday sunucuda `ServiceArea::containsPoint`
ile yeniden süzülür. Sağlayıcı sınırı çoğu zaman bir *tercih* sayar, kesin bir
filtre değil; ikinci süzgeç olmasa kutunun hemen dışındaki bir sokak listeye
sızardı.

`latitude`/`longitude` bu yüzden **her zaman doludur**: eleme koordinat
üzerinden yapılıyor, koordinatsız aday listeye zaten giremiyor. İstemci her
öneride iğneyi güvenle yerleştirebilir.

### 13.2 `GET /api/addresses/reverse`

**İstek**
```
GET /api/addresses/reverse?lat=37.8792&lng=32.4831
Authorization: Bearer <token>
```

**Yanıt 200**
```json
{
  "data": {
    "label": "Feritpaşa Mah., Kültür Sk. No:12, Selçuklu / Konya",
    "line1": "Feritpaşa Mah. Kültür Sk. No:12",
    "neighbourhood": "Feritpaşa Mah.",
    "street": "Kültür Sk.",
    "district": "Selçuklu",
    "city": "Konya",
    "latitude": 37.8792,
    "longitude": 32.4831,
    "source": "osm_nominatim"
  }
}
```

**Yanıttaki koordinat, isteğin kendi koordinatıdır.** Geocoder bir noktayı
tipik olarak sokak ya da bina merkezine *oturtur* (snap). İstemci o oturmuş
noktayı iğneye yazsaydı, iğne kullanıcının parmağının altından birkaç on
metre kayardı ve kullanıcı bunu bir arıza olarak görürdü. Kapının tam yerini
müşteri biliyor, geocoder değil: sağlayıcıdan yalnızca **metin** alınır.

**Kutu dışı koordinat → `422 VALIDATION_FAILED`**, `details.reason =
"out_of_service_area"`:

```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "Seçilen konum hizmet alanımızın dışında.",
    "details": { "reason": "out_of_service_area" }
  }
}
```

Burada `422`, sessiz bir boş yanıttan doğrudur: kullanıcı haritayı gördü ve
teslimat yapmadığımız bir yeri **kasten** seçti; söylenecek net bir şey var.
Aynı mesajı `POST /api/addresses` ve `POST /api/orders` zaten veriyor
(`AddressController::validated`), yani müşteri aynı sınırı iki farklı yerde
iki farklı dille duymuyor.

`lat` ve `lng` **birlikte zorunludur**; yarısı gelen çift `422`. Kayıtlı
adreste yarım koordinat sessizce `null`'a düşüyor, burada düşemez — sorulacak
bir nokta yoksa soru da yoktur.

### 13.3 Geocoder erişilemezse ne dönüyor — **karar: `200` + boş veri**

| Uç | Sağlayıcı çöktüğünde |
|---|---|
| `/addresses/suggest` | `200` `{ "data": [] }` |
| `/addresses/reverse` | `200` `{ "data": null }` |

**Yeni bir `ErrorCode` üyesi EKLENMEDİ ve eklenmeyecek.** `ErrorCode`
sözleşmede bir enum; yeni üye, istemcilerdeki kapsayıcı `switch` bloklarını
ve `openapi-typescript`'in ürettiği birleşim tipini kırar. ADR-09'un koruduğu
şey tam olarak budur ve B-19'da servis günü kapıları için de aynı karar
verilmişti (§4 "Servis günü kapıları").

**Neden `5xx` değil, neden hiç hata değil.** Öneri bir **kolaylıktır**, kapı
değil: beş adres alanının hepsi elle doldurulabiliyor ve harita iğnesi zaten
isteğe bağlı. Dışarıdaki bir servisin arızasını hata koduna çevirmek, o
servise kendi sipariş akışımızı durdurma yetkisi vermek olurdu — Nominatim'in
bakımda olduğu on dakikada hiç kimse adres kaydedemez, dolayısıyla hiç kimse
sipariş veremezdi. Bu, kazandığından çok daha fazlasını kaybeden bir bağımlılık.

**Boş yanıt iki şeyi birden anlatır ve istemci ikisini AYIRT ETMEZ:**
"bu metne uyan adres yok" ve "şu an öneri veremiyoruz". İkisinde de doğru
davranış aynıdır — alanları elle doldurtmak. Ayrım sunucu günlüğüne
(`warning`, sürücü adı + süre + hata sınıfı) yazılır, kullanıcıya değil;
kullanıcıya "sağlayıcı hatası" demek, elinde yapabileceği bir şey olmayan
kişiye suçlu aramak gibidir.

**Bunun istemciye tek zorunluluğu:** öneri listesi **hiçbir zaman zorunlu bir
adım** olmayacak. Liste boşken form gönderilebilir kalmalı, "önerilerden
birini seçin" gibi bir kapı konmamalı. Boş liste, tasarım dilindeki *empty*
tonuyla gösterilir (`brand50`/`brand600`, `role` yok) — *error* tonuyla değil:
bu bir hata değil, bir yokluk.

**Sağlayıcı arızası önbelleğe YAZILMAZ.** Yazılsaydı 30 saniyelik bir kesinti,
önbellek ömrü boyunca (24 saat) donmuş bir "sonuç yok" hâline dönerdi.

### 13.4 Sağlayıcı seçimi — OSM tabanlı sürücüyle başlanıyor

| Karar | Değer |
|---|---|
| İlk sürücü | **OSM / Nominatim** (`source: "osm_nominatim"`) |
| Anahtar | **gerekmiyor** |
| Faturalandırma | yok |
| Sürücü anahtarı | `GEOCODER_DRIVER` (env) |

**Gerekçe.**

1. **Harita kararı zaten OSM.** Web'de Leaflet + OSM karoları, mobilde
   `flutter_map` kullanılıyor (`website/package.json`: `leaflet`,
   `react-leaflet`). Geocoding için başka bir sağlayıcıya gitmek, iğnenin
   oturduğu karo ile adresin çözüldüğü veri tabanını ayırmak demekti; ikisi
   ayrıştığında müşteri haritada gördüğü sokağın adını öneri listesinde
   bulamaz.
2. **Anahtar yok, fatura yok.** Bugün gerçek trafiği olmayan bir özellik
   için sözleşmeli/faturalı bir sağlayıcı açmak, kullanılmadan maliyet
   üreten bir bağımlılıktır. `docs/11` §F2-01'in "Autocomplete oturum başına
   ücretlendirilir, `sessiontoken` kullanılmazsa fatura 10-20 katına çıkar"
   uyarısı da bu riski zaten işaret ediyor.
3. **Sürücü arayüzü geçişi açık bırakıyor.** Sağlayıcı bir arayüzün arkasında
   durur; uç, yanıt biçimi ve istemci kodu sağlayıcıyı hiç bilmez:

   ```
   interface GeocoderDriver {
       suggest(string $query, int $limit): AddressSuggestion[]   // hepsi kutu içi
       reverse(float $lat, float $lng): ?AddressSuggestion
   }
   ```

   Google Places'e geçmek `GEOCODER_DRIVER` değerini değiştirmek + ikinci bir
   sınıf yazmaktır. Sözleşme değişmez, istemci değişmez. `docs/11` §F2-01
   zaten bu geçişi planlıyor.

**`source` alanı neden kapalı bir enum DEĞİL.** Sürücü değişeceği belli olan
bir şey; `source`'u enum yapmak, ilk sürücü değişiminde §1.4'e takılmak
demekti. Serbest metin. İstemci bu alana **göre dallanmaz** — sağlayıcı
atfını göstermek ve günlükte hangi sürücünün konuştuğunu bilmek için var.

**Nominatim'in kullanım politikası bağlayıcıdır** ve ücretsiz olması onu
sınırsız yapmaz: saniyede en fazla 1 istek, kendini tanıtan bir `User-Agent`
(`GEOCODER_USER_AGENT`, iletişim adresi içerir) ve **sonuçların önbelleğe
alınması** zorunlu. Politikayı ihlal eden kaynak IP engellenir; engelin
geldiği gün 13.3'teki boş-veri yolu devreye girer ve sipariş akışı yine
durmaz — ama özellik ölür. Trafik büyüdüğünde çözüm sağlayıcı değiştirmek
değil, **Nominatim'i kendimiz barındırmaktır**: aynı HTTP arayüzü, aynı
sürücü, yalnız taban adres değişir.

**Alan eşlemesi.** Nominatim'in `addressdetails=1` yanıtındaki anahtarlar
bölgeden bölgeye değişir; sürücü sıralı bir geri düşme zinciri uygular:

| Bizim alan | Kaynak (ilk dolu olan) |
|---|---|
| `neighbourhood` | `neighbourhood` → `quarter` → `suburb` |
| `street` | `road` → `pedestrian` → `residential` |
| `building_no` | `house_number` |
| `district` | `town` → `city_district` → `municipality` |
| `city` | `province` → `city` → `state` |

**`floor` ve `door_no` hiçbir geocoder'dan gelmez** ve gelmeyecek: hiçbir
harita verisi hangi katta, hangi dairede oturduğunuzu bilmiyor. Bu ikisi her
zaman müşterinin elinden çıkar. Arayüz bu yüzden öneri seçildikten sonra da
kat/daire alanlarını **açık ve boş** bırakmalı — "adres tamamlandı" izlenimi
verip kuryeyi apartman girişinde bırakmamalı.

Eşleme sonucu ilçe/il hizmet alanına oturmuyorsa aday **düşürülür**; çünkü
`district` alanı istemcide doğrudan ilçe seçicisine yazılıyor ve seçicide
karşılığı olmayan bir değer formu sessizce geçersiz kılardı.

### 13.5 Önbellek ve oran sınırı politikası

**Önbellek sunucudadır, iki anahtarla:**

| Uç | Anahtar | Ömür |
|---|---|---|
| `suggest` | sürücü + normalize edilmiş `q` + `limit` | **24 saat** |
| `reverse` | sürücü + 4 ondalığa yuvarlanmış `lat`,`lng` | **30 gün** |

`q` normalizasyonu: kırp, iç boşlukları teke indir, **Türkçeye duyarlı**
küçült (`I → ı`, `İ → i`). `mb_strtolower` dilden bağımsızdır ve `I`'yı
`i`'ye düşürür; `ServiceArea::lower` bu dersi zaten vermiş durumda. Yanlış
küçültme, "İSTASYON" ile "istasyon" için iki ayrı önbellek satırı açar ve
ikisi de sağlayıcıya gider.

`reverse` anahtarının 4 ondalığa yuvarlanması ≈ **11 metrelik** bir kutu
demek: bir bina ayak izi. Yuvarlamasaydık iğnenin bir piksel oynaması yeni
bir sağlayıcı isteği doğururdu ve önbellek hiç tutmazdı. 30 günlük ömür,
sokak dokusunun ay içinde değişmemesine dayanıyor.

**Ömürler neden farklı:** `suggest` yeni açılan sokakları ve yeni numaralanan
binaları görmeli (bir gün yeterince kısa); `reverse` var olan bir noktanın
adını soruyor ve o ad ayda bir değişmiyor.

**Negatif önbellek: 1 saat.** Eşleşme bulunamayan sorgu da yazılır, ama kısa
ömürle — yoksa aynı yazım hatası her tekrarında sağlayıcıya gider. Sağlayıcı
**arızası** ise (§13.3) hiç yazılmaz.

**Oran sınırı:**

| Uç grubu | Sınır |
|---|---|
| `/api/addresses/suggest`, `/api/addresses/reverse` | **30 istek / dakika / hesap** |

**Neden hesap başına, IP başına değil:** kurumsal müşterinin tipik ağı tek
NAT'ın arkasındadır; IP sınırı aynı ofisin çalışanlarını birbirine kırdırırdı.
Sınırın hesaba bağlanabilmesi, ucun kimlik istemesinin başlıca sebebi.

**Neden 30:** 300 ms debounce ile adres yazan bir kullanıcı tipik olarak
5–8 çağrı üretir; 30 hem tereddütlü bir yazımı hem de bir adres düzeltmesini
aynı dakikada karşılar, ama açık bir istemci döngüsünü dakikada 30'da keser.

**Sağlayıcıya giden trafik ayrıca genel bir kapıdan geçer:** sürücü, sunucu
genelinde saniyede 1 isteği aşmaz (Nominatim politikası). Aynı anda yazan
yirmi müşterinin çoğu önbellekten döner; kapıdan kısa sürede slot alamayan
istek **beklemez**, §13.3'teki boş-veri yolundan döner. Müşteriyi öneri
listesi için bekletmek, öneriyi hiç vermemekten kötüdür.

**Yanıt istemcide önbelleğe alınmaz.** Bu uçlar `Cache-Control: private,
no-store` taşır: yanıt, giriş yapmış bir müşterinin yazdığı metne bağlıdır ve
yazılan adres kişisel veridir (`docs/02` §6). Ara katmandaki bir vekil ya da
CDN bunu paylaşımlı önbelleğe alsaydı bir müşterinin aradığı adres başkasına
dönebilirdi.

**`q` metni uygulama günlüğüne yazılmaz.** Günlüğe yalnız sürücü adı, süre,
sonuç sayısı ve varsa hata sınıfı düşer. Adres aramaları KVKK kapsamında
kişisel veridir ve günlükler sipariş verisiyle aynı saklama kurallarına tabi
değildir.

### 13.6 Anahtar asla istemciye gömülmez

Bugünkü sürücü anahtar istemiyor, yani **şu an sızacak bir sır yok.** Kural
tam da bu yüzden şimdi yazılıyor: sürücü değiştiğinde uyulacak kuralın o gün
tartışılması geç olur.

1. **İstemciler geocoder'a doğrudan İSTEK ATMAZ.** `website/` ve `musteriapp/`
   yalnızca `/api/addresses/suggest` ve `/api/addresses/reverse` uçlarını
   çağırır. Sağlayıcının adresi, biçimi ve varsa anahtarı yalnızca sunucuda
   bilinir. (Harita **karoları** bunun dışındadır — onlar zaten herkese açık
   ve anahtarsız.)
2. **`NEXT_PUBLIC_` öneki yasak.** Next.js bu önekli her değeri tarayıcı
   paketine gömer; `NEXT_PUBLIC_GEOCODER_KEY` gibi bir değişken, anahtarı
   sayfanın kaynağında yayınlamakla aynı şeydir.
3. **Flutter `--dart-define` bir sır kasası değildir.** Verilen değerler
   derlenmiş ikilinin içinde durur ve `strings` ile okunur. Mobilde geocoder
   anahtarı hiçbir biçimde bulunmaz.
4. **Sunucu env'i:** `GEOCODER_DRIVER`, `GEOCODER_BASE_URL`,
   `GEOCODER_USER_AGENT`, (ileride) `GEOCODER_API_KEY`. `.env.example`
   yalnızca **adları** taşır; gerçek değerler repoya girmez (AGENTS.md §2).
5. **Oran sınırı ancak anahtar sunucudayken bir şey ifade eder.** Anahtar
   istemcide olsaydı §13.5'teki 30/dakika sınırı yalnızca dürüst istemciyi
   bağlardı; kotayı anahtarı bulan harcardı ve fatura bize gelirdi.

### 13.7 Şemalara eklenen alanlar (additive)

`Address` (sipariş kopyası), `SavedAddress` ve `SavedAddressInput`
şemalarının **üçüne birden** aynı beş alan eklendi:

| Alan | Tip | Uzunluk | Not |
|---|---|---|---|
| `neighbourhood` | `string \| null` | 96 | Mahalle |
| `street` | `string \| null` | 128 | Cadde / sokak |
| `building_no` | `string \| null` | 24 | Bina no — **metin**, `12/A` yaygın |
| `floor` | `string \| null` | 16 | Kat — `Zemin` de geçerli değer |
| `door_no` | `string \| null` | 16 | Daire / iç kapı no |

Üç şemada da aynı adlar: istemci öneriyi forma, formu isteğe, isteği sipariş
kopyasına **alan alan** taşır ve arada hiçbir eşleme tablosu tutmaz.

**`line1` KALIR ve zorunlu kalır.** Silinmiyor, isteğe bağlı yapılmıyor:

- Sahadaki istemci sürümleri yalnız `line1` gönderiyor; zorunluluğu
  kaldırmak `SavedAddress.line1`'i fiilen boşaltılabilir hâle getirir ve o
  gün fişte adres satırı boş çıkar.
- Mutfak fişi, müşteri fişi ve `OrderPresenter` bu alanı basıyor. Beş yeni
  alanı okumak zorunda bırakılan bir yazıcı katmanı, additive bir değişikliği
  kırıcı bir değişikliğe çevirirdi.

**Sunucu, `line1` boş geldiğinde onu yapılandırılmış alanlardan türetir**
(`neighbourhood` + `street` + `building_no`). Türetme yalnızca `line1` boşken
çalışır: müşterinin kendi yazdığı satırı üzerine yazmak, yazdığını gören
kullanıcıyı şaşırtır ve öneriden gelmeyen ek bilgiyi (site adı, tarif) siler.

Güncelleme davranışı `latitude`/`longitude` ile aynı kuralı izler: **`null`
göndermek alanı siler, alanı hiç göndermemek mevcut değeri korur.** Ama
koordinat çiftinin aksine bu beş alan birbirinden **bağımsızdır** — kat
bilinip daire numarasının bilinmemesi olağan bir durumdur, yarım kalmış bir
çift değil.

> **`docs/11` §F2-01 ile ilişki.** Yol haritası bu işi Google Places +
> `POST /addresses/resolve` olarak planlıyordu. Buradaki iki uç onun
> **okuma yarısını** OSM sürücüsüyle şimdi teslim ediyor. `resolve`'un
> geri kalanı (bölge, teslimat ücreti ve asgari sepet önizlemesi) F2-01'de
> kalıyor: bölgeler (`F2-02`) henüz yok ve olmayan bir bölgeye ücret
> döndüren bir uç yazmak, dolduramayacağımız bir alan yayınlamak olurdu.

---

## 14. Kontrol Merkezi uçları (K-21)

Ayrı bir depoda duran **Kontrol Merkezi** paneli, mutfak kasalarını bu uçlar
üzerinden yönetiyor: kasa açıyor, eşleme kodu üretiyor, kasa iptal ediyor,
ayar ve **kilit** itiyor, komut kuyrukluyor, sipariş revize ediyor ve durum
geçiriyor.

**Neden ayrı bir uç ailesi var.** `/api/kitchen/*` uçları bir **kasanın**
token'ıyla korunuyor ve her istek o kasanın `last_seen_at` alanını tazeliyor.
Kontrol Merkezi oraya eşleşerek girseydi, panelde açık duran bir ekran
**mutfakta olmayan bir kasayı "çevrimiçi" gösterirdi** ve yöneticinin gördüğü
tablo kendi kendini doğrulardı.

**Bu uçlar iş mantığı taşımıyor.** Revizyon `OrderEditor`'da, durum geçişi
`OrderStatusTransition`'da, ayarlar `KitchenDeviceSettings`'te, eşleme ve
iptal `KitchenDevice`'ta. Hepsi mutfak kasasının kullandığı sınıfların ta
kendisi — ayrı bir kopya yazılsaydı, sipariş merkezden düzenlendiğinde iade
kaydı sessizce oluşmayabilirdi. Buradaki tek katman
"gerekçe iste, denetime yaz, kuru provada yazma" kabuğu.

**ADR-08 burada geçerli değil.** Fiyat gizliliği **mutfak kapsamına** ait bir
kuraldı: kasa ekranı gün boyu mutfakta açık duruyor ve fiyat orada yalnız
sızıntı riski. Kontrol Merkezi bir yönetim yüzeyi; ürün seçici fiyat döndürür.

### 14.1 Kimlik doğrulama — `X-Control-Signature`

Cihaz token'ı **yok**, `bbd.signature` **değil**, ayrı bir sır. Uygulaması
`Http\Middleware\VerifyControlSignature`.

Üç başlık birlikte gönderilir:

| Başlık | Değer |
|---|---|
| `X-Control-Timestamp` | UNIX saniye, **yalnız rakam** |
| `X-Control-Nonce` | isteğe özgü rastgele dize, **16–128 karakter** |
| `X-Control-Signature` | `^sha256=[0-9a-f]{64}$` |

**İmza adım adım:**

1. **Kanonik yükü kur** — beş satır, aralarında `\n`:

   ```
   METOT \n YOL \n ZAMAN \n NONCE \n sha256_hex(ham gövde)
   ```

   - `METOT` **büyük harf**: `GET`, `POST`, `PATCH`.
   - `YOL` **`/api` öneki dâhil, sorgu dizesi hariç**:
     `/api/control/kds/devices/7/revoke`. Sorgu dizesi imzaya girmez —
     iki taraf parametre sırasını tutturamazdı; süzgeçler yalnız okuma
     uçlarında var ve yazma uçlarının tamamı gövdeli.
   - `ZAMAN` ve `NONCE` başlıklarda gönderilen değerlerin **aynısı**.
   - Gövde **ham hâliyle** özetlenir. JSON yeniden serileştirilmez: boşluk
     ya da anahtar sırası imzayı değiştirir. Gövdesiz isteklerde boş dizenin
     SHA-256'sı kullanılır
     (`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`).

2. **HMAC'i hesapla ve önekle:**

   ```
   X-Control-Signature = 'sha256=' + HMAC_SHA256(BLD_CONTROL_SECRET, kanonik_yük)
   ```

   Hex çıktı **küçük harf**.

**Tekrar (replay) saldırısına kapalı.** Dört şey birden imzaya girdiği için:

- **Metot ve yol.** `POST .../revoke` imzası `GET .../devices` olarak
  yeniden kullanılamaz. Yalnız gövde imzalansaydı, boş gövdeli iki farklı
  uç aynı imzayı paylaşırdı — ki iptal ucunun gövdesi zaten gövdesize yakın.
- **Zaman.** Pencere **±300 saniye** (saat kayması payı dâhil). Dışındaki
  istek `401`.
- **Nonce.** **600 saniye** (pencerenin iki katı) hatırlanır; aynı nonce
  ikinci kez kabul **edilmez**. Pencere kadar tutmak yetmezdi: pencerenin son
  saniyesinde imzalanmış bir istek, unutulduktan sonra hâlâ zaman
  denetiminden geçebilirdi. Depo `Cache` — sunucu tek düğüm ve kalıcı bir
  tablo her istekte bir yazma daha demekti; önbellek uçarsa en kötü ihtimalle
  pencere kadar bir tekrar aralığı açılır.
- **Sıra: önce imza, sonra nonce.** Tersi olsaydı imzasız bir istemci
  rastgele nonce'lar göndererek meşru istemcinin nonce'unu "kullanılmış"
  işaretleyip onu kilitleyebilirdi. Nonce işaretlemesi `Cache::add` ile
  **atomik**: aynı nonce'la eşzamanlı iki istekten yalnız biri geçer.

**Neden `bbd.signature` yeniden kullanılmadı.** Üç ayrı sebep:

- **Yön ters.** BBD bize sipariş **yazıyor** (tek uç, tek işlem). Kontrol
  Merkezi **yönetiyor**: kasa iptal ediyor, ayar itiyor, sipariş revize
  ediyor, durum geçiriyor.
- **Yetki seviyesi farklı.** Aynı sırrı iki seviye için kullanmak, BBD'nin
  sırrını ele geçiren birine **mutfağı yönetme hakkı** da verirdi.
- **Kapsam farklı.** `bbd.signature` yalnız **gövdeyi** imzalıyor; zaman
  damgası ve nonce yok, yani ağı dinleyen biri geçerli bir isteği sınırsız
  kez oynatabilir. Orada etki `external_id` tekilliğiyle sınırlı kalıyor.
  **Burada kalmazdı:** "cihazı iptal et" isteğini tekrar oynatmak mutfağı
  sipariş göremez hâle getirir.

Ayrıca o şema BBD Store'la **paylaşılan** bir sözleşme ve dokunulmaması
istendi.

**`X-App-Id` / `X-App-Version` / `Accept-Language` istenmez** (`bld.headers`
uygulanmıyor): Kontrol Merkezi bir müşteri istemcisi değil, yöneten bir
sistem. BBD köprüsüyle aynı gerekçe.

**Sır tanımlı değilse uç kapalıdır.** `BLD_CONTROL_SECRET` boşsa her istek
`401` alır; boş sırla imza doğrulamak herkesin geçtiği bir kapıdır.

**Red sebepleri ayrıştırılıyor.** `bbd.signature`'ın aksine `message` hangi
denetimin düştüğünü söyler. Kod her hâlde `UNAUTHENTICATED`:

| `message` | Sebep |
|---|---|
| `İmza başlıkları eksik.` | Üç başlıktan biri yok |
| `İstek zaman penceresinin dışında.` | \|şimdi − timestamp\| > 300 sn |
| `Bu istek daha önce işlendi.` | Nonce tekrar kullanıldı |
| `İmza doğrulanamadı.` | HMAC tutmadı, timestamp rakam değil ya da nonce 16–128 dışında |
| `Kontrol Merkezi entegrasyonu yapılandırılmamış.` | `BLD_CONTROL_SECRET` boş |

Bu uç bir saldırgana değil, bakımını yaptığımız **tek** istemciye hizmet
ediyor ve "saat kaymış" ile "sır yanlış" ayrımı olmadan sahada teşhis
imkânsız. Mesajların hiçbiri sırrın varlığını ya da uzunluğunu ele vermiyor.
İmzası tutmayan istek **denetim satırı bırakmaz** — kapıdan hiç geçmedi.

### 14.2 Uçlar (16)

Hepsi `/api/control/kds/` altında ve hepsi `control.signature` +
`throttle:bld-control` katmanından geçiyor.

| Uç | Ne yapar | Yazma? |
|---|---|---|
| `GET /overview` | Panel açılışı: cihaz, sipariş ve fiş sayıları tek istekte | — |
| `GET /devices` | Kasa listesi — **iptal edilmişler dâhil** | — |
| `POST /devices` | Kasa aç + ilk eşleme kodunu **hemen** üret | ✔ `device.create` |
| `PATCH /devices/{id}` | Yeniden adlandır (**yalnız ad**) | ✔ `device.rename` |
| `POST /devices/{id}/pairing-code` | Yeni eşleme kodu (10 dk, tek kullanımlık) | ✔ `device.pairing_code` |
| `POST /devices/{id}/revoke` | Kasayı iptal et — **satır da token da silinmez** | ✔ `device.revoke` |
| `PATCH /devices/{id}/settings` | Yönetilen ayarlar **ve kilitler** — kısmi yazım | ✔ `device.settings` |
| `GET /devices/{id}/commands` | Komut geçmişi (son 50, üç damgayla) | — |
| `POST /devices/{id}/commands` | Tek seferlik komut kuyrukla | ✔ `device.command` |
| `GET /print-jobs` | Fiş **denetim** kaydı — kuyruk değil | — |
| `GET /orders` | Sipariş listesi — kapsam mutfak panosuyla **aynı** | — |
| `GET /orders/{id}` | Tek sipariş, düzenlenebilir görünüm | — |
| `GET /orders/{id}/revisions` | Revizyon geçmişi (+ `created_by_device_id`) | — |
| `POST /orders/{id}/revisions` | Yeni revizyon | ✔ `order.revise` |
| `POST /orders/{id}/status` | Durum geçişi | ✔ `order.status` |
| `GET /menu` | Düzenleme ekranının ürün seçicisi — **fiyatlı, seçenek kimlikli** | — |

Alan alan şekiller `docs/openapi.yaml` → `Kontrol Merkezi` etiketi; ikisi
çelişirse **openapi kazanır** (§11).

Birkaç davranış kuralı:

- **Eşleme kodu yalnız iki yerde açılır:** kodu üreten uçların yanıtlarında
  ve listede kod hâlâ **kullanılabilirken**. Kullanılmış ya da süresi dolmuş
  bir kodu göstermek yöneticiye çalışmayan bir kod okutur.
- **İptal edilmiş kasaya kod üretilmez ve komut gönderilmez** (`422`).
  Üretilen kod zaten `pairingCodeIsUsable()` denetiminde elenirdi; komut ise
  sonsuza kadar kuyrukta kalırdı.
- **İkinci iptal ilk damgayı oynatmaz.** `revoked_at` "ne zaman iptal edildi"
  sorusunun cevabı ve denetim değeri ilk damgadadır.
- **Ayarlar `settings` nesnesinin altında**, gövdenin kökünde değil. Kökte
  olsalardı `reason`/`actor`/`dry_run` ile aynı ad alanını paylaşırlardı ve
  `reason` adında bir ayar eklemek imkânsız hâle gelirdi.
- **Tanınmayan ayar anahtarı sessizce yutulmaz → `422`.** `allow_settngs`
  gibi bir yazım hatası göz ardı edilseydi yönetici kilidi koyduğunu sanır,
  kasa serbest kalırdı.
- **Sınır dışı ayar sessizce kırpılmaz → `422`.** Servis kırpıyor; buradaki
  kuralların işi kırpmayı **görünür** kılmak — Kontrol Merkezi 70 yazıp 60
  kaydedildiğini fark etmez ve ekranında yanlış değeri gösterirdi.
- **Komut anında gitmez.** Kasanın bir sonraki **sağlık bildiriminin**
  yanıtına biniyor; yanıttaki `arrives_within_seconds` bunu açıkça söylüyor.
  Söylenmeseydi kullanıcı "olmadı" deyip aynı düğmeye tekrar basar ve **iki
  fiş** çıkardı.
- **`GET /print-jobs` bir kuyruk değildir.** KDS'in kalıcı kuyruğu kasanın
  **diskinde** ve sunucuda karşılığı yok; buradan iş silinemez, yeniden
  sıraya alınamaz. Yeniden bastırmanın tek yolu `reprint` komutu.
- **Revizyonun `items` alanı tam listedir**, delta değil; boş liste `422`.
  Siparişi boşaltmak iptal **değildir**.
- **Çağıran ayrımı:** merkezden yazılan revizyonda `created_by_device_id`
  **NULL** kalır ve revizyon **notunun ilk satırına**
  `Kontrol Merkezi · <actor>` etiketi düşer. Etiket `created_by_staff`
  sütununa yazılamıyor: o sütun `unsignedBigInteger` (bir yönetici kimliği)
  ve tipini değiştirmek yayınlanmış bir şemayı kırmak olurdu.
- **`option_value_ids` geri gönderilmelidir.** `GET /orders/{id}` yanıtındaki
  kimlikler revizyon gövdesine aynen konmazsa sunucu satırı **seçeneksiz**
  yeniden fiyatlar ve seçenek sessizce kaybolur.

### 14.3 `reason` ve `actor` — her yazmada zorunlu

Her yazma ucu üç alan taşır: `actor`, `reason` ve isteğe bağlı `dry_run`.

| Alan | Kural |
|---|---|
| `actor` | zorunlu, 2–120 karakter |
| `reason` | zorunlu, **en az 10**, en fazla 500 karakter |
| `dry_run` | isteğe bağlı, varsayılan `false` |

**`reason` neden en az 10 karakter.** Sınır olmasaydı "ok" yazıp geçmek
serbest olurdu ve denetim izi, doldurulmuş ama hiçbir şey anlatmayan bir
sütuna dönerdi. On karakter bir cümlenin başlangıcını zorluyor.

**Sipariş uçlarında üst sınır 160'a daralıyor** (`POST /orders/{id}/revisions`
ve `POST /orders/{id}/status`): aynı metin `veykemtu_order_revisions.reason`
sütununa da yazılıyor ve o sütun 160 karakterlik. Taşan gerekçe **sessizce
kırpılmak yerine `422`** alıyor.

**`actor` neden serbest metin.** Kontrol Merkezi ayrı bir depo, ayrı bir
kullanıcı tablosu; o kişinin BLD'de hesabı yok ve olmayacak. Yabancı anahtar
vermek iki sistemi birbirine bağlardı. Doğruluğu Kontrol Merkezi'nin
sorumluluğunda ve imza zaten isteğin **oradan** geldiğini kanıtlıyor.

**Alanlar eksikse `422` gelir ve denetim satırı YAZILMAZ** — geçerli bir
istek hiç oluşmadı.

**Gerekçe neden sunucuda saklanıyor.** Gerekçeyi ve aktörü karşı tarafın
kaydetmesine güvenmek, kaydı isteyen tarafın kendi kendini denetlemesi
olurdu; Kontrol Merkezi arayüzünde gerekçe alanını gizlemek ya da otomatik
doldurmak tek satırlık bir değişiklik. Sunucu `reason`'ı **zorunlu kılıyor**
ve `veykemtu_control_audit`'e **kendisi** yazıyor.

### 14.4 Kuru prova (`dry_run`)

`dry_run: true` gönderildiğinde:

- **Hiçbir yazma yapılmaz.** Kasa açılmaz, iptal edilmez, ayar yazılmaz,
  komut kuyruğa girmez, revizyon uygulanmaz, durum değişmez.
- Yanıt `ok: true`, `dry_run: true` ve **`would`** nesnesiyle döner; `would`
  "uygulansaydı ne olurdu"yu anlatır.
- **Denetim satırı YİNE YAZILIR**, `result = "dry_run"` ile. "Denedim ama
  uygulamadım" bir eylemdir ve yanlış kasaya kilit uygulamaya çalışan birinin
  ilk adımı çoğu zaman odur.
- **Ön denetimler gerçekten çalışır.** İptal edilmiş kasa, düzenlenemez
  sipariş ve geçersiz durum geçişi kuru provada da `422` verir. Kuru prova
  yalnız isteği yankılasaydı, "kuru prova geçti" diyen bir ekran gerçek
  gönderimde patlardı.
- **Ön denetim düşerse satır `dry_run` KALIR**, `failed` olmaz; sebep
  `payload_json.error` alanına yazılır. Aksi hâlde denetim ekranında kuru
  provalar gerçek yazma denemeleriyle karışırdı.

Kontrol Merkezi geçidinde varsayılan **açık**, yani bu alan çoğu istekte dolu
geliyor. Sorgu dizesindeki `"true"` metni de doğru okunuyor.

### 14.5 Denetim izi

Her yazma isteği `veykemtu_control_audit` tablosuna bir satır bırakıyor
(şema: `docs/02-veri-modeli.md` §2.5). Yanıttaki `audit_id` o satırın
kimliği ve **kuru provada da dolu**.

**Satır işlemden ÖNCE açılıyor.** Sonra açılsaydı, yarıda kalan bir yazma
(veritabanı hatası, zaman aşımı) hiçbir iz bırakmazdı — oysa "denendi ve
olmadı" tam da soruşturulması gereken hâl.

`result` alanının yolculuğu:

| Değer | Anlamı |
|---|---|
| `pending` | Satır açıldı, işlem henüz bitmedi |
| `applied` | Yazma başarıyla tamamlandı |
| `failed` | Yazma denendi, hata aldı (sebep `payload_json.error`) |
| `dry_run` | Kuru prova; hiçbir yazma yapılmadı |

**SATIR SİLİNMEZ.** Silme yolu bilinçli olarak açılmıyor — denetim izini
silebilen bir denetim izi denetim izi değildir. Güncelleme yalnız `result`
(ve hata durumunda `payload_json.error`) alanına dokunuyor; `actor`,
`action`, `reason` ve hedef bir daha değişmiyor.

`payload_json` **isteğin özetidir, tam gövdesi değil**: yalnız o eylemi
anlamlandıran alanlar yazılıyor (hangi ayar, hangi komut, kaç kalem). Ham
gövdeyi saklamak müşteri notu gibi kişisel veriyi ikinci bir yerde
çoğaltırdı.

### 14.6 Oran sınırı — `bld-control`

**1200 istek / saat / IP** (§10). `bld-partner` (300/saat) yetmez, mutfak
bütçesi (2000/saat) fazla: Kontrol Merkezi **açık duran bir panel** ve 10
saniyelik bir yoklama tek başına 360/saat eder; aynı anda iki yönetici panel
açabilir. Mutfak kadar cömert olmaması bilinçli — kasa sipariş göremezse
mutfak durur, panel yavaşlarsa kimse aç kalmaz.

Sınır **IP başına**, çünkü Kontrol Merkezi'nin kimliğini istek başına
hesaplanan bir **imza** taşıyor, sabit bir anahtar değil; sayacı bağlayacak
bir hesap kimliği yok ve panel tek sunucudan çıkıyor. Aşılırsa
`429 RATE_LIMITED`.

---

## 15. Günlük menü satış modeli — sözleşme değişiklikleri (16.08.2026)

İş modeli değişti: satış artık **günün menüsü** üzerinden yürüyor, her servis
günü kendi sabah kesim saatinde kapanıyor, stok iki tavanla yönetiliyor ve
abonelik imzalı sözleşme + peşin dönem ödemesiyle başlıyor. Bu bölüm o
değişikliğin sözleşmeye yansıyan tamamını tek yerde topluyor.

**Biri hariç hepsi additive'dir.** Tek istisna cari hesabın kaldırılmasıdır
(§12.2) ve orada yazan **yayın sırası bağlayıcıdır: istemciler sunucudan
önce**.

### 15.1 Eklenen alanlar

| Şema | Alan | Not |
|---|---|---|
| `Location` | `service_weekdays: int[]` | Menü çıkan haftanın günleri (ISO 1..7). Yalnız görüntüleme. |
| `Location` | `max_lookahead_days` | Şema aynı; **sunucu değeri 7 oldu**. |
| `DailyMenu` | `cutoff_at: string\|null` | Kesimin bittiği **mutlak an** (UTC). |
| `DailyMenu` | `remaining_portions: int\|null` | Gün tavanı. `null` = sınırsız. |
| `DailyMenu` | `image_urls: string[]` | İlk 4 kalemin görseli; 2x2 ızgara. |
| `DailyMenu` | `unavailable_reason` += `no_service_day`, `sold_out` | |
| `DailyMenuPackage` | `remaining_portions: int\|null` | |
| `MenuItem` | `remaining_portions: int\|null` | Kalem tavanı; yalnız günün menüsünde dolu. |
| `MenuCalendarDay` | `cutoff_at`, `sold_out`, `weekend` | |
| `Subscription` | `exceptions[]`, `payment`, `contract` | |
| `Subscription` | `status` += `awaiting_contract`, `awaiting_payment` | |
| `Payment` | `payment_id: int\|null`, `next_action` | |

Ayrıntılar ve gerekçeler: `Location`/`DailyMenu`/`MenuCalendarDay` için §3,
`Subscription` için §12.3.

### 15.2 `next_action` — gevşek enum

`Payment.next_action` ve `SubscriptionPayment.next_action` ödemenin
kesinleşmesi için **sıradaki adımı** söyler. Kararı sunucu verir; istemci
ödeme tipine, tutara ya da bankaya bakarak bunu kendi çıkarmaz — o kural
sağlayıcı tarafında ve bizim dışımızda değişir.

| Değer | İstemci ne yapar |
|---|---|
| `none` | Ek adım yok. Sonuç `status` alanındadır. |
| `otp` | Kullanıcıdan SMS kodu alır, `.../confirm` ucuna gönderir. |
| `three_ds` | `redirect_url` adresine yönlendirir, dönüşte yoklar. |

**Enum gevşektir.** İleride yeni adım tipleri eklenecektir (`app2app`,
`biometric` gibi) ve ek değer kırıcı değişiklik sayılmaz. İstemci bilmediği
değeri gördüğünde **çökmemeli** ve kendiliğinden `none` **varsaymamalıdır**:
`none` saymak, atlanan bir doğrulama adımını "ödeme bitti" diye göstermek
olurdu. Doğru davranış, kullanıcıya güncelleme gerektiğini söyleyip
`GET /api/subscriptions/{id}/payments/{paymentId}` ile yoklamaya düşmektir.

### 15.3 Abonelik dönem ödemesi

| Uç | Ne yapar |
|---|---|
| `POST /api/subscriptions/{id}/payments` | Yürürlükteki dönem için ödeme başlatır → `SubscriptionPayment` |
| `POST /api/subscriptions/{id}/payments/{paymentId}/confirm` | `{ code }` ile OTP onayı |
| `GET /api/subscriptions/{id}/payments/{paymentId}` | Yoklama |

**Tutar istekte gönderilmez.** Dönem tutarı sunucuda hesaplanır (servis günü
sayısı × porsiyon × anlaşmalı fiyat, atlanan günler düşülmüş). İstemciden
alınsaydı, ekranındaki tutar ile gerçek tutar ayrıştığı anda (arada bir gün
atlanmışsa) abone eksik ödeyip "kapattım" sanırdı.

**Aynı dönem için ikinci ödeme kaydı açılmaz.** Açık bir ödeme varken
`POST` yenisini yaratmaz; `201` yerine `200` ve mevcut kaydı döndürür.
İkinci bir kayıt açsaydık geri dönüp tekrar deneyen abone iki kayıt bırakır,
ikisi de sağlayıcıda ayrı ayrı yaşar ve biri gecikmeli başarıya dönerse aynı
dönem iki kez tahsil edilirdi.

**Ödeme bu uçlarda tamamlanmaz.** `status` yalnız ödeme kesinleşince `paid`
olur; istemci onu yoklamayla öğrenir. **Yoklama aralığı en az 2 saniye**
olmalıdır — daha sık yoklamak yalnız oran sınırını doldurur ve sınıra takılan
istemci, ödemesi başarılı olmuş aboneye başarısız ekranı gösterir.

Yanlış OTP kodu `422` döner ve **denemeyi tüketir**; hak bittiğinde ödeme
başarısız kapanır ve abone yeni bir ödeme başlatır. Sınırsız deneme, çalınan
bir kartın kodunu aramanın önünü açardı.

### 15.4 Abonelik sözleşmesi — imzalı bağlantı + SMS OTP

| Uç | Kimlik | Ne yapar |
|---|---|---|
| `GET /api/contracts/{token}` | **yok** | Sözleşme metni + fiyat → `SubscriptionContract` |
| `POST /api/contracts/{token}/otp` | **yok** | Sözleşmedeki telefona SMS kodu → `202 { message, expires_in, resend_after }` |
| `POST /api/contracts/{token}/approve` | **yok** | `{ code, full_name? }` ile onaylar |

**Neden kimlik gerektirmiyor.** Sözleşme bağlantısı aboneye SMS ile gidiyor
ve onaylayan kişi çoğu zaman uygulamada oturum açmış kişi değil, satın almayı
onaylayan yetkilidir. Oturum istemek onayı imkânsız hâle getirirdi. Koruma
bağlantının kendisindedir: imzalı, süreli ve **kayıt kimliği taşımaz** —
sıralı bir kimlik olsaydı bir bağlantıyı eline geçiren, komşu numaraları
deneyerek başkalarının sözleşmelerini okuyabilirdi.

**Numara istekte alınmaz**; kod sözleşmenin kayıtlı numarasına gider.
İstemciden alınsaydı, bağlantıyı eline geçiren biri kodu kendi telefonuna
ısmarlayıp sözleşmeyi onaylayabilirdi. İmzalı bağlantı tek başına kimlik
değildir; SMS kodu ikinci etkendir. Oran sınırı **belirteç başına 5/saat**
(§10): bir sözleşme bağlantısına sınırsız SMS ısmarlanabilmesi doğrudan para
kaybıdır.

**Yanıt bilinçli olarak dardır.** Kimlik gerektirmeyen bir uçtan döndüğü
için abonenin adresleri, e-postası, sipariş geçmişi ve müşteri kimliği
dönmez; telefon **maskeli** verilir (`0555 *** ** 33`). Tam numarayı basmak,
bağlantıyı ele geçirene doğrulanmış bir telefon numarası hediye etmek olurdu.

Metin `body` + `body_format` (`markdown` \| `plain`) olarak gelir. **HTML
gönderilmez**: metin panelde yazılıyor ve doğrudan HTML gömmek, sözleşme
sayfasına script sokabilecek bir kapı açardı.

Süresi dolmuş bağlantı `410` **değil**, `200` + `status: expired` döner —
istemci "bu bağlantının süresi doldu, yenisini isteyin" cümlesini kurabilmeli,
boş bir hata sayfası görmemelidir. `404` yalnız belirteç hiç tanınmadığında.

**Onay geri alınamaz** ve **idempotenttir**: aynı kodla ikinci çağrı `200` ve
aynı gövdeyi döndürür. SMS'in gecikip kullanıcının iki kez dokunması sık
yaşanıyor; ikincisinin hata vermesi, onaylanmış bir sözleşmede "onaylanamadı"
yazan bir ekran demek olurdu. Vazgeçme, sözleşmenin iptali değil aboneliğin
iptalidir (`POST /api/subscriptions/{id}/cancel`) — onay kaydı hukuki bir
izdir ve silinmez.

### 15.5 Uygulama-içi duyurular

| Uç | Ne yapar |
|---|---|
| `GET /api/announcements?placement=` | Müşterinin şu anda görmesi gereken duyurular |
| `POST /api/announcements/{id}/seen` | Görüldü işaretle (listeden düşürmez) |
| `POST /api/announcements/{id}/dismiss` | Kapat (listeden düşürür) |

**Push (FCM) yoktur.** Duyuru yalnız istemci açıkken çekilir. Bu, "duyuru
okundu mu" sorusunun cevabını da değiştirir: görüldü işareti bildirimin
tesliminden değil, duyurunun ekranda çizilmesinden doğar.

Pencere ve kapatma filtresi **sunucuda** uygulanır ki üç istemci aynı kuralı
üç kez yazmasın — cihaz saatine bakan bir istemci, saati kaymış telefonda
süresi dolmuş duyuruyu göstermeye devam ederdi.

`placement` **kapalı enum değildir**. Bilinen değerler: `home`, `menu`,
`cart`, `checkout`, `orders`, `subscription`. Yerleşimler panelde tanımlanıyor
ve yeni bir ekran açıldığında sözleşmeyi beklemek, duyurunun haftalarca
yayınlanamaması demek olurdu. **İstemci tanımadığı yerleşimi hiç çizmez** —
bilmediği bir yeri "ana sayfa" sayıp duyuruyu yanlış ekrana koymak, sessizce
atlamaktan kötüdür. Bilinmeyen `placement` sorgusu `422` değil **boş liste**
döndürür.

`severity` (`info` \| `warning` \| `critical`) tonu, `dismissible`
kapatılabilirliği söyler ve **ikisi ayrıdır**: kritik ama bir kez okunması
yeten duyurular var ("yarın servis yok"). `dismissible: false` duyuruyu
kapatma isteği `422` alır — hizmet kesintisi duyurusunu ilk dokunuşta yok
etmek olurdu.

İki işaret ucu da **idempotenttir**: tekrar çağrılmaları hata değildir.

### 15.6 `POST /api/client-errors` — istemci hata bildirimi

İstemcinin yakalayamadığı hataları sunucuya boşaltır. Kimlik
**opsiyoneldir**: token varsa rapor müşteriye bağlanır, yoksa da kabul edilir.
Hataların önemli bir kısmı tam da oturum açılamadığı için doğuyor ve orada
token istemek, en çok ihtiyaç duyulan kaydı kaybettirirdi.

Gövde (`ClientErrorReport`): `message` (zorunlu), `kind`, `stack`, `route`,
`occurred_at`, `app_build`, `device`, `context`.

> **`source` alanı gövdede BULUNMAZ.** Raporun hangi uygulamadan geldiğini
> sunucu **`X-App-Id` başlığından türetir**. Gövdeye bırakılsaydı web sitesi
> `mutfakapp` yazan bir rapor üretebilir ve mutfağın güvendiği hata
> monitörüne **sahte KDS alarmı** düşürebilirdi — o monitör sahada "kasada
> bir sorun var mı" sorusunun tek cevabı; zehirlendiğinde mutfak kör kalır.
> Gövdede `source` gönderilirse **sessizce yok sayılır**, istek reddedilmez.

**Yanıt her zaman `204`'tür** — doğrulama hatası bile dönmez. Bu ucun bir
hata döndürmesi, hata bildirmeye çalışan istemcinin ikinci bir hata üretmesi
demek olur ve kendini besleyen bir döngü doğar. Ayrıştırılamayan alanlar boş
bırakılır, sınırı aşan metin kesilir, rapor yine kaydedilir. Oran sınırına
takılan istek de **sessizce düşer**; istemci `429` yüzünden yeni bir hata
raporu üretmemelidir.

`context` içine **kişisel veri ve sır konmaz** — token, parola, kart bilgisi
ya da tam adres gönderen istemci hata raporunu bir sızıntı kanalına çevirir.
`route` sorgu dizesi olmadan gönderilir: adres çubuğundaki parametreler zaman
zaman kişisel veri taşır ve hata kaydı onları saklamak için yanlış yerdir.

### 15.7 Stok aritmetiği — `docs/contract/sales-rules.cases.json`

Sepete eklenebilecek azami adet ve stok bandı **üç ayrı dilde** hesaplanıyor:
`packages/core` (Dart), `website` (TypeScript), `platform` (PHP). Aynı kuralı
üç kez yazmak, üç farklı kenar durum davranışı demektir; sahada ortaya çıkan
hâli "web sitesinde 3 eklenebiliyor, uygulamada 2" olur.

`docs/contract/sales-rules.cases.json` o kuralın **normatif kaynağıdır** ve
üç test onu okur (`packages/core`, `website/e2e`, `platform/tests/Unit`).
Kural değişirse üçü birden kırılır; tek bir dilde sessizce sapmak mümkün
değildir.

Kapsadığı iki saf fonksiyon:

```
maxAddable({dayRemaining, itemRemaining, alreadyInCartForDay,
            alreadyInCartForItem, hardMax}) -> int
stockLevel({remaining, lowThreshold}) -> 'unlimited'|'plenty'|'low'|'soldOut'
```

Sabitlenen anlamlar:

- **`null` sınırsız demektir, asla sıfır değil.**
- Gün tavanı ile kalem tavanı **`min()` ile birleşir** — kararın "hangisi
  önce dolarsa kapatır" kısmı budur.
- Sepetteki mevcut adet iki tavandan da **ayrı ayrı** düşülür.
- `hardMax` satır başı tavandır (`website/lib/cart.ts` içindeki
  `MAX_QUANTITY = 99`) ve o satırda duran adet ondan da düşülür.
- Sonuç **asla negatif olmaz**: yönetici tavanı sepet doldurulduktan sonra
  indirmiş olabilir; cevap `0`'dır.
- Stok bandı **sepetten bağımsızdır**; ham kalanı anlatır. Eşiğin kendisi
  `low` sayılır.
