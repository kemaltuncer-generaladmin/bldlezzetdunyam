# website — Müşteri Sipariş Sitesi

**Bu klasör `W-01` görevinde doldurulur.** Şu an yalnızca `.env.example` var.

Spesifikasyon: [`docs/06-website.md`](../docs/06-website.md)

## Değişmez kısıtlar

- Next.js 15 App Router, TypeScript `strict: true`. **`any` yasak** — bilinmeyen
  tip için `unknown` + daraltma (`AGENTS.md` §4).
- `/`, `/menu`, `/urun/[slug]` **SSR/ISR** olmak zorunda — SEO gereksinimi.
  Server Component varsayılan; `"use client"` yalnızca gerçekten gerekliyse.
- API istemcisi `docs/openapi.yaml`'dan üretilir → `lib/api/`.
  **Elle yazılan istemci kodu kabul edilmez** (`docs/03` §9).
- Sepet `localStorage` değil **cookie + server action** ile tutulur (SSR uyumu).

## Sipariş alımı kapalıyken

`ordering_enabled=false` veya `is_open=false` ise menü **görünmeye devam eder**
(SEO), yalnızca sepete ekleme ve `/odeme` engellenir. Menüyü gizlemek arama
sonuçlarını düşürür.

## Ödeme

`/odeme` yalnızca vitrinin `payment_methods` listesindeki yöntemleri gösterir.
Faz 1'de bu liste `["cash","account"]` gelir. Arayüz `online` için de yazılır
ama şalter sunucudadır — sanal POS hazır olunca istemci sürümü değişmez.

## Backend'i bekleme

```bash
docker compose -f infra/docker-compose.dev.yml up mock-api
cp website/.env.example website/.env.local   # zaten mock'a bakıyor
```

Ayrıntı: [`infra/mock/README.md`](../infra/mock/README.md)
