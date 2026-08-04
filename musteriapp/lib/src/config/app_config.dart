/// Derleme zamanı yapılandırma.
///
/// Değerler `--dart-define` ile geçilir; kaynağa gömülü sabit yalnızca
/// geliştirme varsayılanıdır.
library;

/// Uygulamanın sunucuya kendini tanıttığı kimlik ve bağlanacağı adres.
abstract final class AppConfig {
  /// `docs/openapi.yaml` `X-App-Id` enum'undaki değer. Sabittir.
  static const String appId = 'musteriapp';

  /// `X-App-Version` başlığı ve zorunlu güncelleme karşılaştırması bunu kullanır.
  ///
  /// `pubspec.yaml`'daki `version:` ile **aynı** olmalıdır. Sürüm yükseltirken
  /// iki yer birlikte değişir; CI'da karşılaştırılabilir olsun diye burada
  /// tek satırdır.
  static const String appVersion = String.fromEnvironment(
    'BLD_APP_VERSION',
    defaultValue: '1.0.0',
  );

  /// `/api` dahil taban adres.
  ///
  /// Varsayılan **Android emülatörü** içindir: emülatörde `localhost` cihazın
  /// kendisidir, geliştirme makinesi `10.0.2.2`'dir. Gerçek cihazda veya
  /// staging'de `--dart-define=BLD_API_BASE_URL=...` ile geçilir.
  static const String apiBaseUrl = String.fromEnvironment(
    'BLD_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:4010/api',
  );

  /// Sipariş takip ekranının yenileme aralığı (`docs/07-musteriapp.md` §2).
  ///
  /// WebSocket Faz 1.5'e ertelendi (`infra/mock/README.md`), bu yüzden takip
  /// yoklama ile yapılır.
  static const Duration orderPollInterval = Duration(seconds: 5);
}
