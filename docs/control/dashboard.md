# `control/dashboard` — Açılış özeti

Yol öneki: **`/api/control/dashboard`** · Sınır: `bld-control-panel` ·
Ortak kurallar: `00-genel.md`

Panel açıldığında görülen tek ekran. **Tek istek**, çünkü açılış ekranı: on
farklı uçtan sayı toplamak, panelin her açılışında on ağır sorgu demekti ve
sayılar istemcide hesaplansaydı "kaç sipariş aktif" sorusunun cevabı panel
sürümüne göre değişirdi.

`control/kds/overview` ile karıştırılmamalı: o uç **KDS yönetimi** ekranının
özetidir (cihaz, fiş, aktif sipariş) ve olduğu gibi kalır. Bu uç işletmenin
tamamına bakar.

---

## Uçlar

| Metot | Yol | Amaç | İzin | dry_run | Gerekçe |
|---|---|---|---|---|---|
| GET | `/overview` | Tam açılış özeti | `bld_audit.view` | — | — |

Tek uç. Yoklama aralığı **30 saniye** (bütçe hesabı `00-genel.md` §2).

---

## `GET /overview`

Sorgu: `location_id` (opsiyonel), `date` (opsiyonel `YYYY-MM-DD`, varsayılan
bugün — servis günü).

```json
{
  "data": {
    "date": "2026-08-16",
    "location_id": 1,

    "sales": {
      "ordering_enabled": true,
      "paused_until": null,
      "busy": false,
      "cutoff_time": "08:00",
      "cutoff_at": "2026-08-17T05:00:00Z",
      "cutoff_passed_for_today": true,
      "seconds_to_next_cutoff": 72000,
      "next_cutoff_date": "2026-08-17"
    },

    "orders": {
      "by_status": {
        "yeni": 4,
        "onaylandi": 9,
        "hazirlaniyor": 12,
        "hazir": 3,
        "yolda": 2
      },
      "active": 30,
      "delivered_today": 41,
      "cancelled_today": 2,
      "created_today": 73,
      "late": 1,
      "revenue_today_kurus": 13140000,
      "unreleased_subscription_orders": 0
    },

    "capacity": {
      "menu_published": true,
      "capacity_total": 120,
      "sold_total": 86,
      "sold_orders": 66,
      "sold_subscriptions": 20,
      "remaining_total": 34,
      "fill_rate": 0.72,
      "blocked_items": [
        { "menu_id": 27, "name": "Tavuk Sote", "capacity": 60, "sold": 60 }
      ]
    },

    "subscriptions": {
      "active": 7,
      "pending": 2,
      "paused": 1,
      "portions_today": 20,
      "contracts_awaiting_signature": 1,
      "unpaid_periods": 3,
      "unpaid_total_kurus": 1920000,
      "overdue_periods": 1,
      "overdue_total_kurus": 640000
    },

    "devices": {
      "total": 2,
      "online": 1,
      "revoked": 0,
      "printer_fault": 1,
      "queue_pending": 4,
      "queue_failed": 2,
      "queue_oldest_age_minutes": 41
    },

    "monitor": {
      "open_total": 18,
      "critical_open": 1,
      "error_open": 2,
      "warning_open": 3,
      "health_status": "degraded"
    },

    "pending_tasks": [
      {
        "code": "menu_missing",
        "level": "critical",
        "title": "Yarının menüsü girilmemiş",
        "detail": "17 Ağustos için yayınlanmış menü yok. Kesim saatine 20 saat kaldı.",
        "count": 1,
        "link": "/menu/days/2026-08-17"
      },
      {
        "code": "quote_requests_new",
        "level": "warning",
        "title": "Cevaplanmamış teklif talebi",
        "detail": "3 talep 'yeni' durumunda bekliyor.",
        "count": 3,
        "link": "/subscriptions/requests?status=yeni"
      },
      {
        "code": "printer_fault",
        "level": "warning",
        "title": "Yazıcı arızası",
        "detail": "Mutfak Kasa 1 yazıcıya ulaşamıyor, kuyrukta 4 iş var.",
        "count": 1,
        "link": "/monitor/devices"
      }
    ]
  },
  "server_time": "2026-08-16T09:00:00Z"
}
```

