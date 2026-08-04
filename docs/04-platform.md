# 04 — Platform (Backend + Admin)

TastyIgniter kurulumu, eklenti geliştirme ve backend görevlerinin tamamı.

## 1. Kurulum

```bash
cd platform
composer create-project tastyigniter/tastyigniter . --stability=stable
cp .env.example .env
php artisan key:generate
php artisan igniter:install   # etkileşimli; DB bilgileri .env'den
```

`.env` kritik alanlar:
```
APP_URL=https://api.benimlezzetdunyam.com.tr
DB_CONNECTION=mysql
DB_HOST=db
DB_DATABASE=catering
SANCTUM_STATEFUL_DOMAINS=<website domain>
FRONTEND_URL=https://<website domain>
```

## 2. Kurulum sonrası zorunlu yapılandırma

1. **Tek vitrin oluştur:** `Benim Lezzet Dünyam` (id 1, slug `catering`). Ayarlar → Locations.
2. **Tek müşteri grubu:** `Catering Müşterisi`.
3. **Durumları bizim koda göre yapılandır.** Varsayılan TastyIgniter durumlarını sil/düzenle; `docs/02-veri-modeli.md` §3'teki 7 durum kodu birebir olacak: `yeni`, `onaylandi`, `hazirlaniyor`, `hazir`, `yolda`, `teslim_edildi`, `iptal`. Bu bir seeder ile yapılır (`VeykemtuStatusSeeder`), elle değil.
4. **Admin rolleri:** `Yönetici` (tam yetki), `Operatör` (sipariş görüntüleme + durum ilerletme; menü/fiyat/ayar yetkisi yok).

## 3. Eklenti yapısı

Tüm özel kod: `platform/extensions/veykemtu/<modul>/`

Standart iskelet (**v4.3.4'te gerçek yapıdan doğrulandı** — `extension.json` diye
bir dosya yoktur, meta veri `composer.json` içindedir):
```
veykemtu/bridgeapi/
├── composer.json          # "type": "tastyigniter-package"
│                          # extra.tastyigniter-extension.code = "veykemtu.bridgeapi"
│                          # autoload.psr-4: { "Veykemtu\\BridgeApi\\": "src/" }
├── src/
│   ├── Extension.php      # Igniter\System\Classes\BaseExtension'dan türer
│   ├── Console/
│   ├── Http/Controllers/
│   ├── Http/Requests/
│   ├── Http/Resources/    # API yanıt biçimleri
│   ├── Models/
│   ├── Services/
│   └── Middleware/
├── database/migrations/   # `php artisan igniter:up` ile koşar
├── routes/api.php
└── tests/
```

`Extension.php` içinde route dosyası, komutlar ve olay dinleyicileri kaydedilir;
migration'lar `database/migrations/` altında otomatik bulunur. Yeni eklenti
eklendikten sonra `php artisan igniter:package-discover` çalıştırılır.

**`vendor/` altına asla dokunulmaz** — çekirdek davranışı değiştirmek gerekirse
Laravel event listener veya TastyIgniter hook kullanılır. Mevcut bir çekirdek
tablosuna **eklemeli** migration yazmak ihlal değildir (`bridgeapi`'nin
`statuses.status_code` kolonu böyledir).

### `igniter.api` devre dışıdır

TastyIgniter, `tastyigniter/ti-ext-api` eklentisiyle gelir ve `/api` önekinde
82 rota kaydeder — `GET /api/locations`, `/api/orders`, `/api/menus` dahil.
Bunlar bizim sözleşmemizle **aynı yolları farklı gövdelerle** işgal ediyordu.

