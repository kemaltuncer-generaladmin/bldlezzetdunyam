# `control/orders` — Siparişler

Yol öneki: **`/api/control/orders`** · Sınır: `bld-control-panel` ·
Ortak kurallar: `00-genel.md`

Siparişi görme, düzenleme, durumunu ilerletme, iptal etme ve dışa aktarma.

**İş mantığı bu uçlarda yoktur.** Revizyonu `Services\OrderEditor`, durum
geçişini `Services\OrderStatusTransition` yürütür; bunlar mutfak kasasının
kullandığı sınıfların ta kendisidir. Ayrı bir kopya yazılsaydı sipariş
merkezden düzenlendiğinde iade kaydı sessizce oluşmayabilirdi.

---

## Mevcut beş uç ve yeni ev

`control/kds/orders*` altındaki beş uç (`index`, `show`, `revisions` ×2,
`status`) **yayınlanmıştır ve olduğu yerde kalır.** Kontrol Merkezi'nin
`bld_kds` modülü onları kullanıyor.

> KARAR: Panel siparişlerinin evi **`/api/control/orders/*`**'dir ve sekiz ucun
> tamamını taşır. Beş uç iki yolda birden yayında olur (aynı denetleyici
> metotları, ikinci bir rota kaydı). Bu ekleyicidir ve geri alınabilir: eski yol
> silinirse `bld_kds` kırılırdı, yeni yol açılmazsa panel siparişleri KDS
> bütçesinden (`bld-control`, 1200/saat) yerdi ve kasa yönetimini kilitlerdi.
> İki yolun tek farkı hız sınırı kovasıdır; gövde, yanıt ve denetim eylem adları
> aynıdır.

---

## Uçlar

| Metot | Yol | Amaç | İzin | dry_run | Gerekçe |
|---|---|---|---|---|---|
| GET | `/` | Sipariş listesi (**sayfalı**) | `bld_sales.view` | — | — |
| GET | `/{order}` | Düzenlenebilir görünüm | `bld_sales.view` | — | — |
| GET | `/{order}/revisions` | Revizyon geçmişi | `bld_sales.view` | — | — |
| POST | `/{order}/revisions` | Yeni revizyon (**tam kalem listesi**) | `bld_sales.manage` | ✔ | ✔ (maks 160) |
| POST | `/{order}/status` | Durum geçişi | `bld_sales.manage` | ✔ | ✔ (maks 160) |
| POST | `/{order}/cancel` | İptal | `bld_sales.manage` | ✔ | ✔ (maks 160) |
| GET | `/export` | CSV dışa aktarım | `bld_sales.view` | — | — |
| GET | `/{order}/invoice` | Siparişin fatura belgesi | `bld_invoices.view` | — | — |

`{order}` = `orders.order_id`.

---

## `GET /` — liste

`control/kds/orders` **bugünün aktif siparişlerini** döndürür ve mutfak
panosuyla aynı kümedir. Panel listesi farklıdır: **geçmişe bakar, sayfalanır ve
süzülür**. İki uç aynı yolda olsaydı KDS ekranının gördüğü küme değişirdi.

Sorgu parametreleri:

| Ad | Tip | Varsayılan | Not |
|---|---|---|---|
| `service_date` | `YYYY-MM-DD` | — | `orders.bld_service_date` |
| `from` / `to` | `YYYY-MM-DD` | — | Servis günü aralığı |
| `status` | string | — | Virgüllü kod listesi: `yeni,onaylandi,...` |
| `delivery_type` | `delivery`\|`pickup` | — | |
| `customer_id` | int | — | |
| `subscription_id` | int | — | |
| `source` | `all`\|`manual`\|`subscription` | `all` | Abonelikten üretilenler |
| `q` | string | — | Sipariş numarası, ad, telefon |
| `page` / `per_page` | int | 1 / 25 | tavan 100 |

Süzgeç verilmezse **son 7 günün** siparişleri döner. Sınırsız bir varsayılan,
ilk sayfada bir yılın verisini saydırırdı.

Durum kodları `OrderStatusTransition::CODES`'tan gelir ve uydurulmaz:
`yeni` · `onaylandi` · `hazirlaniyor` · `hazir` · `yolda` · `teslim_edildi` ·
`iptal`.

