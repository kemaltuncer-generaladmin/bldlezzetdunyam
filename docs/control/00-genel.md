# Kontrol API — Genel Sözleşme

Bu klasör **dondurulmuş** bir sözleşmedir. Kontrol Merkezi'ndeki 12 yönetim
ekranı ile BLD sunucusundaki `/api/control/*` uçları burada buluşur. Uç yazan
ajan da, ekran yazan ajan da bu dosyaları okur; **buradan okunmayan hiçbir alan
adı, yol ya da başlık uydurulmaz.**

Çelişki çıkarsa sıra: bu klasör → `docs/03-api-sozlesmesi.md` → kod. Bir alan
burada eksikse **uydurulmaz**, rapora yazılır.

| Dosya | Alan | Yol öneki |
|---|---|---|
| `menu.md` | Günlük menü takvimi | `/api/control/menu` |
| `products.md` | Ürün kataloğu | `/api/control/products` |
| `settings.md` | Satış ayarları | `/api/control/settings` |
| `orders.md` | Siparişler | `/api/control/orders` |
| `subscriptions.md` | Abonelik, talep, sözleşme, ödeme | `/api/control/subscriptions` |
| `customers.md` | Müşteriler (**KVKK**) | `/api/control/customers` |
| `invoices.md` | Fatura belgesi | `/api/control/invoices` |
| `cms.md` | Site içeriği | `/api/control/cms` |
| `sms.md` | SMS şablon, kayıt, duyuru | `/api/control/sms` |
| `notifications.md` | Uygulama-içi duyuru | `/api/control/notifications` |
| `monitor.md` | Hata olayları, cihaz sağlığı | `/api/control/monitor` |
| `dashboard.md` | Açılış özeti | `/api/control/dashboard` |
| `audit.md` | Denetim izi (salt okunur) | `/api/control/audit` |

Mevcut `/api/control/kds/*` ailesi (K-21) **olduğu gibi durur**. Yeni alanlar
onun yanına gelir, yerine değil.

Bu klasördeki `_` ile başlayan dosyalar sözleşme değil **arşivdir**
(örn. `_devralinan-odeme-yapisi.md` — cari hesap kaldırılırken kurtarılan
ödeme-niyeti iskeleti). Uç yazan ajan onlardan yol veya alan adı almaz; yalnız
gerekçe okur.

---

## 1. Kimlik — `X-Control-Signature`

Değişiklik yok; `Http\Middleware\VerifyControlSignature` aynen geçerlidir ve
**yeni alanların hepsi aynı ara katmanı kullanır.**

```
X-Control-Timestamp: <unix saniye>
X-Control-Nonce:     <16-128 karakter, rastgele>
X-Control-Signature: sha256=<64 hex>
```

Kanonik dize — beş satır, aralarında tek `\n`:

```
METOT \n YOL \n ZAMAN \n NONCE \n sha256_hex(ham gövde)
```

- `METOT` büyük harf (`GET`, `POST`, `PATCH`, `PUT`, `DELETE`).
- `YOL` **sorgu dizesi hariç**, baştaki `/` dâhil (`$request->getPathInfo()`).
  Süzgeçler imzaya girmez.
- `ZAMAN` saniye cinsinden unix damgası; pencere **±300 sn**.
- `NONCE` 16–128 karakter; sunucuda **600 sn** hatırlanır, ikinci kez kabul
  edilmez.
- Gövdesiz istekte gövde özeti boş dizenin sha256'sıdır:
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

İmza: `"sha256=" + hmac_sha256(kanonik, BLD_CONTROL_SECRET)`.

Sır sunucuda `BLD_CONTROL_SECRET` ortam değişkenidir; Kontrol Merkezi tarafında
kasa anahtarı `server.bld.control_secret`. Sır tanımsızsa uç **kapalıdır** ve
401 döner.

> KARAR: Yeni alanlar için ikinci bir sır **tanımlanmaz**. Kontrol Merkezi zaten
> cihaz iptal edebiliyor ve sipariş revize edebiliyor; ayrı sır, aynı yetkiyi
> ikiye bölmeden yalnızca bir anahtar daha yönetmek olurdu.

### 1.1 Gövde bayt bayt aynı gitmeli

