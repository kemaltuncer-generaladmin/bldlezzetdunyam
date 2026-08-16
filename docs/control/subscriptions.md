# `control/subscriptions` — Abonelik, talep, sözleşme, ödeme

Yol öneki: **`/api/control/subscriptions`** · Sınır: `bld-control-panel` ·
Ortak kurallar: `00-genel.md`

Abonelik bir sipariş **değil**, sipariş üreten kuraldır. Gece işi
`runsOnDate()` true olan her (abonelik × teslimat noktası) için o günün
siparişini üretir; kural sonradan değişse bile üretilmiş sipariş değişmez.

Kaynak tablolar: `veykemtu_subscriptions`, `_lines`, `_delivery_points`,
`_pauses`, `_exceptions`, `_runs`, `veykemtu_quote_requests` ve iki **yeni**
tablo: `veykemtu_subscription_contracts`, `veykemtu_subscription_payments`.

---

## Rota sırası — kırılgan nokta

Sabit parçalı yollar `{id}` **önünde** kaydedilmelidir. Aksi hâlde `requests`,
`contracts`, `payments` ve `orders` birer kimlik sanılır ve `404` döner. Sıra:

```
GET|POST   subscriptions/requests …
GET|POST   subscriptions/contracts/{contract} …
POST       subscriptions/payments/{payment}/mark-paid
POST       subscriptions/orders/{order}/release
GET|POST   subscriptions/{subscription} …
```

Aynı tuzak `AddressController`'da bir kez yaşandı ve orada da yorumla
işaretlendi.

---

## Uçlar

### Abonelik

| Metot | Yol | Amaç | İzin | dry_run | Gerekçe |
|---|---|---|---|---|---|
| GET | `/` | Liste (**sayfalı**) | `bld_subs.view` | — | — |
| GET | `/{id}` | Tek abonelik | `bld_subs.view` | — | — |
| POST | `/` | Yeni abonelik | `bld_subs.manage` | ✔ | ✔ |
| PATCH | `/{id}` | Kural güncelle | `bld_subs.manage` | ✔ | ✔ |
| POST | `/{id}/activate` | Talebi/duraklamayı aktifleştir | `bld_subs.manage` | ✔ | ✔ |
| POST | `/{id}/pause` | Aralıklı duraklat | `bld_subs.manage` | ✔ | ✔ |
| POST | `/{id}/resume` | Duraklamayı bitir | `bld_subs.manage` | ✔ | ✔ |
| POST | `/{id}/cancel` | İptal (geri dönüşsüz) | `bld_subs.manage` | ✔ | ✔ |
| GET | `/{id}/calendar` | Önümüzdeki servis günleri | `bld_subs.view` | — | — |
| POST | `/{id}/exceptions` | Tek-gün istisnası | `bld_subs.manage` | ✔ | ✔ |
| DELETE | `/{id}/exceptions/{date}` | İstisnayı kaldır | `bld_subs.manage` | ✔ | ✔ |
| GET | `/{id}/runs` | Üretim defteri (**sayfalı**) | `bld_subs.view` | — | — |
| POST | `/{id}/generate` | Belirli gün için elle üret | `bld_subs.manage` | ✔ | ✔ |
| POST | `/orders/{order}/release` | Üretilmiş siparişi KDS'e düşür | `bld_subs.manage` | ✔ | ✔ |

### Talepler (teklif formu)

| Metot | Yol | Amaç | İzin | dry_run | Gerekçe |
|---|---|---|---|---|---|
| GET | `/requests` | Talep listesi (**sayfalı**) | `bld_subs.view` | — | — |
| GET | `/requests/{id}` | Tek talep | `bld_subs.view` | — | — |
| PATCH | `/requests/{id}` | Durum + iç not | `bld_subs.manage` | ✔ | ✔ |
| POST | `/requests/{id}/convert` | Talebi aboneliğe çevir | `bld_subs.manage` | ✔ | ✔ |

### Sözleşmeler

| Metot | Yol | Amaç | İzin | dry_run | Gerekçe |
|---|---|---|---|---|---|
| GET | `/{id}/contracts` | Aboneliğin sözleşmeleri | `bld_subs.view` | — | — |
| POST | `/{id}/contracts` | Sözleşme oluştur + link gönder | `bld_subs.manage` | ✔ | ✔ |
| GET | `/contracts/{contract}` | Tek sözleşme | `bld_subs.view` | — | — |
| POST | `/contracts/{contract}/resend` | Linki yeniden gönder | `bld_subs.manage` | ✔ | ✔ |
| POST | `/contracts/{contract}/cancel` | Sözleşmeyi iptal et | `bld_subs.manage` | ✔ | ✔ |

### Ödemeler

| Metot | Yol | Amaç | İzin | dry_run | Gerekçe |
|---|---|---|---|---|---|
| GET | `/{id}/payments` | Dönem ödemeleri | `bld_subs.view` | — | — |
| POST | `/{id}/payments` | Dönem borcu oluştur | `bld_subs.manage` | ✔ | ✔ |
| POST | `/payments/{payment}/mark-paid` | Tahsil edildi işaretle | `bld_subs.manage` | ✔ | ✔ |

---

## Şema — Abonelik

