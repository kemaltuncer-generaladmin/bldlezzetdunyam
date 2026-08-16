# `control/products` — Ürün kataloğu

Yol öneki: **`/api/control/products`** · Sınır: `bld-control-panel` ·
Ortak kurallar: `00-genel.md`

Ürünlerin kalıcı kaydı. Bir ürün burada doğar, fiyatlanır, görsellenir ve
satıştan kaldırılır; **hangi gün satılacağı** `menu.md` alanının işidir. İki
alan bilinçli olarak ayrıdır: ürün kataloğu haftalarca değişmez, günlük menü
her gün değişir.

Kaynak tablolar: çekirdek `menus`, `categories`, `menu_categories`,
`veykemtu_menu_soldout`. Model: `Igniter\Cart\Models\Menu`,
`Igniter\Cart\Models\Category`, `Models\MenuSoldOut`.

`platform/vendor/` **düzenlenmez**; bu uçlar çekirdek modelleri yalnızca okur
ve yazar.

---

## Uçlar

| Metot | Yol | Amaç | İzin | dry_run | Gerekçe |
|---|---|---|---|---|---|
| GET | `/` | Ürün listesi (**sayfalı**) | `bld_menu.view` | — | — |
| GET | `/{menu}` | Tek ürün | `bld_menu.view` | — | — |
| POST | `/` | Yeni ürün | `bld_menu.manage` | ✔ | ✔ |
| PATCH | `/{menu}` | Ürün güncelle | `bld_menu.manage` | ✔ | ✔ |
| DELETE | `/{menu}` | **Yumuşak** kaldır (`menu_status = 0`) | `bld_menu.manage` | ✔ | ✔ |
| PUT | `/{menu}/image` | Görsel yükle (**base64**) | `bld_menu.manage` | ✔ | ✔ |
| DELETE | `/{menu}/image` | Görseli kaldır | `bld_menu.manage` | ✔ | ✔ |
| GET | `/categories` | Kategori listesi | `bld_menu.view` | — | — |
| POST | `/categories` | Yeni kategori | `bld_menu.manage` | ✔ | ✔ |
| PATCH | `/categories/{id}` | Kategori güncelle | `bld_menu.manage` | ✔ | ✔ |
| POST | `/{menu}/sold-out` | Bugün için tükendi işaretle | `bld_menu.manage` | ✔ | ✔ |
| DELETE | `/{menu}/sold-out` | Tükendi işaretini kaldır | `bld_menu.manage` | ✔ | ✔ |

`{menu}` = `menus.menu_id`. `{id}` = `categories.category_id`.

`DELETE /categories/{id}` **yoktur.** Kategori silmek, altındaki ürünleri
kategorisiz bırakır ve site menüsünü sessizce boşaltır; kategori
`status = false` ile gizlenir (`PATCH`).

---

## Şema

### Ürün (`Product`)

| Alan | Tip | Kaynak kolon | Not |
|---|---|---|---|
| `menu_id` | int | `menu_id` | |
| `name` | string | `menu_name` | |
| `description` | string\|null | `menu_description` | |
| `price_kurus` | int | `menu_price` | **Kuruş.** DB `float` TL tutar; dönüşüm `Support\Money` |
| `minimum_qty` | int | `minimum_qty` | |
| `priority` | int | `menu_priority` | Küçük olan önce |
| `status` | bool | `menu_status` | `false` = satıştan kaldırılmış |
| `category_ids` | list\<int\> | `menu_categories` | **Çoklu** — ürün birden çok kategoride olabilir |
| `image_url` | string\|null | `media` (`thumb`) | Tam URL; yoksa `null` |
| `sold_out_today` | bool | `veykemtu_menu_soldout` | Bugünkü işaret |
| `sold_out_reason` | string\|null | `veykemtu_menu_soldout.reason` | |
| `is_package_product` | bool | *türetilir* | `DailyMenu::isPackageProduct()` |
| `options` | list\<ProductOption\> | `menu_options` | Salt okunur (aşağıda) |
| `created_at` | ISO 8601 UTC | `created_at` | |
| `updated_at` | ISO 8601 UTC | `updated_at` | |

`is_package_product` uyarı alanıdır: "Günün Menüsü" paket ürününün kendi fiyatı
0,00'dır ve gerçek fiyat o günün paket fiyatıdır. Panel bu ürünü listede
işaretler ve **fiyat alanını düzenlemeye kapatır**; fiyat yazmak günün menüsünü
yanlış tutara satardı.

### Seçenek (`ProductOption`) — salt okunur

```json
{
  "id": 7,
  "name": "Ekstra",
  "type": "checkbox",
  "required": false,
  "values": [
    { "id": 31, "name": "Ekstra pilav", "price_delta_kurus": 2500 }
  ]
}
```