İmza `$request->getContent()`'i hashler. Gövdeyi **yeniden kodlayan** herhangi
bir vekil (JSON'u yeniden serileştiren gateway, sıkıştırma, boşluk düzeltmesi)
imzayı sessizce bozar ve arıza **kimlik doğrulama hatası** gibi görünür. Bu,
`products` alanındaki görsel yükleme kararının da gerekçesidir (§ `products.md`).

---

## 2. Hız sınırı — `bld-control-panel`

Mevcut `bld-control` sınırı **1200/saat/IP**'dir ve KDS ekranı için hesaplandı:
tek panel, cihaz + sipariş + özet yoklaması. On dört yoklayan panel ekranı o
bütçeyi tek başına tüketir ve sonuç `429` olur — yani yönetici siparişi
göremez, cihazı yönetemez.

Bu yüzden **yeni bir sınır tanımlanır**:

```php
// Extension::registerRateLimiters()
RateLimiter::for('bld-control-panel', static fn(Request $request): Limit
    => Limit::perHour(3000)->by($request->ip() ?? 'bilinmeyen'));
```

| Sınır | Değer | Kimin |
|---|---|---|
| `bld-control` | 1200/saat/IP | `/api/control/kds/*` — **değişmez** |
| `bld-control-panel` | 3000/saat/IP | `/api/control/<alan>/*` — 13 yeni alan |

Bütçe hesabı (tek yönetici, panel açık):

| Yoklayan ekran | Aralık | Saatlik |
|---|---|---|
| `dashboard/overview` | 30 sn | 120 |
| `orders` listesi | 15 sn | 240 |
| `monitor/summary` | 60 sn | 60 |
| `menu/calendar` (açık günlerde) | 120 sn | 30 |
| `notifications` rozeti | 120 sn | 30 |
| **sürekli toplam** | | **480** |

Kalan ~2520 kullanıcı kaynaklıdır: liste sayfalama, arama, düzenleme ekranları,
ikinci bir yöneticinin paneli. `bld-control` bütçesi ayrı kova olduğu için
paneldeki bir patlama **mutfağın KDS yönetimini kilitlemez** — sınırların ayrı
tutulmasının asıl sebebi budur, cömertlik değil.

> KARAR: Sınır yine **IP başına**. Kontrol Merkezi tek sunucudan çıkıyor ve
> kimliği imza taşıyor; istek gövdesinde ayrı bir anahtar yok (`bld-control` ile
> aynı gerekçe).

---

## 3. Yazma uçlarının ortak gövdesi

Her `POST` / `PATCH` / `PUT` / `DELETE` gövdesinde:

| Alan | Tip | Zorunlu | Sınır |
|---|---|---|---|
| `actor` | string | **evet — her uçta** | 2–120 karakter |
| `reason` | string | **uç başına** (varsayılan evet) | zorunluysa en az **10**, her hâlde en çok **500** karakter |
| `dry_run` | bool | hayır | varsayılan `false` |

**`reason` uç başına zorunludur ve alan dosyasındaki "Gerekçe" sütunu
bağlayıcıdır.** Buradaki varsayılan "evet"tir; bir alan dosyası
(`docs/control/<alan>.md`) bir uç için "—" yazıyorsa o uçta `reason`
gönderilmeyebilir. Bugün gevşeyen tek alan **`control/menu`**'dür ve gerekçesi
o dosyanın "Gerekçe politikası" bölümündedir (özeti: taslak kurmak bir taahhüt
değil, yayınlamak taahhüttür). Diğer bütün alanlar her yazmada gerekçe ister.

Gerekçe istenmeyen bir uçta:

- doğrulama `nullable`'dır ve **10 karakterlik alt sınır uygulanmaz** (isteğe
  bağlı bir notu kısa diye reddetmek kimseye bir şey kazandırmaz),
- **denetim satırı yine açılır**, `reason` sütununa boş dize yazılır
  (`veykemtu_control_audit.reason` `NOT NULL`; bunun için göç açılmadı),
- **`actor` yine zorunludur.** Gevşeyen tek alan `reason`; "kim yaptı" sorusu
  hiçbir uçta seyrelmez.