| Alan | Tip | Kaynak kolon | Not |
|---|---|---|---|
| `id` | int | `id` | |
| `customer_id` | int | `customer_id` | |
| `customer_label` | string | *türetilir* | Kurum adı veya ad soyad |
| `location_id` | int | `location_id` | |
| `status` | `pending`\|`active`\|`paused`\|`cancelled` | `status` | |
| `start_date` | `YYYY-MM-DD` | `start_date` | |
| `end_date` | `YYYY-MM-DD`\|null | `end_date` | `null` = süresiz |
| `delivery_type` | `delivery`\|`pickup` | `delivery_type` | |
| `delivery_time_from` | `HH:mm`\|null | `delivery_time_from` | |
| `delivery_time_to` | `HH:mm`\|null | `delivery_time_to` | |
| `service_days` | list\<int\> | `service_days` | ISO 1–7 |
| `menu_mode` | `fixed_list`\|`daily_menu` | `menu_mode` | |
| `default_quantity` | int | `default_quantity` | |
| `agreed_unit_price_kurus` | int\|null | `agreed_unit_price_kurus` | `pending`'de `null` |
| `payment_mode` | `prepaid_monthly` | `payment_mode` | Aşağıya bakın |
| `lines` | list\<Line\> | `veykemtu_subscription_lines` | |
| `delivery_points` | list\<Point\> | `..._delivery_points` | |
| `pauses` | list\<Pause\> | `..._pauses` | |
| `exceptions` | list\<Exception\> | `..._exceptions` | |
| `contract` | Contract\|null | *en son* | `signed` olan varsa o |
| `created_at` / `updated_at` | ISO 8601 UTC | | |

Alt kayıtlar — dördü de abonelik gövdesindeki kendi dizisinin elemanıdır:

`lines[]` (`veykemtu_subscription_lines`)

```json
{ "id": 51, "menu_id": 27, "quantity": 3, "agreed_unit_price_kurus": 9000, "label": "Vejetaryen" }
```

`delivery_points[]` (`veykemtu_subscription_delivery_points`)

```json
{ "id": 9, "address_id": 704, "quantity": 20, "note": "Arka kapı" }
```

`pauses[]` (`veykemtu_subscription_pauses`)

```json
{ "id": 3, "start_date": "2026-09-01", "end_date": "2026-09-07", "reason": "Kurum tatili" }
```

`exceptions[]` (`veykemtu_subscription_exceptions`)

```json
{ "id": 77, "service_date": "2026-08-20", "skip": false, "quantity_override": 12, "note": "Toplantı" }
```

> KARAR: `payment_mode` **yalnız `prepaid_monthly`** kabul eder. Cari hesap
> tamamen kalktığı için (iş kararı 1) `account` değeri artık ödeme yöntemi
> değildir; gönderilirse `422 VALIDATION_FAILED`,
> `details = {"field": "payment_mode", "allowed": ["prepaid_monthly"]}`.
> Kolon ve sabit yerinde kalıyor (şema kırılmıyor); değişen yalnız kabul edilen
> değer kümesi.

> KARAR: `menu_mode` varsayılanı **`daily_menu`**'dür (iş kararı 8: abonelik =
> günün menüsü otomatik). `fixed_list` hâlâ geçerli — bazı kurumlar sabit bir
> liste istiyor — ama panel varsayılan olarak günün menüsünü seçer.

---

## `GET /` — liste

Sorgu: `status` (virgüllü), `customer_id`, `q` (kurum/ad/telefon),
`service_day` (1–7), `active_on` (`YYYY-MM-DD` — o gün üretim yapacaklar),
`page`, `per_page`.

```json
{
  "data": [
    {
      "id": 18,
      "customer_id": 312,
      "customer_label": "Acme Gıda A.Ş.",
      "status": "active",
      "start_date": "2026-08-01",
      "end_date": null,
      "service_days": [1, 2, 3, 4, 5],
      "menu_mode": "daily_menu",
      "default_quantity": 20,
      "agreed_unit_price_kurus": 16000,
      "payment_mode": "prepaid_monthly",
      "delivery_point_count": 1,
      "contract_status": "signed",
      "next_service_date": "2026-08-17",
      "unpaid_periods": 1,
      "unpaid_total_kurus": 640000
    }
  ],
  "meta": { "page": 1, "per_page": 25, "total": 9, "last_page": 1 },
  "server_time": "2026-08-16T09:00:00Z"
}
```

`unpaid_periods` ve `unpaid_total_kurus` **listede vardır** çünkü bu ekranın
asıl sorusu "kim ödemedi"dir; her satır için ayrı bir ödeme çağrısı yapmak
dokuz abonelikte dokuz istek demekti.

`contract_status` değerleri: `none` · `pending` · `sent` · `signed` ·
`cancelled` · `expired`.

---

