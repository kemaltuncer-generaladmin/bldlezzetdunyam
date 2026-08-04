# platform — Backend API + Admin Panel

**Bu klasör `B-01` görevinde doldurulur.** Şu an yalnızca `.env.example` var.

Spesifikasyon: [`docs/04-platform.md`](../docs/04-platform.md)

## Kurulum (B-01)

```bash
docker compose -f infra/docker-compose.dev.yml up -d db app
docker compose -f infra/docker-compose.dev.yml exec app \
  composer create-project tastyigniter/tastyigniter . --stability=stable
cp platform/.env.example platform/.env
docker compose -f infra/docker-compose.dev.yml exec app php artisan key:generate
docker compose -f infra/docker-compose.dev.yml exec app php artisan igniter:install
```

## Kod yazmadan önce — `B-02` doğrulaması

Kurulum bittikten sonra, tek satır extension kodu yazmadan önce **kurulu
sürümün gerçek kodunu oku** ve şu üçünü `docs/BILINMEYENLER.md`'ye yaz:

1. Sipariş oluşturma servisinin gerçek imzası nedir?
2. Hangi API uçları hazır geliyor, hangileri yok?
3. Extension'dan route / migration / panel ekranı nasıl ekleniyor?

Eğitim verisinden hatırlanan TastyIgniter bilgisine **güvenilmez**. Sürümler
arasında bu üçü de değişir; yanlış varsayımla yazılan extension baştan yazılır.

## Mutlak yasak

`platform/vendor/` altına **dokunulmaz** (ADR-02). Çekirdek davranışı
değiştirmek gerekirse Laravel event listener veya TastyIgniter hook kullanılır.
CI'da `vendor/` diff kontrolü var; tek satır değişiklik build'i kırar.

Tüm özel kod: `platform/extensions/veykemtu/<modul>/`

## Yazılacak eklentiler

| Eklenti | Sorumluluk |
|---|---|
| `bridgeapi` | Tüm API uçları, Sanctum kapsamları, durum geçişleri, fiş verisi |
| `push` | FCM bildirimleri |
| `sms` | Netgsm (kapsam kesilirse ilk feda edilecek) |
| `appversion` | Sürüm/self-update ucu |
| `payment` | Sanal POS — Faz 1'de arayüz hazır, şalter kapalı |

`veykemtu/channels` **iptal edilmiştir** — kanal kavramı yok
(`docs/00-genel-bakis.md` §4).

## Sözleşme uyumu

`php artisan veykemtu:openapi` çıktısı `docs/openapi.yaml` ile **anlamsal
olarak aynı** olmak zorundadır. CI bunu kontrol eder; sunucu sözleşmeden
sapamaz (`E-01`).
