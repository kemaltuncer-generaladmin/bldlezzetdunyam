# `control/monitor` — Hata olayları ve cihaz sağlığı

Yol öneki: **`/api/control/monitor`** · Sınır: `bld-control-panel` ·
Ortak kurallar: `00-genel.md`

Sistemin dört bileşeninden (KDS kasası, müşteri uygulaması, site, sunucu) gelen
hata ve uyarı olaylarının tek havuzu. "Bir şey çalışmıyor" şikâyeti geldiğinde
bakılacak ilk ekran.

Bu alan **kasaların kendisini yönetmez** — o iş `control/kds/*` ailesindedir
(`bld_kds` modülü). Burada yalnız sağlık **okunur**.

> **BAŞKA AJANIN KULVARI — yeni tablo gerekiyor.** `veykemtu_monitor_events`:
> `id`, `source` (string 24, indeks), `level` (string 16, indeks),
> `code` (string 64, indeks), `message` (string 500),
> `context` (json, nullable), `device_id` (unsignedBigInteger, nullable, indeks),
> `app_version` (string 32, nullable), `fingerprint` (string 64, indeks),
> `occurrence_count` (unsignedInteger, default 1),
> `first_seen_at` (timestamp), `last_seen_at` (timestamp, indeks),
> `resolved_at` (timestamp, nullable, indeks),
> `resolved_by_actor` (string 120, nullable),
> `resolve_note` (string 500, nullable), `created_at`.
> `UNIQUE(fingerprint)` — tekilleştirme için (aşağıya bakın).

> **BAŞKA AJANIN KULVARI — yazma ucu gerekiyor.** Olayları **bileşenler**
> yazar. Kasa için `POST /api/kitchen/monitor/event` (mutfak kapsamı), müşteri
> uygulaması ve site için imzalı ya da kimlikli bir uç gerekir. Bu sözleşme
> yalnız **okuma ve çözme** tarafını dondurur; yazma ucunun gövdesi burada
> tanımlı `MonitorEvent` alanlarıyla birebir olmalıdır.

---

## Uçlar

| Metot | Yol | Amaç | İzin | dry_run | Gerekçe |
|---|---|---|---|---|---|
| GET | `/events` | Olay listesi (**sayfalı**) | `bld_monitor.view` | — | — |
| GET | `/events/{id}` | Tek olay + bağlam | `bld_monitor.view` | — | — |
| POST | `/events/{id}/resolve` | Çözüldü işaretle | `bld_monitor.manage` | ✔ | ✔ |
| GET | `/devices` | Kasa sağlık özeti | `bld_monitor.view` | — | — |
| GET | `/summary` | Sayaçlar | `bld_monitor.view` | — | — |

`DELETE` yoktur. Bir hata kaydını silmek, o hatanın hiç olmadığını iddia
etmektir; çözülen olay `resolved_at` ile işaretlenir ve listeden düşer.

---

## Tekilleştirme — `fingerprint`

Aynı hata saatte yüzlerce kez tekrarlanabilir (kasa yazıcıya ulaşamıyor, her
yoklamada bir kayıt). Her tekrarı ayrı satır yazmak, tabloyu bir günde okunamaz
hâle getirirdi.

Bu yüzden olaylar **parmak izine göre birleştirilir**:

```
fingerprint = sha256( source + "|" + code + "|" + device_id + "|" + normalize(message) )
```

`normalize(message)` sayıları ve UUID'leri sabit belirteçlerle değiştirir
(`123` → `<n>`, uuid → `<id>`), böylece "Sipariş 8421 basılamadı" ile "Sipariş
8422 basılamadı" **aynı** olayın iki tekrarı sayılır.

Aynı parmak izli bir olay geldiğinde: `occurrence_count` artar, `last_seen_at`
güncellenir, **`resolved_at` sıfırlanır** (yeniden açılır). Çözülmüş sanılan
bir hatanın tekrarı, yeni bir olaydan daha önemlidir.

`first_seen_at` **hiç değişmez** — "bu ne zamandır oluyor" sorusunun cevabı.

