# `control/menu` — Günlük menü takvimi

Yol öneki: **`/api/control/menu`** · Sınır: `bld-control-panel` ·
Ortak kurallar: `00-genel.md`

Satılan şey sabit bir katalog değil, gün gün girilen menüdür. Bu alan o günleri
kurar, yayınlar ve stok tavanını yönetir. Ürünlerin kendisi `products.md`
alanındadır — burada yalnız "hangi gün, hangi üründen, kaç porsiyon, ne fiyata"
sorusu vardır.

Kaynak tablolar: `veykemtu_daily_menus`, `veykemtu_daily_menu_items`.
Model: `Models\DailyMenu`, `Models\DailyMenuItem`.

---

## Uçlar

| Metot | Yol | Amaç | İzin | dry_run | Gerekçe |
|---|---|---|---|---|---|
| GET | `/calendar?from=&to=` | Tarih aralığının gün özeti | `bld_menu.view` | — | — |
| GET | `/days/{date}` | Tek günün tam menüsü | `bld_menu.view` | — | — |
| POST | `/days` | Yeni gün oluştur (taslak) | `bld_menu.manage` | ✔ | ✔ |
| PATCH | `/days/{date}` | Gün başlığı/fiyatı/notu | `bld_menu.manage` | ✔ | ✔ |
| DELETE | `/days/{date}` | Günü sil (yalnız taslak) | `bld_menu.manage` | ✔ | ✔ |
| POST | `/days/{date}/publish` | Yayınla | `bld_menu.manage` | ✔ | ✔ |
| POST | `/days/{date}/unpublish` | Taslağa çek | `bld_menu.manage` | ✔ | ✔ |
| POST | `/days/{date}/items` | Kalem ekle | `bld_menu.manage` | ✔ | ✔ |
| PATCH | `/days/{date}/items/{item}` | Kalem güncelle | `bld_menu.manage` | ✔ | ✔ |
| DELETE | `/days/{date}/items/{item}` | Kalem sil | `bld_menu.manage` | ✔ | ✔ |
| GET | `/days/{date}/stock` | Gün ve kalem stok durumu | `bld_menu.view` | — | — |
| PUT | `/days/{date}/stock` | Stok tavanlarını yaz | `bld_menu.manage` | ✔ | ✔ |
| POST | `/days/{date}/duplicate` | Günü başka güne kopyala | `bld_menu.manage` | ✔ | ✔ |

`{date}` yol parçası **her zaman `YYYY-MM-DD`**. Gün kimliği (`id`) yola
konmaz: yönetici takvimden bir güne tıklıyor, kimliği ezberlemiyor. Ayrıca
`(location_id, menu_date)` zaten tekil (`veykemtu_daily_menu_essiz`), yani tarih
tek başına bir anahtar.

`{item}` = `veykemtu_daily_menu_items.id`.

Hepsinde isteğe bağlı `location_id` (int) vardır; verilmezse **varsayılan
vitrin** (`Location::getDefault()`) kullanılır. Faz 1 tek vitrindir ama alan
bugünden sözleşmede: sonradan eklemek her istemciyi kırardı.

---

## Şema

### Gün (`DailyMenuDay`)

| Alan | Tip | Kaynak kolon | Not |
|---|---|---|---|
| `id` | int | `id` | |
| `location_id` | int | `location_id` | |
| `date` | `YYYY-MM-DD` | `menu_date` | |
| `title` | string\|null | `title` (120) | |
| `description` | string\|null | `description` (500) | Müşteriye görünür |
| `internal_note` | string\|null | `internal_note` (255) | **Müşteriye gitmez** |
| `package_price_kurus` | int\|null | `package_price_kurus` | `null` = paket satılmıyor |
| `components_sellable` | bool | `components_sellable` | `false` = yalnız paket |
| `status` | `draft`\|`published` | `status` | |
| `cutoff_time` | `HH:mm`\|null | `cutoff_time` **(yeni kolon)** | `null` = genel kesim saati |
| `capacity_total` | int\|null | `capacity_total` **(yeni kolon)** | Gün toplam tavanı, porsiyon |
| `image_path` | string\|null | `image_path` | Göreli yol |
| `items_total_kurus` | int | *türetilir* | `DailyMenu::itemsTotalKurus()` |
| `published_at` | ISO 8601 UTC\|null | `published_at` | |
| `created_at` | ISO 8601 UTC | `created_at` | |
| `updated_at` | ISO 8601 UTC | `updated_at` | |
| `items` | list\<DailyMenuItem\> | bağıntı | `sort_order asc, id asc` |

