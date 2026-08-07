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
    "order_cutoff":"16:00", "min_order_total":25000,
    "delivery_fee":4000,
    "payment_methods":["cash","account","online"],
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
| `order_cutoff` | Günlük son sipariş saati (`HH:mm`, Europe/Istanbul) veya `null`. Admin panelden yönetilir. |
| `min_order_total` | Kuruş. Altında sipariş `422 VALIDATION_FAILED`. |
| `delivery_fee` | Kuruş. `delivery` siparişe eklenir, `pickup`'ta uygulanmaz. İstemci toplamı **onaydan önce** gösterebilsin diye ilan edilir; bağlayıcı olan sunucunun sipariş anındaki hesabıdır. |
| `payment_methods` | Bu vitrinde **açık** olan ödeme yöntemleri. İstemci ödeme ekranında yalnızca bunları gösterir. Listede olmayan bir yöntemle sipariş → `422 VALIDATION_FAILED`. |
| `busy` | Mutfak yoğun mu? Mutfak ekranındaki tek tuşla açılır (`POST /kitchen/busy`). **Sipariş almayı ENGELLEMEZ** — istemci yalnızca `busy_message` uyarısını gösterir, sipariş düğmeleri açık kalır. Siparişi gerçekten kesen şalter `ordering_enabled`'dır ve yalnızca yönetici değiştirir; mutfak personeli tek tuşla cirosu kapatabilmemeli. |
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
| `items` | En az 1 kalem. Ürün menüde/uygun değilse `ITEM_UNAVAILABLE`. |
| `delivery_type` | `delivery` \| `pickup`. |
| `address` | `delivery` ise zorunlu, `pickup` ise yok sayılır. |
| `requested_at` | Opsiyonel; vitrinin `order_cutoff` kuralına takılırsa `LOCATION_CLOSED`. |
| `payment_method` | `online` \| `cash` (kapıda) \| `account` (cari hesap). Vitrinin `payment_methods` listesinde olmayan değer → `VALIDATION_FAILED`. |

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

### POST /api/me/push-token
```json
{ "fcm_token": "cXY...", "platform": "android" }
```
**Yanıt 204.**

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
`customer_phone` **yalnızca fişte** vardır: kurye kapıda kaldığında arayacak
numara elinde olsun diye. `GET /api/kitchen/orders` (KDS kartları) telefon
döndürmez ve döndürmeyecektir — o ekran mutfakta gün boyu açık durur.

**Yanıt 200 (type=musteri)** — ayrıca `items` fiyatlı, `subtotal`, `delivery_fee`, `total`, `payment` ve (`delivery_type=delivery` ise) `address` alanları içerir.

Bu, mutfak kapsamının müşteri adresini görebildiği **tek** uçtur ve yalnızca `type=musteri` içindir; `GET /api/kitchen/orders` adres döndürmez.

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
| `/api/auth/*` | 10 istek / dakika / IP |
| `/api/orders` (POST) | 20 istek / saat / hesap |
| `/api/kitchen/*` | **1200 istek / saat / cihaz** |
| `/api/quote-requests` (POST) | 10 istek / saat / IP |
| Diğer | 120 istek / dakika / IP |

**Mutfak sınırı neden 1200:** doküman önce 600 diyordu ve gerekçesi "5 sn
polling'e yeter" idi — bu aritmetik olarak yanlıştı. 5 saniyelik polling tek
başına saatte **720** istek eder (3600 ÷ 5). Üstüne 60 heartbeat, durum
geçişleri, fiş çekmeleri ve ack'ler biner. 600'lük sınır, KDS'i yoğun serviste
sessizce `429`'a düşürür ve mutfak ekranı donar — sahada teşhisi en zor
arıza türü.

1200, 5 sn polling + heartbeat + yoğun bir servisin durum trafiğini iki kat
payla karşılar. Sınır **cihaz başınadır**, IP başına değil: kasa ve yönetici
çoğu zaman aynı ağdan çıkar ve IP sınırı ikisini birbirine kırdırırdı.

## 11. OpenAPI

Makine tarafından okunabilir sözleşme: **`docs/openapi.yaml`** (OpenAPI 3.1). Bu markdown insan için açıklama, `openapi.yaml` ise **normatif** biçimdir; ikisi çelişirse `openapi.yaml` kazanır.

`packages/api_client` ve `website/lib/api` bu dosyadan üretilir. **Elle yazılan istemci kodu kabul edilmez.**

`platform/` aynı sözleşmeyi `openapi.json` olarak üretir (`php artisan veykemtu:openapi`). CI, üretilen `platform/openapi.json` ile `docs/openapi.yaml` arasında **anlamsal fark** olup olmadığını kontrol eder; fark varsa build kırmızıdır. Sunucu sözleşmeden sapamaz.
