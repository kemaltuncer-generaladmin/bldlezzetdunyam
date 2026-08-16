# `control/notifications` — Uygulama-içi duyuru

Yol öneki: **`/api/control/notifications`** · Sınır: `bld-control-panel` ·
Ortak kurallar: `00-genel.md`

Push bildirimi (FCM) **yoktur** (iş kararı 11). Müşteri uygulamasında ve
sitede gösterilen duyurular buradan yönetilir: bakım bildirimi, tatil
duyurusu, yeni hizmet tanıtımı.

SMS'ten farkı **ittirilmemesidir**: müşteri uygulamayı açtığında görür. Acil
bir şey duyurulacaksa SMS kullanılır (`sms.md`); duyuru, uygulamayı açanı
bilgilendirir.

> **BAŞKA AJANIN KULVARI — iki yeni tablo gerekiyor.**
>
> `veykemtu_notifications`: `id`, `title` (string 160), `body` (text),
> `level` (string 16: `info`\|`warning`\|`critical`),
> `audience` (string 24: `all`\|`customers`\|`subscribers`),
> `status` (string 16: `draft`\|`published`\|`archived`, indeks),
> `starts_at` (timestamp, nullable), `ends_at` (timestamp, nullable),
> `action_label` (string 60, nullable), `action_url` (string 255, nullable),
> `dismissible` (boolean, default true),
> `published_at` (timestamp, nullable), `created_by_actor` (string 120),
> `created_at`, `updated_at`.
>
> `veykemtu_notification_reads`: `id`, `notification_id` (indeks),
> `customer_id` (indeks), `seen_at` (timestamp), `dismissed_at` (timestamp,
> nullable), `UNIQUE(notification_id, customer_id)`.

> **BAŞKA AJANIN KULVARI — müşteri ucu gerekiyor.** Duyuruların müşteriye
> ulaşması için `GET /api/notifications` (müşteri kapsamı) ve
> `POST /api/notifications/{id}/seen` uçları gerekir. Bu sözleşme yalnız
> yönetim tarafını dondurur.

---

## Uçlar

| Metot | Yol | Amaç | İzin | dry_run | Gerekçe |
|---|---|---|---|---|---|
| GET | `/` | Duyuru listesi (**sayfalı**) | `bld_comms.view` | — | — |
| POST | `/` | Yeni duyuru (taslak) | `bld_comms.manage` | ✔ | ✔ |
| PATCH | `/{id}` | Duyuru güncelle | `bld_comms.manage` | ✔ | ✔ |
| DELETE | `/{id}` | Arşivle (**yumuşak**) | `bld_comms.manage` | ✔ | ✔ |
| POST | `/{id}/publish` | Yayınla | `bld_comms.manage` | ✔ | ✔ |
| GET | `/{id}/stats` | Görülme istatistiği | `bld_comms.view` | — | — |

`{id}` = `veykemtu_notifications.id`.

`POST /{id}/unpublish` **yoktur.** Yayından kaldırmanın yolu `ends_at`'i geçmişe
çekmek ya da arşivlemektir; üçüncü bir yol, "duyuru neden görünmüyor" sorusunun
üç ayrı cevabı olması demekti.

---

## Şema

| Alan | Tip | Kolon | Not |
|---|---|---|---|
| `id` | int | `id` | |
| `title` | string | `title` (160) | |
| `body` | string | `body` (text) | **Düz metin**, HTML değil |
| `level` | `info`\|`warning`\|`critical` | `level` | Rozet rengi |
| `audience` | `all`\|`customers`\|`subscribers` | `audience` | |
| `status` | `draft`\|`published`\|`archived` | `status` | |
| `starts_at` | ISO 8601 UTC\|null | `starts_at` | `null` = yayınla birlikte |
| `ends_at` | ISO 8601 UTC\|null | `ends_at` | `null` = süresiz |
| `action_label` | string\|null | `action_label` (60) | Düğme metni |
| `action_url` | string\|null | `action_url` (255) | |
| `dismissible` | bool | `dismissible` | Müşteri kapatabilir mi |
| `published_at` | ISO 8601 UTC\|null | `published_at` | |
| `live` | bool | *türetilir* | Şu an gerçekten görünüyor mu |
| `created_at` / `updated_at` | ISO 8601 UTC | | |

`body` **düz metindir, HTML değil.** Duyuru üç uygulamada birden gösteriliyor
(Next.js, Flutter müşteri, ileride başkaları) ve HTML'i üçünde tutarlı çizmek
imkânsız; Flutter tarafında ayrıca bir HTML işleyici bağımlılığı gerektirirdi.
Satır sonu `\n` desteklenir, biçimlendirme yok.