`published_by` ve `created_by` **dönmez**: bunlar TastyIgniter yönetici
kimlikleri ve Kontrol Merkezi kullanıcılarının BLD'de hesabı yok; anlamsız bir
sayı gösterirdi. "Kim yayınladı" sorusunun cevabı denetim izidir
(`action = menu.publish`).

### Kalem (`DailyMenuItem`)

| Alan | Tip | Kaynak kolon | Not |
|---|---|---|---|
| `id` | int | `id` | |
| `menu_id` | int | `menu_id` | Çekirdek `menus.menu_id` |
| `name` | string | *türetilir* | `label` doluysa o, yoksa `menus.menu_name` |
| `label` | string\|null | `label` (120) | "Günün Çorbası: Mercimek" |
| `quantity` | int | `quantity` | Bir **pakette** kaç porsiyon |
| `sort_order` | int | `sort_order` | Çorba → ana yemek → pilav → tatlı |
| `price_override_kurus` | int\|null | `price_override_kurus` | `null` = ürünün kendi fiyatı |
| `unit_price_kurus` | int | *türetilir* | `effectiveUnitPriceKurus()` |
| `is_required` | bool | `is_required` | Zorunlu kalem tükenirse paket düşer |
| `sellable_alone` | bool | `sellable_alone` | `false` = yalnız pakette |
| `capacity` | int\|null | `capacity` **(yeni kolon)** | Ürün bazlı tavan |
| `sold_out` | bool | *türetilir* | `veykemtu_menu_soldout` bugünkü işaret |

> **BAŞKA AJANIN KULVARI — göç gerekiyor.** Üç kolon bugün yok ve eklenmeli:
> `veykemtu_daily_menus.cutoff_time` (`time`, nullable),
> `veykemtu_daily_menus.capacity_total` (`unsignedInteger`, nullable),
> `veykemtu_daily_menu_items.capacity` (`unsignedInteger`, nullable).
> Üçü de nullable ve `null` = "sınır yok / genel ayar geçerli"; mevcut satırlar
> bu göçten etkilenmez.

---

## `GET /calendar`

Takvim ızgarasını besler. Gün başına **kalem listesi dönmez** — bir aylık
görünümde otuz günün kalemlerini taşımak, ekranın hiç göstermediği veriyi
yollamak olurdu.

Sorgu: `from` (zorunlu, `YYYY-MM-DD`), `to` (zorunlu), `location_id`
(opsiyonel). Aralık en çok **92 gün** (`DailyMenuService::MAX_CALENDAR_DAYS`);
aşarsa `422 VALIDATION_FAILED`.

```json
{
  "data": [
    {
      "date": "2026-08-17",
      "id": 214,
      "status": "published",
      "title": "Ev Yemeği Menüsü",
      "package_price_kurus": 18000,
      "item_count": 4,
      "capacity_total": 120,
      "sold_total": 86,
      "remaining_total": 34,
      "cutoff_time": "08:00",
      "cutoff_passed": true,
      "closed": false,
      "closed_reason": null,
      "orderable": false,
      "not_orderable_reason": "cutoff_passed"
    },
    {
      "date": "2026-08-22",
      "id": null,
      "status": null,
      "title": null,
      "package_price_kurus": null,
      "item_count": 0,
      "capacity_total": null,
      "sold_total": 0,
      "remaining_total": null,
      "cutoff_time": null,
      "cutoff_passed": false,
      "closed": false,
      "closed_reason": null,
      "orderable": false,
      "not_orderable_reason": "not_published"
    }
  ],
  "meta": {
    "from": "2026-08-17",
    "to": "2026-08-23",
    "location_id": 1,
    "default_cutoff_time": "08:00",
    "max_lookahead_days": 7
  },
  "server_time": "2026-08-16T09:00:00Z"
}
```

**Aralıktaki her gün döner, menüsü olmayanlar dâhil** (`id: null`). Eksik günü
atlamak, ızgarayı çizen ekranı boşlukları kendi hesaplamaya zorlardı ve "22
Ağustos'a menü girilmemiş" tam da yöneticinin görmesi gereken şey.

