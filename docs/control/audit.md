# `control/audit` — Denetim izi

Yol öneki: **`/api/control/audit`** · Sınır: `bld-control-panel` ·
Ortak kurallar: `00-genel.md`

"Kim, ne zaman, neyi, neden değiştirdi" sorusunun tek cevabı. Tablo:
`veykemtu_control_audit` (`Models\ControlAudit`).

> ## SALT OKUNUR. YAZMA UCU YOKTUR VE OLMAYACAKTIR.
>
> Bu alanda `POST`, `PATCH`, `PUT` ve `DELETE` **tanımlı değildir.** Satır
> silinmez, düzeltilmez, gizlenmez. Denetim izini silebilen bir denetim izi,
> denetim izi değildir.
>
> `ControlAudit` sınıfında da silme yolu yok ve açılmayacak. Tek güncelleme
> `result` alanına dokunur (`pending` → `applied` / `failed`) ve onu da
> `ControlController::write()` kabuğu yapar.

---

## Uçlar

| Metot | Yol | Amaç | İzin | dry_run | Gerekçe |
|---|---|---|---|---|---|
| GET | `/` | Denetim satırları (**sayfalı**) | `bld_audit.view` | — | — |
| GET | `/{id}` | Tek satır + tam `payload_json` | `bld_audit.view` | — | — |
| GET | `/actions` | Bilinen eylem adları | `bld_audit.view` | — | — |

`/actions` bir sözlük ucudur: panelin süzgeç açılır listesini doldurur.
Eylem adlarını panele gömmek, sunucuya yeni bir eylem eklendiğinde süzgecin
eksik kalması demekti.

---

## Şema

| Alan | Tip | Kolon | Not |
|---|---|---|---|
| `id` | int | `id` | |
| `actor` | string | `actor` (120) | Kontrol Merkezi'nin bildirdiği ad |
| `action` | string | `action` (64) | `menu.publish`, `order.cancel` … |
| `target_type` | string\|null | `target_type` (32) | `00-genel.md` §8.1 |
| `target_id` | int\|null | `target_id` | |
| `target_label` | string\|null | *türetilir* | İnsan okunur etiket |
| `reason` | string | `reason` (500) | En az 10 karakter |
| `payload_json` | object\|null | `payload_json` | Listede **kırpılır** |
| `result` | `pending`\|`applied`\|`failed`\|`dry_run` | `result` | |
| `created_at` | ISO 8601 UTC | `created_at` | |

### `result` ne anlatır

| Değer | Anlamı |
|---|---|
| `pending` | Satır açıldı, işlem henüz bitmedi. **Kalıcı `pending` bir arızadır** |
| `applied` | Yazma uygulandı |
| `failed` | Yazma denendi ve hata aldı; sebep `payload_json.error` içinde |
| `dry_run` | Kuru prova; hiçbir şey yazılmadı |

Satır **işlemden önce** açılır. Sonra açılsaydı yarıda kalan bir yazma
(veritabanı hatası, zaman aşımı) hiçbir iz bırakmazdı — oysa "denendi ve
olmadı" tam da soruşturulması gereken hâldir.

Kuru provanın sonucu **hiçbir zaman `failed` olmaz.** Ön denetim başarısız olsa
bile satır `dry_run` kalır ve sebep `payload_json.error`'a yazılır. Aksi hâlde
denetim ekranında provalar gerçek yazma denemeleriyle karışırdı.

`target_label` sunucuda üretilir ve tek kaynaktır:

| `target_type` | Etiket |
|---|---|
| `kitchen_device` | Cihaz adı |
| `order` | Sipariş numarası (`BLD-8421`) |
| `daily_menu` | `17.08.2026 menüsü` |
| `menu` | Ürün adı |
| `customer` | Kurum adı ya da ad soyad |
| `subscription` | `#18 — Acme Gıda A.Ş.` |
| `invoice` | Belge numarası |
| `settings` | Vitrin adı |

Hedef kayıt silinmişse `target_label` `null` döner ve satır yerinde kalır.
Denetim satırı hedefine bağımlı değildir.

---

## `GET /` — liste

Sorgu:

| Ad | Tip | Varsayılan | Not |
|---|---|---|---|
| `actor` | string | — | Tam ya da kısmi eşleşme |
| `action` | string | — | Virgüllü liste; `menu.*` gibi **önek** de kabul edilir |
| `target_type` | string | — | |
| `target_id` | int | — | `target_type` ile birlikte anlamlı |
| `result` | string | — | Virgüllü liste |
| `from` / `to` | ISO 8601 UTC | son 30 gün | `created_at` |
| `q` | string | — | `reason` içinde arar |
| `page` / `per_page` | int | 1 / 50 | tavan 100 |

Varsayılan sıra: `id` azalan. En son ne yapıldı sorusu, en sık sorulan.

Varsayılan pencere **son 30 gün**. Sınırsız bir varsayılan, ilk sayfayı
göstermek için tablonun tamamını saydırırdı.

`action` **öneki** kabul eder: `menu.*` bütün menü eylemlerini getirir. Otuz
küsur eylem adını tek tek seçtirmek, panelin kullanılamaz bir süzgeç çizmesi
demekti.

