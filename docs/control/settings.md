# `control/settings` — Satış ayarları

Yol öneki: **`/api/control/settings`** · Sınır: `bld-control-panel` ·
Ortak kurallar: `00-genel.md`

Satışı açan, kapatan ve kurallarını belirleyen tek yer. Değerler
TastyIgniter'ın kendi `location_options` tablosunda yaşar; okuma ve yazmanın
tek geçidi `Services\LocationGate`'tir.

Kapalı günler ayrı tablodadır: `veykemtu_closed_days` (`Models\ClosedDay`).

---

## Uçlar

| Metot | Yol | Amaç | İzin | dry_run | Gerekçe |
|---|---|---|---|---|---|
| GET | `/sales` | Tüm satış ayarları | `bld_sales.view` | — | — |
| PUT | `/sales` | Ayarları yaz (**kısmi**) | `bld_sales.manage` | ✔ | ✔ |
| POST | `/ordering/pause` | Satışı durdur | `bld_sales.manage` | ✔ | ✔ |
| POST | `/ordering/resume` | Satışı aç | `bld_sales.manage` | ✔ | ✔ |
| GET | `/closed-days` | Kapalı gün listesi | `bld_sales.view` | — | — |
| POST | `/closed-days` | Kapalı gün ekle | `bld_sales.manage` | ✔ | ✔ |
| DELETE | `/closed-days/{date}` | Kapalı günü kaldır | `bld_sales.manage` | ✔ | ✔ |

Hepsinde isteğe bağlı `location_id`; verilmezse varsayılan vitrin.
Kapalı günler **global**'dir (tabloda `location_id` yok) ve `location_id`
parametresi orada yok sayılır.

---

## `GET /sales`

```json
{
  "data": {
    "location_id": 1,
    "location_name": "BLD Merkez Mutfak",

    "ordering_enabled": true,
    "paused_until": null,
    "pause_reason": null,
    "is_open": true,

    "order_cutoff": "08:00",
    "max_lookahead_days": 7,
    "subscription_release_time": "07:00",

    "min_order_total_kurus": 15000,
    "delivery_fee_kurus": 2500,
    "payment_methods": ["online", "cash"],

    "busy": false,
    "busy_message": "Mutfağımız şu anda yoğun. Siparişiniz alınır ancak hazırlanması normalden uzun sürebilir.",

    "prep_minutes": 40,
    "delivery_minutes": 20,
    "busy_extra_minutes": 15,

    "daily_menu_enabled": true,
    "daily_package_menu_id": 88,
    "auto_invoice": false
  },
  "meta": {
    "available_payment_methods": ["online", "cash"],
    "defaults": {
      "busy_message": "Mutfağımız şu anda yoğun. Siparişiniz alınır ancak hazırlanması normalden uzun sürebilir.",
      "max_lookahead_days": 7,
      "prep_minutes": 40,
      "delivery_minutes": 20,
      "busy_extra_minutes": 15,
      "subscription_release_time": "07:00"
    }
  },
  "server_time": "2026-08-16T09:00:00Z"
}
```

`meta.defaults`, yönetici alanı boşalttığında hangi değerin geçerli olacağını
söyler. Panel bu değerleri gri "ipucu" metni olarak gösterir; istemcinin kendi
varsayılanını gömmesi, sunucu varsayılanı değiştiğinde iki farklı gerçek
üretirdi.

### Alanlar