Sunucu tarafında bu ayrım tek yerdedir: `ControlController::write()`
`reasonRequired` parametresi (varsayılanı `true`, yani yeni bir uç yazan ajan
hiçbir şey yapmadan katı davranışı alır).

`reason` üst sınırı **sipariş revizyonu ve durum geçişinde 160'tır**
(`veykemtu_order_revisions.reason` sütunu 160). Taşan gerekçe kırpılmaz, `422`
alır.

`actor` BLD'de bir hesaba bağlanmaz ve bağlanmayacaktır: Kontrol Merkezi ayrı
bir depo, ayrı bir kullanıcı tablosu. Serbest metindir; doğruluğu Kontrol
Merkezi'nin sorumluluğundadır, imza yalnız isteğin oradan geldiğini kanıtlar.

`DELETE` uçları da gövde taşır — gerekçe istenen bir silmede gerekçesiz silme
yoktur. Bu, HTTP açısından alışılmadıktır ama sözleşmede bilinçlidir: gerekçeyi
sorgu dizesine koymak onu imzanın dışında bırakırdı. Gövde `actor` için zaten
her koşulda gerekiyor.

### 3.1 Yazma yanıtının zarfı

```json
{
  "ok": true,
  "dry_run": false,
  "audit_id": 1487,
  "data": { }
}
```

Kuru provada:

```json
{
  "ok": true,
  "dry_run": true,
  "audit_id": 1488,
  "would": { }
}
```

`would` bloğu **isteğin yankısı değildir**: sunucu ön denetimleri gerçekten
koşar (sipariş düzenlenebilir mi, geçiş matrisi izin veriyor mu, stok tavanı
aşılıyor mu) ve aşılamayan bir kural kuru provada da `422` üretir. "Kuru prova
geçti" diyen bir ekran gerçek gönderimde patlamamalıdır.

---

## 4. `dry_run` farkında yollar

**Bu liste kritiktir.** Listede olmayan bir yola kuru prova ile yazılırsa
Laravel `dry_run` alanını sessizce yok sayar; "prova" sanılan istek **gerçek
yazma** olur. Kontrol Merkezi geçidi (`modules/bld_api/backend/client.py`
`_DRY_RUN_AWARE`) bu listeyi birebir taşımalıdır.

> KARAR: Yeni alanlardaki **her yazma ucu** `ControlController::write()`
> kabuğundan geçer, yani hepsi `dry_run` farkındadır. İstisna listesi tutmak
> yerine kuralı tersine çevirdik: bir uç `write()` kullanmıyorsa **o uç
> sözleşmeye aykırıdır**.

Yol kalıpları (`^` ve `$` ile tam eşleşme, `\d+` sayısal kimlik):

```
^/api/control/menu/days$
^/api/control/menu/days/\d{4}-\d{2}-\d{2}$
^/api/control/menu/days/\d{4}-\d{2}-\d{2}/(publish|unpublish|duplicate|stock)$
^/api/control/menu/days/\d{4}-\d{2}-\d{2}/items$
^/api/control/menu/days/\d{4}-\d{2}-\d{2}/items/\d+$

^/api/control/products$
^/api/control/products/\d+$
^/api/control/products/\d+/image$
^/api/control/products/\d+/sold-out$
^/api/control/products/categories$
^/api/control/products/categories/\d+$

^/api/control/settings/sales$
^/api/control/settings/ordering/(pause|resume)$
^/api/control/settings/closed-days$
^/api/control/settings/closed-days/\d{4}-\d{2}-\d{2}$

^/api/control/orders/\d+/revisions$
^/api/control/orders/\d+/status$
^/api/control/orders/\d+/cancel$

^/api/control/subscriptions$
^/api/control/subscriptions/\d+$
^/api/control/subscriptions/\d+/(activate|pause|resume|cancel|generate)$
^/api/control/subscriptions/\d+/exceptions$
^/api/control/subscriptions/\d+/exceptions/\d{4}-\d{2}-\d{2}$
^/api/control/subscriptions/\d+/contracts$
^/api/control/subscriptions/\d+/payments$
^/api/control/subscriptions/contracts/\d+/(resend|cancel)$
^/api/control/subscriptions/payments/\d+/mark-paid$
^/api/control/subscriptions/orders/\d+/release$
^/api/control/subscriptions/requests/\d+$
^/api/control/subscriptions/requests/\d+/convert$

^/api/control/customers/\d+$
^/api/control/customers/\d+/(disable|enable)$

^/api/control/invoices$
^/api/control/invoices/\d+/void$

^/api/control/cms/content/[a-z_]+$
^/api/control/cms/services$
^/api/control/cms/services/\d+$
^/api/control/cms/posts$
^/api/control/cms/posts/\d+$
^/api/control/cms/revalidate$

^/api/control/sms/templates/[a-z0-9_]+$
^/api/control/sms/templates/[a-z0-9_]+/preview$
^/api/control/sms/send-test$
^/api/control/sms/announcement$
^/api/control/sms/announcement/run$

^/api/control/notifications$
^/api/control/notifications/\d+$
^/api/control/notifications/\d+/publish$

^/api/control/monitor/events/\d+/resolve$
```

