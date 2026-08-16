# `control/cms` — Site içeriği

Yol öneki: **`/api/control/cms`** · Sınır: `bld-control-panel` ·
Ortak kurallar: `00-genel.md`

Kurumsal sitenin (Next.js) beslendiği içerik. Site bu verileri
`GET /api/site-content` ile çeker ve ISR ile önbelleğe alır; içerik değişince
`revalidate` ile yeniden çizilir.

Kaynak tablolar: `veykemtu_site_content`, `veykemtu_site_services`,
`veykemtu_site_posts`. Model: `Models\SiteContent`, `SiteService`, `SitePost`.

---

## Uçlar

| Metot | Yol | Amaç | İzin | dry_run | Gerekçe |
|---|---|---|---|---|---|
| GET | `/content` | Tüm anahtarlar | `bld_cms.view` | — | — |
| PUT | `/content/{key}` | Tek anahtarı yaz | `bld_cms.manage` | ✔ | ✔ |
| GET | `/services` | Hizmet listesi | `bld_cms.view` | — | — |
| POST | `/services` | Yeni hizmet | `bld_cms.manage` | ✔ | ✔ |
| PATCH | `/services/{id}` | Hizmet güncelle | `bld_cms.manage` | ✔ | ✔ |
| DELETE | `/services/{id}` | Hizmeti sil | `bld_cms.manage` | ✔ | ✔ |
| GET | `/posts` | Yazı listesi (**sayfalı**) | `bld_cms.view` | — | — |
| POST | `/posts` | Yeni yazı | `bld_cms.manage` | ✔ | ✔ |
| PATCH | `/posts/{id}` | Yazı güncelle | `bld_cms.manage` | ✔ | ✔ |
| DELETE | `/posts/{id}` | Yazıyı sil | `bld_cms.manage` | ✔ | ✔ |
| POST | `/revalidate` | Siteyi yeniden çizdir | `bld_cms.manage` | ✔ | ✔ |

`GET /content/{key}` **yoktur.** Yedi anahtarın tamamı birlikte okunur; tek
anahtar için ayrı bir uç, panelin yedi istek atması demekti.

---

## İçerik anahtarları

Anahtarlar **sabittir** ve `SiteContent::KEYS` listesinden gelir. Yeni anahtar
uydurulamaz; listede olmayan bir anahtara `PUT` → `404 NOT_FOUND`.

| Anahtar | İçerik | `value` şekli |
|---|---|---|
| `brand` | Marka adı, slogan, logo metni | nesne |
| `contact` | Telefon, e-posta, adres, çalışma saatleri, sosyal | nesne |
| `company` | Kurumsal metinler (hakkımızda, misyon) | nesne |
| `faq` | Sık sorulan sorular | dizi |
| `sectors` | Hizmet verilen sektörler | dizi |
| `menus` | Menü çözümleri | dizi |
| `quality` | Kalite zinciri adımları | dizi |

`value` şemasız bir JSON'dur ve **sunucu içeriğini doğrulamaz** — yalnız
geçerli JSON olduğunu ve boyutunu denetler. Şema koymak, site yeni bir alan
eklediğinde sunucu göçü gerektirirdi; oysa bu tablonun tek amacı, siteye
şekilsiz içerik taşımaktı.

### `GET /content`

```json
{
  "data": {
    "brand": {
      "value": { "name": "BLD Catering", "tagline": "Kurumsal mutfak çözümleri" },
      "updated_at": "2026-08-02T10:00:00Z"
    },
    "contact": {
      "value": {
        "phone": "3124445566",
        "email": "info@bld.example",
        "address": "Kızılırmak Mah. 1443. Cad. No:12, Çankaya / Ankara",
        "working_hours": "Hafta içi 08:00 – 18:00"
      },
      "updated_at": "2026-08-02T10:00:00Z"
    },
    "faq": {
      "value": [ { "q": "Minimum sipariş adediniz var mı?", "a": "20 porsiyondan başlıyoruz." } ],
      "updated_at": "2026-07-28T09:00:00Z"
    },
    "company": { "value": {}, "updated_at": null },
    "sectors": { "value": [], "updated_at": null },
    "menus": { "value": [], "updated_at": null },
    "quality": { "value": [], "updated_at": null }
  },
  "meta": { "keys": ["brand","contact","company","faq","sectors","menus","quality"] },
  "server_time": "2026-08-16T09:00:00Z"
}
```