| Alan | Tip | `location_options` anahtarı | Not |
|---|---|---|---|
| `ordering_enabled` | bool | `bld_ordering_enabled` | Ana şalter |
| `paused_until` | ISO 8601 UTC\|null | `bld_ordering_paused_until` | `null` = süresiz veya açık |
| `pause_reason` | string\|null | `bld_ordering_pause_reason` | Müşteriye gösterilir |
| `is_open` | bool | *türetilir* | Çalışma saatlerinden; **yazılamaz** |
| `order_cutoff` | `HH:mm`\|null | `bld_order_cutoff` | **Genel** sabah kesim saati |
| `max_lookahead_days` | int | `bld_max_lookahead_days` | 0–7 |
| `subscription_release_time` | `HH:mm` | `bld_subscription_release_time` **(yeni)** | Abonelik siparişlerinin KDS'e düşme saati |
| `min_order_total_kurus` | int | `bld_min_order_total` | Kuruş |
| `delivery_fee_kurus` | int | `bld_delivery_fee` | Kuruş; gel-al'da uygulanmaz |
| `payment_methods` | list\<string\> | `bld_payment_methods` | Yalnız `online` ve `cash` |
| `busy` | bool | `bld_busy` | Satışı **kesmez**, uyarı gösterir |
| `busy_message` | string | `bld_busy_message` | Boş = varsayılan |
| `prep_minutes` | int | `bld_prep_minutes` | 1–480 |
| `delivery_minutes` | int | `bld_delivery_minutes` | 1–480 |
| `busy_extra_minutes` | int | `bld_busy_extra_minutes` | 1–480 |
| `daily_menu_enabled` | bool | `bld_daily_menu_enabled` | Günün menüsü rejimi |
| `daily_package_menu_id` | int\|null | `bld_daily_package_menu_id` | **Salt okunur**; göç yazar |
| `auto_invoice` | bool | `bld_auto_invoice` **(yeni)** | Teslimde fatura belgesi otomatik üretilsin mi |

> **BAŞKA AJANIN KULVARI.** İki yeni `location_options` anahtarı ve
> `LocationGate` erişimcileri gerekiyor: `bld_subscription_release_time`
> (`HH:mm`, varsayılan `"07:00"`) ve `bld_auto_invoice` (bool, varsayılan
> `false`).

> **BAŞKA AJANIN KULVARI.** `LocationGate::ALL_PAYMENT_METHODS` bugün
> `['online','cash','account']`. Cari hesap kalktığı için (iş kararı 1) liste
> `['online','cash']` olmalı ve `DEFAULT_PAYMENT_METHODS` `['cash']`'e
> düşmeli. Bu sözleşme `account` değerini **kabul etmez**; gönderilirse `422`.

> KARAR: `max_lookahead_days` tavanı **7**'dir (iş kararı 3). `LocationGate`
> bugün 30 varsayıyor; bu uç 7'nin üstünü `422` ile reddeder ve varsayılanı 7
> bildirir. Sunucu sabitini değiştirmek başka ajanın kulvarı, ama sözleşme
> bugünden 7 diyor — daha büyük bir değerin panelden girilebilmesi, kararın
> sessizce delinmesi olurdu.

### İki kesim saati vardır ve karıştırılmamalı

- **Genel kesim saati** (`order_cutoff`): hangi güne sipariş verilirse verilsin
  geçerli olan varsayılan.
- **Gün bazlı kesim saati** (`menu.md` → `DailyMenuDay.cutoff_time`): o servis
  gününe özel. Doluysa **genel olanı ezer**.

İş kararı 3 "her servis günü kendi sabah kesim saatinde kapanır" diyor; gün
bazlı alan bunu mümkün kılar, genel alan ise her güne tek tek saat girmek
zorunda kalmamak içindir. Sunucu tarafında birleştirme kuralı tektir:
`gün.cutoff_time ?? ayar.order_cutoff`.

---

## `PUT /sales`

**Kısmi yazar.** Gönderilmeyen alan değişmez. `PUT` adı seçildi çünkü niyet
"ayar tablosunun bu alanları şu hâle gelsin"dir; `PATCH` ile aralarında
davranış farkı yoktur ve tek bir metot tanımlamak, iki metodu farklı sanan bir
istemci yazılmasını önler.

