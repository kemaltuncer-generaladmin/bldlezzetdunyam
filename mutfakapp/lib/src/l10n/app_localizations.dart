import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('tr')];

  /// Pencere başlığı
  ///
  /// In tr, this message translates to:
  /// **'Mutfak Ekranı'**
  String get appTitle;

  /// Açılış kilidi parola alanının etiketi
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi giriniz'**
  String get unlockPrompt;

  /// Açılış kilidini kaldıran düğme
  ///
  /// In tr, this message translates to:
  /// **'Aç'**
  String get unlockAction;

  /// Yanlış parola girildiğinde
  ///
  /// In tr, this message translates to:
  /// **'Şifre yanlış'**
  String get unlockWrong;

  /// Yoğunluk şalteri kapalıyken düğme etiketi
  ///
  /// In tr, this message translates to:
  /// **'Yoğunluk: KAPALI'**
  String get busyOn;

  /// Yoğunluk şalteri açıkken düğme etiketi
  ///
  /// In tr, this message translates to:
  /// **'YOĞUNLUK AÇIK'**
  String get busyOff;

  /// Yoğunluk düğmesinin ipucu
  ///
  /// In tr, this message translates to:
  /// **'Müşteriye gecikme uyarısı gösterir. Sipariş almayı durdurmaz.'**
  String get busyTooltip;

  /// Şalter sunucuya yazılamayınca
  ///
  /// In tr, this message translates to:
  /// **'Yoğunluk durumu değiştirilemedi'**
  String get busyFailed;

  /// Pencereyi görev çubuğuna indirir
  ///
  /// In tr, this message translates to:
  /// **'Küçült'**
  String get windowMinimize;

  /// Tam ekrana geçiren düğme
  ///
  /// In tr, this message translates to:
  /// **'Tam ekran'**
  String get windowFullScreenOn;

  /// Tam ekrandan çıkaran düğme
  ///
  /// In tr, this message translates to:
  /// **'Pencere'**
  String get windowFullScreenOff;

  /// Üst şeridin etiketi
  ///
  /// In tr, this message translates to:
  /// **'ÜRETİM LİSTESİ'**
  String get productionStripTitle;

  /// Üretim listesi boşken
  ///
  /// In tr, this message translates to:
  /// **'Hazırlanacak ürün yok'**
  String get productionStripEmpty;

  /// Birinci sütun başlığı
  ///
  /// In tr, this message translates to:
  /// **'YENİ'**
  String get columnNew;

  /// İkinci sütun başlığı
  ///
  /// In tr, this message translates to:
  /// **'HAZIRLANIYOR'**
  String get columnPreparing;

  /// Üçüncü sütun başlığı
  ///
  /// In tr, this message translates to:
  /// **'HAZIR'**
  String get columnReady;

  /// Sütun başlığı ve kart sayısı
  ///
  /// In tr, this message translates to:
  /// **'{title} ({count})'**
  String columnHeader(String title, int count);

  /// Sütunda kart olmadığında
  ///
  /// In tr, this message translates to:
  /// **'Sipariş yok'**
  String get columnEmpty;

  /// yeni → onaylandi
  ///
  /// In tr, this message translates to:
  /// **'ONAYLA'**
  String get actionConfirm;

  /// onaylandi → hazirlaniyor
  ///
  /// In tr, this message translates to:
  /// **'BAŞLA'**
  String get actionStart;

  /// hazirlaniyor → hazir
  ///
  /// In tr, this message translates to:
  /// **'HAZIR'**
  String get actionReady;

  /// hazir → yolda, yalnızca adrese gönderim
  ///
  /// In tr, this message translates to:
  /// **'YOLA ÇIKTI'**
  String get actionDispatch;

  /// hazir/yolda → teslim_edildi
  ///
  /// In tr, this message translates to:
  /// **'TESLİM EDİLDİ'**
  String get actionDeliver;

  /// Sipariş notu etiketi
  ///
  /// In tr, this message translates to:
  /// **'NOT'**
  String get notePrefix;

  /// İstenen teslim saati etiketi
  ///
  /// In tr, this message translates to:
  /// **'Teslim'**
  String get requestedAtPrefix;

  /// Durum çubuğu bağlantı göstergesi
  ///
  /// In tr, this message translates to:
  /// **'Bağlı'**
  String get connectionConnected;

  /// Durum çubuğu bağlantı göstergesi
  ///
  /// In tr, this message translates to:
  /// **'Bağlanıyor'**
  String get connectionConnecting;

  /// Durum çubuğu bağlantı göstergesi
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı yok'**
  String get connectionDisconnected;

  /// 403 DEVICE_REVOKED sonrası
  ///
  /// In tr, this message translates to:
  /// **'Cihaz eşlemesi iptal edildi'**
  String get connectionRevoked;

  /// Yazıcı cihaz dosyası erişilebilir
  ///
  /// In tr, this message translates to:
  /// **'Yazıcı hazır'**
  String get printerReady;

  /// Yazıcı cihaz dosyası bulunamadı
  ///
  /// In tr, this message translates to:
  /// **'Yazıcı yok'**
  String get printerUnavailable;

  /// Bekleyen yazdırma işi sayısı
  ///
  /// In tr, this message translates to:
  /// **'Kuyruk: {count}'**
  String printQueueCount(int count);

  /// Durum çubuğundaki ayarlar düğmesi
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get settings;

  /// Ayarlar düğmesinin açtığı pencere
  ///
  /// In tr, this message translates to:
  /// **'Cihaz bilgisi'**
  String get deviceInfoTitle;

  /// API taban adresi satırı
  ///
  /// In tr, this message translates to:
  /// **'Sunucu'**
  String get deviceInfoServer;

  /// Yazıcı cihaz yolu satırı
  ///
  /// In tr, this message translates to:
  /// **'Yazıcı'**
  String get deviceInfoPrinter;

  /// Uygulama sürümü satırı
  ///
  /// In tr, this message translates to:
  /// **'Sürüm'**
  String get deviceInfoVersion;

  /// Pencere kapatma düğmesi
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get close;

  /// Kayıtlı mutfak token'ı yokken
  ///
  /// In tr, this message translates to:
  /// **'Cihaz eşlenmedi'**
  String get devicePairingRequired;

  /// Eşleme yapılmadığında gösterilen açıklama
  ///
  /// In tr, this message translates to:
  /// **'Yönetici panelinden alınan eşleme kodu girilmeden sipariş alınamaz.'**
  String get devicePairingHint;

  /// Eşleme ekranının başlığı
  ///
  /// In tr, this message translates to:
  /// **'Mutfak ekranını eşle'**
  String get pairingTitle;

  /// Eşleme ekranı alanı
  ///
  /// In tr, this message translates to:
  /// **'Sunucu adresi'**
  String get pairingServerLabel;

  /// Eşleme ekranı alanı
  ///
  /// In tr, this message translates to:
  /// **'Eşleme kodu'**
  String get pairingCodeLabel;

  /// Eşleme kodu biçim örneği
  ///
  /// In tr, this message translates to:
  /// **'ABCD-1234'**
  String get pairingCodeHint;

  /// Eşleme ekranı alanı
  ///
  /// In tr, this message translates to:
  /// **'Cihaz adı'**
  String get pairingDeviceNameLabel;

  /// Eşleme ekranı düğmesi
  ///
  /// In tr, this message translates to:
  /// **'EŞLE'**
  String get pairingSubmit;

  /// Doğrulama hatası
  ///
  /// In tr, this message translates to:
  /// **'Sunucu adresi boş olamaz.'**
  String get pairingServerRequired;

  /// Doğrulama hatası
  ///
  /// In tr, this message translates to:
  /// **'Eşleme kodu 4-4 biçiminde olmalı (ABCD-1234).'**
  String get pairingCodeRequired;

  /// Doğrulama hatası
  ///
  /// In tr, this message translates to:
  /// **'Cihaz adı boş olamaz.'**
  String get pairingDeviceNameRequired;

  /// 403 DEVICE_REVOKED sonrası
  ///
  /// In tr, this message translates to:
  /// **'Bu cihazın yetkisi kaldırıldı. Yeni bir eşleme kodu girin.'**
  String get pairingRevokedNotice;

  /// Üç sütun da boşken
  ///
  /// In tr, this message translates to:
  /// **'Bekleyen sipariş yok'**
  String get boardEmpty;

  /// Durum ilerletme isteği başarısız olduğunda
  ///
  /// In tr, this message translates to:
  /// **'Durum güncellenemedi: {message}'**
  String statusChangeFailed(String message);

  /// Pano tamamen boşken alt açıklama
  ///
  /// In tr, this message translates to:
  /// **'Yeni sipariş düştüğünde burada belirir ve sesli uyarı verir.'**
  String get boardEmptyHint;

  /// Üst çubuktaki arama alanının etiketi
  ///
  /// In tr, this message translates to:
  /// **'Sipariş ara'**
  String get searchLabel;

  /// Arama alanı ipucu
  ///
  /// In tr, this message translates to:
  /// **'S-5012, müşteri ya da ürün'**
  String get searchHint;

  /// Arama alanındaki temizleme düğmesi
  ///
  /// In tr, this message translates to:
  /// **'Aramayı temizle'**
  String get searchClear;

  /// Filtre hiçbir kartı bırakmadığında
  ///
  /// In tr, this message translates to:
  /// **'Aramayla eşleşen sipariş yok'**
  String get searchNoResult;

  /// Filtre açıkken kaç kart gösteriliyor
  ///
  /// In tr, this message translates to:
  /// **'{shown}/{total} sipariş'**
  String searchResultCount(int shown, int total);

  /// Üst çubuktaki toplam sayaç
  ///
  /// In tr, this message translates to:
  /// **'{count} aktif sipariş'**
  String activeOrderCount(int count);

  /// Üst çubuktaki alarm rozeti
  ///
  /// In tr, this message translates to:
  /// **'GECİKEN {count}'**
  String lateOrderCount(int count);

  /// Hiç geciken sipariş olmadığında
  ///
  /// In tr, this message translates to:
  /// **'Gecikme yok'**
  String get noLateOrders;

  /// Karttaki bekleme sayacı, bir saatin altında
  ///
  /// In tr, this message translates to:
  /// **'{minutes} dk'**
  String elapsedMinutes(int minutes);

  /// Karttaki bekleme sayacı, bir saat ve üzeri
  ///
  /// In tr, this message translates to:
  /// **'{hours} sa {minutes} dk'**
  String elapsedHours(int hours, int minutes);

  /// İstenen teslim saati henüz gelmemişken
  ///
  /// In tr, this message translates to:
  /// **'{time} · {minutes} dk kaldı'**
  String requestedRemaining(String time, int minutes);

  /// İstenen teslim saati geçtiğinde
  ///
  /// In tr, this message translates to:
  /// **'{time} · {minutes} dk GECİKTİ'**
  String requestedOverdue(String time, int minutes);

  /// Panonun üstündeki kesinti şeridi
  ///
  /// In tr, this message translates to:
  /// **'BAĞLANTI YOK'**
  String get offlineBannerTitle;

  /// Kesinti şeridinin açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Liste güncellenmiyor. Ekranda son bilinen durum var; yeni sipariş görünmeyebilir.'**
  String get offlineBannerBody;

  /// İlk bağlantı kurulurken
  ///
  /// In tr, this message translates to:
  /// **'BAĞLANIYOR'**
  String get connectingBannerTitle;

  /// Bağlanma şeridinin açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Sunucuya ulaşılmaya çalışılıyor.'**
  String get connectingBannerBody;

  /// Yazıcı cihaz dosyası bulunamadığında
  ///
  /// In tr, this message translates to:
  /// **'YAZICI YOK'**
  String get printerBannerTitle;

  /// Yazıcı şeridinin açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Fişler kuyrukta bekliyor. Yazıcı kablosunu ve gücünü denetleyin.'**
  String get printerBannerBody;

  /// Karttaki yeniden basma düğmesi
  ///
  /// In tr, this message translates to:
  /// **'Fişi yeniden bas'**
  String get reprintTooltip;

  /// Yeniden basma menüsü seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Mutfak fişini yeniden bas'**
  String get reprintKitchen;

  /// Yeniden basma menüsü seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Müşteri fişini yeniden bas'**
  String get reprintCustomer;

  /// Yeniden basma isteği kabul edildiğinde
  ///
  /// In tr, this message translates to:
  /// **'{orderNumber} fişi kuyruğa alındı.'**
  String reprintQueued(String orderNumber);

  /// Fiş tipi adı
  ///
  /// In tr, this message translates to:
  /// **'Mutfak fişi'**
  String get receiptTypeKitchen;

  /// Fiş tipi adı
  ///
  /// In tr, this message translates to:
  /// **'Müşteri fişi'**
  String get receiptTypeCustomer;

  /// Durum çubuğunda başarısız iş sayacı
  ///
  /// In tr, this message translates to:
  /// **'{count} fiş hatası'**
  String queueFailedCount(int count);

  /// Ayarlar ekranının başlığı
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get settingsTitle;

  /// Ayarlar ekranından çıkış
  ///
  /// In tr, this message translates to:
  /// **'Panoya dön'**
  String get settingsBack;

  /// Ayarlar bölüm başlığı
  ///
  /// In tr, this message translates to:
  /// **'Sunucu'**
  String get settingsSectionServer;

  /// Ayarlar bölüm başlığı
  ///
  /// In tr, this message translates to:
  /// **'Yazıcı'**
  String get settingsSectionPrinter;

  /// Ayarlar bölüm başlığı
  ///
  /// In tr, this message translates to:
  /// **'Uyarılar ve aciliyet'**
  String get settingsSectionAlerts;

  /// Ayarlar bölüm başlığı
  ///
  /// In tr, this message translates to:
  /// **'Yazdırma kuyruğu'**
  String get settingsSectionQueue;

  /// Ayarlar bölüm başlığı
  ///
  /// In tr, this message translates to:
  /// **'Cihaz'**
  String get settingsSectionDevice;

  /// Sunucu adresini düzenleyen düğme
  ///
  /// In tr, this message translates to:
  /// **'Adresi değiştir'**
  String get settingsServerChange;

  /// Adres değiştirme onayı
  ///
  /// In tr, this message translates to:
  /// **'Adres değişince cihaz eşlemesi silinir; yeni bir eşleme kodu gerekir.'**
  String get settingsServerChangeWarning;

  /// Yazıcı cihaz dosyası alanı
  ///
  /// In tr, this message translates to:
  /// **'Yazıcı cihaz yolu'**
  String get settingsPrinterPath;

  /// Salt okunur kod sayfası satırı
  ///
  /// In tr, this message translates to:
  /// **'Kod sayfası (ESC t n)'**
  String get settingsPrinterCodePage;

  /// Test fişi düğmesi
  ///
  /// In tr, this message translates to:
  /// **'TEST FİŞİ BAS'**
  String get settingsPrinterTest;

  /// Test fişi başarılı
  ///
  /// In tr, this message translates to:
  /// **'Test fişi yazıcıya gönderildi.'**
  String get settingsPrinterTestSent;

  /// Test fişi başarısız
  ///
  /// In tr, this message translates to:
  /// **'Test fişi basılamadı: {message}'**
  String settingsPrinterTestFailed(String message);

  /// Sesli uyarı şalteri
  ///
  /// In tr, this message translates to:
  /// **'Yeni sipariş sesi'**
  String get settingsSound;

  /// Uyarı sesini bir kez çalar
  ///
  /// In tr, this message translates to:
  /// **'Sesi dene'**
  String get settingsSoundTest;

  /// Sipariş çekme sıklığı ayarı
  ///
  /// In tr, this message translates to:
  /// **'Yoklama aralığı'**
  String get settingsPollInterval;

  /// Yoklama aralığı açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Kısaltmak siparişi daha erken gösterir, sunucuyu daha çok yorar.'**
  String get settingsPollIntervalHint;

  /// Kartın sarıya döndüğü süre
  ///
  /// In tr, this message translates to:
  /// **'Sarı uyarı eşiği'**
  String get settingsWarningAfter;

  /// Kartın kırmızıya döndüğü süre
  ///
  /// In tr, this message translates to:
  /// **'Kırmızı gecikme eşiği'**
  String get settingsLateAfter;

  /// Eşiklerin ikinci anlamı
  ///
  /// In tr, this message translates to:
  /// **'Aynı süre, istenen teslim saatine kalan zaman için de geçerlidir.'**
  String get settingsThresholdHint;

  /// Saniye değeri
  ///
  /// In tr, this message translates to:
  /// **'{count} sn'**
  String settingsSeconds(int count);

  /// Dakika değeri
  ///
  /// In tr, this message translates to:
  /// **'{count} dk'**
  String settingsMinutes(int count);

  /// Sayısal ayarı küçülten düğme
  ///
  /// In tr, this message translates to:
  /// **'Azalt'**
  String get settingsDecrease;

  /// Sayısal ayarı büyüten düğme
  ///
  /// In tr, this message translates to:
  /// **'Artır'**
  String get settingsIncrease;

  /// Yazdırma kuyruğu boşken
  ///
  /// In tr, this message translates to:
  /// **'Kuyrukta iş yok.'**
  String get settingsQueueEmpty;

  /// Basılmamış iş durumu
  ///
  /// In tr, this message translates to:
  /// **'Bekliyor'**
  String get settingsQueuePending;

  /// Basılmış iş durumu
  ///
  /// In tr, this message translates to:
  /// **'Basıldı · {time}'**
  String settingsQueuePrinted(String time);

  /// Hata almış iş
  ///
  /// In tr, this message translates to:
  /// **'{count} başarısız deneme'**
  String settingsQueueAttempts(int count);

  /// Kuyruk satırındaki sipariş kimliği
  ///
  /// In tr, this message translates to:
  /// **'Sipariş #{orderId}'**
  String settingsQueueOrder(int orderId);

  /// Kuyruk listesini tazeler
  ///
  /// In tr, this message translates to:
  /// **'Listeyi yenile'**
  String get settingsQueueRefresh;

  /// Token'ı silen düğme
  ///
  /// In tr, this message translates to:
  /// **'Cihaz eşlemesini sıfırla'**
  String get settingsResetPairing;

  /// Eşleme sıfırlama onayı
  ///
  /// In tr, this message translates to:
  /// **'Bu cihaz sunucudan kopar ve sipariş almayı durdurur. Yeni bir eşleme kodu gerekir.'**
  String get settingsResetPairingWarning;

  /// Sürüm denetleme düğmesi
  ///
  /// In tr, this message translates to:
  /// **'Güncelleme denetle'**
  String get settingsCheckUpdate;

  /// Güncel sürümdeyiz
  ///
  /// In tr, this message translates to:
  /// **'En güncel sürüm kullanılıyor ({version}).'**
  String settingsUpdateLatest(String version);

  /// Daha yeni sürüm yayımlanmış
  ///
  /// In tr, this message translates to:
  /// **'Yeni sürüm var: {version}'**
  String settingsUpdateAvailable(String version);

  /// Sürüm ucu hata verdi
  ///
  /// In tr, this message translates to:
  /// **'Sürüm denetlenemedi: {message}'**
  String settingsUpdateFailed(String message);

  /// Ayar diske yazıldığında
  ///
  /// In tr, this message translates to:
  /// **'Ayar kaydedildi.'**
  String get settingsSaved;

  /// Onay penceresindeki olumlu düğme
  ///
  /// In tr, this message translates to:
  /// **'ONAYLA'**
  String get confirm;

  /// Onay penceresindeki olumsuz düğme
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get cancel;

  /// Alan kaydetme düğmesi
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get save;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'tr':
      return AppL10nTr();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