`/api/control/audit` altında **yazma ucu yoktur** — denetim izi silinemez,
düzeltilemez.

---

## 5. Sayfalama

Sözleşmenin tek sayfalama biçimi, `Http\Controllers\OrderController::index`
içinde zaten kullanılan biçimdir:

| Parametre | Tip | Varsayılan | Tavan |
|---|---|---|---|
| `page` | int | `1` | — |
| `per_page` | int | `25` | `100` |

Yanıt:

```json
{
  "data": [],
  "meta": { "page": 1, "per_page": 25, "total": 137, "last_page": 6 },
  "server_time": "2026-08-16T09:00:00Z"
}
```

`limit` / `offset` **kullanılmaz.** Tek istisna, mevcut
`GET /api/control/kds/print-jobs` ucudur: orada `limit` yayınlanmış bir alandır
ve `AGENTS.md` §2.3 gereği değiştirilmez.

`per_page` varsayılanının tek istisnası **`control/audit`**'tir: orada
varsayılan **50**'dir. Denetim izi tarama ekranıdır ve yirmi beşer satır,
"dün ne oldu" sorusunu cevaplamak için sekiz kez sayfa çevirmek demekti. Tavan
yine 100.

Sayfalanan uçlar alan dosyalarında tablo satırında `sayfalı` diye işaretlidir.
Sayfalanmayan liste uçları (takvim, ayarlar, şablonlar) `meta` **döndürmez** —
boş bir `meta` yollamak, istemciye olmayan bir sayfalayıcı çizdirirdi.
Sayfalanmayan uçlar yine de özet alanları taşıyan bir `meta` verebilir
(örn. `cms/posts` → `meta.categories`); ayrım, `page`/`per_page`/`total`/
`last_page` dörtlüsünün bulunup bulunmamasıdır.

---

## 6. Ortak biçimler

| Şey | Biçim | Örnek |
|---|---|---|
| Para | **her zaman tam sayı kuruş**, alan adı `*_kurus` | `18000` = 180,00 TL |
| Para birimi | daima `TRY`; alan yalnız gerektiğinde `currency` | `"TRY"` |
| Tarih (gün) | `YYYY-MM-DD` | `"2026-08-20"` |
| An (zaman damgası) | ISO 8601, **UTC**, `Z` sonekli | `"2026-08-16T06:00:00Z"` |
| Saat (gün içi) | `HH:mm`, **Europe/Istanbul** | `"08:00"` |
| Hafta günü | ISO — 1=Pazartesi … 7=Pazar | `[1,2,3,4,5]` |
| Alan adları | `snake_case` | `package_price_kurus` |
| Telefon | normalleştirilmiş 10 hane | `"5321234567"` |

Ondalıklı TL **hiçbir yerde telde gitmez.** TL ↔ kuruş dönüşümünün tek geçidi
sunucuda `Support\Money`, panelde geçidin kendisidir.

Gün içi saatler yerel (Europe/Istanbul) çünkü işletme kararıdırlar: "sabah
08:00 kesim" cümlesi UTC'ye çevrildiğinde yaz saati uygulamasıyla kayardı.
**Anlar** ise her zaman UTC — ikisini karıştırmayın.

Her yanıt `server_time` taşır (ISO 8601 UTC). Panel geri sayımları (kesim
saatine kalan süre) bunu temel alır; istemcinin saati kaymış olabilir.

---

## 7. Hata biçimi