```json
{
  "data": [
    {
      "id": 2501,
      "actor": "Ayşe Yılmaz",
      "action": "monitor.resolve",
      "target_type": "monitor_event",
      "target_id": 3311,
      "target_label": null,
      "reason": "Yazıcı kablosu değiştirildi, deneme fişi başarılı",
      "payload_json": { "code": "printer_unreachable", "device_id": 2 },
      "payload_truncated": false,
      "result": "applied",
      "created_at": "2026-08-16T09:05:00Z"
    },
    {
      "id": 2500,
      "actor": "Ayşe Yılmaz",
      "action": "menu.publish",
      "target_type": "daily_menu",
      "target_id": 214,
      "target_label": "17.08.2026 menüsü",
      "reason": "17 Ağustos menüsü kontrol edildi ve yayına alındı",
      "payload_json": { "date": "2026-08-17", "from": "draft", "to": "published", "item_count": 4 },
      "payload_truncated": false,
      "result": "applied",
      "created_at": "2026-08-16T08:40:00Z"
    }
  ],
  "meta": {
    "page": 1, "per_page": 50, "total": 2501, "last_page": 51,
    "counts_by_result": { "applied": 2310, "failed": 41, "dry_run": 148, "pending": 2 }
  },
  "server_time": "2026-08-16T09:00:00Z"
}
```

`payload_json` listede **2 KB'de kırpılır** ve `payload_truncated: true` olur;
tam hâli `GET /{id}` ile okunur. Elli satırlık bir sayfada tam yükleri taşımak,
yanıtı megabaytlara çıkarırdı.

`meta.counts_by_result` **süzgeçlenmiş kümenin** dağılımıdır. `pending` sayısı
sıfırdan büyükse panel uyarı gösterir: kalıcı `pending`, yarıda kalmış bir
yazma demektir ve incelenmelidir.

---

## `GET /{id}`

Tam satır, `payload_json` kırpılmadan.

```json
{
  "data": {
    "id": 1801,
    "actor": "Ayşe Yılmaz",
    "action": "order.revise",
    "target_type": "order",
    "target_id": 8421,
    "target_label": "BLD-8421",
    "reason": "Müşteri telefonla iki porsiyon azalttı",
    "payload_json": {
      "item_count": 1,
      "items": [ { "menu_id": 88, "quantity": 10, "option_value_ids": [], "note": null } ],
      "requested_at": null
    },
    "payload_truncated": false,
    "result": "applied",
    "created_at": "2026-08-16T06:20:00Z"
  },
  "server_time": "2026-08-16T09:00:00Z"
}
```

Başarısız bir satırda `payload_json.error` doludur:

```json
{
  "payload_json": {
    "from": "yeni", "to": "yolda",
    "error": "Bu geçişe izin verilmiyor: yeni → yolda"
  },
  "result": "failed"
}
```

---

## `GET /actions`

```json
{
  "data": [
    { "action": "menu.day.create", "group": "menu", "label": "Menü günü oluşturuldu", "count": 61 },
    { "action": "menu.publish", "group": "menu", "label": "Menü yayınlandı", "count": 58 },
    { "action": "order.revise", "group": "order", "label": "Sipariş revize edildi", "count": 143 },
    { "action": "customer.read", "group": "customer", "label": "Kişisel veri görüntülendi", "count": 902 }
  ],
  "meta": { "groups": ["menu", "product", "category", "settings", "order", "subscription",
                       "customer", "invoice", "cms", "sms", "notification", "monitor", "device"] },
  "server_time": "2026-08-16T09:00:00Z"
}
```

`count` **son 90 günün** sayısıdır; hiç kullanılmamış eylemler de listede döner
(`count: 0`). Yalnız kullanılanları döndürmek, panelin süzgecinde yeni bir
eylemi ilk kullanılana kadar göstermemesi demekti.

`label` Türkçedir ve **sunucudan gelir.** Panelin kendi çeviri tablosunu
tutması, sunucuya yeni bir eylem eklendiğinde ekranda ham `snake_case` bir ad
görünmesiyle biterdi.

---

## Kişisel veri

`payload_json`'a **ne yazılacağı sıkı bir kuraldır** (`00-genel.md` §8.2) ve
bu ucun okunabilir kalması ona bağlı. Yazılmayanlar:

parola · token · eşleme kodu · imza bağlantısı (`sign_url`) · base64 görsel
içeriği · SMS gövdesinin tamamı · müşteri adresi · maskesiz telefon ve e-posta.

`customer.update` satırlarında telefon **maskeli** yazılır (`532****567`);
`sms.send_test` satırlarında da öyle. Denetim izi "ne değişti" sorusuna cevap
vermeli, kişisel verinin ikinci bir kopyasını tutmamalı.

`GET /audit` **kendisi denetlenmez.** Denetim izini okumayı denetlemek, her
okumanın yeni bir satır ürettiği ve o satırın okunmasının bir satır daha
ürettiği bir döngü kurardı.

---

## Saklama

Satır silinmiyor ve tablo büyüyor. Bu bilinçli ve sözleşme bir saklama süresi
**tanımlamıyor**: bir denetim izinin ömrünü teknik bir eşik değil, hukuki bir
karar belirler.

Tablo yönetilemez büyüklüğe ulaştığında yapılacak şey silmek değil,
**arşivlemektir** (soğuk depoya taşıma). Arşivleme yordamı bu sözleşmenin
dışındadır ve `docs/RUNBOOK.md` işidir.

Kaba hesap: yoğun bir günde ~200 yazma + `customer.read` satırları ≈ 400
satır/gün, satır başına ~1 KB → yılda ~150 MB. Yıllarca sorun çıkarmaz.

---

## Denetim eylemleri

Yok. Bu alan yalnızca okur.
