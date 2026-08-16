# `control/invoices` — Fatura belgesi

Yol öneki: **`/api/control/invoices`** · Sınır: `bld-control-panel` ·
Ortak kurallar: `00-genel.md`

> ## BU BELGENİN MALİ DEĞERİ YOKTUR
>
> İş kararı 10: fatura, **yazdırılabilir bir A4 belgedir**. Resmî fatura
> değildir, e-Fatura / e-Arşiv değildir, GİB'e gitmez, vergi hesaplamaz.
> Müşterinin "bir belge verin" talebini karşılar ve sipariş/dönem dökümünü
> okunur biçimde basar.
>
> Belgenin üstünde bu ibare **zorunludur** ve HTML şablonundan kaldırılamaz:
> *"Bu belge bilgilendirme amaçlıdır, mali değeri yoktur."*

> **BAŞKA AJANIN KULVARI — yeni tablo gerekiyor.** `veykemtu_invoices`:
> `id`, `invoice_no` (string 32, **unique**), `customer_id` (indeks),
> `order_id` (nullable, indeks), `subscription_id` (nullable, indeks),
> `subscription_payment_id` (nullable), `period_start` (date, nullable),
> `period_end` (date, nullable), `issued_at` (timestamp),
> `total_kurus` (bigInteger), `status` (string 16: `issued`\|`void`),
> `void_at` (timestamp, nullable), `void_reason` (string 255, nullable),
> `snapshot_json` (json), `created_by_actor` (string 120),
> `created_at`, `updated_at`.

---

## Uçlar

| Metot | Yol | Amaç | İzin | dry_run | Gerekçe |
|---|---|---|---|---|---|
| GET | `/` | Belge listesi (**sayfalı**) | `bld_invoices.view` | — | — |
| GET | `/{id}` | Tek belge (JSON) | `bld_invoices.view` | — | — |
| GET | `/{id}/html` | Yazdırılabilir A4 (**HTML**) | `bld_invoices.view` | — | — |
| POST | `/` | Belge üret | `bld_invoices.manage` | ✔ | ✔ |
| POST | `/{id}/void` | Belgeyi iptal et | `bld_invoices.manage` | ✔ | ✔ |

`PATCH` **yoktur.** Kesilmiş bir belgenin içeriği değiştirilemez; yanlışsa iptal
edilir ve yenisi kesilir. Düzenlenebilen bir belge, elindeki kâğıtla sistemdeki
kayıt farklı olan bir müşteri üretir.

`DELETE` **yoktur.** Numara boşluğu bırakan bir belge serisi, "44 nerede"
sorusunu cevapsız bırakır.

---

## Belge numarası

Biçim: **`BLD-<yıl>-<6 hane sıra>`** — örn. `BLD-2026-000044`.

- Sıra **yıl başında sıfırlanır** ve boşluksuz artar.
- Numara üretimi **işlem içinde ve satır kilidiyle** yapılır; iki eşzamanlı
  istek aynı numarayı alamaz. Tekil indeks son güvencedir.
- İptal edilen belgenin numarası **serbest kalmaz.** Boşluk yok, geri kullanım
  yok; iptal edilmiş numara belge listesinde `void` olarak görünür.

---

## Şema

| Alan | Tip | Not |
|---|---|---|
| `id` | int | |
| `invoice_no` | string | `BLD-2026-000044` |
| `status` | `issued`\|`void` | |
| `customer_id` | int | |
| `customer_label` | string | Kurum adı, yoksa ad soyad |
| `order_id` | int\|null | Tek sipariş belgesi |
| `subscription_id` | int\|null | Dönem belgesi |
| `subscription_payment_id` | int\|null | Bağlı dönem ödemesi |
| `period_start` / `period_end` | `YYYY-MM-DD`\|null | Dönem belgesinde dolu |
| `issued_at` | ISO 8601 UTC | |
| `total_kurus` | int | |
| `void_at` | ISO 8601 UTC\|null | |
| `void_reason` | string\|null | |
| `snapshot_json` | object | Aşağıya bakın |
| `html_url` | string | `/api/control/invoices/{id}/html` |
| `created_at` | ISO 8601 UTC | |

### `snapshot_json` — belgenin donmuş içeriği

Belge kesildiği andaki bilgiyi taşır ve **bir daha değişmez.** Müşteri adı,
kurum unvanı, sipariş kalemleri ve fiyatlar sonradan değişse bile basılmış
belge aynı kalmalı; canlı tablodan okunan bir belge, iki farklı zamanda iki
farklı kâğıt üretirdi.

