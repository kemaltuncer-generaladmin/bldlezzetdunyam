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

  @override
  String get boardEmptyHint =>
      'Yeni sipariş düştüğünde burada belirir ve sesli uyarı verir.';

  @override
  String get searchLabel => 'Sipariş ara';

  @override
  String get searchHint => 'S-5012, müşteri ya da ürün';

  @override
  String get searchClear => 'Aramayı temizle';

  @override
  String get searchNoResult => 'Aramayla eşleşen sipariş yok';

  @override
  String searchResultCount(int shown, int total) {
    return '$shown/$total sipariş';
  }

  @override
  String activeOrderCount(int count) {
    return '$count aktif sipariş';
  }

  @override
  String lateOrderCount(int count) {
    return 'GECİKEN $count';
  }

  @override
  String get noLateOrders => 'Gecikme yok';

  @override
  String elapsedMinutes(int minutes) {
    return '$minutes dk';
  }

  @override
  String elapsedHours(int hours, int minutes) {
    return '$hours sa $minutes dk';
  }

  @override
  String requestedRemaining(String time, int minutes) {
    return '$time · $minutes dk kaldı';
  }

  @override
  String requestedOverdue(String time, int minutes) {
    return '$time · $minutes dk GECİKTİ';
  }

  @override
  String get offlineBannerTitle => 'BAĞLANTI YOK';

  @override
  String get offlineBannerBody =>
      'Liste güncellenmiyor. Ekranda son bilinen durum var; yeni sipariş görünmeyebilir.';

  @override
  String get connectingBannerTitle => 'BAĞLANIYOR';

  @override
  String get connectingBannerBody => 'Sunucuya ulaşılmaya çalışılıyor.';

  @override
  String get printerBannerTitle => 'YAZICI YOK';

  @override
  String get printerBannerBody =>
      'Fişler kuyrukta bekliyor. Yazıcı kablosunu ve gücünü denetleyin.';

  @override
  String get reprintTooltip => 'Fişi yeniden bas';

  @override
  String get reprintKitchen => 'Mutfak fişini yeniden bas';

  @override
  String get reprintCustomer => 'Müşteri fişini yeniden bas';

  @override
  String reprintQueued(String orderNumber) {
    return '$orderNumber fişi kuyruğa alındı.';
  }

  @override
  String get receiptTypeKitchen => 'Mutfak fişi';

  @override
  String get receiptTypeCustomer => 'Müşteri fişi';

  @override
  String queueFailedCount(int count) {
    return '$count fiş hatası';
  }

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get settingsBack => 'Panoya dön';

  @override
  String get settingsSectionServer => 'Sunucu';

  @override
  String get settingsSectionPrinter => 'Yazıcı';

  @override
  String get settingsSectionAlerts => 'Uyarılar ve aciliyet';

  @override
  String get settingsSectionQueue => 'Yazdırma kuyruğu';

  @override
  String get settingsSectionDevice => 'Cihaz';

  @override
  String get settingsServerChange => 'Adresi değiştir';

  @override
  String get settingsServerChangeWarning =>
      'Adres değişince cihaz eşlemesi silinir; yeni bir eşleme kodu gerekir.';

  @override
  String get settingsPrinterPath => 'Yazıcı cihaz yolu';

  @override
  String get settingsPrinterCodePage => 'Kod sayfası (ESC t n)';

  @override
  String get settingsPrinterTest => 'TEST FİŞİ BAS';

  @override
  String get settingsPrinterTestSent => 'Test fişi yazıcıya gönderildi.';

  @override
  String settingsPrinterTestFailed(String message) {
    return 'Test fişi basılamadı: $message';
  }

  @override
  String get settingsSound => 'Yeni sipariş sesi';

  @override
  String get settingsSoundTest => 'Sesi dene';

  @override
  String get settingsPollInterval => 'Yoklama aralığı';

  @override
  String get settingsPollIntervalHint =>
      'Kısaltmak siparişi daha erken gösterir, sunucuyu daha çok yorar.';

  @override
  String get settingsWarningAfter => 'Sarı uyarı eşiği';

  @override
  String get settingsLateAfter => 'Kırmızı gecikme eşiği';

  @override
  String get settingsThresholdHint =>
      'Aynı süre, istenen teslim saatine kalan zaman için de geçerlidir.';

  @override
  String settingsSeconds(int count) {
    return '$count sn';
  }

  @override
  String settingsMinutes(int count) {
    return '$count dk';
  }

  @override
  String get settingsDecrease => 'Azalt';

  @override
  String get settingsIncrease => 'Artır';

  @override
  String get settingsQueueEmpty => 'Kuyrukta iş yok.';

  @override
  String get settingsQueuePending => 'Bekliyor';

  @override
  String settingsQueuePrinted(String time) {
    return 'Basıldı · $time';
  }

  @override
  String settingsQueueAttempts(int count) {
    return '$count başarısız deneme';
  }

  @override
  String settingsQueueOrder(int orderId) {
    return 'Sipariş #$orderId';
  }

  @override
  String get settingsQueueRefresh => 'Listeyi yenile';

  @override
  String get settingsResetPairing => 'Cihaz eşlemesini sıfırla';

  @override
  String get settingsResetPairingWarning =>
      'Bu cihaz sunucudan kopar ve sipariş almayı durdurur. Yeni bir eşleme kodu gerekir.';

  @override
  String get settingsCheckUpdate => 'Güncelleme denetle';

  @override
  String settingsUpdateLatest(String version) {
    return 'En güncel sürüm kullanılıyor ($version).';
  }

  @override
  String settingsUpdateAvailable(String version) {
    return 'Yeni sürüm var: $version';
  }

  @override
  String settingsUpdateFailed(String message) {
    return 'Sürüm denetlenemedi: $message';
  }

  @override
  String get settingsSaved => 'Ayar kaydedildi.';

  @override
  String get confirm => 'ONAYLA';

  @override
  String get cancel => 'Vazgeç';

  @override
  String get save => 'Kaydet';
}