`is_open` ve `daily_package_menu_id` **yazılamaz**; gönderilirse `422`
(`details.field`). İlki çalışma saatlerinden türer, ikincisini göç yazar ve
yanlış bir kimlik günün menüsünü sıfır liraya sattırır.

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Kesim saati 08:00'e çekildi, ileri sipariş 7 güne indirildi",
  "dry_run": false,
  "order_cutoff": "08:00",
  "max_lookahead_days": 7,
  "payment_methods": ["online", "cash"],
  "min_order_total_kurus": 15000
}
```

Doğrulama:

- `order_cutoff`: `HH:mm` (`^([01]\d|2[0-3]):[0-5]\d$`) ya da `null` (kesim
  saati yok). Başka biçim → `422`.
- `subscription_release_time`: aynı biçim, `null` **kabul edilmez** — abonelik
  siparişlerinin KDS'e düşmediği bir yapılandırma, mutfağın sabah boş ekrana
  bakması demektir.
- `max_lookahead_days`: `0`–`7`. Sıfır geçerlidir ("yalnız bugüne sipariş").
- `payment_methods`: boş olamaz; yalnız `online` ve `cash`; tekrar yok.
  Boş liste, hiçbir ödeme yöntemi olmayan bir satış kanalı demekti.
- `min_order_total_kurus`, `delivery_fee_kurus`: `>= 0` tam sayı kuruş.
- `prep_minutes`, `delivery_minutes`, `busy_extra_minutes`: 1–480.
  `LocationGate` bugün aralık dışını **sessizce varsayılana çeviriyor**; bu uç
  **reddeder**. Sessizce düzeltilen bir ayar, yöneticinin girdiğini sandığı
  değerle çalışmadığını hiç öğrenmemesi demektir.
- `busy_message`: `null` ya da boş dize → varsayılana döner. En çok 500 karakter.
- `ordering_enabled` **burada yazılamaz**; kendi uçları var (`/ordering/pause`,
  `/ordering/resume`). Şalteri gerekçesiz ve süresiz çevirmek, tam da
  durdurmanın en sık hatasını (açmayı unutmak) üretirdi.

Yanıt:

```json
{
  "ok": true,
  "dry_run": false,
  "audit_id": 1701,
  "data": { },
  "changed": ["order_cutoff", "max_lookahead_days", "min_order_total_kurus"]
}
```

`data` = tam `GET /sales` gövdesindeki `data`. `changed` yalnız **gerçekten
değişen** alanları listeler; aynı değeri yeniden yazmak listede görünmez ve
denetim izine "değişiklik yok" olarak düşer.

Kuru prova `would` eski ve yeni değeri **yan yana** verir — asıl işi budur:

```json
{
  "action": "settings.sales",
  "changes": [
    { "field": "order_cutoff", "from": "09:30", "to": "08:00" },
    { "field": "max_lookahead_days", "from": 30, "to": 7 }
  ]
}
```

---

## `POST /ordering/pause`

Satışı durdurur. `busy` ile karıştırılmamalı: `busy` yalnız uyarır, bu **satışı
gerçekten keser**.

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Buzdolabı arızası, öğleden sonra satış durduruldu",
  "dry_run": false,
  "until": "2026-08-16T15:00:00Z",
  "customer_message": "Teknik bir arıza nedeniyle bugün 18:00'e kadar sipariş alamıyoruz."
}
```

- `until`: ISO 8601 UTC ya da `null`. `null` = **süresiz** (elle açılana kadar).
- `until` geçmişte olamaz → `422`. En fazla 30 gün ileri → `422`; daha uzun bir
  durdurma "süreli" değil, kapanıştır ve `null` ile ifade edilmelidir.
- `customer_message`: müşteriye gösterilir, en çok 300 karakter. Boş bırakılırsa
  `pause_reason` `null` olur ve istemciler kendi genel metnini gösterir.
  **`reason` müşteriye gösterilmez** — o denetim izi içindir ve "buzdolabı
  arızası" cümlesi müşteriye söylenecek şey değildir. İkisinin ayrı olması
  bilinçlidir.

Süre dolduğunda satış **kendiliğinden açılır**; arka planda bir iş yoktur,
`LocationGate::orderingEnabled()` okuma anında karşılaştırır. Zamanlayıcıya
bağlamak, zamanlayıcının çalışmadığı her durumda dükkânın kapalı kalması
olurdu.

```json
{
  "ok": true, "dry_run": false, "audit_id": 1710,
  "data": {
    "ordering_enabled": false,
    "paused_until": "2026-08-16T15:00:00Z",
    "pause_reason": "Teknik bir arıza nedeniyle bugün 18:00'e kadar sipariş alamıyoruz."
  }
}
```

Zaten durdurulmuşsa yeni `until` ve mesaj **üzerine yazılır**, `409` verilmez:
süreyi uzatmak olağan bir eylemdir.

## `POST /ordering/resume`

```json
{ "actor": "Ayşe Yılmaz", "reason": "Arıza giderildi, satış yeniden açıldı" }
```