**Kaydı olmayan anahtar da döner**, boş değer ve `updated_at: null` ile. Eksik
anahtarı atlamak, panelin "bu alan yok mu, yoksa boş mu" sorusunu kendi
cevaplamasını gerektirirdi.

### `PUT /content/{key}`

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "İletişim telefonu güncellendi",
  "dry_run": false,
  "value": {
    "phone": "3124445577",
    "email": "info@bld.example",
    "address": "Kızılırmak Mah. 1443. Cad. No:12, Çankaya / Ankara",
    "working_hours": "Hafta içi 08:00 – 18:00"
  },
  "revalidate": true
}
```

- `value` **tam değerdir**, birleştirilmez. Kısmi yazma, iç içe geçmiş JSON'da
  "hangi seviyede birleştiriliyor" sorusunu doğururdu ve iki farklı cevabı olan
  bir kural, sessizce veri kaybettirir.
- Boyut sınırı **256 KB** (serileştirilmiş). Aşarsa `422`.
- `revalidate` (varsayılan `true`): yazma sonrası siteyi yeniden çizdirir.
  `false` ile art arda birkaç anahtar yazıp sonunda bir kez çizdirmek mümkün.

```json
{
  "ok": true, "dry_run": false, "audit_id": 2201,
  "data": { "key": "contact", "updated_at": "2026-08-16T09:00:00Z" },
  "revalidated": true
}
```

`payload_json` **eski ve yeni değerin tamamını yazmaz**, yalnız
`{"key": "contact", "bytes": 412, "changed_top_level_keys": ["phone"]}`.
İçeriğin tam kopyasını denetime yazmak, tabloyu bir sürüm deposu hâline
getirirdi.

---

## Hizmetler

`veykemtu_site_services` — site menüsündeki hizmet sayfaları.

| Alan | Tip | Kolon | Not |
|---|---|---|---|
| `id` | int | `id` | |
| `slug` | string | `slug` (96, unique) | Adres parçası |
| `title` | string | `title` (160) | |
| `summary` | string | `summary` (400) | Kart metni |
| `intro` | string | `intro` (text) | |
| `icon` | string | `icon` (48) | Lucide ikon adı |
| `body_html` | string\|null | `body_html` | **Kayıtta temizlenir** |
| `audience` | array | `audience` (json) | Kimler için |
| `how_it_works` | array | `how_it_works` (json) | Nasıl işler |
| `benefits` | array | `benefits` (json) | Ne kazandırır |
| `menu_planning` | string | `menu_planning` (text) | |
| `quote_needs` | array | `quote_needs` (json) | Teklif için gerekenler |
| `sort_order` | int | `sort_order` | |
| `is_published` | bool | `is_published` | |
| `created_at` / `updated_at` | ISO 8601 UTC | | |

### `GET /services`

Sayfalanmaz — hizmet sayısı onlarla ifade edilir.

Sorgu: `published` (`true`\|`false`\|`all`, varsayılan `all`).

```json
{
  "data": [
    {
      "id": 3, "slug": "kurumsal-catering", "title": "Kurumsal Catering",
      "summary": "Ofis ve fabrikalara günlük sıcak yemek",
      "intro": "Her sabah taze pişirilen menüler…",
      "icon": "Building2",
      "body_html": "<p>…</p>",
      "audience": ["Ofisler", "Fabrikalar"],
      "how_it_works": ["Menü planlanır", "Sabah teslim edilir"],
      "benefits": ["Sabit fiyat", "Tek fatura"],
      "menu_planning": "Haftalık menü birlikte belirlenir.",
      "quote_needs": ["Kişi sayısı", "Teslim adresi"],
      "sort_order": 10, "is_published": true,
      "created_at": "2026-06-01T08:00:00Z", "updated_at": "2026-08-02T10:00:00Z"
    }
  ],
  "server_time": "2026-08-16T09:00:00Z"
}
```

### `POST /services`

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Yeni hizmet sayfası yayına hazırlandı",
  "dry_run": false,
  "slug": "etkinlik-catering",
  "title": "Etkinlik Catering",
  "summary": "Toplantı, açılış ve organizasyonlar için",
  "intro": "…",
  "icon": "PartyPopper",
  "body_html": "<p>…</p>",
  "audience": ["Ajanslar"],
  "how_it_works": ["Brief alınır"],
  "benefits": ["Anahtar teslim"],
  "menu_planning": "…",
  "quote_needs": ["Kişi sayısı", "Tarih"],
  "sort_order": 40,
  "is_published": false,
  "revalidate": true
}
```