`id` = `menu_option_id`, `values[].id` = `menu_option_value_id`. Bu kimlikler
sipariş revizyonundaki `option_value_ids` alanına doğrudan konur
(`orders.md`).

> KARAR: Seçenekler bu turda **salt okunur**. Seçenek düzenlemek TastyIgniter
> admin panelinde yapılır. Seçenek yazan bir uç eklemek, `menu_options`,
> `menu_option_values` ve `options` üçlüsünü sözleşmeye taşımak demekti; en
> küçük ve geri alınabilir karar, okumayla yetinmektir. Eksik olduğu
> raporlanmıştır.

### Kategori (`Category`)

| Alan | Tip | Kaynak kolon |
|---|---|---|
| `category_id` | int | `category_id` |
| `name` | string | `name` |
| `description` | string\|null | `description` |
| `parent_id` | int\|null | `parent_id` |
| `priority` | int | `priority` |
| `status` | bool | `status` |
| `slug` | string\|null | `permalink_slug` |
| `menu_count` | int | *türetilir* |

---

## `GET /` — liste

Sorgu parametreleri:

| Ad | Tip | Varsayılan | Not |
|---|---|---|---|
| `q` | string | — | Ad ve açıklamada arar; en az 2 karakter |
| `category_id` | int | — | Tek kategori |
| `status` | `active`\|`inactive`\|`all` | `all` | `menu_status` süzgeci |
| `sold_out` | bool | — | `true` = yalnız bugün tükenmişler |
| `sort` | `name`\|`price`\|`priority`\|`updated` | `name` | |
| `direction` | `asc`\|`desc` | `asc` | |
| `page` | int | 1 | |
| `per_page` | int | 25 | tavan 100 |

`status` varsayılanı **`all`**, `active` değil. Yönetimin ilk sorusu çoğu zaman
"bu ürün nerede" biçiminde gelir ve cevabı "satıştan kaldırılmış"tır; varsayılan
süzgeç onu gizleseydi ürün kaybolmuş görünürdü.

```json
{
  "data": [
    {
      "menu_id": 27,
      "name": "Tavuk Sote",
      "description": "Tereyağında sotelenmiş tavuk",
      "price_kurus": 9000,
      "minimum_qty": 1,
      "priority": 10,
      "status": true,
      "category_ids": [3],
      "image_url": "https://api.bld.example/uploads/menu/tavuk-sote.jpg",
      "sold_out_today": false,
      "sold_out_reason": null,
      "is_package_product": false,
      "options": [],
      "created_at": "2026-06-02T07:00:00Z",
      "updated_at": "2026-08-11T19:20:00Z"
    }
  ],
  "meta": { "page": 1, "per_page": 25, "total": 84, "last_page": 4 },
  "server_time": "2026-08-16T09:00:00Z"
}
```

Listede `options` **boş dizi olarak döner** — seksen ürünün seçeneklerini her
sayfada taşımak, ekranın göstermediği veriyi yollamak olurdu. Dolu hâli yalnız
`GET /{menu}` yanıtındadır.

---