Tek biçim (`Exceptions\ApiException`):

```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "Kesim saati HH:mm biçiminde olmalı.",
    "details": { "field": "order_cutoff" }
  }
}
```

İstemci **HTTP durumuna değil `error.code`'a bakar**. `message` doğrudan
kullanıcıya gösterilebilir Türkçe metindir.

### 7.1 Mevcut kodlar (değişmez)

| Kod | HTTP | Ne zaman |
|---|---|---|
| `UNAUTHENTICATED` | 401 | İmza başlığı eksik/yanlış, pencere dışı, nonce tekrarı, sır tanımsız |
| `FORBIDDEN` | 403 | Uç var, bu istemciye kapalı |
| `NOT_FOUND` | 404 | Kayıt yok (uç var) |
| `VALIDATION_FAILED` | 422 | Gövde/parametre doğrulanamadı |
| `INVALID_TRANSITION` | 422 | Sipariş durum matrisi izin vermiyor |
| `LOCATION_CLOSED` | 422 | Satış kapalı |
| `ITEM_UNAVAILABLE` | 422 | Ürün o gün satılamaz |
| `SERVER_ERROR` | 500 | Beklenmeyen |

### 7.2 Yeni kodlar

| Kod | HTTP | Ne zaman | `details` |
|---|---|---|---|
| `CONFLICT` | 409 | Aynı anahtar zaten var, durum uygun değil ya da aradan değişti | `{"conflict": "<alan>", …}` |
| `STOCK_EXCEEDED` | 422 | Gün toplamı veya ürün tavanı aşılıyor | `{"scope": "day\|item", "menu_id": 41, "capacity": 120, "sold": 118, "requested": 5}` |

**İki kodla yetiniliyor.** Her yeni kod, istemcide yeni bir `if` demektir;
ayırt edilmesi ekranda **farklı bir davranış** gerektirmiyorsa
`VALIDATION_FAILED` + `details` yeterlidir. `CONFLICT` bilinçli olarak geniş
tutuldu: "zaten var", "durum uygun değil", "bağlı kayıt var" ve "aradan
değişti" hâllerinin hepsinde ekranın yapacağı şey aynı — tazele ve tekrar sor.
Ayrımı `details.conflict` taşır.

`STOCK_EXCEEDED` panel uçlarından yalnız
`POST /api/control/subscriptions/{id}/generate` içinde doğar (o günün tavanı
dolmuşsa); asıl evi müşteri sipariş yoludur (`POST /api/orders`). Panelde tavan
**yazan** uç (`PUT /control/menu/days/{date}/stock`) bu kodu üretmez — tavanı
satılmışın altına çekmek meşru bir eylemdir ve yanıtta `warnings` ile bildirilir.

Ayrı bir `IMMUTABLE` kodu **tanımlanmadı**: değiştirilemez kayıtlara giden bir
rota zaten yok (denetim izinde yazma ucu bulunmuyor, fatura `PATCH`'i
tanımlanmadı). Rotası olmayan bir hata kodu, istemciye asla ulaşmayacak bir
`if` yazdırırdı.

Laravel'in kendi 404/405'i `error` alanında düz metin taşır ya da hiç JSON
döndürmez. Kontrol Merkezi bu farkı **"uç yayında değil"** ile **"kayıt yok"**u
ayırmak için kullanır; sunucu tarafı bu ayrımı bozmamalı, yani mevcut bir uçtan
gelen 404 mutlaka `ApiException::notFound()` olmalıdır.

---

## 8. Denetim izi

Her yazma `veykemtu_control_audit`'e bir satır yazar. Kabuk
`ControlController::write()`'tır ve sırası değişmez:

1. `actor` (+ ucun istediği hâllerde `reason`, §3) doğrulanır → geçersizse
   **422 ve denetim satırı YOK** (geçerli bir istek hiç oluşmadı),
2. denetim satırı **işlemden önce** açılır (`pending` ya da `dry_run`),
3. kuru provada `$apply` hiç çağrılmaz,
4. hata çıkarsa satır `failed` işaretlenir (kuru prova satırı `dry_run` kalır)
   ve istisna yukarı gider.