```json
{
  "data": [
    {
      "id": 8421,
      "order_number": "BLD-8421",
      "status": "hazirlaniyor",
      "service_date": "2026-08-16",
      "requested_at": "2026-08-16T09:30:00Z",
      "delivery_type": "delivery",
      "customer_id": 312,
      "customer_name": "Acme Gıda — Mehmet Kaya",
      "customer_phone": "5321234567",
      "item_count": 12,
      "total_kurus": 216000,
      "payment_method": "online",
      "payment_status": "paid",
      "is_subscription": false,
      "subscription_id": null,
      "revision_no": 1,
      "has_invoice": false,
      "created_at": "2026-08-15T18:04:00Z",
      "updated_at": "2026-08-16T06:20:00Z"
    }
  ],
  "meta": { "page": 1, "per_page": 25, "total": 137, "last_page": 6 },
  "server_time": "2026-08-16T09:00:00Z"
}
```

**Listede fiyat vardır.** ADR-08 **mutfak kapsamını** para görmekten men eder
çünkü kasa ekranı gün boyu mutfakta açık durur; Kontrol Merkezi bir yönetim
yüzeyidir ve ciro sorusuna cevap vermek zorundadır. Kural kaldırılmadı,
daraltıldı.

`payment_method` değerleri `online` ve `cash` (iş kararı 1). `payment_status`:
`pending` · `paid` · `failed` · `refunded`.

---

## `GET /{order}`

Gövde `Services\OrderPresenter::editable()` çıktısıdır ve **fiyatsızdır** —
düzenleme ekranı adet değiştirir, fiyatı kaydetme onayında görür. Panel bu
uca ek olarak `total_kurus` ve `payment_*` alanlarını **liste ucundan** taşır.

```json
{
  "data": {
    "id": 8421,
    "order_number": "BLD-8421",
    "status": "hazirlaniyor",
    "service_date": "2026-08-16",
    "requested_at": "2026-08-16T09:30:00Z",
    "delivery_type": "delivery",
    "customer_name": "Mehmet Kaya",
    "customer_phone": "5321234567",
    "customer_note": "Kapıda zili çalmayın",
    "revision_no": 1,
    "editable": true,
    "not_editable_reason": null,
    "items": [
      {
        "menu_id": 88,
        "name": "Günün Menüsü (16.08.2026)",
        "quantity": 12,
        "option_value_ids": [],
        "note": null
      }
    ],
    "totals": {
      "subtotal_kurus": 216000,
      "delivery_fee_kurus": 0,
      "total_kurus": 216000,
      "currency": "TRY"
    },
    "payment": { "method": "online", "status": "paid" },
    "invoice": { "id": null, "invoice_no": null }
  },
  "server_time": "2026-08-16T09:00:00Z"
}
```

**Bileşen satırları listede görünmez** (B-19). Günün menüsü bir paket satırı +
sıfır fiyatlı bileşen satırları olarak yazılır; bileşenler de listelenseydi
panel onları geri gönderir, `LineResolver` tek tek satılan ürünler gibi
fiyatlandırır ve toplam kendiliğinden şişerdi. Personel paketi **tek birim**
olarak düzenler ("Günün Menüsü ×12" → ×10), sunucu bileşenleri yeniden açar.
Tasarımdaki en keskin kenar budur.

`not_editable_reason`: `delivered` · `cancelled` · `null`.

---

## `GET /{order}/revisions`

```json
{
  "data": [
    {
      "revision_no": 1,
      "reason": "Müşteri iki porsiyon azalttı",
      "note": "Kontrol Merkezi · Ayşe Yılmaz",
      "refund_kurus": 36000,
      "extra_charge_kurus": 0,
      "created_by_device_id": null,
      "created_at": "2026-08-16T06:20:00Z"
    }
  ],
  "server_time": "2026-08-16T09:00:00Z"
}
```

`created_by_device_id` `null` ise revizyon **merkezden** geldi; dolu ise
mutfak kasasından. Ayrım ayrıca notun başındaki `"Kontrol Merkezi · <actor>"`
etiketinden de okunur.

---

## `POST /{order}/revisions`