- `slug`: `^[a-z0-9]+(-[a-z0-9]+)*$`, 2–96 karakter, **tekil** → çakışırsa
  `409 CONFLICT`.
- `body_html` **kayıt anında temizlenir** (`HtmlSanitizer`). İzin listesi
  dışındaki etiketler ve öznitelikler düşer; bu, `SiteService` modelinin
  mutator'ında olur, yani içeriğin nereden geldiği (uç, komut, admin formu)
  fark etmez. Yanıt **temizlenmiş hâli** döner ve panel onu gösterir —
  gönderdiğini geri okumayan bir editör, yaptığı yapıştırmanın kaybolduğunu
  fark etmez.
- Dizi alanları (`audience`, `how_it_works`, `benefits`, `quote_needs`) düz
  string listesidir; her eleman en çok 300 karakter, liste en çok 20 eleman.
- `icon` bilinmeyen bir ad olabilir; site onu sessizce varsayılana düşürür ve
  boş kutu göstermez. Sunucu ikon listesini doğrulamaz — liste sitede yaşıyor
  ve sunucuya kopyalamak iki yerde iki gerçek üretirdi.

### `PATCH /services/{id}`

Kısmi. `slug` **yazılabilir** ama yanıt uyarı taşır:

```json
{
  "ok": true, "dry_run": false, "audit_id": 2211,
  "data": { },
  "warnings": [ { "code": "slug_changed", "from": "kurumsal-catering", "to": "kurumsal-yemek",
                  "note": "Eski adrese verilen bağlantılar kırılacak." } ]
}
```

### `DELETE /services/{id}`

Gerçek silme. Hizmet kayıtları başka hiçbir tabloya bağlı değil; yumuşak silme
için `is_published = false` zaten var ve gerçekten silmek isteyen yönetici onu
kastediyor.

```json
{ "actor": "Ayşe Yılmaz", "reason": "Bu hizmet artık verilmiyor, sayfa kaldırıldı", "revalidate": true }
```

---

## Yazılar

`veykemtu_site_posts` — bilgi merkezi.

| Alan | Tip | Kolon |
|---|---|---|
| `id` | int | `id` |
| `slug` | string | `slug` (96, unique) |
| `title` | string | `title` (200) |
| `description` | string | `description` (400) |
| `category` | string | `category` (64) |
| `body_html` | string | `body_html` (temizlenir) |
| `published_at` | `YYYY-MM-DD` | `published_at` |
| `reading_minutes` | int\|null | `reading_minutes` |
| `reading_minutes_effective` | int | *türetilir* |
| `is_published` | bool | `is_published` |
| `created_at` / `updated_at` | ISO 8601 UTC | |

`published_at` bir **tarihtir, an değil**: yayın günü yazarın kararıdır ve
`created_at` ile aynı olmak zorunda değil (geçmişe tarihli yazı, ileri tarihli
planlama).

`reading_minutes_effective` = elle girilmişse o, yoksa gövdeden hesaplanmış
değer (`SitePost::readingMinutes()`). İkisini ayrı vermek, panelin "hesaplandı"
ipucunu gösterebilmesi içindir.

### `GET /posts`

Sorgu: `q`, `category`, `published` (`true`\|`false`\|`all`), `page`,
`per_page`. Varsayılan sıra: `published_at` azalan, sonra `id` azalan.

