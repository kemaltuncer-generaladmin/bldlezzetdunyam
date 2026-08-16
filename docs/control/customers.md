# `control/customers` — Müşteriler

Yol öneki: **`/api/control/customers`** · Sınır: `bld-control-panel` ·
Ortak kurallar: `00-genel.md`

> ## KVKK — OKUMALAR DA DENETLENİR
>
> Bu, sistemdeki **en geniş kişisel veri yüzeyidir**: ad, telefon, e-posta,
> kurum bilgisi, adres defteri, sipariş geçmişi ve abonelikler tek ekranda
> birleşiyor. Diğer alanlarda yalnız yazmalar denetim izine düşer; burada
> **okumalar da düşer.** Kural ve gerekçesi `00-genel.md` §9'dadır; aşağıda
> uygulama ayrıntısı var.

Kaynak tablo: çekirdek `customers` (+ `bld_` önekli kolonlar), `addresses`,
`orders`, `veykemtu_subscriptions`.

---

## Uçlar

| Metot | Yol | Amaç | İzin | dry_run | Gerekçe | Okuma denetimi |
|---|---|---|---|---|---|---|
| GET | `/` | Müşteri arama (**sayfalı**) | `bld_customers.view` | — | — | ✔ |
| GET | `/{id}` | Tek müşteri | `bld_customers.view` | — | — | ✔ |
| PATCH | `/{id}` | İletişim + kurum etiketleri | `bld_customers.manage` | ✔ | ✔ | — |
| GET | `/{id}/orders` | Sipariş geçmişi (**sayfalı**) | `bld_customers.view` | — | — | ✔ |
| GET | `/{id}/subscriptions` | Abonelikleri | `bld_customers.view` | — | — | ✔ |
| GET | `/{id}/addresses` | Adres defteri | `bld_customers.view` | — | — | ✔ |
| POST | `/{id}/disable` | Hesabı kapat | `bld_customers.manage` | ✔ | ✔ | — |
| POST | `/{id}/enable` | Hesabı aç | `bld_customers.manage` | ✔ | ✔ | — |

`{id}` = `customers.customer_id`.

---

## Okuma denetiminin uygulanışı

Her `GET`:

1. **`actor` sorgu parametresini zorunlu kılar** (2–120 karakter). Eksik ya da
   kısa → `422 VALIDATION_FAILED`, `details = {"field": "actor"}`.
2. `ControlAudit` satırı yazar:

```
actor       = <gelen actor>
action      = "customer.read"
target_type = "customer"
target_id   = <müşteri kimliği>  |  null (liste ucunda)
reason      = "Kişisel veri görüntüleme: /api/control/customers/312"
payload_json= { "path": "/api/control/customers", "filters": {"q": "acme", "page": 2} }
result      = "applied"
```

3. `payload_json` **yalnız süzgeçleri** taşır. Dönen kayıtların kendisi
   yazılmaz — denetim izini ikinci bir müşteri veritabanına çevirirdi.

**Bu ekranlar yoklanmaz.** Panel burada otomatik yenileme kurmaz; her okuma
yöneticinin bilinçli bir eylemidir. 15 saniyede bir yoklayan bir ekran, izi
günde binlerce anlamsız satırla doldurup içindeki gerçek erişimi görünmez
kılardı.

`actor` sorgu dizesinde taşındığı için **imzaya girmez** (kanonik dize sorguyu
dışlar). Sınır bilinçlidir ve `00-genel.md` §9'da yazılıdır.

---

## Şema

| Alan | Tip | Kaynak kolon | Yazılabilir |
|---|---|---|---|
| `customer_id` | int | `customer_id` | — |
| `first_name` | string | `first_name` | ✔ |
| `last_name` | string | `last_name` | ✔ |
| `email` | string | `email` | **ASLA** |
| `telephone` | string\|null | `telephone` | ✔ |
| `status` | bool | `status` | disable/enable uçları |
| `is_activated` | bool | `is_activated` | — |
| `account_type` | `corporate`\|`individual` | `bld_account_type` | — (aşağıya bakın) |
| `org_name` | string\|null | `bld_org_name` | ✔ |
| `tax_office` | string\|null | `bld_tax_office` | ✔ |
| `tax_no` | string\|null | `bld_tax_no` | ✔ |
| `contact_person` | string\|null | `bld_contact_person` | ✔ |
| `org_phone` | string\|null | `bld_org_phone` | ✔ |
| `created_at` | ISO 8601 UTC | `created_at` | — |
| `last_login` | ISO 8601 UTC\|null | `last_login` | — |

**Parola hiçbir uçta, hiçbir biçimde geçmez.** Ne okunur, ne yazılır, ne
sıfırlanır. Parola sıfırlama müşterinin kendi akışıdır (`/api/auth/*`); bir
yönetim panelinden parola yazabilmek, panele erişen herkesin her müşterinin
hesabına girebilmesi demektir.

**E-posta yazılamaz.** E-posta giriş kimliğidir; değiştirmek hesabı devretmek
anlamına gelir ve doğrulama akışı gerektirir. Yanlış yazılmış bir e-posta
müşterinin kendi hesap ekranından ya da destek üzerinden düzeltilir.

