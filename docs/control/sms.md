# `control/sms` — SMS şablonları, kayıt ve duyuru

Yol öneki: **`/api/control/sms`** · Sınır: `bld-control-panel` ·
Ortak kurallar: `00-genel.md`

Push bildirimi (FCM) **yoktur** (iş kararı 11). Müşteriye ulaşmanın iki yolu
var: **SMS** (bu alan) ve **uygulama-içi duyuru** (`notifications.md`).

Sağlayıcı arayüzü `Services\Sms\SmsSender`; üretimde `NetgsmSmsSender`, sır
tanımsızsa `LogSmsSender`. Bu alan sağlayıcıyı bilmez, yalnız gönderim ister.

> **BAŞKA AJANIN KULVARI — iki yeni tablo gerekiyor.**
>
> `veykemtu_sms_templates`: `key` (string 48, **primary**), `title` (string 120),
> `body` (string 500), `enabled` (boolean, default true), `updated_at`.
>
> `veykemtu_sms_log`: `id`, `template_key` (string 48, nullable, indeks),
> `phone` (string 32, indeks), `customer_id` (nullable, indeks),
> `order_id` (nullable), `subscription_id` (nullable),
> `body` (string 500), `segments` (unsignedTinyInteger),
> `status` (string 16: `sent`\|`failed`), `error` (string 255, nullable),
> `provider_ref` (string 64, nullable), `context` (string 32 — `auto`\|`test`\|`announcement`),
> `sent_at` (timestamp, indeks).

---

## Uçlar

| Metot | Yol | Amaç | İzin | dry_run | Gerekçe |
|---|---|---|---|---|---|
| GET | `/templates` | Şablon listesi | `bld_comms.view` | — | — |
| PATCH | `/templates/{key}` | Şablon metni/durumu | `bld_comms.manage` | ✔ | ✔ |
| POST | `/templates/{key}/preview` | Örnek veriyle işle | `bld_comms.view` | ✔ | ✔ |
| POST | `/send-test` | Tek numaraya deneme | `bld_comms.manage` | ✔ | ✔ |
| GET | `/log` | Gönderim kaydı (**sayfalı**) | `bld_comms.view` | — | — |
| GET | `/announcement` | Duyuru taslağı | `bld_comms.view` | — | — |
| PUT | `/announcement` | Duyuruyu yaz | `bld_comms.manage` | ✔ | ✔ |
| POST | `/announcement/run` | Duyuruyu gönder | `bld_comms.manage` | ✔ | ✔ |

`preview` bir okuma gibi görünür ama **POST**'tur: örnek veriyi gövdeyle
taşıyor ve gövdesiz bir GET onu sorgu dizesine, yani imzanın dışına koyardı.
Yazma kabuğundan geçer, denetim satırı yazar ve `dry_run` anlar — böylece
"listede olmayan yola prova" tuzağı burada da yok.

---

## Şablonlar

Anahtarlar **sabittir**; listede olmayan bir anahtara `PATCH` → `404`.

| `key` | Ne zaman gider | Değişkenler |
|---|---|---|
| `order_created` | Sipariş oluştu | `order_no`, `service_date`, `total`, `customer_name` |
| `order_confirmed` | Sipariş onaylandı | `order_no`, `service_date` |
| `order_on_the_way` | Kurye çıktı | `order_no`, `eta` |
| `order_delivered` | Teslim edildi | `order_no` |
| `order_cancelled` | İptal edildi | `order_no`, `service_date`, `reason` |
| `order_revised` | Sipariş düzenlendi | `order_no`, `reason` |
| `subscription_contract` | Sözleşme bağlantısı | `customer_name`, `link`, `expires_at` |
| `subscription_payment_due` | Dönem borcu hatırlatma | `customer_name`, `period`, `amount`, `due_date` |
| `invoice_issued` | Fatura belgesi kesildi | `invoice_no`, `total`, `link` |
| `announcement` | Toplu duyuru | `customer_name` |

`otp_login` (giriş kodu) **bu listede yoktur ve olmayacaktır.** O metin
`OtpService` içindedir ve panelden düzenlenebilir olsaydı, kodun kendisini
metinden çıkarmak ya da bağlantı gömmek tek satırlık bir değişiklik olurdu.
Kimlik doğrulama metni yönetim yüzeyinden uzak durur.

