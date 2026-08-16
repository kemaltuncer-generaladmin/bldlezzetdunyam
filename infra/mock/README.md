# Mock API (`X-04`)

`docs/openapi.yaml` sözleşmesinin **durum tutan** uygulaması. İstemci hatları
(`K`, `W`, `M`) backend'i beklemeden buna bağlanır — 1 haftalık takvimi mümkün
kılan şey budur.

## Çalıştırma

```bash
# Docker ile (tercih edilen)
docker compose -f infra/docker-compose.dev.yml up mock-api

# Doğrudan Node ile
cd infra/mock && npm install && npm start
```

Adres: `http://localhost:4010/api`

## Zorunlu başlıklar

Gerçek sunucu gibi mock da bunları arar (`docs/03` §1.1). Eksikse `422` döner —
istemciler bu hatayı ilk gün görsün diye bilinçli:

```
X-App-Id: website | musteriapp | mutfakapp
X-App-Version: 1.0.0
```

## Hazır hesaplar

| E-posta | Şifre | Not |
|---|---|---|
| `ayse@ornek.com` | `parola123` | 3 siparişi var, aboneliği yok |
| `mehmet@ornek.com` | `parola123` | 2 siparişi + sözleşme bekleyen 1 aboneliği var |

**Mutfak eşleme kodu:** `BLD1-MOCK`
**Sözleşme anahtarı:** `SOZLESME-MOCK` (→ `GET /api/contracts/SOZLESME-MOCK`)

## Satış modeli: günün menüsü

Satılan şey katalog değil **o günün menüsü**. `/locations/1/menu` katalogu
döndürmeye devam eder (ürün kayıtları, SEO) ama sipariş yalnız günün
menüsünden verilebilir; `POST /orders` bunu yeniden denetler.

| Kural | Mock'taki karşılığı |
|---|---|
| Her servis günü kendi sabah kesiminde kapanır | `order_cutoff: "08:00"`, yanıtta mutlak `cutoff_at` |
| En fazla 7 gün ileri sipariş | `max_lookahead_days: 7`, ötesi `too_far` |
| Hafta sonu menü yok, satış kanalı açık | `service_weekdays: [1,2,3,4,5]`, takvimde `weekend: true` |
| Gün toplamı **ve** ürün tavanı | `remaining_portions` her iki tavanın darı |
| Cari hesap yok | `payment_methods: ["online","cash"]` |

`unavailable_reason` değerleri:
`past`, `too_far`, `closed_day`, `no_service_day`, `not_published`,
`cutoff_passed`, `sold_out` — bu **sırayla** değerlendirilir (en dıştaki, en
kalıcı sebep önce söylenir).

### Örnek veri: hangi gün neyi test eder

Menüler **bugünden itibaren 14 gün**e yayınlanır ve yalnız iş günlerine
düşer. Sıra, bugünden sonraki iş günlerine göre kurulur:

| İş günü sırası | Ne | Neyi test eder |
|---|---|---|
| 0 | Ev Yemeği Menüsü, stok sınırsız | Bugün iş günüyse **kesim saati geçmiş** gün (08:00 sonrası) |
| 1 | Kuru Fasulye Günü, stok sınırsız | Mutlu yol: paket + kalem siparişi |
| 2 | Fırın Günü, gün tavanı 40 / 28 satıldı | **Kalan porsiyon** gösterimi (12) |
| 3 | Karnıyarık Günü, 30 / 30 | **Tükenmiş gün** (`sold_out`) |
| 4 | Serbest Gün, paket fiyatı yok | Paketsiz gün + **ürün bazlı tavan** (ikinci kalem) |
| +10 gün sonrasındaki ilk iş günü | Kapalı gün | `closed_day` ve `note` |

Her menüde `sellable_alone: false` bir kalem (ayran) var: paketin
bileşenlerinde görünür, `items[]` listesinde **görünmez** ve tek başına
sipariş edilirse `ITEM_UNAVAILABLE` döner.

> **Kesim saati dalı haftanın gününe bağlı.** Bugün cumartesiyse hiçbir gün
> "kesim geçti" durumunda değildir. Belirlenimci bir zemin isteyen test
> `/__mock/location` + `/__mock/daily-menu` kancalarını kullanmalı
> (`smoke.sh` sonundaki bölüm örnek).

## Örnek veri (katalog ve siparişler)

3 kategori, 12 ürün (biri bilinçli olarak `is_available: false` — `Izgara
Köfte`), 5 sipariş. Paket ürünü (`menu_id: 100`) kategorilerin **dışındadır**:
fiyatı ürüne değil güne aittir.

| # | Durum | Teslimat | Neyi test eder |
|---|---|---|---|
| 5008 | `teslim_edildi` | adrese | Tamamlanmış sipariş, KDS'te görünmez |
| 5009 | `hazir` | gel-al | `GELAL` rozeti, "TESLİM EDİLDİ" butonu |
| 5010 | `hazirlaniyor` | adrese | Üretim listesi, sipariş notu, **revizyon** (`revision_no: 2`) |
| 5011 | `onaylandi` | gel-al | Üretim listesi |
| 5012 | `yeni` | adrese | Mutfak fişi tetiği, kart yanıp sönmesi |

## Gerçekten uygulanan davranışlar

- **Günün menüsü:** yayın durumu, kesim saati, ileri görüş penceresi, kapalı
  gün, hafta sonu ve stok kararları tek yerde (`MockState.verdict`)
