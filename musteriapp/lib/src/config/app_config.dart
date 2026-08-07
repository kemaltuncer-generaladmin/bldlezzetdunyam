/// Derleme zamanı yapılandırma.
///
/// Değerler `--dart-define` ile geçilir; kaynağa gömülü sabit yalnızca
/// geliştirme varsayılanıdır.
library;

import 'package:flutter/foundation.dart';

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

  /// `--dart-define=BLD_API_BASE_URL=...` ile geçilen adres. Boşsa
  /// [apiBaseUrl] platforma göre bir geliştirme varsayılanı seçer.
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'BLD_API_BASE_URL',
  );

  /// `/api` dahil taban adres.
  ///
  /// ## Neden mock değil?
  ///
  /// Varsayılan eskiden prism mock'unu (`:4010`) gösteriyordu. Mock sözleşmeyi
  /// doğrulamak için iyi ama uydurma veri döndürüyor: menü, fiyat ve sipariş
  /// numaraları gerçek değil, sipariş KDS'ye hiç düşmüyor. Uygulamayı elle
  /// denerken bu fark edilmiyor — ekran dolu görünüyor. Varsayılan artık
  /// **ayaktaki platform** (`:8080`, `infra/docker-compose.dev.yml`).
  ///
  /// ## Neden platforma göre değişiyor?
  ///
  /// Android emülatöründe `localhost` cihazın kendisidir; geliştirme makinesi
  /// `10.0.2.2` üzerinden görünür. Web ve masaüstünde ise `localhost` doğru
  /// adres. Tek bir sabit yazmak, iki hedeften birini her seferinde bozardı.
  ///
  /// Gerçek cihaz ve staging için `--dart-define` ile geçilir.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';
    return 'http://$host:8080/api';
  }

  /// Sipariş takip ekranının yenileme aralığı (`docs/07-musteriapp.md` §2).
  ///
  /// WebSocket Faz 1.5'e ertelendi (`infra/mock/README.md`), bu yüzden takip
  /// yoklama ile yapılır. Mutfak durumu değiştirdiği anda müşterinin görmesi
  /// bu aralığa bağlı — beş saniye, KDS ile müşteri arasındaki gecikmenin üst
  /// sınırı.
  static const Duration orderPollInterval = Duration(seconds: 5);

  /// Günlük menü hatırlatmasının varsayılan saati (yerel saat).
  ///
  /// 10:30: öğle siparişi için karar verilen saat. Daha erken atılsa gün
  /// başlamamış, daha geç atılsa mutfak siparişi yetiştiremiyor.
  static const int dailyReminderHour = 10;
  static const int dailyReminderMinute = 30;
}