### Değişken sözdizimi

`{degisken}` — süslü parantez, boşluksuz, küçük harf ve alt çizgi. Tanınmayan
bir değişken **kaydedilmez**: `PATCH` `422` verir,
`details = {"unknown_variables": ["musteri_adi"]}`. Sessizce boş bırakılan bir
değişken, müşteriye "Sayın , siparişiniz…" diye giden bir SMS üretirdi.

### `GET /templates`

```json
{
  "data": [
    {
      "key": "order_created",
      "title": "Sipariş alındı",
      "body": "Sayın {customer_name}, {service_date} tarihli {order_no} numaralı siparişiniz alındı. Tutar: {total} TL.",
      "enabled": true,
      "variables": ["order_no", "service_date", "total", "customer_name"],
      "length": 112,
      "segments": 1,
      "has_turkish_chars": true,
      "updated_at": "2026-08-02T10:00:00Z"
    }
  ],
  "meta": { "sender_driver": "netgsm", "sender_configured": true },
  "server_time": "2026-08-16T09:00:00Z"
}
```

`meta.sender_configured` `false` ise sağlayıcı sırrı tanımsızdır ve gönderimler
yalnız günlüğe yazılır (`LogSmsSender`). Panel bunu açıkça göstermeli; aksi
hâlde "SMS gitti" diyen bir ekran hiçbir şey göndermemiş olur.

### Uzunluk ve segment

`length` şablonun **değişkenler yerine konmuş hâlinin** değil, ham metnin
uzunluğudur; `segments` ise en kötü durum tahminidir.

- `has_turkish_chars: true` ise metin GSM-7 tablosuna sığmaz ve **UCS-2**
  gönderilir: tek segment **70** karakter (çoklu segmentte 67).
- Aksi hâlde GSM-7: tek segment **160** (çoklu segmentte 153).

Segment sayısı doğrudan maliyettir. Panel iki segmente geçen bir şablonu
uyarıyla göstermeli; sunucu **engellemez** çünkü bazı mesajlar gerçekten uzun.

### `PATCH /templates/{key}`

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Sipariş SMS metnine teslim saati eklendi",
  "dry_run": false,
  "body": "Sayın {customer_name}, {service_date} tarihli {order_no} numaralı siparişiniz alındı.",
  "enabled": true
}
```

- `body` 1–500 karakter; boş olamaz.
- `title` **yazılamaz** — şablonun adı sistemin kendi sözlüğüdür, yöneticinin
  değiştireceği bir şey değil.
- `enabled: false` o bildirimi tamamen kapatır. Kapalı bir şablon için gönderim
  denenmez ve kayda satır yazılmaz.

```json
{
  "ok": true, "dry_run": false, "audit_id": 2301,
  "data": { "key": "order_created", "length": 96, "segments": 2, "enabled": true,
            "updated_at": "2026-08-16T09:00:00Z" }
}
```

`payload_json` **metnin tamamını yazmaz**, yalnız
`{"key": "order_created", "length_from": 112, "length_to": 96, "enabled": true}`.

### `POST /templates/{key}/preview`

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Şablon metni gönderim öncesi kontrol edildi",
  "body": "Sayın {customer_name}, siparişiniz {service_date} günü hazır.",
  "sample": { "customer_name": "Mehmet Kaya", "service_date": "17.08.2026" }
}
```

- `body` verilmezse **kayıtlı şablon** işlenir; verilirse gönderilen taslak
  işlenir (kaydetmeden önce görmek için).
- `sample` verilmezse sunucu **gerçekçi örnek değerler** üretir.
- Hiçbir şey **gönderilmez**; bu uç ağa çıkmaz.

```json
{
  "ok": true, "dry_run": false, "audit_id": 2302,
  "data": {
    "key": "order_created",
    "rendered": "Sayın Mehmet Kaya, siparişiniz 17.08.2026 günü hazır.",
    "length": 53,
    "segments": 1,
    "encoding": "ucs2",
    "unresolved_variables": []
  }
}
```

`unresolved_variables` dolu ise metinde `sample` içinde karşılığı olmayan bir
değişken var demektir; işlenmiş metinde o değişken **olduğu gibi bırakılır**
(`{eta}`), boşa çevrilmez — yöneticinin eksiği görmesi gerekiyor.

---

## `POST /send-test`