## `POST /` — yeni abonelik

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Acme Gıda ile aylık abonelik anlaşması yapıldı",
  "dry_run": false,
  "customer_id": 312,
  "location_id": 1,
  "start_date": "2026-09-01",
  "end_date": null,
  "delivery_type": "delivery",
  "delivery_time_from": "11:30",
  "delivery_time_to": "12:30",
  "service_days": [1, 2, 3, 4, 5],
  "menu_mode": "daily_menu",
  "default_quantity": 20,
  "agreed_unit_price_kurus": 16000,
  "payment_mode": "prepaid_monthly",
  "lines": [],
  "delivery_points": [ { "address_id": 704, "quantity": 20, "note": null } ]
}
```

- Abonelik **`pending` doğar.** Fiyatı ve sözleşmesi tamamlanmadan üretim
  yapmamalı; aktifleştirme ayrı bir eylemdir ve ayrı bir denetim satırı bırakır.
- `service_days` boş olamaz; 1–7 arası, tekrarsız.
- `menu_mode = fixed_list` iken `lines` **boş olamaz** → `422`. Sabit liste
  seçip liste vermemek, hiçbir şey üretmeyen bir kural yaratırdı.
- `menu_mode = daily_menu` iken `lines` **gönderilemez** → `422`. Menü o günün
  yayınlanmış menüsünden gelir.
- `delivery_type = delivery` iken en az bir `delivery_points` → `422`.
- `address_id` müşterinin adres defterinde olmalı → `422`.
  `details = {"field": "delivery_points.0.address_id"}`.
- `agreed_unit_price_kurus` `null` bırakılabilir (fiyat sonra girilir) ama
  `activate` onu **zorunlu** kılar.
- `end_date` verilirse `start_date`'ten sonra olmalı.

Yanıt `201`, `data` = tam abonelik.

Kuru prova `would`:

```json
{
  "action": "subscription.create",
  "customer_id": 312,
  "service_days": [1,2,3,4,5],
  "first_service_dates": ["2026-09-01","2026-09-02","2026-09-03"],
  "monthly_estimate_kurus": 7040000
}
```

`first_service_dates` ilk üç üretim gününü gösterir ve kuru provanın asıl
faydası budur: yönetici kuralın gerçekten hangi günleri ürettiğini kaydetmeden
görür.

---

## `PATCH /{id}`

Kısmi. Yazılabilir: `end_date`, `delivery_type`, `delivery_time_from`,
`delivery_time_to`, `service_days`, `menu_mode`, `default_quantity`,
`agreed_unit_price_kurus`, `lines`, `delivery_points`.

`customer_id`, `location_id`, `start_date` ve `status` **yazılamaz**. Müşteriyi
değiştirmek yeni abonelik açmaktır; durum kendi uçlarındadır.

`lines` ve `delivery_points` gönderilirse **tam listedir** (menü kalemlerinde
olduğu gibi). `id` taşıyan satır güncellenir, taşımayan eklenir, listede
olmayan silinir.

`cancelled` bir aboneliğe `PATCH` → `409 CONFLICT`. İptal geri dönüşsüzdür.

Kural değişikliği **üretilmiş siparişleri etkilemez.** Yarın için sipariş zaten
üretildiyse bugün adedi değiştirmek onu değiştirmez; o işi `orders.md` →
revizyon yapar. Yanıt bunu `warnings` ile söyler:

```json
{
  "ok": true, "dry_run": false, "audit_id": 1901,
  "data": { },
  "warnings": [
    { "code": "generated_orders_unaffected", "dates": ["2026-08-17"], "order_ids": [8455] }
  ]
}
```

---

## Durum uçları

| Uç | Kaynak durum | Hedef | Ek gövde |
|---|---|---|---|
| `activate` | `pending`, `paused` | `active` | — |
| `pause` | `active` | `paused` | `start_date`, `end_date`, `pause_reason` |
| `resume` | `paused` | `active` | — |
| `cancel` | `pending`, `active`, `paused` | `cancelled` | `effective_date` |

### `POST /{id}/activate`

```json
{ "actor": "Ayşe Yılmaz", "reason": "Sözleşme imzalandı, abonelik aktifleştirildi" }
```

Ön denetimler (kuru provada da koşar):

- `agreed_unit_price_kurus` **dolu olmalı** → `422`. Fiyatsız bir abonelik
  sipariş üretir ve o siparişin tutarı sıfır olurdu.
- **İmzalı sözleşme olmalı** → yoksa `422 VALIDATION_FAILED`,
  `details = {"reason": "contract_not_signed", "contract_status": "sent"}`.
  İş kararı 9 sözleşmeyi zorunlu kılıyor.
- `end_date` geçmişte kalmışsa → `422`.

```json
{
  "ok": true, "dry_run": false, "audit_id": 1910,
  "data": { "id": 18, "status": "active", "next_service_date": "2026-09-01" }
}
```

### `POST /{id}/pause`

Duraklatma **iptal değildir**: aralık boyunca üretim durur, sonra aynı fiyatla
devam eder. `veykemtu_subscription_pauses` satırı yazılır; abonelik durumu
`paused` olur.

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Kurum yıllık izinde, iki hafta duraklatıldı",
  "start_date": "2026-09-01",
  "end_date": "2026-09-14",
  "pause_reason": "Kurum tatili"
}
```

- `start_date` bugünden geriye alınamaz → `422`. Geçmiş bir günü duraklatmak,
  üretilmiş siparişi silmez ve yalnız raporu bozar.
- Aralık mevcut bir duraklamayla çakışırsa → `409 CONFLICT`.
- `end_date` `null` **kabul edilmez**: süresiz duraklatma, iptalin adı
  konmamış hâlidir. Süresiz durdurmak isteyen `cancel` kullanır.

**Aralıktaki üretilmiş siparişler otomatik iptal edilmez.** Yanıt onları
listeler ve yönetici tek tek karar verir:

```json
{
  "ok": true, "dry_run": false, "audit_id": 1911,
  "data": { "id": 18, "status": "paused", "pause": { "id": 4, "start_date": "2026-09-01", "end_date": "2026-09-14" } },
  "warnings": [
    { "code": "generated_orders_in_range", "order_ids": [8501, 8502], "dates": ["2026-09-01","2026-09-02"] }
  ]
}
```