## `POST /` — yeni ürün

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Yeni ana yemek kataloğa eklendi",
  "dry_run": false,
  "name": "Karnıyarık",
  "description": "Zeytinyağlı, kıymalı",
  "price_kurus": 9500,
  "minimum_qty": 1,
  "priority": 20,
  "status": true,
  "category_ids": [3]
}
```

- `name` zorunlu, 2–128 karakter.
- `price_kurus` zorunlu, `>= 0`. Sıfır geçerlidir (paket bileşeni olarak
  satılan ekmek, ayran).
- `category_ids` boş olabilir; kategorisiz ürün sitede görünmez ama günlük
  menüde kullanılabilir.
- Aynı adda ürün varsa **engellenmez**. "Tavuk Sote" iki farklı tarifle iki
  ürün olabilir; adı tekilleştirmek gerçek bir işi bloke ederdi. Panel uyarı
  gösterir, sunucu engellemez.

Yanıt `201`, gövde `{ok, dry_run, audit_id, data: Product}`.

Kuru prova `would`:

```json
{ "action": "product.create", "name": "Karnıyarık", "price_kurus": 9500, "category_ids": [3] }
```

---

## `PATCH /{menu}` — güncelle

Kısmi. Yazılabilir: `name`, `description`, `price_kurus`, `minimum_qty`,
`priority`, `status`, `category_ids`.

`category_ids` gönderilirse **tam listedir** — pivot tablo o listeye
eşitlenir. Fark göndermek, iki kategoriden birini kaldırmanın adını
gerektirirdi.

Paket ürününe (`is_package_product: true`) `price_kurus` yazılması
**`422 VALIDATION_FAILED`** verir; `details = {"field": "price_kurus",
"reason": "package_product"}`. Bu ürünün fiyatı günün menüsündedir.

```json
{ "actor": "Ayşe Yılmaz", "reason": "Zam sonrası fiyat güncellendi", "price_kurus": 10000 }
```

---

## `DELETE /{menu}` — yumuşak kaldırma

Satır **silinmez**, `menu_status = 0` yazılır. Gerçek silme, geçmiş
siparişlerin `order_menus` satırlarındaki ürün bağını kırar ve "bu sipariş neydi"
sorusunu cevapsız bırakır.

```json
{ "actor": "Ayşe Yılmaz", "reason": "Ürün menüden kalıcı olarak çıkarıldı" }
```

```json
{
  "ok": true, "dry_run": false, "audit_id": 1602,
  "data": { "menu_id": 27, "status": false, "soft_deleted": true }
}
```

Ürün **yayınlanmış bir günlük menüde kullanılıyorsa** `409 CONFLICT` verilir:
`details = {"conflict": "daily_menu", "dates": ["2026-08-17","2026-08-19"]}`.
Yayındaki bir menünün kalemini sessizce satıştan kaldırmak, o menüyü sepete
eklenemez hâle getirirdi. Yönetici önce menüden çıkarır.

Geri açmak `PATCH {menu}` ile `status: true` yazmaktır; ayrı bir "restore" ucu
yok.

---

## Görsel

### Neden base64, neden multipart değil

İmza kanonik dizesi `sha256(request.getContent())` içerir. **Multipart gövde
sınır dizeleri (boundary) taşır ve gövdeyi yeniden kodlayan herhangi bir vekil
— proxy, load balancer, gzip, WAF — baytları değiştirir.** Değişen tek bayt
imzayı bozar; sunucu `401 UNAUTHENTICATED` döndürür ve arıza sahada "sır yanlış"
ya da "saat kaymış" gibi görünür. Görsel yükleme başarısızlığının kimlik
doğrulama hatası kılığına girmesi, teşhis edilmesi en zor arıza türüdür.

Bu yüzden görsel **JSON gövdesinin içinde base64 olarak** gider. JSON gövde
bayt bayt korunur ve diğer bütün yazma uçlarıyla aynı yoldan geçer.

### `PUT /{menu}/image`

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Ürün fotoğrafı yenilendi",
  "dry_run": false,
  "filename": "tavuk-sote.jpg",
  "content_base64": "/9j/4AAQSkZJRgABAQEAYABgAAD..."
}
```

Doğrulama sırası **bu sıradadır** ve her adım kendi hatasını verir:

1. `content_base64` geçerli base64 mü → değilse `422`,
   `details = {"field": "content_base64", "reason": "invalid_base64"}`.
2. **Çözülmüş boyut ≤ 5 MB (5 242 880 bayt)** → aşarsa `422`,
   `details = {"reason": "too_large", "bytes": 6100000, "max_bytes": 5242880}`.
3. **MIME içerikten okunur** (`finfo_buffer`), dosya adından **değil**. İzinli:
   `image/jpeg`, `image/png`, `image/webp`. Başka her şey → `422`,
   `details = {"reason": "invalid_mime", "mime": "application/pdf"}`.
   Uzantıya güvenmek, `.jpg` adlı bir PHP dosyasını yüklemenin en bilinen
   yoludur.
4. `filename` yalnız uzantı ve görüntüleme için kullanılır; kayıt adı sunucuda
   üretilir. İstemciden gelen yolu diske yazmak yol geçişi (`../`) demekti.

Boyut sınırı **çözülmüş** bayt üzerindendir. Base64 ~%33 şişirir, yani 5 MB'lık
bir görsel ~6,7 MB gövde eder; sunucunun `post_max_size` ve ters vekilin
`client_max_body_size` değerleri **en az 8 MB** olmalıdır. Aksi hâlde istek
denetleyiciye hiç ulaşmaz ve hata `413` olarak, sözleşmenin hata biçimi dışında
döner.

Yanıt:

```json
{
  "ok": true, "dry_run": false, "audit_id": 1610,
  "data": {
    "menu_id": 27,
    "image_url": "https://api.bld.example/uploads/menu/27-8f3a.jpg",
    "mime": "image/jpeg",
    "bytes": 184320
  }
}
```

Kuru prova görseli **çözer ve denetler ama diske yazmaz**:

```json
{ "action": "product.image", "menu_id": 27, "mime": "image/jpeg", "bytes": 184320, "valid": true }
```

