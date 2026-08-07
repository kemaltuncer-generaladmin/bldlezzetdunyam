# musteriapp — Müşteri Mobil Uygulaması

Flutter → **Android + iOS**. Spesifikasyon: [`docs/07-musteriapp.md`](../docs/07-musteriapp.md),
normatif sözleşme: [`docs/openapi.yaml`](../docs/openapi.yaml).

Tamamlanan görevler: `M-01` … `M-06` + zorunlu güncelleme ekranı, adres defteri
ve bildirimler. Yapılmayanlar ve varsayımlar:
[`docs/BILINMEYENLER.md`](../docs/BILINMEYENLER.md).

## Değişmez kısıtlar

- Flutter → **Android + iOS** (Google Play, App Store). `linux/`, `macos/`,
  `windows/` hedefi **yoktur**.
- `web/` bir **yayın hedefi değildir**; yalnızca uygulamayı emülatörsüz
  görebilmek için üretilir ve `.gitignore`'dadır (aşağıda "Tarayıcıda
  çalıştırma").
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

Önce backend'i ayağa kaldırın:

```bash
docker compose -f infra/docker-compose.dev.yml up -d
```

Sonra uygulamayı çalıştırın. Taban adres **platforma göre** seçilir: Android
emülatöründe `localhost` cihazın kendisidir, geliştirme makinesi `10.0.2.2`'dir.

```bash
flutter run                     # Android: 10.0.2.2:8080, diğerleri: localhost:8080
flutter run --dart-define=BLD_API_BASE_URL=https://staging-api.benimlezzetdunyam.com.tr/api
```

**Mock'a (prism, `:4010`) bağlanmayın.** Sözleşme testleri için var; uydurma
menü ve fiyat döndürür, sipariş KDS'ye hiç düşmez. Ekran dolu göründüğü için
fark edilmesi zordur.

Yapılandırılabilir derleme değişkenleri (`lib/src/config/app_config.dart`):

| Değişken | Varsayılan | Ne işe yarar |
|---|---|---|
| `BLD_API_BASE_URL` | Android `http://10.0.2.2:8080/api`, diğerleri `http://localhost:8080/api` | `/api` dahil taban adres |
| `BLD_APP_VERSION` | `1.0.0` | `X-App-Version` başlığı ve zorunlu güncelleme karşılaştırması |

`BLD_APP_VERSION`, `pubspec.yaml`'daki `version:` ile aynı olmalıdır.

### Tarayıcıda çalıştırma (emülatörsüz önizleme)

`web/` klasörü repoda **yoktur** — bir kez üretilir:

```bash
flutter create --platforms=web .
```

Sonra:

```bash
flutter build web --release --dart-define=BLD_API_BASE_URL=http://localhost:8080/api
python3 tool/serve_web.py            # http://127.0.0.1:8090
```

`flutter run -d chrome` de çalışır ama hata ayıklama derlemesi tarayıcıya 850+
modül yükler ve ilk açılış yarım dakikayı bulur; önizleme için release derleme
belirgin biçimde hızlıdır. `tool/serve_web.py` düz dosya sunucusu değildir:
`go_router` yol tabanlı adres üretiyor ve karşılığı olmayan her yol
`index.html`'e düşmeli.

Tarayıcıda ürün görselleri `Access-Control-Allow-Origin` ister; `infra/Caddyfile.dev`
bunu `/storage/*` için veriyor. Android/iOS'ta böyle bir gereksinim yok.

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
| Hesabım | `/account` | Profil, adres defteri bağlantısı, bildirim ayarı, çıkış |
| Adreslerim | `/account/addresses` | `GET/POST/PATCH/DELETE /addresses` |

## Bildirimler

İki ayrı iş, ikisi de `lib/src/data/notifications.dart` içinde:

| Ne | Nasıl | Uygulama kapalıyken |
|---|---|---|
| Günlük menü hatırlatması | Yerel zamanlama, her gün seçilen saatte (varsayılan 10:30) | **Çalışır** |
| Sipariş durumu | Takip yoklaması durumu değiştiğinde bildirir | Çalışmaz — push gerekir |

Ayar Hesabım ekranında. İzin reddedilirse anahtar açılmaz: "açık" görünen ama
hiç bildirim atmayan bir ayar kullanıcının güvenini bozar.

Zaman dilimi veritabanı **yüklenmez** — `packages/core`'daki kararla aynı
gerekçe: Türkiye sabit UTC+3, ~1 MB IANA verisi taşımaya değmez. `timezone`
paketinin API'si kullanılır, tek bir sabit ofsetli `Location` elle kurulur.

## Kapsam dışı (bilinçli)

- **FCM push** — token kaydı hazır (`PushRegistration`, `POST /me/push-token`)
  ama token'ı Firebase üretir ve Firebase projesi, `google-services.json`,
  APNs anahtarı repoda yok; uydurulamaz (`AGENTS.md` §2.2). Bunlar girildiğinde
  yalnızca token'ı `register()`'a vermek yeterli — sözleşme değişmez.
- **Play kaydı ve imzalama anahtarı** (`I-06`).
- **Ödeme WebView'i** — sanal POS sayfası uygulama içi WebView yerine sistem
  tarayıcısında açılıyor. Gerekçe: 3-D Secure akışında bankalar uygulama içi
  WebView'ları giderek daha çok reddediyor, kullanıcı adres çubuğundaki alan
  adını göremiyor ve `webview_flutter` web hedefini desteklemiyor.