### `POST /{id}/resume`

Açık duraklamayı **bugün itibarıyla kapatır** (`end_date = dün`) ve durumu
`active` yapar. Satırı silmez: "ne zaman duraklatıldı, ne zaman devam edildi"
sorusunun cevabı kalmalı.

### `POST /{id}/cancel`

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Kurum sözleşmeyi yenilemedi, abonelik sonlandırıldı",
  "effective_date": "2026-08-31"
}
```

- `effective_date` bugünden geriye alınamaz.
- `end_date` o güne yazılır ve `status = cancelled` olur.
- **Geri dönüşü yoktur.** Yeniden başlatmak yeni abonelik açmaktır; iptal
  edilmiş bir kuralı canlandırmak, iptal tarihinden sonraki günlerin hangi
  kurala tabi olduğunu belirsiz kılardı.
- `effective_date`'ten **sonraki** üretilmiş siparişler `warnings` ile
  listelenir; iptalleri `orders.md` → `POST /{order}/cancel` işidir.

---

## `GET /{id}/calendar`

Önümüzdeki servis günleri. Kaynak `Subscription::upcomingServiceDays()` —
üretim işinin kullandığı metodun ta kendisi. Takvim kendi mantığını yazsaydı
ekranda görünen günler ile gerçekte üretilenler zamanla ayrışırdı ve bu
ayrışmanın fark edileceği yer mutfak olurdu.

Sorgu: `from` (varsayılan bugün), `days` (varsayılan 30, tavan 92).

```json
{
  "data": [
    { "date": "2026-08-17", "weekday": 1, "quantity": 20, "closed": false, "note": null,
      "exception": null, "generated": true, "order_id": 8455, "released_at": "2026-08-17T04:00:00Z" },
    { "date": "2026-08-18", "weekday": 2, "quantity": 12, "closed": false, "note": null,
      "exception": { "skip": false, "quantity_override": 12, "note": "Toplantı" },
      "generated": false, "order_id": null, "released_at": null },
    { "date": "2026-08-30", "weekday": 7, "quantity": 20, "closed": true,
      "note": "30 Ağustos Zafer Bayramı", "exception": null,
      "generated": false, "order_id": null, "released_at": null }
  ],
  "meta": { "from": "2026-08-17", "days": 30, "subscription_id": 18 },
  "server_time": "2026-08-16T09:00:00Z"
}
```

**Yalnız üretim yapılacak günler döner** (`runsOnDate()` true olanlar). Hafta
sonu menü olmadığı için (iş kararı 4) `service_days` beş gün olan bir
abonelikte cumartesi/pazar hiç görünmez. Kapalı günler **görünür ama
`closed: true`** ile — yöneticinin "o gün neden üretim yok" sorusunun cevabı
listede olmalı.

---

## İstisnalar

Tek-günlük istisna: "yarın 20 değil 12" ya da "yarın atla". Kural değişikliği
değildir.

### `POST /{id}/exceptions`

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Kurum 20 Ağustos'ta toplantıda, 12 porsiyon istendi",
  "service_date": "2026-08-20",
  "skip": false,
  "quantity_override": 12,
  "note": "Toplantı"
}
```

- `(subscription_id, service_date)` tekildir; aynı gün için ikinci istisna →
  **üzerine yazılır**, `409` verilmez. Yönetici aynı güne iki kez karar
  verebilir ve son karar geçerlidir. Denetim izinde ikisi de görünür.
- `skip: true` iken `quantity_override` gönderilemez → `422`. "Atla ama 12
  yap" tutarsız.
- `service_date` geçmişte olamaz.
- `service_date` o aboneliğin servis günlerinden biri olmalı → değilse `422`,
  `details = {"reason": "not_a_service_day", "weekday": 6}`. Cumartesiye
  istisna girmek, hiçbir zaman uygulanmayacak bir kayıt yaratırdı.
- **O gün için sipariş zaten üretilmişse** `409 CONFLICT`,
  `details = {"conflict": "already_generated", "order_id": 8455}`. Üretilmiş
  siparişi değiştirmenin yolu revizyondur.

### `DELETE /{id}/exceptions/{date}`

```json
{ "actor": "Ayşe Yılmaz", "reason": "Toplantı iptal oldu, normal adede dönüldü" }
```

Gerçek silme; istisna bir belge değil bir kuraldır. Kayıt yoksa `404`.

---

## Üretim defteri

### `GET /{id}/runs`

`veykemtu_subscription_runs` — idempotency kaydı. Bir (abonelik × nokta × gün)
en fazla bir sipariş; güvence koddaki `if` değil, veritabanı kısıtıdır.

Sorgu: `from`, `to`, `page`, `per_page`.

```json
{
  "data": [
    {
      "id": 2201, "service_date": "2026-08-17", "delivery_point_id": 9,
      "order_id": 8455, "order_number": "BLD-8455", "order_status": "hazirlaniyor",
      "quantity": 20, "released_at": "2026-08-17T04:00:00Z", "created_at": "2026-08-17T00:12:00Z"
    },
    {
      "id": 2202, "service_date": "2026-08-18", "delivery_point_id": 9,
      "order_id": null, "order_number": null, "order_status": null,
      "quantity": 12, "released_at": null, "created_at": "2026-08-18T00:12:00Z"
    }
  ],
  "meta": { "page": 1, "per_page": 25, "total": 42, "last_page": 2 },
  "server_time": "2026-08-16T09:00:00Z"
}
```