Gövde `control/kds` ucuyla **birebir aynıdır**.

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Müşteri telefonla iki porsiyon azalttı",
  "dry_run": false,
  "note": "Muhasebe bilgilendirildi",
  "items": [
    { "menu_id": 88, "quantity": 10, "option_value_ids": [], "note": null }
  ],
  "requested_at": null,
  "customer_note": null
}
```

- `items` **tam listedir, delta değil.** Gönderilen liste siparişin yeni
  hâlidir. Fark göndermek, eşzamanlı bir kasa düzenlemesiyle yarışan merkez
  isteğinin sessizce yanlış sipariş üretmesi demekti.
- **Boş liste reddedilir** (`422`). Siparişi boşaltmak iptal değildir; iptalin
  kendi durumu ve kendi kaydı vardır.
- `reason` en çok **160** karakter (`veykemtu_order_revisions.reason` sütunu).
- Kalemler **olduğu gibi geçer, ayıklanmaz.** Bilinen alanları seçip gerisini
  atan bir dönüşüm `option_value_ids`'i düşürürdü: "ekstra peynir" silinir,
  sipariş ucuzlar, mutfak yanlış yemeği yapar ve hata hiçbir yerde görünmez.

Kuru prova **gerçekten denetler**: teslim edilmiş ya da iptal edilmiş sipariş
burada da `422` alır.

```json
{
  "ok": true, "dry_run": false, "audit_id": 1801,
  "order": { },
  "revision": { "revision_no": 2, "refund_kurus": 36000, "extra_charge_kurus": 0 }
}
```

`order` = `OrderPresenter::kitchen()` çıktısı (sipariş `refresh()` edilmiş
hâliyle — `OrderEditor` toplamları işlem içinde yeniden yazar).

Kuru prova `would`:

```json
{
  "action": "order.revise",
  "order_id": 8421,
  "next_revision_no": 2,
  "items": [ { "menu_id": 88, "quantity": 10, "option_value_ids": [], "note": null } ]
}
```

---

## `POST /{order}/status`

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Kurye çıktı, yolda olarak işaretlendi",
  "dry_run": false,
  "status": "yolda"
}
```

`status` `OrderStatusTransition::CODES` içinde olmalı. Geçiş matrisi izin
vermezse `422 INVALID_TRANSITION`, `details = {"from": "yeni", "to": "yolda"}`.

Gerekçe `status_history`'ye de yorum olarak düşer: "bu sipariş neden iptal
edildi" sorusunun cevabı siparişin kendi geçmişinde durmalı, yalnız ayrı bir
denetim tablosunda değil. Yazılan metin `"Kontrol Merkezi · <actor>: <reason>"`.

Geri alma penceresi **120 saniyedir** (`UNDO_WINDOW_SECONDS`); dışında kalan
geri geçişler matris tarafından reddedilir.

```json
{ "ok": true, "dry_run": false, "audit_id": 1810, "order": { } }
```

---

## `POST /{order}/cancel`

