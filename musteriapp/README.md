# musteriapp — Müşteri Mobil Uygulaması

Flutter → **Android**. Spesifikasyon: [`docs/07-musteriapp.md`](../docs/07-musteriapp.md),
normatif sözleşme: [`docs/openapi.yaml`](../docs/openapi.yaml).

Tamamlanan görevler: `M-01` … `M-05` + zorunlu güncelleme ekranı.
Yapılmayanlar ve varsayımlar: [`docs/BILINMEYENLER.md`](../docs/BILINMEYENLER.md).

## Değişmez kısıtlar

- Flutter → **Android** (Google Play). `ios/`, `web/`, `linux/`, `macos/`,
  `windows/` hedefi **yoktur** ve oluşturulmayacaktır.
- State: Riverpod. Model: freezed + json_serializable.
- Tüm ağ çağrıları `packages/api_client` üzerinden. Uygulama kodunda `dio` veya
  `http` importu **yoktur** (`AGENTS.md` §2.4).
- Para her yerde **kuruş** cinsinden `int`; biçimleme `packages/core`'daki
  `Money.format`.
- Arayüz metinleri `lib/src/l10n/app_tr.arb` içindedir; koda gömülü Türkçe dize
  yoktur (`AGENTS.md` §4).
- İş kuralı uygulamada kodlanmaz: hangi menü, sipariş açık mı
  (`is_open` + `ordering_enabled`), hangi ödeme yöntemleri geçerli
  (`payment_methods`) — üçünü de sunucu söyler (`docs/07` §3).

## Çalıştırma

Mock sunucu (backend'i beklemeye gerek yok):

```bash
docker compose -f infra/docker-compose.dev.yml up mock-api
```

Emülatörde `localhost` cihazın kendisidir; geliştirme makinesi `10.0.2.2`'dir ve
varsayılan taban adres budur:

```bash
flutter run                                   # http://10.0.2.2:4010/api
flutter run --dart-define=BLD_API_BASE_URL=https://staging-api.benimlezzetdunyam.com.tr/api
```

Yapılandırılabilir derleme değişkenleri (`lib/src/config/app_config.dart`):

| Değişken | Varsayılan | Ne işe yarar |
|---|---|---|
| `BLD_API_BASE_URL` | `http://10.0.2.2:4010/api` | `/api` dahil taban adres |
| `BLD_APP_VERSION` | `1.0.0` | `X-App-Version` başlığı ve zorunlu güncelleme karşılaştırması |

`BLD_APP_VERSION`, `pubspec.yaml`'daki `version:` ile aynı olmalıdır.

Hazır hesap: `ayse@ornek.com` / `parola123` — ayrıntı:
[`infra/mock/README.md`](../infra/mock/README.md)

Düz HTTP yalnızca **debug** derlemesinde açıktır
(`android/app/src/debug/AndroidManifest.xml`); release TLS ister.

## Klasör düzeni

```
lib/
  main.dart                     SharedPreferences + ProviderScope
  src/
    app.dart                    MaterialApp.router
    config/app_config.dart      dart-define ile gelen ayarlar
    core/                       hata metni, etiketler, doğrulayıcılar, zaman girişi
    data/                       TokenStore ve çevrimdışı önbellek (shared_preferences)
    l10n/                       app_tr.arb + üretilen sınıflar (commitli)
    providers/                  Riverpod sağlayıcıları
    router/app_router.dart      go_router + sürüm/oturum kapıları
    theme/bld_theme.dart        packages/design_system belirteçlerinden ThemeData
    features/                   ekranlar
    widgets/                    ortak görünümler
```

## Geliştirme komutları

```bash
flutter pub get
flutter gen-l10n                                  # app_tr.arb değişince
flutter pub run build_runner build                # cart_model değişince
flutter analyze                                   # sıfır uyarı olmalı
flutter test
```

Üretilen `*.freezed.dart`, `*.g.dart` ve `l10n/app_localizations*.dart`
dosyaları **commitlenir** (`AGENTS.md` §4) ve elle düzenlenmez.

## Ekranlar

| Ekran | Yol | Not |
|---|---|---|
| Açılış | `/` | Token + `GET /app-version` |
| Zorunlu güncelleme | `/update` | `version < min_supported` — geri tuşu kapalı |
| Giriş / Kayıt | `/login`, `/register` | KVKK onayı zorunlu |
| Menü | `/menu` | Kategori sekmeleri, arama |
| Ürün detayı | `/menu/item/:id` | Seçenekler, adet, not |
| Sepet | `/cart` | Yerelde korunur |
| Ödeme | `/checkout` | Teslimat tipi/adres, istenen saat, `payment_methods` |
| Siparişlerim | `/orders` | |
| Sipariş takibi | `/orders/:id` | Adım çubuğu, 5 sn yoklama |
| Hesabım | `/account` | |

## Kapsam dışı (bilinçli)

- **FCM/push** (`M-06`), **Play kaydı ve imzalama anahtarı** (`I-06`) — bu
  görevin kapsamı dışında bırakıldı.
- **Ödeme WebView'i** — Faz 1'de `online` hiçbir vitrinin `payment_methods`
  listesinde yok (`docs/openapi.yaml` `PaymentMethod`). Sunucu yine de
  `redirect_url` dönerse kullanıcı bilgilendirilir.