Tek bir numaraya deneme SMS'i.

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Netgsm entegrasyonu kurulum sonrası doğrulandı",
  "dry_run": false,
  "phone": "5321234567",
  "template_key": "order_created",
  "sample": { "customer_name": "Deneme", "order_no": "BLD-0000", "service_date": "17.08.2026", "total": "180,00" }
}
```

- `phone` normalleştirilmiş 10 hane (`5xxxxxxxxx`) → değilse `422`.
- `template_key` yerine `body` de gönderilebilir (serbest metin denemesi);
  ikisi birden gönderilirse `422`.
- Metnin başına **`[DENEME]`** eklenir ve kaldırılamaz. Deneme SMS'inin gerçek
  bir bildirimden ayırt edilememesi, yanlış numaraya giden bir mesajın müşteride
  panik yaratması demekti.
- `dry_run: true` iken **hiçbir şey gönderilmez**; `would.rendered` döner.
- Sağlayıcı hata verirse `502` değil, **`ok: true` + `data.status: "failed"`**
  döner ve hata metni gövdededir. Gönderim denemesi kayda geçti; isteğin kendisi
  başarısız değil.

```json
{
  "ok": true, "dry_run": false, "audit_id": 2310,
  "data": {
    "log_id": 9912,
    "phone": "5321234567",
    "rendered": "[DENEME] Sayın Deneme, 17.08.2026 tarihli BLD-0000 numaralı siparişiniz alındı. Tutar: 180,00 TL.",
    "segments": 2,
    "status": "sent",
    "error": null
  }
}
```

---

## `GET /log`

Gönderim kaydı. Sağlayıcının kendi panelinden bağımsız, bizim tarafımızdaki
gerçek.

Sorgu: `phone`, `template_key`, `status` (`sent`\|`failed`), `context`
(`auto`\|`test`\|`announcement`), `customer_id`, `from`, `to`, `page`,
`per_page`.

```json
{
  "data": [
    {
      "id": 9912,
      "template_key": "order_created",
      "phone": "532****567",
      "customer_id": 312,
      "order_id": 8421,
      "subscription_id": null,
      "body": "Sayın Mehmet K., 16.08.2026 tarihli BLD-8421 numaralı siparişiniz alındı…",
      "segments": 2,
      "status": "sent",
      "error": null,
      "provider_ref": "NG-77219043",
      "context": "auto",
      "sent_at": "2026-08-15T18:04:12Z"
    }
  ],
  "meta": { "page": 1, "per_page": 25, "total": 4218, "last_page": 169,
            "sent_count": 4102, "failed_count": 116, "segment_total": 6840 },
  "server_time": "2026-08-16T09:00:00Z"
}
```

- **Telefon maskelenir** (ilk 3 + son 3). Tam numara zaten müşteri kartında ve
  orası denetleniyor; gönderim kaydı bir iletişim defterine dönüşmemeli.
- **Gövde 120 karakterde kırpılır** ve `…` ile biter. Tam metin şablondan
  okunabilir; kayıtta tutmanın amacı "hangi metin gitti"yi doğrulamak, arşiv
  değil.
- `meta.segment_total` süzgeçlenmiş kümenin segment toplamıdır — maliyet
  sorusunun cevabı.

Kayıt **silinemez** ve silme ucu yoktur.

---

## Duyuru

Toplu SMS. Tek bir taslak kaydı vardır ve `location_options` içinde yaşar
(kendi tablosunu açmaya değmeyecek kadar küçük).

> **BAŞKA AJANIN KULVARI.** Üç yeni `location_options` anahtarı:
> `bld_sms_announcement_body` (string), `bld_sms_announcement_audience`
> (string), `bld_sms_announcement_last_run_at` (ISO 8601 UTC).

### `GET /announcement`

```json
{
  "data": {
    "body": "Değerli müşterimiz, 30 Ağustos'ta hizmet veremeyeceğiz. Siparişlerinizi 29 Ağustos'a kadar iletebilirsiniz.",
    "audience": "active_customers",
    "length": 108,
    "segments": 2,
    "encoding": "ucs2",
    "last_run_at": "2026-07-14T09:00:00Z",
    "estimate": { "recipients": 186, "segments": 372 }
  },
  "server_time": "2026-08-16T09:00:00Z"
}
```

`estimate` **her okumada yeniden hesaplanır** — alıcı sayısı sürekli değişiyor
ve donmuş bir tahmin, yöneticinin sandığından fazla SMS göndermesi demekti.

### Kitle (`audience`)

| Değer | Kim |
|---|---|
| `active_customers` | `status = true` ve son 180 günde siparişi olan |
| `subscribers` | Aktif aboneliği olan müşteriler |
| `all_customers` | `status = true` olan herkes |

`all_customers` bilinçli olarak **en sonda** ve panelde ek onay ister: iki yıl
önce bir kez sipariş vermiş birine duyuru göndermek, spam şikâyeti ve numara
kaybı demektir.

Kitle seçimi telefon numarası olan kayıtlarla sınırlıdır; numarası olmayanlar
sessizce elenir ve `estimate.recipients` zaten elenmiş sayıyı verir.

### `PUT /announcement`

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "30 Ağustos kapanış duyurusu hazırlandı",
  "dry_run": false,
  "body": "Değerli müşterimiz, 30 Ağustos'ta hizmet veremeyeceğiz…",
  "audience": "active_customers"
}
```

