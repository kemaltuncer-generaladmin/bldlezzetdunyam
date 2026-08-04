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
  String get boardEmpty => 'Bekleyen sipariş yok';

  @override
  String statusChangeFailed(String message) {
    return 'Durum güncellenemedi: $message';
  }
}