```json
{
  "issuer": {
    "name": "BLD Catering",
    "address": "Kızılırmak Mah. 1443. Cad. No:12, Çankaya / Ankara",
    "phone": "3124445566",
    "email": "info@bld.example"
  },
  "customer": {
    "label": "Acme Gıda A.Ş.",
    "contact_person": "Mehmet Kaya",
    "tax_office": "Çankaya",
    "tax_no": "1234567890",
    "address": "Kızılırmak Mah. 1443. Cad. No:12, Kat 4, Çankaya / Ankara",
    "phone": "3124445566"
  },
  "lines": [
    {
      "description": "Günün Menüsü (16.08.2026)",
      "service_date": "2026-08-16",
      "order_number": "BLD-8421",
      "quantity": 12,
      "unit_price_kurus": 18000,
      "line_total_kurus": 216000
    }
  ],
  "totals": {
    "subtotal_kurus": 216000,
    "delivery_fee_kurus": 0,
    "total_kurus": 216000,
    "currency": "TRY"
  },
  "payment": { "method": "online", "status": "paid", "paid_at": "2026-08-16T12:00:00Z" },
  "notice": "Bu belge bilgilendirme amaçlıdır, mali değeri yoktur."
}
```

`issuer` bloğu `veykemtu_site_content` → `contact` ve `company` anahtarlarından
**kopyalanır**, bağlanmaz. Şirket adresi değişince eski belge eski adresi
göstermeli.

Vergi satırı **yoktur.** KDV hesaplamak, belgeye mali değer atfetmek olurdu ve
yanlış hesaplanmış bir KDV, olmayan bir belgeden daha kötüdür.

---

## `GET /` — liste

Sorgu: `customer_id`, `subscription_id`, `order_id`, `status`, `from`, `to`
(`issued_at` üzerinden), `q` (belge numarası veya müşteri), `page`, `per_page`.

```json
{
  "data": [
    {
      "id": 44, "invoice_no": "BLD-2026-000044", "status": "issued",
      "customer_id": 312, "customer_label": "Acme Gıda A.Ş.",
      "order_id": 8421, "subscription_id": null,
      "period_start": null, "period_end": null,
      "issued_at": "2026-08-16T15:00:00Z", "total_kurus": 216000,
      "void_at": null, "html_url": "/api/control/invoices/44/html"
    }
  ],
  "meta": { "page": 1, "per_page": 25, "total": 44, "last_page": 2, "issued_total_kurus": 8912000 },
  "server_time": "2026-08-16T09:00:00Z"
}
```

`meta.issued_total_kurus` **süzgeçlenmiş kümenin** toplamıdır, sayfanın değil
— ekranın alt satırındaki toplam, sayfa değiştirince değişmemeli. İptal
edilmiş belgeler bu toplama **girmez**.

---

## `GET /{id}` — JSON

Tam kayıt (`snapshot_json` dâhil).

## `GET /{id}/html` — yazdırılabilir belge

**Yanıt JSON değildir.**

```
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
Content-Disposition: inline; filename="BLD-2026-000044.html"
Cache-Control: no-store
```

Belge kuralları:

- **Tek dosya, dış bağımlılık yok.** CSS gömülü, yazı tipi sistem yazı tipi,
  görsel yok. Panelde yeni sekmede açılıp `Ctrl+P` ile basılıyor; dışarıdan
  kaynak çeken bir sayfa, ağ yokken boş basardı.
- `@page { size: A4; margin: 18mm 16mm; }` ve `@media print` kuralları dâhil.
- İçerik `snapshot_json`'dan üretilir, **canlı tablodan değil.**
- Sayfa altında zorunlu ibare: *"Bu belge bilgilendirme amaçlıdır, mali değeri
  yoktur."*
- `status = void` ise belgenin üzerine çapraz **"İPTAL"** filigranı basılır ve
  iptal gerekçesi alt bilgide görünür. İptal edilmiş bir belgenin temiz
  basılabilmesi, elindeki kâğıdın geçerli olduğunu sanan bir müşteri üretirdi.
- Türkçe metin; sayılar `1.234,56` biçiminde (kuruş → TL dönüşümü yalnız
  görüntüleme katmanında).