---

## Şema — `MonitorEvent`

| Alan | Tip | Değerler |
|---|---|---|
| `id` | int | |
| `source` | string | `mutfakapp` \| `musteriapp` \| `website` \| `platform` \| `kontrol_merkezi` |
| `level` | string | `info` \| `warning` \| `error` \| `critical` |
| `code` | string | `printer_unreachable`, `order_sync_failed` … |
| `message` | string | Türkçe, en çok 500 karakter |
| `context` | object\|null | Serbest JSON, en çok 8 KB |
| `device_id` | int\|null | `veykemtu_kitchen_devices.id` |
| `device_name` | string\|null | *türetilir* |
| `app_version` | string\|null | |
| `occurrence_count` | int | |
| `first_seen_at` | ISO 8601 UTC | |
| `last_seen_at` | ISO 8601 UTC | |
| `resolved_at` | ISO 8601 UTC\|null | `null` = açık |
| `resolved_by_actor` | string\|null | |
| `resolve_note` | string\|null | |

`level` seviyeleri:

| Seviye | Ne demek | Panelde |
|---|---|---|
| `info` | Kayda değer ama eylem gerektirmez | Gri, varsayılan süzgeçte **gizli** |
| `warning` | Bakılmalı, iş durmuyor | Sarı |
| `error` | Bir iş yapılamadı | Kırmızı |
| `critical` | Sistem işlevini kaybetti | Kırmızı + panelde kalıcı şerit |

`info` varsayılan süzgeçte gizlidir: bilgi seviyesindeki olaylar sayıca en
kalabalık olanlardır ve listeyi doldurup gerçek hataları görünmez kılarlar.

---

## `GET /events`

Sorgu:

| Ad | Tip | Varsayılan | Not |
|---|---|---|---|
| `source` | string | — | Virgüllü liste |
| `level` | string | `warning,error,critical` | Virgüllü liste |
| `code` | string | — | |
| `device_id` | int | — | |
| `since` | ISO 8601 UTC | son 7 gün | `last_seen_at` üzerinden |
| `resolved` | `true`\|`false`\|`all` | `false` | Varsayılan: **açık olanlar** |
| `q` | string | — | Mesaj ve kodda arar |
| `page` / `per_page` | int | 1 / 25 | tavan 100 |

Varsayılan sıra: `last_seen_at` azalan. En son ne oldu sorusu, en sık sorulan.

```json
{
  "data": [
    {
      "id": 3311,
      "source": "mutfakapp",
      "level": "error",
      "code": "printer_unreachable",
      "message": "Yazıcıya ulaşılamadı: /dev/usb/lp0 açılamıyor",
      "device_id": 2,
      "device_name": "Mutfak Kasa 1",
      "app_version": "1.4.2",
      "occurrence_count": 47,
      "first_seen_at": "2026-08-16T05:12:00Z",
      "last_seen_at": "2026-08-16T08:58:00Z",
      "resolved_at": null,
      "resolved_by_actor": null,
      "resolve_note": null
    }
  ],
  "meta": {
    "page": 1, "per_page": 25, "total": 6, "last_page": 1,
    "open_counts": { "info": 12, "warning": 3, "error": 2, "critical": 1 }
  },
  "server_time": "2026-08-16T09:00:00Z"
}
```

`context` **listede dönmez** — sekiz kilobaytlık bağlam nesnelerini yirmi beş
satır için taşımak, ekranın hiç göstermediği veriyi yollamak olurdu.

`meta.open_counts` süzgeçten **bağımsızdır**: açık olayların seviye dağılımını
her zaman tam gösterir, çünkü panel bunu sekme rozetlerinde kullanıyor ve
süzgece göre değişen bir rozet yanıltıcı olurdu.

---

## `GET /events/{id}`

Tam kayıt + `context`.