---

## Blokların tanımı

Buradaki sayılar **tanımdır, tahmin değil.** Her birinin nereden geldiği aşağıda
yazılı; iki ekranın aynı soruya farklı cevap vermemesi buna bağlı.

### `sales`

`LocationGate`'ten okunur. `cutoff_at`, **bir sonraki** kesim anının UTC
karşılığıdır: bugünün kesimi geçtiyse yarının kesimi.

`seconds_to_next_cutoff` sunucuda hesaplanır. Panelin geri sayımı bunu ve
`server_time`'ı temel alır; istemcinin kendi saatini kullanması, saati kaymış
bir makinede yanlış bir aciliyet yaratırdı.

Kesim saati birleştirmesi: `gün.cutoff_time ?? ayar.order_cutoff`
(`settings.md`). Yarına özel bir saat varsa `cutoff_at` onu kullanır.

### `orders`

- `by_status`: **terminal olmayan** siparişlerin dağılımı. `teslim_edildi` ve
  `iptal` anahtarları **bulunmaz** — aktif kümenin dışındalar ve her seferinde
  `0` dönerlerdi. Kalan beş kod sipariş yokken bile `0` ile durur; istemcinin
  eksik anahtar için savunma yazmasına gerek kalmasın.
- `active` = `by_status` toplamı.
- `created_today` / `delivered_today` / `cancelled_today`: **işletme günü**
  (Europe/Istanbul) sınırında, `orders.created_at` üzerinden.
  UTC gece yarısı kullanılsaydı 00:00–03:00 arası siparişler "dün" sayılırdı
  ve catering'de gece siparişi olağan.
- `revenue_today_kurus`: bugün **servis edilen** (`bld_service_date = date`)
  ve iptal edilmemiş siparişlerin toplamı. Oluşturulma gününe göre saymak,
  ileri tarihli siparişleri bugünün cirosuna yazardı.
- `late`: **planlanan teslim saati geçmiş ve hâlâ teslim edilmemiş** aktif
  sipariş. "En kısa sürede" siparişler sayılmaz — planlanmış bir saatleri yok
  ve onları saymak için uydurulacak her eşik yanlış bir alarm üretirdi.
- `unreleased_subscription_orders`: üretilmiş ama henüz KDS'e düşmemiş abonelik
  siparişleri (`bld_kds_release_at > now`). Sıfırdan farklıysa panel saatini
  gösterir.

### `capacity`

`menu.md` → `GET /days/{date}/stock` ile **aynı hesap**, özet hâli.

`menu_published: false` ise diğer alanlar `null` döner (sıfır değil): menü
yayınlanmamışsa kapasite diye bir kavram yok ve sıfır "doldu" anlamına gelirdi.

`fill_rate` = `sold_total / capacity_total`, iki basamak. `capacity_total`
`null` ise `null`.

`blocked_items` en çok 10 kalem taşır.

### `subscriptions`

- `portions_today`: bugün üretilen abonelik siparişlerinin toplam adedi.
- `contracts_awaiting_signature`: durumu `pending` veya `sent` olan
  sözleşmeler.
- `unpaid_*`: `veykemtu_subscription_payments`, `status = pending`.
- `overdue_*`: yukarıdakilerin `due_date < bugün` olanları — `unpaid`'in alt
  kümesidir, ayrı bir küme değil. Panel ikisini üst üste değil, biri diğerinin
  içinde gösterir.

### `devices` · `monitor`

`monitor.md` → `GET /summary` ile **birebir aynı sayılar.** İki uç aynı
hesabı iki kez yazmaz; gösterge paneli o servisi çağırır. Farklı sayılar
göstermeleri, hangisine inanılacağını belirsiz kılardı.

---

## `pending_tasks` — bekleyen işler

Yöneticinin **bugün yapması gereken** işlerin listesi. Gösterge panelinin asıl
değeri buradadır: sayılar durumu anlatır, bu liste eylemi söyler.