`order_id: null` olan bir defter satırı, üretimin **denendiği ama sipariş
oluşmadığı** anlamına gelir (kapalı gün, menü yayınlanmamış, stok dolu). Satır
yine de yazılır ki gece işi ertesi koşuda aynı günü yeniden denemesin ve
"neden sipariş yok" sorusunun bir cevabı olsun.

`delivery_point_id = 0` = noktasız üretim (`null` yerine `0`: MySQL null'ları
tekil saymaz ve idempotency bozulurdu).

### `POST /{id}/generate`

Gece işini beklemeden belirli bir gün için üretim yapar. Kural
`SubscriptionGenerateCommand` ile aynıdır — ayrı bir kopya yazılmaz.

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Gece işi çalışmadı, 17 Ağustos siparişleri elle üretildi",
  "service_date": "2026-08-17",
  "release_now": false
}
```

- `service_date` bugünden en fazla **7 gün** ileri olabilir
  (`max_lookahead_days`) → `422`.
- Abonelik o gün üretim yapmıyorsa (`runsOnDate()` false) → `422`,
  `details = {"reason": "not_a_service_day"}`.
- Defterde satır varsa → `409 CONFLICT`,
  `details = {"conflict": "already_generated", "order_id": 8455}`.
  İdempotency **veritabanı kısıtından** gelir; uç onu 500 yerine 409'a çevirir.
- O günün stok tavanı dolmuşsa → **`422 STOCK_EXCEEDED`**,
  `details = {"scope": "day", "capacity": 120, "sold": 118, "requested": 20}`.
  Abonelikler stoku **önce rezerve eder** (iş kararı 6); elle üretim o
  rezervasyonun dışında kalan bir talep olduğu için tavana takılabilir.
  Yönetici tavanı yükseltir ya da üretimi bilinçli olarak ertesi güne bırakır.
- `release_now: true` üretilen siparişi **anında KDS'e düşürür**; varsayılan
  `false`, yani normal serbest bırakma saati (`subscription_release_time`,
  varsayılan 07:00) geçerlidir.

```json
{
  "ok": true, "dry_run": false, "audit_id": 1930,
  "data": {
    "service_date": "2026-08-17",
    "created": [ { "run_id": 2201, "order_id": 8455, "order_number": "BLD-8455",
                   "delivery_point_id": 9, "quantity": 20, "release_at": "2026-08-17T04:00:00Z" } ],
    "skipped": []
  }
}
```

Kuru prova `would` aynı yapıyı `created` yerine `would_create` ile döner ve
**hiçbir satır yazmaz**.

### `POST /orders/{order}/release`

Abonelik siparişleri gece üretilir ve **KDS'e 07:00'de düşer** (iş kararı 7).
Bu uç, bir siparişi o saatten önce mutfağa açar.

Neden gecikmeli düşüyor: gece 00:12'de üretilen kırk sipariş sabah 05:00'te
işbaşı yapan mutfağın ekranını doldurur ve o an gelen **gerçek** bir siparişi
görünmez kılardı. Serbest bırakma saati, panoyu vardiya başlangıcıyla
hizalar.

```json
{ "actor": "Ayşe Yılmaz", "reason": "Erken teslimat talebi, sipariş mutfağa açıldı" }
```

- Sipariş abonelikten üretilmiş olmalı (`orders.bld_subscription_id` dolu) →
  değilse `422`.
- Zaten serbest bırakılmışsa → `ok: true`, `409` verilmez.

```json
{
  "ok": true, "dry_run": false, "audit_id": 1940,
  "data": { "order_id": 8455, "released_at": "2026-08-16T09:00:00Z", "was_scheduled_for": "2026-08-17T04:00:00Z" }
}
```

> **BAŞKA AJANIN KULVARI — göç gerekiyor.** `orders.bld_kds_release_at`
> (`timestamp`, nullable, indeksli). `null` = beklemesiz (normal sipariş).
> Mutfak sorgusu `bld_kds_release_at IS NULL OR bld_kds_release_at <= NOW()`
> süzgecini eklemeli; aksi hâlde abonelik siparişleri üretildikleri anda
> panoya düşer ve serbest bırakma saati hiçbir işe yaramaz.

---

## Talepler

Kurumsal sitedeki "Teklif Al" formundan gelen kayıtlar
(`veykemtu_quote_requests`). **Kişisel veri taşır**: `full_name`, `telephone`,
`email` KVKK kapsamındadır.

> KARAR: Talep uçları `customers` alanındaki okuma denetimi kuralına **tabi
> değildir**. Bu kayıtlar müşteri değil, henüz iletişime geçilmemiş adaylardır
> ve talep listesi günde birkaç kez açılan bir iş kuyruğudur; her açılışı
> denetlemek izi doldurup asıl erişimleri görünmez kılardı. `full_name` ve
> iletişim bilgisi yine de **listede maskelenir** (aşağıda), yalnız tekil
> kayıtta açılır.

### `GET /requests`

Sorgu: `status` (`yeni`\|`okundu`\|`cevaplandi`\|`kapandi`), `q`,
`from`, `to`, `page`, `per_page`. Varsayılan sıra: en yeni önce.

```json
{
  "data": [
    {
      "id": 88,
      "full_name": "Mehmet K.",
      "organization": "Acme Gıda A.Ş.",
      "telephone": "532****567",
      "email": "m***@acme.com.tr",
      "service_type": "kurumsal-catering",
      "headcount": 20,
      "frequency": "haftalik",
      "start_date": "2026-09-01",
      "location": "Ankara / Çankaya",
      "status": "yeni",
      "converted_subscription_id": null,
      "created_at": "2026-08-14T11:05:00Z"
    }
  ],
  "meta": { "page": 1, "per_page": 25, "total": 31, "last_page": 2 },
  "server_time": "2026-08-16T09:00:00Z"
}
```

Maskeleme kuralı: soyadın ilk harfi + `.`; telefonun ilk 3 ve son 3 hanesi;
e-postanın ilk harfi + alan adı. Liste ekranında tam iletişim bilgisine ihtiyaç
yok — arayacak kişi kaydı açar.

### `GET /requests/{id}`

Tam kayıt, **maskesiz**: `full_name`, `telephone`, `email`, `menu_preference`,
`kitchen_note`, `message`, `kvkk_accepted_at`, `submitted_at`, `admin_note`.

`kvkk_accepted_at` **her zaman doludur** — onaysız kayıt hiç oluşmaz.

### `PATCH /requests/{id}`

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Müşteri arandı, teklif gönderildi",
  "status": "cevaplandi",
  "admin_note": "16.08 arandı, 20 kişilik günlük menü teklifi e-postayla gitti."
}
```