```json
{
  "data": {
    "id": 3311,
    "source": "mutfakapp",
    "level": "error",
    "code": "printer_unreachable",
    "message": "Yazıcıya ulaşılamadı: /dev/usb/lp0 açılamıyor",
    "context": {
      "device_path": "/dev/usb/lp0",
      "errno": 13,
      "queue_pending": 4,
      "last_successful_print_at": "2026-08-16T05:02:00Z"
    },
    "device_id": 2,
    "device_name": "Mutfak Kasa 1",
    "app_version": "1.4.2",
    "occurrence_count": 47,
    "first_seen_at": "2026-08-16T05:12:00Z",
    "last_seen_at": "2026-08-16T08:58:00Z",
    "resolved_at": null,
    "resolved_by_actor": null,
    "resolve_note": null,
    "related": {
      "device_online": true,
      "device_printer_ok": false,
      "queue_pending": 4,
      "queue_failed": 2
    }
  },
  "server_time": "2026-08-16T09:00:00Z"
}
```

`related` bloğu, olay bir cihaza bağlıysa o cihazın **şu anki** sağlığını
taşır. Olay saat 05:12'de kaydedildi; yönetici 09:00'da bakıyor ve asıl merak
ettiği "hâlâ bozuk mu" sorusudur. Ayrı bir cihaz çağrısı yapmak, ekranın iki
isteği sıraya koyması demekti.

`context` **kişisel veri taşımamalıdır.** Bunu yazan taraf (bileşenler) garanti
eder; sunucu bilinen anahtarları (`phone`, `email`, `address`, `token`,
`password`) **kayıt anında maskeler** — güvenmek yerine kesmek, sızıntının en
ucuz önlemidir.

---

## `POST /events/{id}/resolve`

```json
{
  "actor": "Ayşe Yılmaz",
  "reason": "Yazıcı kablosu değiştirildi, deneme fişi başarılı",
  "dry_run": false,
  "note": "USB kablosu kopmuştu, yedekle değiştirildi."
}
```

- Zaten çözülmüşse → `409 CONFLICT`. İkinci bir çözüm notu, ilkini gizlerdi.
- `note` isteğe bağlı, en çok 500 karakter; `reason` zaten zorunlu ve
  `resolve_note` alanına o metin yazılır. `note` verilirse ikisi birleştirilir
  (`reason` + `\n` + `note`).
- Çözülen olay **varsayılan listeden düşer** (`resolved=false` süzgeci).
- **Olay yeniden gelirse otomatik yeniden açılır** ve `resolved_at` sıfırlanır.
  Çözüm notu **silinmez**, `resolve_note` alanında kalır: "geçen sefer ne
  yapılmıştı" bilgisi, aynı hatanın ikinci kez teşhisinde en kısa yoldur.

```json
{
  "ok": true, "dry_run": false, "audit_id": 2501,
  "data": {
    "id": 3311, "resolved_at": "2026-08-16T09:05:00Z",
    "resolved_by_actor": "Ayşe Yılmaz",
    "resolve_note": "Yazıcı kablosu değiştirildi, deneme fişi başarılı\nUSB kablosu kopmuştu, yedekle değiştirildi."
  }
}
```

---

## `GET /devices`

Kasa sağlık özeti. `control/kds/devices` ucunun **dar bir yüzü**: ayar, komut ve
eşleme bilgisi taşımaz, yalnız "hangi kasa ne durumda" sorusuna cevap verir.

Neden ayrı bir uç: izleme ekranı `bld_monitor.view` yetkisiyle açılıyor ve o
yetkiyi taşıyan kişinin cihaz ayarlarını görmesi gerekmiyor. Aynı uca iki
yetkiyle bakmak, yetkilerin anlamını siler.

```json
{
  "data": [
    {
      "device_id": 2,
      "name": "Mutfak Kasa 1",
      "online": true,
      "last_seen_at": "2026-08-16T08:59:40Z",
      "app_version": "1.4.2",
      "printer_ok": false,
      "sound_ok": true,
      "alarm_muted": false,
      "queue_pending": 4,
      "queue_failed": 2,
      "queue_oldest_at": "2026-08-16T08:18:00Z",
      "queue_oldest_age_minutes": 41,
      "last_error": "Yazıcıya ulaşılamadı: /dev/usb/lp0",
      "health_reported_at": "2026-08-16T08:59:00Z",
      "revoked": false,
      "open_event_count": 2
    }
  ],
  "meta": {
    "total": 2, "online": 1, "revoked": 0,
    "printer_fault": 1, "queue_pending": 4, "queue_failed": 2
  },
  "server_time": "2026-08-16T09:00:00Z"
}
```