- **Stok:** sipariş porsiyonu gün toplamından ve kalem tavanından düşer;
  paket satışı zorunlu bileşenlerin tavanını da tüketir
- **Artımlı polling:** `after`, `since`, `max_id`, `server_time`
- **Durum geçiş matrisi:** geçersiz geçiş → `422 INVALID_TRANSITION`.
  `pickup` siparişte `hazir → yolda` reddedilir.
- **Kapsam ayrımı:** müşteri token'ı `/api/kitchen/*`'a giremez, mutfak token'ı
  `/api/orders`'a giremez → `403 FORBIDDEN` (`docs/10` S5)
- **Varlık sızdırmama:** başkasının siparişi `404`, `403` değil
- **Fiş ack idempotentliği:** aynı `(order_id, type, revision)` üçlüsü ikinci
  kez kayıt açmaz
- **Tutar hesabı sunucuda:** istemcinin gönderdiği tutar yok sayılır; fiyat
  siparişe yazılır (menü yarın değişince dünkü sipariş değişmez)
- **Mutfak yanıtlarında fiyat/adres/telefon yok** — tek istisna müşteri fişi
- **Abonelik ödemesi:** `online` → 3D Secure (`next_action: "otp"`),
  `cash` → anında kapanır
- **Sözleşme:** girişsiz okunur, SMS koduyla imzalanır, imza aboneliği
  `pending → active` yapar

## Uygulanmayanlar

- Oran sınırları (`docs/03` §8) — yalnızca gerçek sunucuda
- WebSocket (`docs/03` §7) — Faz 1.5
- Gerçek ödeme sağlayıcısı — `online` seçilirse sahte bir `redirect_url` döner
- Gece üretilen abonelik siparişleri (zamanlanmış iş) — mock zamanlayıcı
  koşturmuyor; abonelik siparişi `/__mock/orders` ile elle düşürülür
- `DailyMenu.image_urls` boş döner: erişilemeyen bir adres kırık resimden
  başka bir şey üretmezdi. Galeri yolunu denemek isteyen test adresleri
  `/__mock/daily-menu` ile kendisi yazar.

## Kaldırılanlar

- **Cari hesap:** `/api/account/summary`, `/statement`, `/payments` ve
  `__mock/ledger`, `__mock/cari-odeme` kancaları. `account` ödeme yöntemi de
  listeden çıktı.
- **Push (FCM):** `POST /api/me/push-token`. Bildirim kanalı artık uygulama
  içi duyuru (`GET /api/announcements`) ve SMS.

## Test kancaları (`/__mock/*`)

**Bu uçlar gerçek sunucuda yoktur.** `docs/10-test-kabul.md` senaryolarını elle
koşabilmek için var.

```bash
# Örnek veriye dön (token havuzunu da siler — sonra yeniden giriş yapın)
curl -X POST localhost:4010/__mock/reset

# Son gönderilen SMS kodu (giriş VE sözleşme onayı aynı havuzda)
curl localhost:4010/__mock/otp/5551234567

# Abonelik ödemesinin 3D Secure kodu
curl localhost:4010/__mock/payment-otp/1

# Bir güne menü aç / stoğunu değiştir — belirlenimci zemin kurmanın tek yolu
curl -X POST localhost:4010/__mock/daily-menu/2026-08-17 \
  -H 'Content-Type: application/json' \
  -d '{"published":true,"day_capacity":5,"day_sold":5}'

# Kapalı gün ekle/kaldır
curl -X POST localhost:4010/__mock/closed-days/2026-08-20 \
  -H 'Content-Type: application/json' -d '{"note":"Bayram"}'

# Vitrin ayarları: şalter, kesim saati, servis günleri, ileri görüş
curl -X POST localhost:4010/__mock/location \
  -H 'Content-Type: application/json' \
  -d '{"ordering_enabled":false}'
curl -X POST localhost:4010/__mock/location \
  -H 'Content-Type: application/json' \
  -d '{"order_cutoff":null,"service_weekdays":[1,2,3,4,5,6,7]}'

# Yeni sipariş düşür — KDS 3 saniye kuralı ve sesli uyarı testi (S1 adım 5)
curl -X POST localhost:4010/__mock/orders \
  -H 'Content-Type: application/json' \
  -d '{"delivery_type":"pickup","customer_note":"Acele"}'

# Abonelik ve sözleşme kur
curl -X POST localhost:4010/__mock/subscriptions \
  -H 'Content-Type: application/json' -d '{"customer_id":12,"status":"active"}'
curl -X POST localhost:4010/__mock/contracts \
  -H 'Content-Type: application/json' -d '{"subscription_id":2}'

# Toplanan istemci hata raporlarını oku
curl localhost:4010/__mock/client-errors

# Cihazı iptal et — S5 adım 5, KDS eşleme ekranına dönmeli
curl -X POST localhost:4010/__mock/revoke-device/1
```

## Duman testi

```bash
./infra/mock/smoke.sh                      # localhost:4010
./infra/mock/smoke.sh https://staging-api  # gerçek sunucuya karşı
```

`__mock/*` kancaları olmayan bir hedefte o bölümler atlanır.

## Sınır

Durum **bellektedir**. Konteyner yeniden başlarsa örnek veriye döner. Bu
bilinçli: her test koşusu temiz bir zeminden başlasın.

Günlük menü tohumu **açılış anındaki güne** göre kurulur. Uzun süre ayakta
kalan bir konteyner ertesi gün "bugün"ü kaçırır; gece yarısını geçen bir test
koşusundan önce `/__mock/reset` çağırın.