`payload_json`'a **base64 içerik yazılmaz** — yalnız `{"mime": ..., "bytes": ...}`.
Denetim tablosunu megabaytlık dizelerle doldurmak, izi okunamaz ve tabloyu
yönetilemez kılardı.

### `DELETE /{menu}/image`

```json
{ "actor": "Ayşe Yılmaz", "reason": "Fotoğraf yanlış üründü, kaldırıldı" }
```

```json
{ "ok": true, "dry_run": false, "audit_id": 1611, "data": { "menu_id": 27, "image_url": null } }
```

Görseli olmayan bir üründen görsel silmek **hata değildir**, `ok: true` ve
`image_url: null` döner. İşlem sonuç odaklıdır: istenen son hâl zaten geçerli.

---

## Kategoriler

### `GET /categories`

Sayfalanmaz — kategori sayısı onlarla ifade edilir ve ekran hepsini bir ağaç
olarak çizer.

```json
{
  "data": [
    { "category_id": 3, "name": "Ana Yemek", "description": null, "parent_id": null,
      "priority": 10, "status": true, "slug": "ana-yemek", "menu_count": 22 },
    { "category_id": 4, "name": "Çorba", "description": null, "parent_id": null,
      "priority": 20, "status": true, "slug": "corba", "menu_count": 9 }
  ],
  "server_time": "2026-08-16T09:00:00Z"
}
```

### `POST /categories`

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Tatlı kategorisi kataloğa eklendi",
  "name": "Tatlı",
  "description": null,
  "parent_id": null,
  "priority": 40,
  "status": true
}
```

`slug` gönderilmez; `permalink_slug` çekirdeğin `HasPermalink` özelliğiyle
addan üretilir. Elle slug yazdırmak, sitedeki adresin yönetici yazım hatasına
bağlı olması demekti.

### `PATCH /categories/{id}`

Kısmi. Yazılabilir: `name`, `description`, `parent_id`, `priority`, `status`.

`parent_id` kendisine ya da kendi alt ağacına işaret ederse `422`
(`details.reason = "cycle"`). Çekirdek `NestedTree` böyle bir kaydı kabul edip
ağacı bozardı.

---

## Tükendi işareti

Bugüne özeldir ve **ertesi gün kendiliğinden düşer** (`sold_out_on` tarih
bazlı). Kalıcı satıştan kaldırma `DELETE /{menu}`'dür, bu değil.

Normalde işareti **KDS koyar** (`Services\MenuAvailability`). Kontrol
Merkezi'nden de konabilmesinin sebebi somut: mutfak kasası çöktüğünde ya da
yönetici sahada olmadığında bir ürünü satıştan çekmenin başka yolu kalmıyor.

### `POST /{menu}/sold-out`

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Tavuk tedariki gelmedi, bugünlük kapatıldı",
  "note": "Tedarikçi 15:00 sonrası getirecek"
}
```

`reason` zaten zorunlu ortak alandır ve `veykemtu_menu_soldout.reason`
sütununa **da** yazılır — mutfak ekranındaki "neden yok" sorusunun cevabı orada
görünür. `note` ayrıca denetim izine gider.

```json
{
  "ok": true, "dry_run": false, "audit_id": 1620,
  "data": { "menu_id": 27, "sold_out_today": true, "sold_out_on": "2026-08-16",
            "sold_out_reason": "Tavuk tedariki gelmedi, bugünlük kapatıldı" }
}
```

Zaten işaretliyse `ok: true` döner ve gerekçe **güncellenir**; `409` verilmez.
İkinci bir gerekçe yazmak isteyen yöneticiyi hata ekranına düşürmek anlamsız.

### `DELETE /{menu}/sold-out`

```json
{ "actor": "Ayşe Yılmaz", "reason": "Tedarik geldi, ürün yeniden satışa açıldı" }
```

İşaret yoksa `ok: true`, `sold_out_today: false`.

---

## Denetim eylemleri

| `action` | Uç | `target_type` / `target_id` |
|---|---|---|
| `product.create` | `POST /` | `menu` / yeni `menu_id` |
| `product.update` | `PATCH /{menu}` | `menu` / `menu_id` |
| `product.delete` | `DELETE /{menu}` | `menu` / `menu_id` |
| `product.image` | `PUT /{menu}/image` | `menu` / `menu_id` |
| `product.image.delete` | `DELETE /{menu}/image` | `menu` / `menu_id` |
| `product.sold_out` | `POST /{menu}/sold-out` | `menu` / `menu_id` |
| `product.sold_out.clear` | `DELETE /{menu}/sold-out` | `menu` / `menu_id` |
| `category.create` | `POST /categories` | `category` / yeni `category_id` |
| `category.update` | `PATCH /categories/{id}` | `category` / `category_id` |