`not_orderable_reason` değerleri `DailyMenuService` sabitlerinden gelir ve
uydurulmaz: `closed_day` · `not_published` · `cutoff_passed` · `past` ·
`too_far`. `orderable: true` iken alan `null`'dır.

`remaining_total` yalnız `capacity_total` doluyken sayıdır; tavan yoksa `null`
("sınırsız"). Sıfır ile `null` karıştırılmamalı: sıfır "doldu", `null` "tavan
konmamış".

---

## `GET /days/{date}`

```json
{
  "data": {
    "id": 214,
    "location_id": 1,
    "date": "2026-08-17",
    "title": "Ev Yemeği Menüsü",
    "description": "Mercimek çorbası, tavuk sote, pilav, sütlaç",
    "internal_note": "Tavuk tedarikçisi B firması",
    "package_price_kurus": 18000,
    "components_sellable": true,
    "status": "published",
    "cutoff_time": "08:00",
    "capacity_total": 120,
    "image_path": "veykemtu/daily/2026-08-17.jpg",
    "items_total_kurus": 21500,
    "published_at": "2026-08-16T13:40:00Z",
    "created_at": "2026-08-10T08:12:00Z",
    "updated_at": "2026-08-16T13:40:00Z",
    "items": [
      {
        "id": 901,
        "menu_id": 12,
        "name": "Günün Çorbası: Mercimek",
        "label": "Günün Çorbası: Mercimek",
        "quantity": 1,
        "sort_order": 10,
        "price_override_kurus": null,
        "unit_price_kurus": 4500,
        "is_required": true,
        "sellable_alone": true,
        "capacity": null,
        "sold_out": false
      },
      {
        "id": 902,
        "menu_id": 27,
        "name": "Tavuk Sote",
        "label": null,
        "quantity": 1,
        "sort_order": 20,
        "price_override_kurus": 9000,
        "unit_price_kurus": 9000,
        "is_required": true,
        "sellable_alone": true,
        "capacity": 60,
        "sold_out": false
      }
    ]
  },
  "server_time": "2026-08-16T09:00:00Z"
}
```

O güne menü yoksa **`404 NOT_FOUND`**. Boş bir gövde döndürmek, "menü yok" ile
"boş menü var"ı ayırt edilemez kılardı.

---

## `POST /days`

Gün **her zaman `draft` doğar.** Yayın ayrı bir eylemdir ve ayrı bir denetim
satırı bırakır — yarım girilmiş bir perşembe kaydedildiği anda müşteriye
görünmemeli.

İstek:

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "17 Ağustos menüsü takvimden kuruldu",
  "dry_run": false,
  "location_id": 1,
  "date": "2026-08-17",
  "title": "Ev Yemeği Menüsü",
  "description": "Mercimek çorbası, tavuk sote, pilav, sütlaç",
  "internal_note": null,
  "package_price_kurus": 18000,
  "components_sellable": true,
  "cutoff_time": "08:00",
  "capacity_total": 120,
  "items": [
    { "menu_id": 12, "quantity": 1, "sort_order": 10, "label": "Günün Çorbası: Mercimek",
      "price_override_kurus": null, "is_required": true, "sellable_alone": true, "capacity": null },
    { "menu_id": 27, "quantity": 1, "sort_order": 20, "label": null,
      "price_override_kurus": 9000, "is_required": true, "sellable_alone": true, "capacity": 60 }
  ]
}
```

Doğrulama:

- `date` bugünden **geçmişte olamaz** → `422`.
- Aynı `(location_id, date)` varsa → **`409 CONFLICT`**, `details.conflict = "date"`.
  Yönetici mevcut günün üzerine yazmak istiyorsa `PATCH` kullanır; POST'un
  sessizce güncellemesi, iki sekmede açık iki taslağın birbirini ezmesi olurdu.
- `package_price_kurus` verilirse **> 0**. Sıfır kabul edilmez: "bedava paket"
  anlamına gelirdi ve `LineResolver` onu zaten reddediyor.
- `items` boş olabilir (önce günü kur, kalemleri sonra ekle).
- Aynı `menu_id` iki kez → `422` (`veykemtu_daily_menu_item_essiz`).
- `cutoff_time` `HH:mm` (00:00–23:59), yerel saat.

Yanıt `201`:

```json
{
  "ok": true,
  "dry_run": false,
  "audit_id": 1501,
  "data": { }
}
```

`data` = tam `DailyMenuDay` (yukarıdaki `GET /days/{date}` gövdesi).

Kuru provada:

```json
{
  "ok": true,
  "dry_run": true,
  "audit_id": 1502,
  "would": {
    "action": "menu.day.create",
    "date": "2026-08-17",
    "location_id": 1,
    "item_count": 2,
    "package_price_kurus": 18000,
    "conflicts_with_existing": false
  }
}
```

---

## `PATCH /days/{date}`

**Kısmi yazar.** Gönderilmeyen alan değişmez; `null` gönderilen alan
temizlenir. İkisi ayrı: alanı hiç göndermemek "dokunma", `null` göndermek "boşalt".

Yazılabilir alanlar: `title`, `description`, `internal_note`,
`package_price_kurus`, `components_sellable`, `cutoff_time`, `capacity_total`,
`image_path`.

`date`, `location_id` ve `status` **yazılamaz.** Günü taşımak yeni gün kurup
eskisini silmektir; durum değişimi kendi uçlarındadır.

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Paket fiyatı 190 TL olarak güncellendi",
  "package_price_kurus": 19000
}
```