**Satır gerekçeden bağımsız olarak her yazmada açılır.** Gerekçe istenmeyen
uçlarda yalnız `reason` sütunu boş kalır; `actor`, `action`, hedef ve
`payload_json` her koşulda yazılır. Denetim izinin taşıyıcısı gerekçe değil,
satırın kendisidir.

### 8.1 Yeni `ControlAudit::TARGET_*` sabitleri

Mevcut: `TARGET_DEVICE = 'kitchen_device'`, `TARGET_ORDER = 'order'`.
Eklenecekler (`target_type` sütunu `string(32)`, hepsi sığar):

| Sabit | Değer | `target_id` |
|---|---|---|
| `TARGET_DAILY_MENU` | `daily_menu` | `veykemtu_daily_menus.id` |
| `TARGET_MENU` | `menu` | `menus.menu_id` |
| `TARGET_CATEGORY` | `category` | `categories.category_id` |
| `TARGET_SETTINGS` | `settings` | `location_id` |
| `TARGET_CLOSED_DAY` | `closed_day` | `veykemtu_closed_days.id` |
| `TARGET_SUBSCRIPTION` | `subscription` | `veykemtu_subscriptions.id` |
| `TARGET_QUOTE_REQUEST` | `quote_request` | `veykemtu_quote_requests.id` |
| `TARGET_SUBSCRIPTION_CONTRACT` | `subscription_contract` | `veykemtu_subscription_contracts.id` |
| `TARGET_SUBSCRIPTION_PAYMENT` | `subscription_payment` | `veykemtu_subscription_payments.id` |
| `TARGET_CUSTOMER` | `customer` | `customers.customer_id` |
| `TARGET_INVOICE` | `invoice` | `veykemtu_invoices.id` |
| `TARGET_SITE_CONTENT` | `site_content` | `null` (anahtar `payload_json.key`) |
| `TARGET_SITE_SERVICE` | `site_service` | `veykemtu_site_services.id` |
| `TARGET_SITE_POST` | `site_post` | `veykemtu_site_posts.id` |
| `TARGET_SMS_TEMPLATE` | `sms_template` | `null` (anahtar `payload_json.key`) |
| `TARGET_ANNOUNCEMENT` | `announcement` | `null` |
| `TARGET_NOTIFICATION` | `notification` | `veykemtu_notifications.id` |
| `TARGET_MONITOR_EVENT` | `monitor_event` | `veykemtu_monitor_events.id` |

`action` adları `<alan>.<eylem>` biçiminde ve nokta ayrılmıştır:
`menu.publish`, `product.create`, `settings.sales`, `order.cancel`,
`subscription.activate`, `customer.read`, `invoice.void`, `cms.revalidate`,
`sms.announcement.run`, `notification.publish`, `monitor.resolve`. Tam liste
alan dosyalarındaki tablolardadır.

### 8.2 `payload_json` neyi taşır

**İsteğin özeti, tam gövdesi değil.** Yalnız eylemi anlamlandıran alanlar:
hangi gün, kaç kalem, hangi ayar, eski ve yeni değer. Ham gövdeyi saklamak
müşteri notu gibi kişisel veriyi ikinci bir yerde çoğaltırdı.

**Asla yazılmaz:** parola, token, eşleme kodu, base64 görsel içeriği, SMS
gövdesinin tamamı, müşteri adresi. Görselde yalnız `{"bytes": 184320,
"mime": "image/jpeg"}` yazılır.

---

## 9. KVKK — `control/customers/*` okumaları da denetlenir

Diğer alanlarda yalnız **yazmalar** denetim izine düşer. `control/customers/*`
farklıdır: **okumalar da düşer.** Sebep, bu uçların sistemdeki en geniş kişisel
veri yüzeyi olması — ad, telefon, e-posta, kurum bilgisi, adres geçmişi ve
sipariş geçmişi tek ekranda birleşiyor. "Kim, ne zaman, kimin kaydını açtı"
sorusunun bir cevabı olmalı; yazma izi tek başına o soruya cevap vermiyor,
çünkü sızıntı çoğu zaman bir yazma değil bir okumadır.

Uygulama kuralları:

1. `control/customers/*` altındaki her `GET` **`actor` sorgu parametresini
   zorunlu** kılar (2–120 karakter). Eksikse `422`.
