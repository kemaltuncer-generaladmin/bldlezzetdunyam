// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppL10nTr extends AppL10n {
  AppL10nTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Mutfak Ekranı';

  @override
  String get unlockPrompt => 'Şifreyi giriniz';

  @override
  String get unlockAction => 'Aç';

  @override
  String get unlockWrong => 'Şifre yanlış';

  @override
  String get busyOn => 'Yoğunluk: KAPALI';

  @override
  String get busyOff => 'YOĞUNLUK AÇIK';

  @override
  String get busyTooltip =>
      'Müşteriye gecikme uyarısı gösterir. Sipariş almayı durdurmaz.';

  @override
  String get busyFailed => 'Yoğunluk durumu değiştirilemedi';

  @override
  String get windowMinimize => 'Küçült';

  @override
  String get windowFullScreenOn => 'Tam ekran';

  @override
  String get windowFullScreenOff => 'Pencere';

  @override
  String get productionStripTitle => 'ÜRETİM LİSTESİ';

  @override
  String get productionStripEmpty => 'Hazırlanacak ürün yok';

  @override
  String get columnNew => 'YENİ';

  @override
  String get columnPreparing => 'HAZIRLANIYOR';

  @override
  String get columnReady => 'HAZIR';

  @override
  String columnHeader(String title, int count) {
    return '$title ($count)';
  }

  @override
  String get columnEmpty => 'Sipariş yok';

  @override
  String get actionConfirm => 'ONAYLA';

  @override
  String get actionStart => 'BAŞLA';

  @override
  String get actionReady => 'HAZIR';

  @override
  String get actionDispatch => 'YOLA ÇIKTI';

  @override
  String get actionDeliver => 'TESLİM EDİLDİ';

  @override
  String get notePrefix => 'NOT';

  @override
  String get requestedAtPrefix => 'Teslim';

  @override
  String get connectionConnected => 'Bağlı';

  @override
  String get connectionConnecting => 'Bağlanıyor';

  @override
  String get connectionDisconnected => 'Bağlantı yok';

  @override
  String get connectionRevoked => 'Cihaz eşlemesi iptal edildi';

  @override
  String get printerReady => 'Yazıcı hazır';

  @override
  String get printerUnavailable => 'Yazıcı yok';

  @override
  String printQueueCount(int count) {
    return 'Kuyruk: $count';
  }

  @override
  String get settings => 'Ayarlar';

  @override
  String get deviceInfoTitle => 'Cihaz bilgisi';

  @override
  String get deviceInfoServer => 'Sunucu';

  @override
  String get deviceInfoPrinter => 'Yazıcı';

  @override
  String get deviceInfoVersion => 'Sürüm';

  @override
  String get close => 'Kapat';

  @override
  String get devicePairingRequired => 'Cihaz eşlenmedi';

  @override
  String get devicePairingHint =>
      'Yönetici panelinden alınan eşleme kodu girilmeden sipariş alınamaz.';

  @override
  String get pairingTitle => 'Mutfak ekranını eşle';

  @override
  String get pairingServerLabel => 'Sunucu adresi';

  @override
  String get pairingCodeLabel => 'Eşleme kodu';

  @override
  String get pairingCodeHint => 'ABCD-1234';

  @override
  String get pairingDeviceNameLabel => 'Cihaz adı';

  @override
  String get pairingSubmit => 'EŞLE';

  @override
  String get pairingServerRequired => 'Sunucu adresi boş olamaz.';

  @override
  String get pairingCodeRequired =>
      'Eşleme kodu 4-4 biçiminde olmalı (ABCD-1234).';

  @override
  String get pairingDeviceNameRequired => 'Cihaz adı boş olamaz.';

  @override
  String get pairingRevokedNotice =>
      'Bu cihazın yetkisi kaldırıldı. Yeni bir eşleme kodu girin.';

  @override
  String get boardEmpty => 'Bekleyen sipariş yok';

  @override
  String statusChangeFailed(String message) {
    return 'Durum güncellenemedi: $message';
  }
}