Yayınlanmış bir güne `PATCH` **serbesttir**: menü yayındayken fiyat düzeltmek
gerçek bir ihtiyaç. Ama kesim saati geçmiş bir güne fiyat yazmak `409 CONFLICT`
alır — o gün için sipariş kapandı ve girmiş siparişler eski fiyattan; fiyatı
değiştirmek yalnız raporları bozardı.

---

## `DELETE /days/{date}`

Yalnız **`draft`** günler silinir. Yayınlanmış bir güne `DELETE` → `409 CONFLICT`,
`details.conflict = "status"`. Önce `unpublish` çağrılır.

O güne ait sipariş varsa (`orders.bld_service_date`) → **`409 CONFLICT`**,
`details = {"conflict": "orders", "order_count": 3}`. Siparişi olan bir günün
menüsünü silmek, siparişin neye karşılık geldiğini kaybetmektir.

Kalemler birlikte silinir (`veykemtu_daily_menu_items`). Bunlar bağımsız bir
varlık değil, günün parçası.

```json
{ "actor": "Ayşe Yılmaz", "reason": "Yanlış tarihe kurulmuş taslak kaldırıldı" }
```

```json
{ "ok": true, "dry_run": false, "audit_id": 1510, "data": { "deleted": true, "date": "2026-08-22" } }
```

---

## `POST /days/{date}/publish` · `POST /days/{date}/unpublish`

Gövde yalnız ortak alanları taşır.

`publish` ön denetimleri (kuru provada da koşar):

- Gün `draft` olmalı; zaten yayındaysa `409 CONFLICT`.
- **En az bir kalem** olmalı → yoksa `422 VALIDATION_FAILED`.
- `package_price_kurus` `null` ise `components_sellable` **true** olmalı;
  ikisi birden kapalıysa o gün hiçbir şey satılamaz → `422`.
- Kalemlerin `menu_id`'leri `menus` tablosunda var ve `menu_status = 1` olmalı.
  Satıştan kaldırılmış bir ürünü içeren menüyü yayınlamak, sepete
  eklenemeyecek bir menü yayınlamaktır → `422 ITEM_UNAVAILABLE`,
  `details.menu_id`.

`unpublish`, o güne **sipariş girmişse** `409 CONFLICT` verir
(`details = {"conflict": "orders", "order_count": 7}`). Satılmış bir günü
gizlemek, siparişin bağlandığı menüyü müşteriden kaçırmak olurdu.

```json
{
  "ok": true, "dry_run": false, "audit_id": 1520,
  "data": { "date": "2026-08-17", "status": "published", "published_at": "2026-08-16T13:40:00Z" }
}
```

Kuru prova `would`:

```json
{ "action": "menu.publish", "date": "2026-08-17", "from": "draft", "to": "published", "item_count": 4 }
```

---

## Kalem uçları

