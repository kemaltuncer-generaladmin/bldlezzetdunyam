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
    "busy_message":"Mutfağımız şu anda yoğun. Siparişiniz alınır ancak hazırlanması normalden uzun sürebilir." }
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
  "customer_note": "Fatura kurumsal",
  "printed_at": null
}
```
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

## 6. Sürüm ucu

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

## 7. WebSocket (Faz 1.5)

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

## 8. Oran sınırları

| Uç grubu | Sınır |
|---|---|
| `/api/auth/*` | 10 istek / dakika / IP |
| `/api/orders` (POST) | 20 istek / saat / hesap |
| `/api/kitchen/*` | **1200 istek / saat / cihaz** |
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

## 9. OpenAPI

Makine tarafından okunabilir sözleşme: **`docs/openapi.yaml`** (OpenAPI 3.1). Bu markdown insan için açıklama, `openapi.yaml` ise **normatif** biçimdir; ikisi çelişirse `openapi.yaml` kazanır.

`packages/api_client` ve `website/lib/api` bu dosyadan üretilir. **Elle yazılan istemci kodu kabul edilmez.**

`platform/` aynı sözleşmeyi `openapi.json` olarak üretir (`php artisan veykemtu:openapi`). CI, üretilen `platform/openapi.json` ile `docs/openapi.yaml` arasında **anlamsal fark** olup olmadığını kontrol eder; fark varsa build kırmızıdır. Sunucu sözleşmeden sapamaz.