> KARAR: `account_type` **okunur, yazılmaz.** Kurumsal sipariş kapısı
> (`CustomerGate`) kalktığı için (iş kararı 2) bu alan artık bir yetki
> belirlemiyor; yalnız geçmiş kayıtların etiketi. Yazılabilir yapmak, kalkmış
> bir kapının anahtarını panelde tutmak olurdu. Kurum alanları
> (`org_name`, `tax_*`, `contact_person`, `org_phone`) **serbest metin
> etiket** olarak kalır ve yazılabilir.

---

## `GET /` — arama

Sorgu parametreleri:

| Ad | Tip | Varsayılan | Not |
|---|---|---|---|
| `actor` | string | — | **Zorunlu** (KVKK) |
| `q` | string | — | Ad, soyad, telefon, e-posta, kurum adı |
| `status` | `active`\|`disabled`\|`all` | `all` | |
| `has_subscription` | bool | — | `true` = aboneliği olanlar |
| `sort` | `name`\|`created`\|`last_order` | `name` | |
| `direction` | `asc`\|`desc` | `asc` | |
| `page` / `per_page` | int | 1 / 25 | tavan 100 |

`q` en az **2 karakter** olmalı → kısa ise `422`. Tek harflik bir arama bütün
müşteri tablosunu döndürürdü; sayfalama onu yavaşlatır ama engellemez.

**Süzgeçsiz istek serbesttir** ve ilk sayfayı döndürür. Listeyi tamamen
kapatmak, "kaç müşterimiz var" gibi meşru bir soruyu cevapsız bırakırdı; asıl
koruma denetim izidir.

```json
{
  "data": [
    {
      "customer_id": 312,
      "first_name": "Mehmet",
      "last_name": "Kaya",
      "email": "mehmet.kaya@acme.com.tr",
      "telephone": "5321234567",
      "status": true,
      "is_activated": true,
      "account_type": "corporate",
      "org_name": "Acme Gıda A.Ş.",
      "order_count": 128,
      "last_order_at": "2026-08-15T18:04:00Z",
      "subscription_count": 1,
      "created_at": "2026-03-02T09:11:00Z"
    }
  ],
  "meta": { "page": 1, "per_page": 25, "total": 214, "last_page": 9 },
  "server_time": "2026-08-16T09:00:00Z"
}
```

**Liste maskelenmez.** Talep listesindeki (`subscriptions.md`) maskeleme
kuralı buraya uygulanmadı ve sebebi somut: yönetici müşteriyi telefonundan
tanır ve maskeli bir listede doğru kaydı seçemez, hepsini tek tek açmak zorunda
kalır — yani her arama için bir düzine denetim satırı doğar. Maskeleme burada
gizliliği artırmaz, izi bozar.

---

## `GET /{id}`

```json
{
  "data": {
    "customer_id": 312,
    "first_name": "Mehmet",
    "last_name": "Kaya",
    "email": "mehmet.kaya@acme.com.tr",
    "telephone": "5321234567",
    "status": true,
    "is_activated": true,
    "account_type": "corporate",
    "org_name": "Acme Gıda A.Ş.",
    "tax_office": "Çankaya",
    "tax_no": "1234567890",
    "contact_person": "Mehmet Kaya",
    "org_phone": "3124445566",
    "created_at": "2026-03-02T09:11:00Z",
    "last_login": "2026-08-15T17:50:00Z",
    "stats": {
      "order_count": 128,
      "cancelled_order_count": 3,
      "total_spent_kurus": 27648000,
      "first_order_at": "2026-03-05T10:00:00Z",
      "last_order_at": "2026-08-15T18:04:00Z",
      "active_subscription_count": 1,
      "unpaid_total_kurus": 640000,
      "address_count": 2
    }
  },
  "server_time": "2026-08-16T09:00:00Z"
}
```

`stats` **burada döner**, ayrı bir uçta değil: müşteri kartını açan yönetici
zaten bu sayıları görmek istiyor ve ayrı bir çağrı ikinci bir denetim satırı
yazardı.

`unpaid_total_kurus` abonelik dönem borçlarından gelir
(`veykemtu_subscription_payments`, `status = pending`). Cari hesap kalktığı
için başka bir borç kaynağı yoktur.

---