2. Sunucu `action = "customer.read"` ile bir denetim satırı yazar;
   `result = "applied"`, `target_type = "customer"`, `target_id` tekil kayıtta
   müşteri kimliği, listede `null`.
3. `reason` okumalarda **istemciden istenmez**; sunucu sabit bir metin yazar:
   `"Kişisel veri görüntüleme: <yol>"`. `reason` sütunu `NOT NULL` ve en az 10
   karakter beklendiği için üretilen metin bu sınırı karşılar.
4. `payload_json` yalnız süzgeçleri taşır (`{"q": "acme", "page": 2}`).
   **Dönen kayıtların kendisi yazılmaz** — denetim izini ikinci bir müşteri
   veritabanına çevirirdi.

> KARAR: `actor` sorgu dizesinde taşınır ve **imzaya girmez** (kanonik dize
> sorguyu dışlıyor). Bu, alanın kriptografik olarak bağlanmadığı anlamına gelir
> — ama zaten `actor` yazma uçlarında da serbest metindir ve imza yalnız
> "Kontrol Merkezi'nden geldi"yi kanıtlar. Kanonik dizeyi değiştirmek K-21'i
> kırardı; onun yerine sınır olduğu gibi yazıldı.

> KARAR: `control/customers/*` uçları **yoklanmaz.** Panel bu ekranlarda
> otomatik yenileme kurmaz; her okuma yöneticinin bilinçli bir eylemidir.
> 15 saniyede bir yoklayan bir ekran, denetim izini günde binlerce anlamsız
> satırla doldurup içindeki gerçek erişimi görünmez kılardı.

---

## 10. Yetkiler (Kontrol Merkezi tarafı)

BLD sunucusu imzayı doğrular ve **kim olduğuna bakmaz**; ince yetki ayrımı
Kontrol Merkezi'nin kendi izin sistemindedir (K9). Alan dosyalarındaki "İzin"
sütunu **Kontrol Merkezi izinlerini** gösterir, BLD yetkisini değil.

| İzin | Kapsam |
|---|---|
| `bld_menu.view` / `bld_menu.manage` | menu, products |
| `bld_sales.view` / `bld_sales.manage` | settings, orders |
| `bld_subs.view` / `bld_subs.manage` | subscriptions |
| `bld_customers.view` / `bld_customers.manage` | customers — **ayrı kutu, KVKK** |
| `bld_invoices.view` / `bld_invoices.manage` | invoices |
| `bld_cms.view` / `bld_cms.manage` | cms |
| `bld_comms.view` / `bld_comms.manage` | sms, notifications |
| `bld_monitor.view` / `bld_monitor.manage` | monitor |
| `bld_audit.view` | audit, dashboard |

`bld_customers.*` ayrı durur çünkü içerik yazan ya da menü kuran birinin
müşteri telefon defterine erişmesi için hiçbir sebep yok.

---

## 11. Bilerek yapılmayanlar

- **Idempotency anahtarı yok.** Sözleşmede böyle bir başlık tanımlı değil ve
  eklenmedi; bu yüzden **yazma yinelenmez.** Zaman aşımına uğrayan bir yazma
  uzakta uygulanmış olabilir. Tek istisna `429`: hız sınırı isteği
  denetleyiciye hiç ulaştırmaz, yan etkisi yoktur.
- **Toplu (bulk) uç yok.** "Seçilenleri sil", "hepsini yayınla" gibi uçlar
  tanımlanmadı: tek gerekçe ile onlarca kaydı değiştirmek, denetim izini
  okunamaz kılar.
- **Silme çoğu yerde yumuşak.** Ürün `menu_status = 0`, abonelik
  `status = cancelled`, fatura `status = void`. Gerçek `DELETE` yalnızca
  bağlantısı olmayan yardımcı kayıtlarda var (menü kalemi, kapalı gün,
  istisna) ve her birinde neden güvenli olduğu alan dosyasında yazılı.
- **Websocket / SSE yok.** Panel yoklar. Canlı akış, imzalı ve nonce'lu bir
  şemayla uyumsuz olurdu.
- **Sürüm öneki (`/v2`) yok.** Sözleşme additive büyür (`AGENTS.md` §2.3):
  alan eklenir, adı ve tipi değişmez, alan silinmez.