`live` sunucuda hesaplanır:
`status = published` **ve** (`starts_at` boş veya geçmiş) **ve** (`ends_at` boş
veya gelecek). İstemcide hesaplansaydı saati kaymış bir panelde duyuru bir gün
erken "bitmiş" görünürdü.

### `audience` ne demek

| Değer | Kim görür |
|---|---|
| `all` | Herkes — giriş yapmamış ziyaretçi dâhil (site) |
| `customers` | Giriş yapmış müşteriler |
| `subscribers` | Aktif aboneliği olan müşteriler |

`all` duyurusu **istatistik üretmez** (`seen_count` hep 0 kalır): giriş
yapmamış ziyaretçinin kimliği yok ve okunma kaydı yazılamaz. Panel bunu
`stats` yanıtında açıkça söyler.

---

## `GET /` — liste

Sorgu: `status`, `audience`, `level`, `live` (bool), `q`, `page`, `per_page`.
Varsayılan sıra: `published_at` azalan, sonra `id` azalan; taslaklar en üstte.

```json
{
  "data": [
    {
      "id": 12,
      "title": "30 Ağustos'ta kapalıyız",
      "body": "30 Ağustos Zafer Bayramı nedeniyle üretim yapılmayacaktır.\nSiparişlerinizi 29 Ağustos'a kadar iletebilirsiniz.",
      "level": "warning",
      "audience": "customers",
      "status": "published",
      "starts_at": "2026-08-20T00:00:00Z",
      "ends_at": "2026-08-31T00:00:00Z",
      "action_label": null,
      "action_url": null,
      "dismissible": true,
      "published_at": "2026-08-16T09:00:00Z",
      "live": false,
      "seen_count": 0,
      "created_at": "2026-08-16T08:55:00Z",
      "updated_at": "2026-08-16T09:00:00Z"
    }
  ],
  "meta": { "page": 1, "per_page": 25, "total": 12, "last_page": 1, "live_count": 1 },
  "server_time": "2026-08-16T09:00:00Z"
}
```

`meta.live_count` **şu an gerçekten görünen** duyuru sayısıdır. Panel bunu
rozet olarak gösterir; "üç duyuru yayında" demek ile "üçü de tarih aralığının
dışında" demek arasındaki farkı görmeyen yönetici, duyurusunun neden
görünmediğini anlayamaz.

---

## `POST /` — yeni duyuru

**Her zaman `draft` doğar.** Yayın ayrı bir eylemdir.

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Bayram kapanışı duyurusu hazırlandı",
  "dry_run": false,
  "title": "30 Ağustos'ta kapalıyız",
  "body": "30 Ağustos Zafer Bayramı nedeniyle üretim yapılmayacaktır.",
  "level": "warning",
  "audience": "customers",
  "starts_at": "2026-08-20T00:00:00Z",
  "ends_at": "2026-08-31T00:00:00Z",
  "action_label": null,
  "action_url": null,
  "dismissible": true
}
```

Doğrulama:

- `title` 2–160, `body` 2–2000 karakter.
- `ends_at` `starts_at`'tan sonra olmalı; ikisi de `null` olabilir.
- `ends_at` geçmişte olamaz → `422`. Doğduğu anda bitmiş bir duyuru,
  yöneticinin fark etmediği bir hatadır.
- `action_url` verilirse `action_label` de zorunlu (ve tersi) → `422`.
  Etiketsiz bir düğme çizilemez, adressiz bir etiket tıklanamaz.
- `action_url` **`https://` ya da uygulama-içi göreli yol (`/`) olmalı**;
  `http://`, `javascript:` ve `data:` reddedilir. Duyuru üç istemcide birden
  açılıyor ve güvenilmeyen bir şema en az birinde çalıştırılabilir olurdu.
- `dismissible: false` yalnız `level = critical` ile birlikte kullanılabilir →
  aksi hâlde `422`. Kapatılamayan bir bilgilendirme duyurusu, uygulamayı
  kullanılamaz hâle getirir.

Yanıt `201`, `data` = tam duyuru.

---

## `PATCH /{id}`

Kısmi. Yazılabilir: `title`, `body`, `level`, `audience`, `starts_at`,
`ends_at`, `action_label`, `action_url`, `dismissible`.

`status` yazılamaz (kendi uçları var).