Yazılabilir yalnız `status` ve `admin_note`. Talebin kendisi (ziyaretçinin
yazdığı) **değiştirilemez**: bir kaydın içeriğini düzeltebilen bir panel, o
kaydın delil değerini yok eder.

`status` `QuoteRequest::STATUSES` içinde olmalı.

### `POST /requests/{id}/convert`

Talebi bir aboneliğe çevirir. Talep kaydı **silinmez**, `status = kapandi`
olur ve `converted_subscription_id` dolar.

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Talep kabul edildi, abonelik açıldı",
  "dry_run": false,
  "customer_id": 312,
  "subscription": {
    "location_id": 1,
    "start_date": "2026-09-01",
    "end_date": null,
    "delivery_type": "delivery",
    "service_days": [1, 2, 3, 4, 5],
    "menu_mode": "daily_menu",
    "default_quantity": 20,
    "agreed_unit_price_kurus": 16000,
    "payment_mode": "prepaid_monthly",
    "delivery_points": [ { "address_id": 704, "quantity": 20, "note": null } ]
  }
}
```

- `customer_id` **zorunludur.** Talep sahibi henüz müşteri değildir ve bu uç
  müşteri **yaratmaz**: hesap açmak parola ve e-posta doğrulaması gerektirir,
  ikisi de bu sözleşmenin dışındadır. Yönetici müşteriyi önce oluşturur
  (TastyIgniter admin) ya da mevcut kaydı seçer.
- `subscription` bloğu `POST /` gövdesiyle **aynı doğrulamalardan geçer**.
- Talep zaten çevrilmişse → `409 CONFLICT`,
  `details = {"conflict": "already_converted", "subscription_id": 18}`.

```json
{
  "ok": true, "dry_run": false, "audit_id": 1950,
  "data": {
    "request_id": 88,
    "request_status": "kapandi",
    "subscription": { "id": 19, "status": "pending" }
  }
}
```

Abonelik yine **`pending` doğar**: sözleşme imzalanmadan aktifleşmez.

---

## Sözleşmeler

İş kararı 9: **imzalı link + SMS OTP onayı.** Sözleşme bir PDF değil, tek
kullanımlık bir bağlantıdır; müşteri açar, metni okur, telefonuna gelen kodu
girer ve onaylar.

> **BAŞKA AJANIN KULVARI — yeni tablo gerekiyor.**
> `veykemtu_subscription_contracts`:
> `id`, `subscription_id` (indeks), `token` (string 64, **unique**),
> `status` (string 16), `terms_snapshot` (json — imzalandığı andaki koşullar),
> `sent_to_phone` (string 32), `sent_at`, `expires_at`, `signed_at`,
> `signed_ip` (string 45), `otp_verified_at`, `cancelled_at`,
> `cancel_reason` (string 255), `created_by_actor` (string 120), `created_at`.
> `token` **yanıtta hiçbir zaman dönmez** — dönerse imzalı bağlantı denetim
> ekranından okunabilir hâle gelirdi.

### Durum makinesi

```
pending ──(gönderildi)──▶ sent ──(OTP doğrulandı)──▶ signed
   │                        │
   └───────(iptal)──────────┴──▶ cancelled
                            │
                            └──(süre doldu)──▶ expired
