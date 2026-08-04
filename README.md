# Benim Lezzet Dünyam — Sipariş Platformu

Catering şirketi için uçtan uca sipariş altyapısı. Müşteri web veya mobilden sipariş verir, sipariş mutfaktaki Ubuntu kasada çalışan ekrana anında düşer, fiş basılır, mutfak hazırlar, müşteri durumu canlı takip eder.

## Bileşenler

| Klasör | Ne | Teknoloji | Çalıştığı yer |
|---|---|---|---|
| `platform/` | Backend API + Admin panel | TastyIgniter (PHP/Laravel) + MySQL | Hetzner VPS |
| `website/` | Müşteri sipariş sitesi | Next.js 15 + TypeScript | Hetzner VPS |
| `musteriapp/` | Müşteri mobil uygulaması | Flutter (Android) | Google Play |
| `mutfakapp/` | Mutfak ekranı (KDS) | Flutter Linux desktop | MSI kasa · Ubuntu 24.04 |
| `packages/` | Ortak Dart paketleri | Dart | — |
| `infra/` | Docker, Caddy, yedekleme | — | Hetzner VPS |
| `docs/` | Tüm teknik dokümantasyon | — | — |

## Hızlı başlangıç

```bash
# 0. Mock API — backend hazır olmadan istemci geliştirmek için yeterli
cp infra/.env.example infra/.env
docker compose -f infra/docker-compose.dev.yml up mock-api
curl http://localhost:4010/api/locations

# 1. Tam dev yığını (mysql + platform + mock)
docker compose -f infra/docker-compose.dev.yml up -d

# 2. Platformu kur
docker compose -f infra/docker-compose.dev.yml exec app php artisan igniter:install

# 3. Ortak Dart paketleri
dart pub get && dart test packages/core

# 4. Website
cd website && cp .env.example .env.local && npm install && npm run dev

# 5. Mutfak uygulaması (Ubuntu)
cd mutfakapp && flutter run -d linux

# 6. Müşteri uygulaması
cd musteriapp && flutter run
```

Detaylı kurulum: `docs/08-kurulum-deploy.md`

## Ajanlar için

Çalışmaya başlamadan önce **`AGENTS.md`** dosyasını oku. Görevler `docs/09-gorev-plani.md` içindedir.

## Doküman haritası

- `docs/00-genel-bakis.md` — Kapsam, roller, sözlük
- `docs/01-mimari.md` — Mimari kararlar (ADR)
- `docs/02-veri-modeli.md` — Şema ve durum makinesi
- `docs/03-api-sozlesmesi.md` — API sözleşmesi (açıklamalı)
- `docs/openapi.yaml` — **normatif sözleşme**, istemciler bundan üretilir
- `docs/04-platform.md` — Backend/eklenti geliştirme
- `docs/05-mutfakapp.md` — KDS spesifikasyonu
- `docs/06-website.md` — Web spesifikasyonu
- `docs/07-musteriapp.md` — Mobil spesifikasyonu
- `docs/08-kurulum-deploy.md` — Kurulum ve dağıtım
- `docs/09-gorev-plani.md` — Görev planı
- `docs/10-test-kabul.md` — Kabul ölçütleri