## `PATCH /{id}`

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Müşteri telefon numarasını değiştirdi, kayıt güncellendi",
  "dry_run": false,
  "telephone": "5329876543",
  "org_name": "Acme Gıda ve Turizm A.Ş.",
  "contact_person": "Zeynep Demir"
}
```

Kısmi yazar. Yazılabilir alanlar **yalnız**: `first_name`, `last_name`,
`telephone`, `org_name`, `tax_office`, `tax_no`, `contact_person`, `org_phone`.

Başka bir alan gönderilirse istek **tümüyle reddedilir** (`422`,
`details = {"field": "email", "reason": "read_only"}`) — bilinmeyen alanı
sessizce yok saymak, e-posta değiştirdiğini sanan bir yöneticiye "başarılı"
demek olurdu.

Doğrulama:

- `telephone` ve `org_phone`: rakam, boşluk, `+`, `(`, `)`, `-` karakterleri;
  temizlenmiş hâli 10–15 hane. Boş dize → `null`.
- `tax_no`: 10 veya 11 hane rakam ya da `null`. Başka bir uzunluk `422`.
  On/on bir hane ayrımı vergi numarası ile TC kimlik numarasının ikisini de
  kabul etmek içindir.
- Ad ve soyad boş bırakılamaz (`""` → `422`); müşterinin adı sistemde her
  yerde görünüyor.

`payload_json` **eski ve yeni değeri birlikte yazar** ama telefon ve e-posta
**maskelenir**:

```json
{ "changes": [ { "field": "telephone", "from": "532****567", "to": "532****543" } ] }
```

Denetim izi "ne değişti" sorusuna cevap vermeli, kişisel verinin ikinci bir
kopyasını tutmamalı.

```json
{
  "ok": true, "dry_run": false, "audit_id": 2001,
  "data": { },
  "changed": ["telephone", "org_name", "contact_person"]
}
```

---

## `GET /{id}/orders`

Sorgu: `actor` (zorunlu), `status`, `from`, `to`, `page`, `per_page`.

Gövde `orders.md` → `GET /` ile **aynı satır biçimini** kullanır. İki farklı
sipariş şekli tanımlamak, panelin iki ayrı tablo bileşeni yazması demekti.

```json
{
  "data": [ { "id": 8421, "order_number": "BLD-8421", "status": "hazirlaniyor",
              "service_date": "2026-08-16", "total_kurus": 216000, "…": "orders.md ile aynı" } ],
  "meta": { "page": 1, "per_page": 25, "total": 128, "last_page": 6 },
  "server_time": "2026-08-16T09:00:00Z"
}
```

## `GET /{id}/subscriptions`

Gövde `subscriptions.md` → `GET /` satır biçimi. Sayfalanmaz: bir müşterinin
abonelik sayısı tek haneli.

## `GET /{id}/addresses`

```json
{
  "data": [
    {
      "address_id": 704,
      "label": "Merkez ofis",
      "line_1": "Kızılırmak Mah. 1443. Cad. No:12",
      "line_2": "Kat 4",
      "city": "Ankara",
      "district": "Çankaya",
      "neighbourhood": "Kızılırmak",
      "postcode": "06520",
      "latitude": 39.9042,
      "longitude": 32.8597,
      "is_default": true
    }
  ],
  "server_time": "2026-08-16T09:00:00Z"
}
```

**Salt okunur.** Adres yazan bir uç yok: adres siparişe **kopyalanıyor**,
bağlanmıyor (`AddressController` sınıf yorumu) ve defteri panelden düzenlemek
geçmiş siparişlerin adresini değiştirmez — yönetici değiştirdiğini sanır.
Adresi müşteri kendi uygulamasından yönetir.

---

## `POST /{id}/disable` · `POST /{id}/enable`

`customers.status` alanını yazar. Kapalı bir hesap giriş yapamaz ve sipariş
veremez.

```json
{ "actor": "Ayşe Yılmaz", "reason": "Ödenmemiş dönem borcu, hesap geçici kapatıldı" }
```

- Zaten kapalı/açık ise `ok: true`, `409` verilmez.
- **Aktif aboneliği olan** bir hesabı kapatmak `warnings` üretir ama
  engellenmez: abonelik üretimi durmaz (kural hesaba değil aboneliğe bağlı) ve
  yönetici bunu bilmeli.
- Hesap kapatmak **veri silmez.** Silme uçu yoktur ve olmayacaktır: geçmiş
  siparişlerin müşterisi olmayan kayıtlara dönüşmesi, muhasebe ve denetim
  açısından geri alınamaz bir kayıptır. KVKK silme talebi geldiğinde izlenecek
  yol ayrıca belirlenir ve panelden tek tuşla yapılan bir iş değildir.

```json
{
  "ok": true, "dry_run": false, "audit_id": 2010,
  "data": { "customer_id": 312, "status": false },
  "warnings": [ { "code": "active_subscriptions", "subscription_ids": [18] } ]
}
```

---

## Denetim eylemleri

| `action` | Uç | `target_type` / `target_id` | `result` |
|---|---|---|---|
| `customer.read` | Her `GET` | `customer` / id veya `null` | `applied` |
| `customer.update` | `PATCH /{id}` | `customer` / id | normal kabuk |
| `customer.disable` | `POST /{id}/disable` | `customer` / id | normal kabuk |
| `customer.enable` | `POST /{id}/enable` | `customer` / id | normal kabuk |

`customer.read` satırları `ControlController::write()` kabuğundan **geçmez**
(okuma, kuru provası yok); doğrudan `ControlAudit::record(...,
RESULT_APPLIED)` ile yazılır. Bu, sözleşmedeki tek "okuma denetim satırı"
biçimidir ve başka hiçbir alanda tekrarlanmaz.