Karar (04.08): eklenti kapatıldı, sözleşme `bridgeapi`'de sıfırdan uygulanıyor.
Paket çekirdeğin zorunlu bağımlılığı olduğu için composer'dan kaldırılamaz;
kapatma `platform/bootstrap/cache/disabled-addons.json` dosyasındadır ve bu
dosya **commitlenir** (`.gitignore`'da istisnası vardır). `laravel/sanctum`
ayrı bir pakettir, durmaya devam eder.

Yeniden açmak `/api` rotalarımızı sessizce gölgeler — açmayın.

## 4. Yazılacak eklentiler

> **İptal:** `veykemtu/channels` eklentisi (kanal kavramı, teslim kodu üreteci, kurum içi sipariş ekranı) **yazılmayacaktır** — bkz. `docs/00-genel-bakis.md` §4.

### 4.1 `veykemtu/bridgeapi`

**Sorumluluk:** Tüm API uçları (`docs/03-api-sozlesmesi.md`).

- Migration: `veykemtu_kitchen_devices`, `veykemtu_print_jobs`.
- **Kimlik:** Laravel Sanctum. Müşteri token'ı `customer` kapsamı, cihaz token'ı `kitchen` kapsamı. Kapsam kontrolü middleware'de.
- **Cihaz eşleme:** `KitchenDeviceService` — admin panelde "Cihaz Ekle" ile 12 karakterlik kod üretilir (10 dk geçerli), `POST /api/kitchen/pair` ile token'a çevrilir. Token hash'lenerek saklanır.
- **Durum geçiş servisi** `OrderStatusTransition`: `docs/02-veri-modeli.md` §3'teki tabloyu uygular. Geçersiz geçişte `InvalidTransitionException` → `422`.
- **Resource sınıfları:** API yanıt biçimleri sözleşmeye birebir uyar. `KitchenOrderResource` fiyat ve iletişim bilgisi **içermez**.
- **Fiş verisi:** `ReceiptBuilder` — iki tip (`mutfak`, `musteri`) için yapılandırılmış veri döner.
- **Sipariş alım şalteri:** `ordering_enabled` vitrin ayarı + admin panelde bir anahtar. Kapalıyken `POST /api/orders` → `422 LOCATION_CLOSED`.
- **Üretim listesi:** `ProductionListService` — `docs/02-veri-modeli.md` §4'teki sorgu.
- **Hata biçimi:** Global exception handler tüm hataları sözleşmedeki tek biçime çevirir.
- **OpenAPI üretimi:** `php artisan veykemtu:openapi` → `platform/openapi.json`.
- **Oran sınırlama:** `docs/03-api-sozlesmesi.md` §8.

**Kabul:** Sözleşmedeki her uç çalışıyor, mutlu yol + bir hata yolu testi var, `openapi.json` üretiliyor.

### 4.2 `veykemtu/push`

- Migration: `veykemtu_device_tokens`.
- FCM entegrasyonu (HTTP v1 API, servis hesabı `.env`'den).
- Durum değişimi olayını dinler, ilgili müşteriye bildirim gönderir.
- Bildirim metinleri Türkçe, durum bazlı: `onaylandi` → "Siparişiniz onaylandı", `hazirlaniyor` → "Siparişiniz hazırlanıyor", `hazir` → "Siparişiniz hazır", `yolda` → "Siparişiniz yola çıktı", `teslim_edildi` → "Siparişiniz teslim edildi".
- Gönderim başarısızsa sessizce loglar, siparişi etkilemez.

### 4.3 `veykemtu/sms`

- Netgsm API entegrasyonu (`.env`: kullanıcı, şifre, başlık).
- Yalnızca iki tetik: sipariş onayı, sipariş yolda.
- Şablonlar ayarlardan düzenlenebilir.
- Rate limit ve hata durumunda kuyruk (Laravel queue) ile tekrar deneme.

### 4.4 `veykemtu/appversion`

- Migration: `veykemtu_app_releases`.
- `GET /api/app-version` ucu.
- Admin ekranı: sürüm kaydı ekleme/düzenleme.

### 4.5 `veykemtu/realtime` (Faz 1.5 — zaman kalırsa)

- Laravel Reverb kurulumu.
- Sipariş olaylarını `private-kitchen` ve `private-customer.{id}` kanallarına yayınlar.
- Kanal yetkilendirmesi cihaz/müşteri token'ıyla.

## 5. Ödeme entegrasyonu

Sanal POS entegrasyonu bir TastyIgniter **payment gateway eklentisi** olarak yazılır: `veykemtu/payment`. Sağlayıcı bilgisi `.env`'den gelir; **anahtarlar repoya girmez**.

Akış: sipariş oluşur (`payment.status = pending`) → istemci `redirect_url`'e gider → sağlayıcı callback'i `POST /payment/callback` ucuna düşer → imza doğrulanır → `payment.status = paid` → sipariş normal akışına devam eder.

Callback **idempotent** olmalı: aynı işlem iki kez gelirse sipariş iki kez ödenmiş sayılmaz.

## 6. Testler

```bash
cd platform && php artisan test
```
Her uç için `tests/Feature/` altında en az: 200 mutlu yol, 401/403 yetki, 422 doğrulama. `OrderStatusTransition` için tüm geçiş matrisini kapsayan unit test zorunlu.

## 7. Yerelleştirme

Tüm kullanıcıya görünen metinler `lang/tr/` altında. Kodda sabit Türkçe metin yasak.
