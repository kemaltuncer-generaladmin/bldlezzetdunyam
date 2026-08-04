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
| `ayse@ornek.com` | `parola123` | 3 siparişi var |
| `mehmet@ornek.com` | `parola123` | 2 siparişi var |

**Mutfak eşleme kodu:** `BLD1-MOCK`

## Örnek veri

3 kategori, 12 ürün (biri bilinçli olarak `is_available: false` — `Izgara
Köfte`), 5 sipariş. Siparişler durum makinesinin farklı noktalarına ve iki
teslimat tipine yayılmıştır:

| # | Durum | Teslimat | Neyi test eder |
|---|---|---|---|
| 5008 | `teslim_edildi` | adrese | Tamamlanmış sipariş, KDS'te görünmez |
| 5009 | `hazir` | gel-al | `GELAL` rozeti, "TESLİM EDİLDİ" butonu |
| 5010 | `hazirlaniyor` | adrese | Üretim listesi, sipariş notu vurgusu |
| 5011 | `onaylandi` | gel-al | Üretim listesi |
| 5012 | `yeni` | adrese | Mutfak fişi tetiği, kart yanıp sönmesi |

## Gerçekten uygulanan davranışlar

- **Artımlı polling:** `after`, `since`, `max_id`, `server_time`
- **Durum geçiş matrisi:** geçersiz geçiş → `422 INVALID_TRANSITION`.
  `pickup` siparişte `hazir → yolda` reddedilir.
- **Kapsam ayrımı:** müşteri token'ı `/api/kitchen/*`'a giremez, mutfak token'ı
  `/api/orders`'a giremez → `403 FORBIDDEN` (`docs/10` S5)
- **Varlık sızdırmama:** başkasının siparişi `404`, `403` değil
- **Fiş ack idempotentliği:** aynı `(order_id, type)` ikinci kez kayıt açmaz
- **Tutar hesabı sunucuda:** istemcinin gönderdiği tutar yok sayılır
- **Mutfak yanıtlarında fiyat/adres/telefon yok** — tek istisna müşteri fişi

## Uygulanmayanlar

- Oran sınırları (`docs/03` §8) — yalnızca gerçek sunucuda
- WebSocket (`docs/03` §7) — Faz 1.5
- Gerçek ödeme sağlayıcısı — `online` seçilirse sahte bir `redirect_url` döner

## Test kancaları (`/__mock/*`)

**Bu uçlar gerçek sunucuda yoktur.** `docs/10-test-kabul.md` senaryolarını elle
koşabilmek için var.

```bash
H='-H "X-App-Id: website" -H "X-App-Version: 1.0.0"'

# Örnek veriye dön
curl -X POST localhost:4010/__mock/reset

# Yeni sipariş düşür — KDS 3 saniye kuralı ve sesli uyarı testi (S1 adım 5)
curl -X POST localhost:4010/__mock/orders \
  -H 'Content-Type: application/json' \
  -d '{"delivery_type":"pickup","customer_note":"Acele"}'

# Sipariş alımını kapat — S3
curl -X POST localhost:4010/__mock/location \
  -H 'Content-Type: application/json' -d '{"ordering_enabled":false}'

# Online ödemeyi aç (sanal POS geldiğinde nasıl olacağını denemek için)
curl -X POST localhost:4010/__mock/location \
  -H 'Content-Type: application/json' \
  -d '{"payment_methods":["cash","account","online"]}'

# Cihazı iptal et — S5 adım 5, KDS eşleme ekranına dönmeli
curl -X POST localhost:4010/__mock/revoke-device/1
```

## Sınır

Durum **bellektedir**. Konteyner yeniden başlarsa örnek veriye döner. Bu
bilinçli: her test koşusu temiz bir zeminden başlasın.