```

`signed` **terminaldir**: imzalanmış sözleşme iptal edilemez, ancak yeni bir
sözleşme oluşturulup eskisinin yerini alabilir.

### `GET /{id}/contracts`

```json
{
  "data": [
    {
      "id": 7,
      "subscription_id": 18,
      "status": "signed",
      "sent_to_phone": "5321234567",
      "sent_at": "2026-08-14T12:00:00Z",
      "expires_at": "2026-08-21T12:00:00Z",
      "signed_at": "2026-08-14T12:06:00Z",
      "otp_verified_at": "2026-08-14T12:06:00Z",
      "cancelled_at": null,
      "cancel_reason": null,
      "terms_snapshot": {
        "agreed_unit_price_kurus": 16000,
        "service_days": [1,2,3,4,5],
        "default_quantity": 20,
        "start_date": "2026-09-01",
        "end_date": null,
        "payment_mode": "prepaid_monthly"
      },
      "created_at": "2026-08-14T11:58:00Z"
    }
  ],
  "server_time": "2026-08-16T09:00:00Z"
}
```

`terms_snapshot` **imzalandığı andaki koşullardır.** Abonelik sonradan
değişirse sözleşme değişmez; "neyi imzaladı" sorusunun cevabı burada durmalı.

### `POST /{id}/contracts`

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Abonelik sözleşmesi müşteriye gönderildi",
  "dry_run": false,
  "phone": "5321234567",
  "expires_in_days": 7,
  "send_sms": true
}
```

- `phone` verilmezse müşterinin kayıtlı telefonu kullanılır; ikisi de yoksa
  `422`.
- `expires_in_days`: 1–30, varsayılan **7**. Süresiz bir imza bağlantısı,
  bir yıl sonra ele geçtiğinde hâlâ geçerli olurdu.
- Aynı abonelikte **açık (`pending`/`sent`) bir sözleşme varsa** → `409 CONFLICT`,
  `details = {"conflict": "open_contract", "contract_id": 7}`. İki geçerli
  bağlantı, hangisinin imzalandığını belirsiz kılardı. Önce iptal edilir.
- `send_sms: false` iken kayıt `pending` kalır ve link **yanıtta döner**
  (yönetici elden iletecek). `true` iken SMS gider ve durum `sent` olur.

```json
{
  "ok": true, "dry_run": false, "audit_id": 1960,
  "data": {
    "id": 8,
    "status": "sent",
    "sent_to_phone": "5321234567",
    "expires_at": "2026-08-23T09:00:00Z",
    "sign_url": null,
    "sms_sent": true
  }
}
```

`sign_url` **yalnız `send_sms: false` iken doludur.** SMS gönderildiğinde
`null` döner: bağlantı zaten müşterinin telefonunda ve panelde de göstermek onu
ikinci bir yerde sızdırılabilir kılardı. `payload_json`'a hiçbir koşulda
yazılmaz.

### `GET /contracts/{contract}`

Tek sözleşme, yukarıdaki gövde. `token` ve `sign_url` **dönmez**.

### `POST /contracts/{contract}/resend`

Aynı sözleşmenin bağlantısını yeniden gönderir ve `expires_at`'i tazeler.
Yeni token **üretilmez**: müşterinin elindeki eski SMS'in çalışmaya devam
etmesi, "hangi linke tıklayacağım" sorusunu ortadan kaldırır.

```json
{ "actor": "Ayşe Yılmaz", "reason": "Müşteri SMS'i bulamadı, link yeniden gönderildi", "expires_in_days": 7 }
```

`signed` ya da `cancelled` bir sözleşmede → `409 CONFLICT`.

### `POST /contracts/{contract}/cancel`

```json
{ "actor": "Ayşe Yılmaz", "reason": "Koşullar değişti, sözleşme iptal edilip yenisi hazırlanacak" }
```

`signed` bir sözleşmede → `409 CONFLICT` (`details.conflict = "signed"`).
İmzalanmış bir sözleşmeyi iptal edilmiş göstermek, imzanın kendisini geçersiz
kılmaktır; yeni koşullar yeni bir sözleşme gerektirir.

---

## Ödemeler

Dönem borcu ve tahsilat kaydı. Cari hesap kalktığı için (iş kararı 1) bu
tablo, aboneliğin **tek** para defteridir.

> **BAŞKA AJANIN KULVARI — yeni tablo gerekiyor.**
> `veykemtu_subscription_payments`:
> `id`, `subscription_id` (indeks), `period_start` (date),
> `period_end` (date), `amount_kurus` (bigInteger), `due_date` (date),
> `status` (string 16: `pending`\|`paid`\|`void`), `method` (string 16,
> nullable: `online`\|`cash`), `paid_at` (timestamp, nullable),
> `reference` (string 120, nullable), `note` (string 255, nullable),
> `invoice_id` (unsignedBigInteger, nullable), `created_by_actor` (string 120),
> `created_at`, `updated_at`.
> `UNIQUE(subscription_id, period_start, period_end)` — aynı dönem iki kez
> borçlandırılamaz.

> **MÜŞTERİ TARAFI BU SÖZLEŞMENİN DIŞINDA.** Buradaki uçlar dönem borcunu
> **yönetici** adına açar ve tahsilatı kaydeder. Müşterinin dönem bedelini
> uygulamadan **online ödemesi** ayrı bir akıştır (ödeme niyeti, sağlayıcı
> dönüşü, idempotent sonuçlandırma) ve iskeleti
> `docs/control/_devralinan-odeme-yapisi.md` dosyasında arşivlenmiştir.
> O akış yazıldığında `veykemtu_subscription_payments.status` alanına
> `paid` yazan **ikinci** bir yol doğar; `mark-paid` ucunun `409 CONFLICT`
> kuralı o yolu da kapsar ve iki taraf aynı dönemi iki kez tahsil edemez.

### `GET /{id}/payments`

Sorgu: `status`, `from`, `to`. Sayfalanmaz — bir aboneliğin dönem sayısı
sınırlıdır ve ekran hepsini bir tablo olarak çizer.