**Yayınlanmış bir duyuru düzenlenebilir** ve bu bilinçlidir: yazım hatası
düzeltmek, tarihi uzatmak gerçek ihtiyaçlar. Ama `audience` değişimi uyarı
üretir:

```json
{
  "ok": true, "dry_run": false, "audit_id": 2401,
  "data": { },
  "warnings": [
    { "code": "audience_changed_after_publish", "from": "customers", "to": "subscribers",
      "note": "Duyuruyu daha önce görmüş 84 müşteriden 61'i artık kapsam dışında." }
  ]
}
```

Görülme kayıtları **silinmez**: kapsam daralınca kimin gördüğü bilgisi
kaybolmamalı.

---

## `POST /{id}/publish`

```json
{ "actor": "Ayşe Yılmaz", "reason": "Bayram duyurusu yayına alındı" }
```

Ön denetimler (kuru provada da koşar):

- `status` `draft` ya da `archived` olmalı; zaten `published` ise
  `409 CONFLICT`.
- `ends_at` geçmişte ise `422`,
  `details = {"reason": "already_expired", "ends_at": "..."}`.

`published_at` **ilk yayında yazılır ve sonra değişmez.** Arşivden geri
yayınlanan bir duyurunun ilk yayın tarihi korunur; "bu duyuru ne zamandır
duruyor" sorusunun cevabı ilk yayındır.

```json
{
  "ok": true, "dry_run": false, "audit_id": 2410,
  "data": {
    "id": 12, "status": "published", "published_at": "2026-08-16T09:00:00Z",
    "live": false, "live_from": "2026-08-20T00:00:00Z",
    "estimated_audience": 214
  }
}
```

`live_from`, `starts_at` gelecekteyse doludur ve panelin "yayınlandı ama henüz
görünmüyor" mesajını yazmasını sağlar — yayınla düğmesine basıp hiçbir şey
görmeyen yönetici, aksi hâlde ikinci kez basardı.

---

## `DELETE /{id}` — arşivle

Yumuşak: `status = archived`. Satır silinmez.

```json
{ "actor": "Ayşe Yılmaz", "reason": "Duyuru güncelliğini yitirdi, arşivlendi" }
```

Arşivlenen duyuru **anında görünmez olur**, `ends_at` beklenmez. Görülme
kayıtları kalır ve `stats` çalışmaya devam eder.

Gerçek silme ucu yoktur: bir duyurunun kaç kişiye ulaştığı, sonradan sorulan
bir sorudur ve kaydı silinmiş bir duyuru o soruyu cevapsız bırakır.

```json
{ "ok": true, "dry_run": false, "audit_id": 2420, "data": { "id": 12, "status": "archived" } }
```

---

## `GET /{id}/stats`

```json
{
  "data": {
    "id": 12,
    "status": "published",
    "audience": "customers",
    "audience_size": 214,
    "seen_count": 84,
    "dismissed_count": 51,
    "seen_rate": 0.39,
    "first_seen_at": "2026-08-20T06:12:00Z",
    "last_seen_at": "2026-08-24T18:40:00Z",
    "trackable": true,
    "daily": [
      { "date": "2026-08-20", "seen": 46 },
      { "date": "2026-08-21", "seen": 22 }
    ]
  },
  "server_time": "2026-08-16T09:00:00Z"
}
```

- `audience_size` **şu anki** kitle büyüklüğüdür, yayın anındaki değil. Müşteri
  sayısı artıyor ve donmuş bir payda, oranı zamanla yanlış gösterirdi.
- `seen_rate` = `seen_count / audience_size`, iki basamak. `audience_size` sıfır
  ise `null`.
- `dismissed_count` yalnız `dismissible: true` duyurularda anlamlıdır.
- `trackable: false` → `audience = all`. O durumda `seen_count`, `seen_rate` ve
  `daily` **`null`** döner (sıfır değil): sıfır "kimse görmedi" demektir, `null`
  "ölçülemiyor". İkisini karıştırmak, çalışan bir duyuruyu başarısız
  gösterirdi.
- `daily` en fazla **90 gün** taşır.

---

## Denetim eylemleri

| `action` | Uç | `target_type` / `target_id` |
|---|---|---|
| `notification.create` | `POST /` | `notification` / yeni id |
| `notification.update` | `PATCH /{id}` | `notification` / id |
| `notification.publish` | `POST /{id}/publish` | `notification` / id |
| `notification.archive` | `DELETE /{id}` | `notification` / id |

`payload_json` başlığı ve kitleyi taşır, gövdenin tamamını değil
(`{"title": "...", "audience": "customers", "body_length": 118}`).