### `POST /days/{date}/items`

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Menüye ayran eklendi, paket içinde",
  "menu_id": 55,
  "quantity": 1,
  "sort_order": 40,
  "label": null,
  "price_override_kurus": null,
  "is_required": false,
  "sellable_alone": false,
  "capacity": null
}
```

Aynı `menu_id` zaten varsa `409 CONFLICT` (`details.conflict = "menu_id"`).
Tekil indeks var; sunucu hatasını 409'a çevirir, 500'e değil.

`sort_order` verilmezse mevcut en büyük + 10 atanır. On'ar artmak, araya kalem
sokmayı bütün listeyi yeniden numaralamadan mümkün kılar.

### `PATCH /days/{date}/items/{item}`

Kısmi. Yazılabilir: `quantity`, `sort_order`, `label`, `price_override_kurus`,
`is_required`, `sellable_alone`, `capacity`.

`menu_id` **yazılamaz** — ürünü değiştirmek kalemi silip yenisini eklemektir ve
denetim izinde iki ayrı satır olarak görünmelidir.

### `DELETE /days/{date}/items/{item}`

Yayınlanmış bir günden kalem silmek serbesttir ama **o kalem bugünkü siparişlerde
kullanılmışsa** `409 CONFLICT` verilir (`details.order_count`). Sipariş satırı
`order_menus`'ta kendi kopyasını taşıdığı için geçmiş bozulmaz; engel,
yöneticinin farkında olmadan "mutfağın bugün pişirdiği bir kalemi" listeden
düşürmesini önlemek içindir.

Yanıt:

```json
{ "ok": true, "dry_run": false, "audit_id": 1533, "data": { "deleted": true, "item_id": 902 } }
```

---

## Stok

**İki tavan vardır ve hangisi önce dolarsa satışı o kapatır** (iş kararı 5):

- **Gün toplamı** (`capacity_total`): o gün satılan toplam porsiyon.
- **Ürün bazlı** (`items[].capacity`): o günün o kaleminden satılan porsiyon.

`null` = tavan yok. Sıfır = "bugün satılmıyor" ve geçerli bir değerdir.

### Sayım tanımı

`sold` **rezerve edilmiş porsiyondur, teslim edilmiş değil.** İptal edilmiş
siparişler düşülür; diğer her durum (yeni, onaylandı, hazırlanıyor, hazır,
yolda, teslim edildi) sayılır. Yalnız teslim edilenleri saymak, sabah girilen
siparişleri görünmez kılar ve tavanı anlamsızlaştırırdı.

**Abonelikler önce rezerve eder** (iş kararı 6). Abonelik siparişi henüz
üretilmemiş olsa bile o günün rezervasyonu sayılır; kaynak
`Subscription::runsOnDate()` + `quantityForDate()`. Bu yüzden `sold` iki
bileşenlidir ve yanıt ikisini **ayrı gösterir** — yönetici "34 porsiyon kaldı"
dediğinde bunun 20'sinin aboneliğe ayrıldığını bilmelidir.

### `GET /days/{date}/stock`

```json
{
  "data": {
    "date": "2026-08-17",
    "day": {
      "capacity": 120,
      "sold": 86,
      "sold_orders": 66,
      "sold_subscriptions": 20,
      "remaining": 34,
      "full": false
    },
    "items": [
      {
        "item_id": 901, "menu_id": 12, "name": "Günün Çorbası: Mercimek",
        "capacity": null, "sold": 86, "sold_orders": 66, "sold_subscriptions": 20,
        "remaining": null, "full": false, "sold_out": false
      },
      {
        "item_id": 902, "menu_id": 27, "name": "Tavuk Sote",
        "capacity": 60, "sold": 60, "sold_orders": 46, "sold_subscriptions": 14,
        "remaining": 0, "full": true, "sold_out": false
      }
    ],
    "blocking": { "day": false, "items": [27] }
  },
  "server_time": "2026-08-16T09:00:00Z"
}
```

`blocking.items` = tavanı dolmuş `menu_id` listesi. `sold_out` ayrı bir alandır
ve **mutfağın elle koyduğu işaretidir** (`veykemtu_menu_soldout`); tavan dolması
otomatiktir, ikisi karıştırılmamalı. Bir ürün tavanı dolmadan da tükenmiş
olabilir (malzeme bitti).

### `PUT /days/{date}/stock`

Tavanları **birlikte** yazar. Kısmi değil, **tam liste** gönderilir:
gönderilmeyen kalem tavanı `null`'a düşer. Fark göndermek, iki sekmede açık iki
yöneticinin birbirinin tavanını sessizce koruması demekti — burada niyet
"bugünün tavan tablosu şudur"dur.

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Tavuk tedariki azaldı, sote tavanı 60'a çekildi",
  "dry_run": false,
  "capacity_total": 120,
  "items": [
    { "item_id": 901, "capacity": null },
    { "item_id": 902, "capacity": 60 }
  ]
}
```