Bu uç **denetim izine düşmez**: belge zaten `GET /{id}` ile de okunabiliyor ve
yalnız basılabilir hâlini denetlemek izi eksik ve yanıltıcı kılardı.

---

## `POST /` — belge üret

İki kip vardır ve **biri seçilmelidir**: sipariş belgesi ya da dönem belgesi.

### Sipariş belgesi

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Müşteri sipariş için belge talep etti",
  "dry_run": false,
  "order_id": 8421
}
```

### Dönem belgesi

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Ağustos dönemi için belge kesildi",
  "dry_run": false,
  "subscription_id": 18,
  "period_start": "2026-08-01",
  "period_end": "2026-08-31",
  "subscription_payment_id": 41
}
```

Doğrulama:

- `order_id` **veya** `subscription_id` — ikisi birden gönderilirse `422`,
  hiçbiri gönderilmezse `422`.
- Dönem kipinde `period_start` ve `period_end` zorunlu; aralık en çok 62 gün.
- Sipariş kipinde sipariş `iptal` durumunda olamaz → `422`. İptal edilmiş bir
  siparişe belge kesmek, olmamış bir hizmetin belgesidir.
- Aynı sipariş için **geçerli (`issued`) bir belge varsa** → `409 CONFLICT`,
  `details = {"conflict": "existing_invoice", "invoice_id": 44,
  "invoice_no": "BLD-2026-000044"}`. Aynı dönem için de aynı kural.
  İkinci bir belge kesmek isteyen önce eskisini iptal eder.
- Dönem kipinde **hiç sipariş yoksa** → `422`,
  `details = {"reason": "no_lines"}`. Boş bir belge basmak anlamsız.

```json
{
  "ok": true, "dry_run": false, "audit_id": 2101,
  "data": {
    "id": 44, "invoice_no": "BLD-2026-000044", "status": "issued",
    "total_kurus": 216000, "line_count": 1,
    "issued_at": "2026-08-16T15:00:00Z",
    "html_url": "/api/control/invoices/44/html"
  }
}
```

Kuru prova **numara üretmez** (seride boşluk açardı) ve toplamı hesaplayıp
döner:

```json
{
  "action": "invoice.create",
  "mode": "order",
  "order_id": 8421,
  "line_count": 1,
  "total_kurus": 216000,
  "existing_invoice_id": null
}
```

### Otomatik üretim

`settings.md` → `auto_invoice` açıkken sunucu, sipariş `teslim_edildi`
durumuna geçtiğinde belgeyi kendisi üretir. O kayıtların `created_by_actor`
alanı **`"sistem"`** olur ve denetim satırı `actor = "sistem"`,
`reason = "Otomatik fatura belgesi (auto_invoice)"` ile yazılır. Otomatik
üretilmiş bir belgeyi elle üretilmişten ayırt edebilmek, "bu belgeyi kim
kesti" sorusunun tek cevabıdır.

---

## `POST /{id}/void`

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Belgede yanlış kurum unvanı vardı, iptal edilip yenisi kesilecek",
  "dry_run": false
}
```

- Zaten `void` ise → `409 CONFLICT`.
- `void_reason` alanına **ortak `reason` metni** yazılır; ayrı bir alan
  istenmez. İptalin gerekçesi belgenin üzerinde basılacak ve zaten zorunlu bir
  alan olarak isteniyor; ikinci bir metin alanı, ikisinin çelişmesine yol
  açardı.
- İptal, bağlı `subscription_payment` kaydının durumunu **değiştirmez.** Belge
  ile tahsilat ayrı şeylerdir; belgeyi iptal etmek parayı geri vermez.

```json
{
  "ok": true, "dry_run": false, "audit_id": 2110,
  "data": {
    "id": 44, "invoice_no": "BLD-2026-000044", "status": "void",
    "void_at": "2026-08-16T16:00:00Z",
    "void_reason": "Belgede yanlış kurum unvanı vardı, iptal edilip yenisi kesilecek"
  }
}
```

---

## Denetim eylemleri

| `action` | Uç | `target_type` / `target_id` |
|---|---|---|
| `invoice.create` | `POST /` | `invoice` / yeni id |
| `invoice.void` | `POST /{id}/void` | `invoice` / id |

`payload_json` belge numarasını, toplamı ve kaynağı (`order_id` /
`subscription_id` + dönem) taşır; `snapshot_json` **yazılmaz** — kişisel veriyi
ve adresi denetim tablosunda ikinci kez çoğaltırdı.