Durdurma izlerini (`paused_until`, `pause_reason`) temizler.

```json
{
  "ok": true, "dry_run": false, "audit_id": 1711,
  "data": { "ordering_enabled": true, "paused_until": null, "pause_reason": null }
}
```

Zaten açıksa `ok: true` döner. İşlem sonuç odaklıdır.

---

## Kapalı günler

Resmî tatil ve planlı kapanış. **Global**: bütün vitrinler için geçerli.
Abonelik üretimi bu günleri atlar (`SubscriptionGenerateCommand`) ve günlük
menü takvimi `closed_day` gerekçesiyle sipariş almaz.

### `GET /closed-days`

Sorgu: `from`, `to` (`YYYY-MM-DD`, ikisi de opsiyonel). Verilmezse **bugünden
itibaren 365 gün**. Geçmiş kapalı günleri varsayılan olarak döndürmek, listeyi
her yıl biraz daha uzatırdı.

```json
{
  "data": [
    { "id": 12, "date": "2026-08-30", "description": "30 Ağustos Zafer Bayramı" },
    { "id": 13, "date": "2026-10-29", "description": "29 Ekim Cumhuriyet Bayramı" }
  ],
  "meta": { "from": "2026-08-16", "to": "2027-08-16" },
  "server_time": "2026-08-16T09:00:00Z"
}
```

Sayfalanmaz — bir yılda en çok birkaç düzine gün olur.

### `POST /closed-days`

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Resmî tatil takvimi girildi",
  "date": "2026-08-30",
  "description": "30 Ağustos Zafer Bayramı"
}
```

- Aynı tarih varsa → `409 CONFLICT` (`veykemtu_closed_day_essiz`).
- Geçmiş tarih **kabul edilir**: yönetici geçmiş bir günü sonradan kapalı
  işaretleyebilmeli (rapor tutarlılığı). Ancak o güne ait sipariş varsa yanıt
  `warnings` taşır ve engel çıkmaz.
- `description` en çok 160 karakter (kolon sınırı), `null` olabilir.

```json
{
  "ok": true, "dry_run": false, "audit_id": 1720,
  "data": { "id": 12, "date": "2026-08-30", "description": "30 Ağustos Zafer Bayramı" },
  "warnings": []
}
```

### `DELETE /closed-days/{date}`

Yol parçası **tarihtir**, kimlik değil: `closed_on` tekil ve yönetici takvimden
bir güne tıklıyor.

```json
{ "actor": "Ayşe Yılmaz", "reason": "Tatil iptal edildi, o gün çalışılacak" }
```

```json
{ "ok": true, "dry_run": false, "audit_id": 1721, "data": { "deleted": true, "date": "2026-08-30" } }
```

Gün kayıtlı değilse `404 NOT_FOUND`. Burada "zaten öyle" hoşgörüsü
uygulanmıyor: var olmayan bir tatili silmeye çalışan yönetici muhtemelen yanlış
tarihe bakıyor ve bunu bilmeli.

Silme **gerçek silmedir** (satır kalkar). Kapalı gün bir belge değil, bir
kuraldır; iptal edilmiş bir kuralın "iptal edilmiş" hâlini saklamak, üretim
sorgularının her seferinde bir bayrak daha kontrol etmesi demekti. Kaydın
tarihçesi denetim izindedir.

---

## Denetim eylemleri

| `action` | Uç | `target_type` / `target_id` |
|---|---|---|
| `settings.sales` | `PUT /sales` | `settings` / `location_id` |
| `settings.ordering.pause` | `POST /ordering/pause` | `settings` / `location_id` |
| `settings.ordering.resume` | `POST /ordering/resume` | `settings` / `location_id` |
| `settings.closed_day.create` | `POST /closed-days` | `closed_day` / yeni id |
| `settings.closed_day.delete` | `DELETE /closed-days/{date}` | `closed_day` / silinen id |

`settings.sales` satırının `payload_json`'ı `changes` dizisini taşır
(`[{field, from, to}]`). "Kesim saati ne zaman değişti ve kim değiştirdi"
sorusunun cevabı yalnızca burada bulunur — `location_options` tablosu geçmiş
tutmaz.