İptal **`status` ucuyla `iptal` göndermekten farklıdır** ve ayrı bir uçtur
çünkü para hareketi üretir: ödenmiş bir siparişin iadesi, aboneliğe bağlı bir
siparişin üretim defterinden düşülmesi.

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Müşteri iptal istedi, kesim saatinden önce",
  "dry_run": false,
  "refund": true,
  "notify_customer": true
}
```

| Alan | Tip | Varsayılan | Not |
|---|---|---|---|
| `refund` | bool | `true` | Ödeme `paid` ise iade kaydı üretilir |
| `notify_customer` | bool | `true` | İptal SMS'i gönderilir (`sms.md`, `order_cancelled`) |

- Zaten `iptal` olan sipariş → `409 CONFLICT`.
- `teslim_edildi` olan sipariş → `422 INVALID_TRANSITION`. Teslim edilmiş bir
  siparişi iptal etmek, olmuş bir şeyi olmamış saymaktır; iade gerekiyorsa
  revizyon yolu kullanılır ve orada tutar açıkça yazılır.
- `refund: false` ödemesi `paid` bir siparişte **serbesttir** ve yanıt
  `warnings` taşır: bazen para elden iade edilir ve sistemin ikinci kez iade
  üretmemesi gerekir.
- Abonelikten üretilmiş bir siparişi iptal etmek **aboneliği durdurmaz** —
  yalnız o günün siparişini düşürür. `veykemtu_subscription_runs` satırı
  **kalır**; silinseydi gece işi ertesi koşuda aynı günü yeniden üretirdi.

```json
{
  "ok": true, "dry_run": false, "audit_id": 1820,
  "order": { },
  "data": {
    "refund_kurus": 216000,
    "refund_created": true,
    "sms_sent": true,
    "stock_released": { "day": 12, "items": [ { "menu_id": 88, "quantity": 12 } ] }
  },
  "warnings": []
}
```

`stock_released` **iptalin en önemli yan etkisidir**: iptal edilen porsiyonlar
gün toplamı ve ürün tavanından düşer, yani o kadar sipariş yeniden alınabilir
hâle gelir. Ekran bunu göstermezse yönetici "neden birden 12 yer açıldı" diye
sorar.

Kuru prova `would`:

```json
{
  "action": "order.cancel",
  "order_id": 8421,
  "from": "hazirlaniyor",
  "refund_kurus": 216000,
  "would_refund": true,
  "would_notify": true,
  "stock_would_release": { "day": 12 }
}
```

---

## `GET /export`

CSV dışa aktarım. Muhasebe ve tedarik planlaması için.

Sorgu: `GET /` ile **aynı süzgeçler** (`page`/`per_page` hariç) + `format`.

| Ad | Tip | Varsayılan | Not |
|---|---|---|---|
| `format` | `csv` | `csv` | Şimdilik tek biçim |
| `max_rows` | int | `5000` | Tavan `20000` |

Yanıt **JSON değildir**:

```
HTTP/1.1 200 OK
Content-Type: text/csv; charset=utf-8
Content-Disposition: attachment; filename="bld-siparisler-2026-08-01_2026-08-16.csv"
X-Total-Rows: 137
X-Truncated: false
```

Sütunlar (başlık satırı **Türkçe**, veri makine okunur):

```
siparis_no,servis_gunu,olusturulma,durum,teslimat_turu,musteri_id,musteri,telefon,
kalem_sayisi,ara_toplam_kurus,teslimat_ucreti_kurus,toplam_kurus,odeme_yontemi,
odeme_durumu,abonelik_id,revizyon_no,fatura_no
```

- Ayraç **virgül**, alan sınırlayıcı çift tırnak, satır sonu `\r\n`.
- Dosya **UTF-8 BOM ile başlar** (`EF BB BF`). BOM olmadan Excel Türkçe
  karakterleri bozar ve dosyayı açan muhasebeci "ğ" yerine kutu görür.
- Para sütunları **kuruş tam sayıdır**. TL'ye çevirmek, ondalık ayracının
  Excel yerel ayarına bağlı olması demekti.
- `max_rows` aşılırsa satırlar kesilir, `X-Truncated: true` başlığı döner ve
  **hata verilmez** — kesilmiş bir dosya, hiç dosya olmamasından iyidir; başlık
  bunu açıkça söyler.

Bu uç **okuma** olduğu için denetim izine düşmez. Dışa aktarımın kişisel veri
içerdiği doğrudur (ad, telefon) ama `customers` alanındaki KVKK kuralı buraya
genişletilmedi: sipariş listesi zaten `GET /` ile de görülebiliyor ve yalnız
CSV'yi denetlemek, izi eksik ve yanıltıcı kılardı.

> KARAR: CSV dışa aktarımı denetlenmiyor ve bu **bilinçli bir eksiktir**.
> Doğru çözüm bütün sipariş okumalarını denetlemek olurdu; o da yoklayan liste
> ekranı yüzünden günde binlerce satır demek. Karar gözden geçirilecekse
> `customers` alanındaki "yoklanmaz" kuralıyla birlikte ele alınmalı.

---

## `GET /{order}/invoice`

Siparişin fatura belgesini döndürür. Belge **yoksa üretmez** — üretim
`invoices.md` → `POST /invoices` işidir. Burada yalnız var olan belgeye bakılır.

```json
{
  "data": {
    "id": 44,
    "invoice_no": "BLD-2026-000044",
    "order_id": 8421,
    "status": "issued",
    "issued_at": "2026-08-16T15:00:00Z",
    "total_kurus": 216000,
    "html_url": "/api/control/invoices/44/html"
  },
  "server_time": "2026-08-16T09:00:00Z"
}
```

Belge yoksa `404 NOT_FOUND` (`message`: "Bu siparişe ait fatura belgesi
oluşturulmamış.").

---

## Denetim eylemleri

| `action` | Uç | `target_type` / `target_id` |
|---|---|---|
| `order.revise` | `POST /{order}/revisions` | `order` / `order_id` |
| `order.status` | `POST /{order}/status` | `order` / `order_id` |
| `order.cancel` | `POST /{order}/cancel` | `order` / `order_id` |

`order.revise` ve `order.status` **mevcut eylem adlarıdır ve değişmez** —
`control/kds` yolundan gelen istekler de aynı adı yazıyor. Denetim ekranında iki
yolun ayrı görünmesi gerekmiyor: eylem aynı eylem, aktör zaten yazılı.