Tavanı **satılmışın altına** çekmek serbesttir ve `409` vermez: gerçek hayatta
malzeme biter ve yönetici satışı kapatmak ister. Ama yanıt bunu açıkça söyler:

```json
{
  "ok": true, "dry_run": false, "audit_id": 1544,
  "data": {
    "date": "2026-08-17",
    "day": { "capacity": 120, "sold": 86, "remaining": 34, "full": false },
    "items": [
      { "item_id": 902, "capacity": 60, "sold": 60, "remaining": 0, "full": true, "oversold": false }
    ],
    "warnings": [
      { "code": "capacity_below_sold", "item_id": 902, "capacity": 60, "sold": 60 }
    ]
  }
}
```

`oversold: true`, tavan satılmışın **altına** düştüğünde çıkar (`sold > capacity`)
ve `remaining` **negatife düşmez, `0` olur**. Negatif bir kalan sayısı ekranda
anlamsızdır; gerçek bilgi `oversold` bayrağıdır.

Kuru prova `would` aynı gövdeyi taşır ve **`warnings` dâhil hesaplanır** — asıl
işi budur: yönetici tavanı yazmadan önce kaç siparişin altında kaldığını görür.

---

## `POST /days/{date}/duplicate`

Bir günün menüsünü başka bir güne kopyalar. Haftalık menü kuran yönetici için
tek gerçek zaman kazancı budur.

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Geçen haftanın salı menüsü bu salıya kopyalandı",
  "target_date": "2026-08-24",
  "overwrite": false
}
```

- Hedef gün **her zaman `draft` doğar**, kaynak yayında olsa bile.
- Kopyalananlar: `title`, `description`, `package_price_kurus`,
  `components_sellable`, `cutoff_time`, `capacity_total` ve **tüm kalemler**
  (kalem tavanları dâhil).
- Kopyalanmayanlar: `status`, `published_at`, `image_path`, `internal_note`.
  Görsel ve iç not güne özgüdür; kopyalamak yanlış fotoğrafı yayınlatırdı.
- `overwrite: false` iken hedefte gün varsa → `409 CONFLICT`.
- `overwrite: true` iken hedef gün **`draft` olmalı**; yayınlanmış bir günün
  üzerine kopyalamak `409 CONFLICT` verir.

```json
{
  "ok": true, "dry_run": false, "audit_id": 1560,
  "data": { "source_date": "2026-08-17", "target_date": "2026-08-24", "id": 231, "item_count": 4, "status": "draft" }
}
```

---

## Denetim eylemleri

| `action` | Uç | `target_type` / `target_id` |
|---|---|---|
| `menu.day.create` | `POST /days` | `daily_menu` / yeni gün id |
| `menu.day.update` | `PATCH /days/{date}` | `daily_menu` / gün id |
| `menu.day.delete` | `DELETE /days/{date}` | `daily_menu` / gün id |
| `menu.publish` | `POST /days/{date}/publish` | `daily_menu` / gün id |
| `menu.unpublish` | `POST /days/{date}/unpublish` | `daily_menu` / gün id |
| `menu.item.create` | `POST /days/{date}/items` | `daily_menu` / gün id |
| `menu.item.update` | `PATCH .../items/{item}` | `daily_menu` / gün id |
| `menu.item.delete` | `DELETE .../items/{item}` | `daily_menu` / gün id |
| `menu.stock` | `PUT /days/{date}/stock` | `daily_menu` / gün id |
| `menu.duplicate` | `POST /days/{date}/duplicate` | `daily_menu` / **hedef** gün id |

Kalem eylemlerinin hedefi **gün**dür, kalem değil: "17 Ağustos menüsüne ne
oldu" sorusu tek bir `target_id` ile cevaplanabilmeli. Kalem kimliği
`payload_json.item_id` içindedir.

`menu.duplicate` hedefi **hedef gün**dür; kaynak `payload_json.source_date`
içinde durur. Denetim sorusu "bu gün nereden geldi" biçiminde sorulur.