```json
{
  "data": [
    {
      "id": 21, "slug": "toplu-yemekte-soguk-zincir", "title": "Toplu yemekte soğuk zincir",
      "description": "Taşıma sırasında sıcaklık nasıl korunur?",
      "category": "gida-guvenligi",
      "body_html": "<p>…</p>",
      "published_at": "2026-08-01",
      "reading_minutes": null, "reading_minutes_effective": 4,
      "is_published": true,
      "created_at": "2026-07-30T12:00:00Z", "updated_at": "2026-08-01T07:00:00Z"
    }
  ],
  "meta": { "page": 1, "per_page": 25, "total": 21, "last_page": 1,
            "categories": ["gida-guvenligi", "menu-planlama"] },
  "server_time": "2026-08-16T09:00:00Z"
}
```

`meta.categories` mevcut kategorilerin **damıtılmış listesidir** — kategori
ayrı bir tablo değil, serbest bir metin alanı; panel açılır listeyi buradan
doldurur ve yönetici her seferinde yeni bir kategori uydurmaz.

### `POST /posts` · `PATCH /posts/{id}` · `DELETE /posts/{id}`

Hizmetlerle aynı kurallar: `slug` tekil ve kalıplı, `body_html` kayıtta
temizlenir, `slug` değişimi uyarı üretir, silme gerçek silmedir.

`body_html` **zorunludur** ve boş olamaz (`text` kolonu `NOT NULL`); boş gövdeli
bir yazı, sitede başlığı olan boş bir sayfa üretirdi.

---

## `POST /revalidate`

Next.js sitesinin ISR önbelleğini boşaltır. Sunucu tarafında
`Services\SiteRevalidator::revalidate()` çağrılır.

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "İçerik güncellendi, site yeniden çizdirildi",
  "dry_run": false,
  "paths": null
}
```

- `paths`: `null` (tümü) ya da yol listesi (`["/hizmetler", "/blog/…"]`).
  En çok 20 yol; her biri `/` ile başlamalı.
- Diğer uçlardaki `revalidate: true` bayrağı bu ucun **aynısını** çağırır; bu
  uç, bayrağı `false` bırakıp toplu çizdirmek isteyen yönetici içindir.

```json
{
  "ok": true, "dry_run": false, "audit_id": 2230,
  "data": { "requested": "all", "status": "ok", "duration_ms": 340 }
}
```

Yeniden çizdirme **başarısız olursa istek başarısız sayılmaz**:

```json
{
  "ok": true, "dry_run": false, "audit_id": 2231,
  "data": { "requested": "all", "status": "failed", "error": "Bağlantı zaman aşımı (3 sn)" },
  "warnings": [ { "code": "revalidate_failed" } ]
}
```

Gerekçe: içerik zaten yazıldı. Çizdirme hatası yüzünden `500` döndürmek,
yöneticiye "kaydedilmedi" dedirtir ve o kaydı ikinci kez yazar; oysa tek eksik,
sitenin birkaç dakika sonra kendiliğinden tazelenecek olması.
`SiteRevalidator` zaman aşımı **3 saniyedir** ve paneli bekletmez.

---

## Denetim eylemleri

| `action` | Uç | `target_type` / `target_id` |
|---|---|---|
| `cms.content.update` | `PUT /content/{key}` | `site_content` / `null` |
| `cms.service.create` | `POST /services` | `site_service` / yeni id |
| `cms.service.update` | `PATCH /services/{id}` | `site_service` / id |
| `cms.service.delete` | `DELETE /services/{id}` | `site_service` / id |
| `cms.post.create` | `POST /posts` | `site_post` / yeni id |
| `cms.post.update` | `PATCH /posts/{id}` | `site_post` / id |
| `cms.post.delete` | `DELETE /posts/{id}` | `site_post` / id |
| `cms.revalidate` | `POST /revalidate` | `null` / `null` |

`cms.content.update` satırında `target_id` yoktur (`veykemtu_site_content`
birincil anahtarı bir metin); anahtar `payload_json.key` içindedir. Aynı durum
`sms.md` şablonlarında da geçerli.
