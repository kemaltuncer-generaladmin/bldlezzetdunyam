/// Çalışma zamanı yapılandırması.
///
/// Değerler `--dart-define` ile verilir; kasa kurulumunda `infra/kasa` betiği
/// bunları geçer. Varsayılanlar geliştirme içindir ve mock sunucuyu gösterir
/// (`infra/mock/README.md`).
library;

import 'package:bld_core/escpos.dart';

/// Uygulamanın ihtiyaç duyduğu tüm dış ayarlar.
class AppConfig {
  const AppConfig({
    required this.baseUrl,
    required this.printerDevicePath,
    required this.printerCodePage,
    required this.pollInterval,
    required this.provisionedToken,
  });

  /// Derleme zamanı değerlerinden okur.
  factory AppConfig.fromEnvironment() => AppConfig(
    baseUrl: const String.fromEnvironment(
      'BLD_API_BASE_URL',
      defaultValue: 'http://localhost:4010/api',
    ),
    printerDevicePath: const String.fromEnvironment(
      'BLD_PRINTER_DEVICE',
      defaultValue: defaultPrinterDevicePath,
    ),
    printerCodePage: const int.fromEnvironment(
      'BLD_PRINTER_CODEPAGE',
      defaultValue: EscPosCommands.turkishCodePage,
    ),
    pollInterval: const Duration(
      seconds: int.fromEnvironment('BLD_POLL_SECONDS', defaultValue: 5),
    ),
    provisionedToken: const String.fromEnvironment('BLD_KITCHEN_TOKEN'),
  );

  /// `X-App-Id` başlığı — sözleşmede sabit (`docs/03-api-sozlesmesi.md` §1.1).
  static const String appId = 'mutfakapp';

  /// `X-App-Version` başlığı. `pubspec.yaml`'daki sürümle aynı tutulmalıdır.
  static const String appVersion = '1.0.0';

  /// udev kuralının kurduğu sembolik bağ (`infra/kasa/99-thermal-printer.rules`).
  static const String defaultPrinterDevicePath = '/dev/thermal0';

  /// `/api` dahil taban adres.
  final String baseUrl;

  /// Termal yazıcının cihaz dosyası.
  final String printerDevicePath;

  /// `ESC t n` kod sayfası numarası — yazıcıdan yazıcıya değişir.
  ///
  /// Varsayılan 29, sahadaki `aaaait Printer` üzerinde doğrulandı. Yazıcı
  /// değişirse doğru değeri `infra/kasa/kodsayfasi-tara.sh` bulur ve buradan
  /// (ya da ayarlar ekranından) verilir; kod değişmez.
  final int printerCodePage;

  /// Sipariş çekme aralığı (`docs/05-mutfakapp.md` §4).
  final Duration pollInterval;

  /// Kurulumda önceden verilen mutfak token'ı.
  ///
  /// Boşsa cihaz eşleme ekranından (`K-07`) alınır. Kasa görüntü sunucusuz
  /// hazırlanırken (headless provizyon) elle giriş yapmadan token yerleştirmeyi
  /// mümkün kılar.
  final String provisionedToken;
}