**Üç durumlu alanlar korunur.** `printer_ok`, `sound_ok` ve `alarm_muted`
`null` olabilir ve `null` "bilinmiyor" demektir, `false` değil. Sağlık
bildirmemiş bir kasa **arızalı sayılmaz**; `meta.printer_fault` yalnız
`printer_ok === false` olanları sayar. İkisini toplamak, yeni kurulan her
kasayı arıza sayacına yazardı.

`queue_oldest_age_minutes` **sunucuda hesaplanır** ve en çok işe yarayan
alandır: "kuyrukta 4 iş var" ile "kuyrukta 4 iş var ve en eskisi 41 dakikadır
bekliyor" arasındaki fark, sahaya gitme kararını değiştirir. İlki yazıcı
meşgulse normaldir, ikincisi kuyruğun akmadığı anlamına gelir.

`online` **sunucunun kararıdır** (`ONLINE_THRESHOLD_MINUTES = 3`). Kontrol
Merkezi kendi saatiyle hesaplasaydı, saati üç dakika kaymış bir panelde bütün
mutfak çevrimdışı görünürdü.

İptal edilmiş cihazlar listede **kalır** (`revoked: true`) ama sayaçlara
girmez: "o kasa neredeydi" sorusunun cevabı listede olmalı.

---

## `GET /summary`

Tek istekte izleme durumu. Panelin izleme rozeti bunu yoklar (60 sn).

```json
{
  "data": {
    "events": {
      "open": { "info": 12, "warning": 3, "error": 2, "critical": 1 },
      "open_total": 18,
      "critical_open": 1,
      "last_24h": { "info": 40, "warning": 9, "error": 6, "critical": 1 },
      "oldest_open_at": "2026-08-12T11:00:00Z",
      "by_source": { "mutfakapp": 4, "musteriapp": 1, "website": 0, "platform": 1, "kontrol_merkezi": 0 }
    },
    "devices": {
      "total": 2, "online": 1, "revoked": 0,
      "printer_fault": 1, "queue_pending": 4, "queue_failed": 2,
      "queue_oldest_age_minutes": 41
    },
    "health": {
      "status": "degraded",
      "reasons": ["printer_fault", "critical_event_open"]
    }
  },
  "server_time": "2026-08-16T09:00:00Z"
}
```

`health.status` **sunucunun tek cümlelik hükmüdür** ve üç değer alır:

| Değer | Koşul |
|---|---|
| `ok` | Açık `critical` yok, bütün kasalar çevrimiçi, yazıcı arızası yok |
| `degraded` | Yukarıdakilerden biri bozuk ama satış sürüyor |
| `down` | Hiçbir kasa çevrimiçi değil **veya** açık `critical` olay var ve kaynağı `platform` |

`reasons` makine okunur etiket listesidir; panel Türkçe karşılığını kendi
yazar. Hükmü sunucunun vermesi bilinçli: üç ayrı ekranın (izleme, gösterge
paneli, KDS yönetimi) aynı duruma bakıp farklı renk göstermesi, hangisine
inanılacağını belirsiz kılardı.

---

## Denetim eylemleri

| `action` | Uç | `target_type` / `target_id` |
|---|---|---|
| `monitor.resolve` | `POST /events/{id}/resolve` | `monitor_event` / id |

Bu alanda tek yazma ucu var. Okumalar denetlenmez: izleme ekranı yoklanıyor ve
her yoklamayı denetlemek, izin tamamını izleme trafiğine boğardı. İçerik
kişisel veri taşımıyor (`context` maskeleniyor), yani `customers` alanındaki
gerekçe burada geçerli değil.
