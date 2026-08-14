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

  /// API taban adresi satırı
  ///
  /// In tr, this message translates to:
  /// **'Sunucu'**
  String get deviceInfoServer;

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

  /// Çalan alarmı o an için susturan düğme
  ///
  /// In tr, this message translates to:
  /// **'SESİ SUSTUR'**
  String get alarmSilence;

  /// Sustur düğmesinin ipucu
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca şu anki alarmı susturur. Bir sonraki yeni sipariş yeniden çalar.'**
  String get alarmSilenceTooltip;

  /// Alarm çalarken üst çubuktaki metin
  ///
  /// In tr, this message translates to:
  /// **'{count} sipariş onay bekliyor'**
  String alarmSounding(int count);

  /// Personel sustur dedikten sonra
  ///
  /// In tr, this message translates to:
  /// **'Alarm susturuldu · {count} sipariş hâlâ onay bekliyor'**
  String alarmSilenced(int count);

  /// Ses kapalı ya da oynatıcı yokken şerit
  ///
  /// In tr, this message translates to:
  /// **'ALARM ÇALMIYOR'**
  String get alarmMutedTitle;

  /// Sessiz alarm şeridinin açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Yeni sipariş sessiz düşer. Ekranı gözle takip edin ya da ayarlardan sesi açın.'**
  String get alarmMutedBody;

  /// Üst çubuktaki kalıcı sessizlik rozeti
  ///
  /// In tr, this message translates to:
  /// **'SES KAPALI'**
  String get alarmMutedBadge;

  /// İlk liste sunucudan gelmeden önce
  ///
  /// In tr, this message translates to:
  /// **'Siparişler yükleniyor'**
  String get boardLoading;

  /// Yükleme durumunun açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Sunucuya ilk bağlantı kuruluyor. Bu ekran bir kaç saniye içinde dolacak.'**
  String get boardLoadingHint;

  /// Karttaki kalem ilerlemesi
  ///
  /// In tr, this message translates to:
  /// **'{done}/{total} hazır'**
  String itemsDone(int done, int total);

  /// Kalem işaretleme düğmesi
  ///
  /// In tr, this message translates to:
  /// **'Kalemi hazır / beklemede yap'**
  String get itemToggleTooltip;

  /// Kart başlığındaki not uyarısı
  ///
  /// In tr, this message translates to:
  /// **'NOTLU'**
  String get cardNoteBadge;

  /// Karttaki hazırlanma süresi hedefi
  ///
  /// In tr, this message translates to:
  /// **'Hedef {minutes} dk'**
  String prepTargetLabel(int minutes);

  /// Hazır siparişte gerçekleşen hazırlanma süresi
  ///
  /// In tr, this message translates to:
  /// **'Hazırlandı: {minutes} dk'**
  String prepActualLabel(int minutes);

  /// Sunucudan hiç liste alınmadıysa
  ///
  /// In tr, this message translates to:
  /// **'Hiç güncellenmedi'**
  String get lastUpdateNever;

  /// Bir dakikadan yeni güncelleme
  ///
  /// In tr, this message translates to:
  /// **'Şimdi güncellendi'**
  String get lastUpdateNow;

  /// Listenin yaşı — kopukken ne kadar güvenilir
  ///
  /// In tr, this message translates to:
  /// **'{minutes} dk önce güncellendi'**
  String lastUpdateAgo(int minutes);

  /// Elle tam yenileme düğmesi
  ///
  /// In tr, this message translates to:
  /// **'Yenile'**
  String get refreshNow;

  /// Elle yenileme başarısız
  ///
  /// In tr, this message translates to:
  /// **'Yenilenemedi: {message}'**
  String refreshFailed(String message);

  /// 422 INVALID_TRANSITION alındığında
  ///
  /// In tr, this message translates to:
  /// **'Bu sipariş başka bir yerden güncellenmiş. Liste tazelendi.'**
  String get statusChangeConflict;

  /// Yardım penceresinin başlığı
  ///
  /// In tr, this message translates to:
  /// **'Klavye kısayolları'**
  String get shortcutsTitle;

  /// Yardımı açan tuş — durum çubuğunda gösterilir
  ///
  /// In tr, this message translates to:
  /// **'F1'**
  String get shortcutsHint;

  /// Ok tuşlarının işlevi
  ///
  /// In tr, this message translates to:
  /// **'Kart seç'**
  String get shortcutSelect;

  /// Enter tuşunun işlevi
  ///
  /// In tr, this message translates to:
  /// **'Seçili kartı bir adım ilerlet'**
  String get shortcutAdvance;

  /// F2 tuşunun işlevi
  ///
  /// In tr, this message translates to:
  /// **'Aramaya geç'**
  String get shortcutSearch;

  /// Esc tuşunun işlevi
  ///
  /// In tr, this message translates to:
  /// **'Aramayı temizle / seçimi bırak'**
  String get shortcutClear;

  /// F5 tuşunun işlevi
  ///
  /// In tr, this message translates to:
  /// **'Listeyi yenile'**
  String get shortcutRefresh;

  /// F4 tuşunun işlevi
  ///
  /// In tr, this message translates to:
  /// **'Alarmı sustur'**
  String get shortcutSilence;

  /// F3 tuşunun işlevi
  ///
  /// In tr, this message translates to:
  /// **'Vardiya özeti'**
  String get shortcutSummary;

  /// F1 tuşunun işlevi
  ///
  /// In tr, this message translates to:
  /// **'Bu pencere'**
  String get shortcutHelp;

  /// Özet penceresinin başlığı
  ///
  /// In tr, this message translates to:
  /// **'Vardiya özeti'**
  String get shiftSummaryTitle;

  /// Özet penceresinin altındaki uyarı
  ///
  /// In tr, this message translates to:
  /// **'Sayaçlar uygulama açıldığından beri sayar; yeniden başlatma sıfırlar.'**
  String get shiftSummaryHint;

  /// Vardiyada ekrana düşen sipariş sayısı
  ///
  /// In tr, this message translates to:
  /// **'Görülen sipariş'**
  String get shiftSeen;

  /// Hazır ve ötesine geçen sipariş sayısı
  ///
  /// In tr, this message translates to:
  /// **'Hazırlanan sipariş'**
  String get shiftReady;

  /// Ortalama hazırlanma süresi
  ///
  /// In tr, this message translates to:
  /// **'Ortalama hazırlanma'**
  String get shiftAverage;

  /// En çok bekleyen sipariş
  ///
  /// In tr, this message translates to:
  /// **'En uzun süren'**
  String get shiftSlowest;

  /// Ölçülecek sipariş olmadığında
  ///
  /// In tr, this message translates to:
  /// **'Henüz veri yok'**
  String get shiftNone;

  /// Kuyrukta hata alan iş varken şerit
  ///
  /// In tr, this message translates to:
  /// **'FİŞLER BASILAMIYOR'**
  String get queueBacklogTitle;

  /// Kuyruk hatası şeridinin açıklaması
  ///
  /// In tr, this message translates to:
  /// **'{count} fiş yazıcıya gönderilemedi. Kâğıdı, kapağı ve kabloyu denetleyin; işler kuyrukta duruyor.'**
  String queueBacklogBody(int count);

  /// Deneme sesini kesen düğme
  ///
  /// In tr, this message translates to:
  /// **'Sesi durdur'**
  String get settingsSoundStop;

  /// Oynatıcı yokken uyarı
  ///
  /// In tr, this message translates to:
  /// **'Ses çalınamıyor: kasada pw-play ya da aplay bulunamadı.'**
  String get settingsSoundUnavailable;

  /// Sağlık panelinin başlığı
  ///
  /// In tr, this message translates to:
  /// **'Sistem durumu'**
  String get healthTitle;

  /// Sağlık panelini açan düğmenin ipucu
  ///
  /// In tr, this message translates to:
  /// **'Sistem durumu (F6)'**
  String get healthOpen;

  /// Sağlık paneli kutusu
  ///
  /// In tr, this message translates to:
  /// **'Yazıcı'**
  String get healthPrinter;

  /// Sağlık paneli kutusu
  ///
  /// In tr, this message translates to:
  /// **'Sunucu'**
  String get healthServer;

  /// Sağlık paneli kutusu
  ///
  /// In tr, this message translates to:
  /// **'Bugünkü sipariş'**
  String get healthOrdersToday;

  /// Sağlık paneli kutusu
  ///
  /// In tr, this message translates to:
  /// **'Alarm sesi'**
  String get healthSound;

  /// Yazıcı kutusunun alt satırı
  ///
  /// In tr, this message translates to:
  /// **'Kuyrukta {pending} fiş'**
  String healthPrinterQueue(int pending);

  /// Yazıcı kutusunda hata sayısı
  ///
  /// In tr, this message translates to:
  /// **'{count} fiş basılamadı'**
  String healthPrinterFailed(int count);

  /// Sağlık bildirimi başarılı
  ///
  /// In tr, this message translates to:
  /// **'Ulaşılıyor'**
  String get healthServerOk;

  /// Sağlık bildirimi başarısız
  ///
  /// In tr, this message translates to:
  /// **'Ulaşılamıyor'**
  String get healthServerDown;

  /// Henüz bildirim gönderilmedi
  ///
  /// In tr, this message translates to:
  /// **'Deneniyor'**
  String get healthServerUnknown;

  /// Son başarılı sağlık bildirimi
  ///
  /// In tr, this message translates to:
  /// **'Son iletişim: {time}'**
  String healthLastContact(String time);

  /// Hiç başarılı bildirim olmadıysa
  ///
  /// In tr, this message translates to:
  /// **'Henüz iletişim kurulmadı'**
  String get healthNoContact;

  /// Aktif sipariş sayısı
  ///
  /// In tr, this message translates to:
  /// **'{count} sipariş ekranda'**
  String healthActiveOrders(int count);

  /// Sunucudan sayı gelmediyse
  ///
  /// In tr, this message translates to:
  /// **'—'**
  String get healthTodayUnknown;

  /// Bugünkü sipariş sayısının tanımı
  ///
  /// In tr, this message translates to:
  /// **'İptaller hariç, Türkiye günü.'**
  String get healthTodayHint;

  /// Alarm çalınabiliyor
  ///
  /// In tr, this message translates to:
  /// **'Çalışıyor'**
  String get healthSoundOk;

  /// Alarm çalınamıyor ya da kapalı
  ///
  /// In tr, this message translates to:
  /// **'Sessiz'**
  String get healthSoundMuted;

  /// Alarm kutusunun açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Yeni sipariş, onaylanana kadar sesle uyarır.'**
  String get healthSoundHint;

  /// Sağlık bildirimini elle tetikleyen düğme
  ///
  /// In tr, this message translates to:
  /// **'Şimdi bildir'**
  String get healthRefresh;

  /// F6 tuşunun işlevi
  ///
  /// In tr, this message translates to:
  /// **'Sistem durumu'**
  String get shortcutHealth;

  /// Durum çubuğundaki günlük sipariş sayacı
  ///
  /// In tr, this message translates to:
  /// **'Bugün: {count}'**
  String statusToday(int count);

  /// Abonelikten üretilmiş sipariş kartındaki rozet
  ///
  /// In tr, this message translates to:
  /// **'ABONE'**
  String get cardSubscriptionBadge;

  /// Abonelik bildirim şeridi başlığı
  ///
  /// In tr, this message translates to:
  /// **'Bugün abonelik var'**
  String get subscriptionBannerTitle;

  /// Abonelik şeridinde bugün/yarın sayıları ve dokunma ipucu
  ///
  /// In tr, this message translates to:
  /// **'Bugün {today} · Yarın {tomorrow} — ayrıntı için dokunun'**
  String subscriptionBannerBreakdown(int today, int tomorrow);

  /// Ses ayarları bölüm başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Ses ve hoparlör'**
  String get settingsSectionSound;

  /// Alarmın kendi akış seviyesi.
  ///
  /// In tr, this message translates to:
  /// **'Uygulama ses seviyesi'**
  String get settingsSoundVolume;

  /// Uygulama seviyesinin sınırını açıklar.
  ///
  /// In tr, this message translates to:
  /// **'Alarmın kendi seviyesi. Hoparlör kısıksa bu ayar tek başına yetmez.'**
  String get settingsSoundVolumeHint;

  /// Kasanın genel ses seviyesi.
  ///
  /// In tr, this message translates to:
  /// **'Hoparlör (sistem) seviyesi'**
  String get settingsSpeakerVolume;

  /// Sistem seviyesinin kapsamını açıklar.
  ///
  /// In tr, this message translates to:
  /// **'Kasanın kendi seviyesi. Değiştirmek tüm sistemi etkiler.'**
  String get settingsSpeakerVolumeHint;

  /// Sistem seviyesini yazan düğme.
  ///
  /// In tr, this message translates to:
  /// **'Uygula'**
  String get settingsSpeakerApply;

  /// Sistem ses seviyesi okunamadığında gösterilen değer.
  ///
  /// In tr, this message translates to:
  /// **'Okunamadı'**
  String get settingsSpeakerUnknown;

  /// wpctl/amixer başarısız olduğunda.
  ///
  /// In tr, this message translates to:
  /// **'Hoparlör seviyesi ayarlanamadı.'**
  String get settingsSpeakerFailed;

  /// Çıkış cihazı seçimi.
  ///
  /// In tr, this message translates to:
  /// **'Ses çıkışı'**
  String get settingsAudioOutput;

  /// Çıkış cihazı seçilmediğinde.
  ///
  /// In tr, this message translates to:
  /// **'Sistem varsayılanı'**
  String get settingsAudioOutputDefault;

  /// pactl/wpctl yoksa.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış listesi alınamadı.'**
  String get settingsAudioOutputEmpty;

  /// Olay bazlı ses şalterlerinin başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Hangi olaylarda ses çalsın?'**
  String get settingsSoundEvents;

  /// Bağlantı uyarısı gibi kapatılamayan sesler için rozet.
  ///
  /// In tr, this message translates to:
  /// **'Kapatılamaz'**
  String get settingsSoundEventAlways;

  /// Alarm tekrar aralığı.
  ///
  /// In tr, this message translates to:
  /// **'Tekrarlar arası bekleme'**
  String get settingsAlarmRepeat;

  /// Tekrar aralığını açıklar.
  ///
  /// In tr, this message translates to:
  /// **'0 = aralıksız. Alarm sipariş onaylanana kadar çalar.'**
  String get settingsAlarmRepeatHint;

  /// Alarm tekrar sınırı.
  ///
  /// In tr, this message translates to:
  /// **'En fazla tekrar'**
  String get settingsAlarmMaxRepeats;

  /// Tekrar sınırını açıklar.
  ///
  /// In tr, this message translates to:
  /// **'0 = sınırsız. Sınır koymak, kimse gelmediğinde hoparlörün fişini çektirmeyi önler.'**
  String get settingsAlarmMaxRepeatsHint;

  /// Tekrar sayısı biçimi
  ///
  /// In tr, this message translates to:
  /// **'{count} kez'**
  String settingsTimes(int count);

  /// Yüzde biçimi
  ///
  /// In tr, this message translates to:
  /// **'%{count}'**
  String settingsPercent(int count);

  /// TTS şalteri.
  ///
  /// In tr, this message translates to:
  /// **'Sesli anons'**
  String get settingsTts;

  /// TTS davranışını açıklar.
  ///
  /// In tr, this message translates to:
  /// **'Yeni siparişi Türkçe okur: \"12 numaralı yeni sipariş, 4 ürün\".'**
  String get settingsTtsHint;

  /// TTS hız ayarı.
  ///
  /// In tr, this message translates to:
  /// **'Anons hızı'**
  String get settingsTtsRate;

  /// TTS deneme düğmesi.
  ///
  /// In tr, this message translates to:
  /// **'Anonsu dene'**
  String get settingsTtsTest;

  /// spd-say/espeak yoksa.
  ///
  /// In tr, this message translates to:
  /// **'Sesli anons aracı yok. Kurmak için: sudo apt install speech-dispatcher'**
  String get settingsTtsUnavailable;

  /// Ses sorunlarını gösteren blok.
  ///
  /// In tr, this message translates to:
  /// **'Ses tanılama'**
  String get settingsSoundDiagnostics;

  /// Seçilen ses ikilisi.
  ///
  /// In tr, this message translates to:
  /// **'Oynatıcı'**
  String get settingsSoundPlayer;

  /// İkili bulunamadığında değer.
  ///
  /// In tr, this message translates to:
  /// **'bulunamadı'**
  String get settingsSoundPlayerMissing;

  /// Seslerin çıkarıldığı yol.
  ///
  /// In tr, this message translates to:
  /// **'Ses klasörü'**
  String get settingsSoundFolder;

  /// Sessizlik sebebi etiketi.
  ///
  /// In tr, this message translates to:
  /// **'Sorun'**
  String get settingsSoundProblem;

  /// Sorun yokken.
  ///
  /// In tr, this message translates to:
  /// **'Ses çalışıyor.'**
  String get settingsSoundOk;

  /// Oynatıcı henüz seçilmemişken.
  ///
  /// In tr, this message translates to:
  /// **'Henüz denenmedi'**
  String get settingsSoundNotProbed;

  /// Dokunmatik bölüm başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Dokunmatik'**
  String get settingsSectionTouch;

  /// Dokunmatik kip şalteri.
  ///
  /// In tr, this message translates to:
  /// **'Dokunmatik kip'**
  String get settingsTouchMode;

  /// Dokunmatik kipin etkisini açıklar.
  ///
  /// In tr, this message translates to:
  /// **'Düğmeler büyür, açılır menüler alt sayfaya döner, klavye gerektiren alanlarda ekran klavyesi açılır.'**
  String get settingsTouchModeHint;

  /// İlerletme sonrası geri alma şeridi — düğmenin yanındaki kısa bilgi.
  ///
  /// In tr, this message translates to:
  /// **'{status} durumuna'**
  String undoPrompt(String status);

  /// Geri alma düğmesi.
  ///
  /// In tr, this message translates to:
  /// **'GERİ AL'**
  String get undoAction;

  /// Geri alma şeridini kapatan düğme.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get undoDismiss;

  /// Geri alma reddedildiğinde.
  ///
  /// In tr, this message translates to:
  /// **'Geri alınamadı — süre doldu ya da sipariş başka yerden değiştirildi.'**
  String get undoFailed;

  /// Satış kontrolü ekranı başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Satış kontrolü'**
  String get salesTitle;

  /// Şalter açıkken.
  ///
  /// In tr, this message translates to:
  /// **'Sipariş alınıyor'**
  String get salesOpenTitle;

  /// Şalter açıkken açıklama.
  ///
  /// In tr, this message translates to:
  /// **'Web ve mobil uygulamadan sipariş verilebiliyor.'**
  String get salesOpenBody;

  /// Şalter kapalıyken.
  ///
  /// In tr, this message translates to:
  /// **'SİPARİŞ ALINMIYOR'**
  String get salesClosedTitle;

  /// Süresiz durdurma.
  ///
  /// In tr, this message translates to:
  /// **'Elle açılana kadar kapalı.'**
  String get salesClosedIndefinite;

  /// Süreli durdurma.
  ///
  /// In tr, this message translates to:
  /// **'Otomatik açılış: {time} (kalan {remaining})'**
  String salesClosedUntil(String time, String remaining);

  /// Durdurma düğmesi.
  ///
  /// In tr, this message translates to:
  /// **'SATIŞI DURDUR'**
  String get salesStop;

  /// Açma düğmesi.
  ///
  /// In tr, this message translates to:
  /// **'SATIŞI AÇ'**
  String get salesResume;

  /// Sebep adımı başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Neden durduruluyor?'**
  String get salesReasonTitle;

  /// Süre adımı başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Ne kadar süreyle?'**
  String get salesDurationTitle;

  /// Şifre adımı başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Açılış şifresi'**
  String get salesPasswordTitle;

  /// Şifre adımı açıklaması.
  ///
  /// In tr, this message translates to:
  /// **'Satışı durdurmak ciroyu keser. Kasanın açılış şifresini girin.'**
  String get salesPasswordHint;

  /// Yanlış şifre.
  ///
  /// In tr, this message translates to:
  /// **'Şifre yanlış.'**
  String get salesPasswordWrong;

  /// Sebep seçeneği.
  ///
  /// In tr, this message translates to:
  /// **'Yoğunluk'**
  String get salesReasonBusy;

  /// Sebep seçeneği.
  ///
  /// In tr, this message translates to:
  /// **'Arıza (yazıcı, ocak, kasa)'**
  String get salesReasonFault;

  /// Sebep seçeneği.
  ///
  /// In tr, this message translates to:
  /// **'Malzeme bitti'**
  String get salesReasonStock;

  /// Sebep seçeneği.
  ///
  /// In tr, this message translates to:
  /// **'Diğer'**
  String get salesReasonOther;

  /// Başarı mesajı.
  ///
  /// In tr, this message translates to:
  /// **'Satış durduruldu.'**
  String get salesStopped;

  /// Başarı mesajı.
  ///
  /// In tr, this message translates to:
  /// **'Satış yeniden açıldı.'**
  String get salesResumed;

  /// Hata mesajı.
  ///
  /// In tr, this message translates to:
  /// **'İşlem başarısız: {message}'**
  String salesFailed(String message);

  /// Pano üstündeki kırmızı şerit.
  ///
  /// In tr, this message translates to:
  /// **'SİPARİŞ ALINMIYOR — {detail}'**
  String salesBannerClosed(String detail);

  /// Ürün listesi başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Ürünler'**
  String get salesProducts;

  /// Tükendi anahtarı.
  ///
  /// In tr, this message translates to:
  /// **'Bugün tükendi'**
  String get salesSoldOut;

  /// Kalıcı kapalı ürün.
  ///
  /// In tr, this message translates to:
  /// **'Menüde değil (yönetici kapattı)'**
  String get salesNotListed;

  /// Ürün arama alanı.
  ///
  /// In tr, this message translates to:
  /// **'Ürün ara'**
  String get salesProductSearch;

  /// Boş liste.
  ///
  /// In tr, this message translates to:
  /// **'Ürün bulunamadı.'**
  String get salesProductsEmpty;

  /// Kalan süre biçimi.
  ///
  /// In tr, this message translates to:
  /// **'{count} dk'**
  String salesRemainingMinutes(int count);

  /// Kalan süre biçimi.
  ///
  /// In tr, this message translates to:
  /// **'{hours} sa {minutes} dk'**
  String salesRemainingHours(int hours, int minutes);

  /// F7 kısayolu açıklaması.
  ///
  /// In tr, this message translates to:
  /// **'Satış kontrolü (durdur/aç, tükendi)'**
  String get shortcutSales;

  /// Kurye fişi etiketi (K-14).
  ///
  /// In tr, this message translates to:
  /// **'Kurye fişi'**
  String get receiptTypeCourier;

  /// Kartın fiş menüsündeki kurye seçeneği.
  ///
  /// In tr, this message translates to:
  /// **'Kurye fişini yeniden bas'**
  String get reprintCourier;

  /// Düzenlenmiş sipariş rozeti (K-12).
  ///
  /// In tr, this message translates to:
  /// **'REVİZE #{count}'**
  String orderRevised(int count);

  /// Düzenleme ekranı başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Siparişi düzenle'**
  String get editTitle;

  /// Karttaki düzenleme düğmesi.
  ///
  /// In tr, this message translates to:
  /// **'DÜZENLE'**
  String get editAction;

  /// Ekranın üstündeki uyarı.
  ///
  /// In tr, this message translates to:
  /// **'Kaydetmeden ÖNCE müşteriyi arayın ve anlaşın.'**
  String get editPhoneHint;

  /// Abonelik uyarısı.
  ///
  /// In tr, this message translates to:
  /// **'Bu bir abonelik siparişi. Değişiklik YALNIZ bugünü etkiler; abonelik tanımı değişmez.'**
  String get editSubscriptionWarning;

  /// Kalem listesi başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Kalemler'**
  String get editItems;

  /// Ürün ekleme düğmesi.
  ///
  /// In tr, this message translates to:
  /// **'Ürün ekle'**
  String get editAddProduct;

  /// Kalem kaldırma.
  ///
  /// In tr, this message translates to:
  /// **'Kaldır'**
  String get editRemove;

  /// Sebep seçimi başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Değişiklik sebebi'**
  String get editReason;

  /// Sebep boş uyarısı.
  ///
  /// In tr, this message translates to:
  /// **'Sebep seçmeden kaydedilemez.'**
  String get editReasonRequired;

  /// Personel notu alanı.
  ///
  /// In tr, this message translates to:
  /// **'İç not (isteğe bağlı)'**
  String get editNote;

  /// Teslimat saati boşsa gösterilen metin
  ///
  /// In tr, this message translates to:
  /// **'Saat belirtilmemiş'**
  String get editNoRequestedAt;

  /// Müşteri notunu düzenleme düğmesi
  ///
  /// In tr, this message translates to:
  /// **'Notu düzenle'**
  String get editChangeNote;

  /// Müşteri notu boşsa gösterilen metin
  ///
  /// In tr, this message translates to:
  /// **'Not yok'**
  String get editNoNote;

  /// Kaydet düğmesi.
  ///
  /// In tr, this message translates to:
  /// **'KAYDET VE FİŞ BAS'**
  String get editSave;

  /// Değişiklik yokken.
  ///
  /// In tr, this message translates to:
  /// **'Hiçbir şey değişmedi.'**
  String get editNoChange;

  /// Onay penceresi başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Değişikliği kaydet'**
  String get editConfirmTitle;

  /// İade tutarı.
  ///
  /// In tr, this message translates to:
  /// **'Müşteriye iade edilecek: {amount}'**
  String editRefund(String amount);

  /// Ek tahsilat tutarı.
  ///
  /// In tr, this message translates to:
  /// **'Tahsil edilecek fark: {amount}'**
  String editExtraCharge(String amount);

  /// Başarı bildirimi.
  ///
  /// In tr, this message translates to:
  /// **'Revizyon #{count} kaydedildi. Fişler yeniden basılıyor.'**
  String editSaved(int count);

  /// Hata bildirimi.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilemedi: {message}'**
  String editFailed(String message);

  /// Manuel iade uyarısı.
  ///
  /// In tr, this message translates to:
  /// **'Para farkı elle tamamlanacak: {message}'**
  String editSettlementManual(String message);

  /// İade başarısız.
  ///
  /// In tr, this message translates to:
  /// **'Sipariş güncellendi ama iade başlatılamadı. Yönetici panelinden takip edin.'**
  String get editSettlementFailed;

  /// Ürün ekleme arama alanı.
  ///
  /// In tr, this message translates to:
  /// **'Ürün ara'**
  String get editProductSearch;

  /// Boş kalem listesi.
  ///
  /// In tr, this message translates to:
  /// **'Sipariş boş bırakılamaz. Tümünü kaldırmak için siparişi iptal edin.'**
  String get editEmptyItems;

  /// Teslimat saati alanı.
  ///
  /// In tr, this message translates to:
  /// **'Teslimat saati'**
  String get editRequestedAt;

  /// Saat değiştirme düğmesi.
  ///
  /// In tr, this message translates to:
  /// **'Saati değiştir'**
  String get editChangeTime;

  /// Abonelik ekranı başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Abonelik üretim planı'**
  String get planTitle;

  /// Sekme.
  ///
  /// In tr, this message translates to:
  /// **'Bugün'**
  String get planToday;

  /// Sekme.
  ///
  /// In tr, this message translates to:
  /// **'Yarın'**
  String get planTomorrow;

  /// Sekme.
  ///
  /// In tr, this message translates to:
  /// **'Bu hafta'**
  String get planWeek;

  /// Üretim toplamları başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Hazırlanacak toplam'**
  String get planTotals;

  /// Teslimat listesi başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Teslimat çizelgesi'**
  String get planDeliveries;

  /// Uyarılar başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Dikkat'**
  String get planWarnings;

  /// Boş gün.
  ///
  /// In tr, this message translates to:
  /// **'Bu gün için abonelik siparişi yok.'**
  String get planEmpty;

  /// Fiş basma düğmesi.
  ///
  /// In tr, this message translates to:
  /// **'ÜRETİM PLANI FİŞİ BAS'**
  String get planPrint;

  /// Basım bildirimi.
  ///
  /// In tr, this message translates to:
  /// **'Üretim planı yazıcıya gönderildi.'**
  String get planPrinted;

  /// Basım hatası.
  ///
  /// In tr, this message translates to:
  /// **'Plan fişi basılamadı: {message}'**
  String planPrintFailed(String message);

  /// Toplam porsiyon.
  ///
  /// In tr, this message translates to:
  /// **'{count} porsiyon'**
  String planPortions(int count);

  /// Teslimat saati boşken.
  ///
  /// In tr, this message translates to:
  /// **'Saat yok'**
  String get planNoTime;

  /// Yükleme hatası.
  ///
  /// In tr, this message translates to:
  /// **'Plan alınamadı: {message}'**
  String planFailed(String message);

  /// Banner ve kısayol etiketi.
  ///
  /// In tr, this message translates to:
  /// **'Abonelik planı'**
  String get planOpen;

  /// Durum çubuğundaki BBD sayacı (K-16).
  ///
  /// In tr, this message translates to:
  /// **'BBD: {count}'**
  String bbdPrinted(int count);

  /// BBD çipi ipucu.
  ///
  /// In tr, this message translates to:
  /// **'BBD Store fişleri — bu siparişler panoda görünmez, yalnız fiş basılır.'**
  String get bbdTooltip;

  /// Basılmayı bekleyen BBD fişi uyarısı.
  ///
  /// In tr, this message translates to:
  /// **'BBD kuyruğunda {count} fiş bekliyor'**
  String bbdPending(int count);

  /// Ekran klavyesi penceresinin varsayılan başlığı
  ///
  /// In tr, this message translates to:
  /// **'Metin girin'**
  String get keyboardTitle;

  /// Durum çubuğundaki dokunmatik işlem menüsünün başlığı
  ///
  /// In tr, this message translates to:
  /// **'İşlemler'**
  String get actionsTitle;

  /// Yönetici özel bir kilit metni yazmadıysa gösterilen genel metin (K-21 §5.4)
  ///
  /// In tr, this message translates to:
  /// **'Bu işlem Kontrol Merkezi\'nden kilitlendi.'**
  String get lockedMessage;

  /// Durum çubuğundaki kilit rozeti ve kilitli ekran şeridinin başlığı
  ///
  /// In tr, this message translates to:
  /// **'KİLİTLİ'**
  String get lockedBadge;

  /// Kilit rozetinin ipucu
  ///
  /// In tr, this message translates to:
  /// **'Bazı işlemler Kontrol Merkezi\'nden kilitlendi.'**
  String get lockedBadgeTooltip;
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