Sıra: `critical` → `warning` → `info`, her grup içinde aciliyete göre.
En çok **12 madde** döner.

| `code` | Ne zaman çıkar | `level` |
|---|---|---|
| `ordering_paused` | Satış durdurulmuş | `critical` |
| `menu_missing` | Kesim saati yaklaşan bir güne yayınlanmış menü yok | `critical` |
| `no_device_online` | Hiçbir kasa çevrimiçi değil | `critical` |
| `critical_event_open` | Açık `critical` izleme olayı var | `critical` |
| `menu_draft` | Yayınlanmamış taslak menü, servis günü yaklaşıyor | `warning` |
| `capacity_full` | Bugünün gün tavanı dolmuş | `warning` |
| `printer_fault` | Kasa yazıcıya ulaşamıyor | `warning` |
| `print_queue_stale` | Kuyruktaki en eski iş 15 dakikayı aştı | `warning` |
| `late_orders` | Planlanan saati geçmiş sipariş var | `warning` |
| `quote_requests_new` | `yeni` durumda teklif talebi var | `warning` |
| `contracts_awaiting` | İmza bekleyen abonelik sözleşmesi var | `warning` |
| `payments_overdue` | Vadesi geçmiş dönem borcu var | `warning` |
| `subscriptions_pending` | Fiyatlandırılmayı bekleyen abonelik talebi | `warning` |
| `unreleased_orders` | KDS'e düşmemiş abonelik siparişi var | `info` |

`menu_missing` eşiği: **bugünden itibaren 3 gün** içindeki servis günlerinden
biri yayınlanmamışsa. Hafta sonu menü olmadığı için (iş kararı 4) cumartesi ve
pazar bu denetime **girmez** — girseydi her cuma sahte bir kritik uyarı
doğardı.

`link` alanı **Kontrol Merkezi'nin kendi yolu**, BLD API yolu değil. Sunucu bu
yolları biliyor çünkü sözleşme onları burada donduruyor; panelin kod
eşleştirmesi yazması, yeni bir madde eklendiğinde tıklanamayan bir satır
üretirdi.

`detail` metni **Türkçe ve doğrudan gösterilebilirdir.** Panel kendi cümlesini
kurmaz: aynı durumun iki farklı ekranda iki farklı cümleyle anlatılması,
sahada telefonda konuşan iki kişinin farklı şey söylemesi demektir.

`count` maddenin kaç kayda karşılık geldiğidir; tekil bir durumda `1`.

---

## Yük

Bu uç **tek bir istekte** yedi blok üretiyor ve 30 saniyede bir yoklanıyor.
Sunucu tarafında beklenen davranış:

- Sayaçlar `COUNT` sorgularıyla alınır, **koleksiyon çekilip PHP'de sayılmaz**.
  `OverviewController` bugün aktif siparişleri `get()` ile çekiyor ve bu, otuz
  siparişte sorun değil ama üç yüzde olur.
- `pending_tasks` blokları **var olan sayaçlardan türetilir**, her madde için
  ayrı sorgu açılmaz.
- Sonuç **60 saniye önbelleklenebilir**; yoklama 30 saniyede bir ve iki
  yoklamadan biri önbellekten dönebilir. Önbellek anahtarı `location_id` +
  `date` olmalı.

> KARAR: Önbellek **isteğe bağlıdır**, sözleşme onu şart koşmaz. Şart koşulsaydı
> "satışı durdurdum ama panel hâlâ açık gösteriyor" gibi bir gecikme sözleşmenin
> parçası olurdu. Uygulayan ajan ölçer ve gerekiyorsa açar; açarsa yanıt
> `meta.cached_at` alanı taşımalıdır.

---

## Denetim

Bu alanda yazma ucu **yoktur** ve okumalar denetlenmez. Gösterge paneli
yoklanan bir ekran; her yoklamayı denetlemek, izi tamamen bu trafiğe boğardı.
Kişisel veri taşımaz — bütün alanlar toplam sayı ya da durum etiketidir.