Yalnız taslağı yazar, **göndermez.** Gönderme ayrı bir eylemdir ve ayrı bir
gerekçe ister; metni yazmakla göndermeyi tek tuşta birleştirmek, yazım hatasını
186 kişiye ulaştırır.

### `POST /announcement/run`

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "30 Ağustos kapanış duyurusu gönderildi",
  "dry_run": false,
  "confirm_recipients": 186
}
```

- `confirm_recipients` **zorunludur** ve sunucunun o andaki hesabıyla
  **birebir eşleşmelidir**; aksi hâlde `409 CONFLICT`,
  `details = {"conflict": "recipient_count", "expected": 191, "given": 186}`.
  Yönetici ekranda 186 görüp onayladıysa ve arada 5 müşteri daha eklendiyse,
  gönderimin sessizce büyümemesi gerekir. Ekran sayıyı tazeler ve yeniden
  sorar.
- Son çalıştırmadan **10 dakika** geçmeden ikinci gönderim → `409 CONFLICT`,
  `details = {"conflict": "cooldown", "retry_after_seconds": 420}`. Çift
  tıklama ile aynı duyuruyu iki kez almak, müşterinin gördüğü tek şeydir.
- `body` boşsa → `422`.
- Gönderim **kuyruğa alınmaz, akış hâlinde yapılır** ve her alıcı için
  `veykemtu_sms_log` satırı yazılır (`context = "announcement"`). Kuyruk
  altyapısı eklemek, bu turda gerekmeyen bir bağımlılık olurdu; 186 mesaj
  sağlayıcının toplu ucu ile tek istekte gider.

```json
{
  "ok": true, "dry_run": false, "audit_id": 2330,
  "data": {
    "recipients": 186,
    "sent": 184,
    "failed": 2,
    "segments": 368,
    "started_at": "2026-08-16T09:00:00Z",
    "finished_at": "2026-08-16T09:00:07Z",
    "failures": [ { "phone": "533****112", "error": "Geçersiz numara" } ]
  }
}
```

`failures` en çok **20 satır** taşır; fazlası `GET /log?status=failed` ile
okunur. Yanıtı yüzlerce hatayla şişirmek, ekranda okunamayan bir liste üretirdi.

Kuru prova `would`:

```json
{
  "action": "sms.announcement.run",
  "audience": "active_customers",
  "recipients": 186,
  "segments": 368,
  "sample_rendered": "Değerli müşterimiz, 30 Ağustos'ta hizmet veremeyeceğiz…"
}
```

---

## Denetim eylemleri

| `action` | Uç | `target_type` / `target_id` |
|---|---|---|
| `sms.template.update` | `PATCH /templates/{key}` | `sms_template` / `null` |
| `sms.template.preview` | `POST /templates/{key}/preview` | `sms_template` / `null` |
| `sms.send_test` | `POST /send-test` | `null` / `null` |
| `sms.announcement.update` | `PUT /announcement` | `announcement` / `null` |
| `sms.announcement.run` | `POST /announcement/run` | `announcement` / `null` |

Denetim satırlarına **telefon numarası yazılmaz** — `send-test` payload'ında
maskeli hâli durur (`532****567`). Gönderilen metnin tamamı da yazılmaz; kayıt
zaten `veykemtu_sms_log`'da.
