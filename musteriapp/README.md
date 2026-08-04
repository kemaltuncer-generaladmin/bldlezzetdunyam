# musteriapp — Müşteri Mobil Uygulaması

**Bu klasör `M-01` görevinde doldurulur.** Şu an bilinçli olarak boştur.

Spesifikasyon: [`docs/07-musteriapp.md`](../docs/07-musteriapp.md)

## Değişmez kısıtlar

- Flutter → **Android** (Google Play). iOS Faz 3.
- State: Riverpod. Model: freezed + json_serializable.
- Tüm ağ çağrıları `packages/api_client` üzerinden — uygulama içinde doğrudan
  `http`/`dio` çağrısı **bulunmayacak** (`AGENTS.md` §2.4).
- İş kuralı uygulamada kodlanmaz: hangi menü, sipariş açık mı, hangi ödeme
  yöntemleri geçerli — üçünü de sunucu söyler
  (`docs/07-musteriapp.md` §3).

## Gün 1'de mutlaka

Google Play Console'da uygulama kaydını aç ve imzalı APK üretimini çalışır hale
getir. Play inceleme süreci günler alıyor, arka planda işlesin (`I-06`).
İmzalama anahtarı CI gizli değişkenlerinde tutulur; `.gitignore` `*.jks` ve
`key.properties` dosyalarını zaten engelliyor.

## Backend'i bekleme

```bash
docker compose -f infra/docker-compose.dev.yml up mock-api
```

Hazır hesap: `ayse@ornek.com` / `parola123` — ayrıntı:
[`infra/mock/README.md`](../infra/mock/README.md)