```json
{
  "data": [
    {
      "id": 41, "period_start": "2026-08-01", "period_end": "2026-08-31",
      "amount_kurus": 640000, "due_date": "2026-08-05",
      "status": "pending", "method": null, "paid_at": null,
      "reference": null, "note": null, "invoice_id": null,
      "overdue": true, "overdue_days": 11
    }
  ],
  "meta": {
    "total_kurus": 640000,
    "paid_kurus": 0,
    "pending_kurus": 640000,
    "overdue_kurus": 640000
  },
  "server_time": "2026-08-16T09:00:00Z"
}
```

`overdue` sunucuda hesaplanır: `status = pending` **ve** `due_date < bugün`.
İstemcide hesaplansaydı saati kaymış bir panelde borç bir gün erken kırmızıya
dönerdi.

### `POST /{id}/payments`

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Ağustos dönemi borcu oluşturuldu",
  "dry_run": false,
  "period_start": "2026-08-01",
  "period_end": "2026-08-31",
  "amount_kurus": null,
  "due_date": "2026-09-05",
  "note": null
}
```

- `amount_kurus` `null` gönderilirse sunucu **hesaplar**: dönemdeki üretilmiş
  ve iptal edilmemiş siparişlerin toplamı. Elle tutar yazmak serbesttir ama
  varsayılan hesaplanmış olmalı — yönetici her ay çarpma yapmamalı.
- `period_end` `period_start`'tan sonra olmalı; aralık en çok 62 gün.
- Aynı dönem varsa → `409 CONFLICT` (tekil kısıt).
- `due_date` `period_start`'tan önce olamaz.

```json
{
  "ok": true, "dry_run": false, "audit_id": 1970,
  "data": {
    "id": 42, "period_start": "2026-08-01", "period_end": "2026-08-31",
    "amount_kurus": 640000, "amount_source": "calculated",
    "order_count": 40, "due_date": "2026-09-05", "status": "pending"
  }
}
```

`amount_source`: `calculated` veya `manual`. Denetim izinde ikisinin ayrılması,
"bu tutar nereden geldi" sorusunun cevabıdır.

Kuru prova `would` hesabı **gerçekten yapar** ve `order_count` ile birlikte
döner — yöneticinin borcu yazmadan önce görmesi gereken tam olarak budur.

### `POST /payments/{payment}/mark-paid`

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Havale geldi, dönem borcu kapatıldı",
  "method": "online",
  "paid_at": "2026-09-03T10:00:00Z",
  "reference": "TR12 0001 ... 4455",
  "create_invoice": true
}
```

- `method` zorunlu: `online` veya `cash`.
- `paid_at` verilmezse şimdi. Gelecek bir an → `422`.
- Zaten `paid` ise → `409 CONFLICT`. İkinci kez tahsil işaretlemek, tutarı
  iki kez saydırırdı.
- `create_invoice: true` ise dönem için fatura belgesi de üretilir
  (`invoices.md`) ve `invoice_id` dolar. Varsayılan `false` — fatura
  yazdırılabilir bir belgedir ve her tahsilatta üretmek gereksiz.
- Ödemeyi **geri almak için uç yoktur.** Yanlış işaretlenen bir tahsilat, yeni
  bir dönem kaydıyla düzeltilir; para defterinde silme yoktur.

```json
{
  "ok": true, "dry_run": false, "audit_id": 1980,
  "data": {
    "id": 41, "status": "paid", "method": "online",
    "paid_at": "2026-09-03T10:00:00Z", "invoice_id": 45, "invoice_no": "BLD-2026-000045"
  }
}
```

---

## Denetim eylemleri

| `action` | Uç | `target_type` / `target_id` |
|---|---|---|
| `subscription.create` | `POST /` | `subscription` / yeni id |
| `subscription.update` | `PATCH /{id}` | `subscription` / id |
| `subscription.activate` | `POST /{id}/activate` | `subscription` / id |
| `subscription.pause` | `POST /{id}/pause` | `subscription` / id |
| `subscription.resume` | `POST /{id}/resume` | `subscription` / id |
| `subscription.cancel` | `POST /{id}/cancel` | `subscription` / id |
| `subscription.exception.create` | `POST /{id}/exceptions` | `subscription` / id |
| `subscription.exception.delete` | `DELETE /{id}/exceptions/{date}` | `subscription` / id |
| `subscription.generate` | `POST /{id}/generate` | `subscription` / id |
| `subscription.order.release` | `POST /orders/{order}/release` | `order` / `order_id` |
| `subscription.request.update` | `PATCH /requests/{id}` | `quote_request` / id |
| `subscription.request.convert` | `POST /requests/{id}/convert` | `quote_request` / id |
| `subscription.contract.create` | `POST /{id}/contracts` | `subscription_contract` / yeni id |
| `subscription.contract.resend` | `POST /contracts/{c}/resend` | `subscription_contract` / id |
| `subscription.contract.cancel` | `POST /contracts/{c}/cancel` | `subscription_contract` / id |
| `subscription.payment.create` | `POST /{id}/payments` | `subscription_payment` / yeni id |
| `subscription.payment.paid` | `POST /payments/{p}/mark-paid` | `subscription_payment` / id |

`subscription.order.release` hedefi **sipariştir**, abonelik değil: soru "bu
sipariş neden erken düştü" biçiminde sorulur.
