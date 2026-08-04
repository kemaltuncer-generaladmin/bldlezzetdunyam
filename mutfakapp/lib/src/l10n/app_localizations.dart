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
