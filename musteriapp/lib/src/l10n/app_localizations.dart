import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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

  /// No description provided for @appTitle.
  ///
  /// In tr, this message translates to:
  /// **'Benim Lezzet Dünyam'**
  String get appTitle;

  /// No description provided for @commonRetry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get commonRetry;

  /// No description provided for @commonCancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get commonCancel;

  /// No description provided for @commonRequired.
  ///
  /// In tr, this message translates to:
  /// **'Zorunlu'**
  String get commonRequired;

  /// No description provided for @offlineBadge.
  ///
  /// In tr, this message translates to:
  /// **'Çevrimdışı'**
  String get offlineBadge;

  /// No description provided for @offlineMenuNotice.
  ///
  /// In tr, this message translates to:
  /// **'Çevrimdışısınız. Menü son kaydedilen haliyle gösteriliyor.'**
  String get offlineMenuNotice;

  /// No description provided for @offlineOrderBlocked.
  ///
  /// In tr, this message translates to:
  /// **'Sipariş vermek için internet bağlantısı gerekir.'**
  String get offlineOrderBlocked;

  /// No description provided for @errorUnauthenticated.
  ///
  /// In tr, this message translates to:
  /// **'Oturumunuzun süresi doldu. Lütfen tekrar giriş yapın.'**
  String get errorUnauthenticated;

  /// No description provided for @errorForbidden.
  ///
  /// In tr, this message translates to:
  /// **'Bu işlem için yetkiniz yok.'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Aradığınız kayıt bulunamadı.'**
  String get errorNotFound;

  /// No description provided for @errorValidationFailed.
  ///
  /// In tr, this message translates to:
  /// **'Gönderilen bilgilerde eksik veya hatalı alan var.'**
  String get errorValidationFailed;

  /// No description provided for @errorInvalidTransition.
  ///
  /// In tr, this message translates to:
  /// **'Sipariş bu aşamada bu işleme uygun değil.'**
  String get errorInvalidTransition;

  /// No description provided for @errorLocationClosed.
  ///
  /// In tr, this message translates to:
  /// **'Şu anda sipariş alınmıyor.'**
  String get errorLocationClosed;

  /// No description provided for @errorItemUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Sepetinizdeki bir ürün şu anda satışta değil.'**
  String get errorItemUnavailable;

  /// No description provided for @errorDeviceRevoked.
  ///
  /// In tr, this message translates to:
  /// **'Cihaz erişimi kaldırıldı.'**
  String get errorDeviceRevoked;

  /// No description provided for @errorRateLimited.
  ///
  /// In tr, this message translates to:
  /// **'Çok fazla deneme yaptınız. Lütfen biraz sonra tekrar deneyin.'**
  String get errorRateLimited;

  /// No description provided for @errorServerError.
  ///
  /// In tr, this message translates to:
  /// **'Sunucuda bir hata oluştu. Lütfen daha sonra tekrar deneyin.'**
  String get errorServerError;

  /// No description provided for @errorNetwork.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı kurulamadı. İnternetinizi kontrol edin.'**
  String get errorNetwork;

  /// No description provided for @errorUnknown.
  ///
  /// In tr, this message translates to:
  /// **'Beklenmeyen bir hata oluştu.'**
  String get errorUnknown;

  /// No description provided for @splashChecking.
  ///
  /// In tr, this message translates to:
  /// **'Bağlanılıyor…'**
  String get splashChecking;

  /// No description provided for @updateTitle.
  ///
  /// In tr, this message translates to:
  /// **'Güncelleme gerekli'**
  String get updateTitle;

  /// No description provided for @updateBody.
  ///
  /// In tr, this message translates to:
  /// **'Uygulamanın bu sürümü artık desteklenmiyor. Devam etmek için Google Play üzerinden güncelleyin.'**
  String get updateBody;

  /// No description provided for @updateCurrentVersion.
  ///
  /// In tr, this message translates to:
  /// **'Yüklü sürüm: {version}'**
  String updateCurrentVersion(String version);

  /// No description provided for @updateMinimumVersion.
  ///
  /// In tr, this message translates to:
  /// **'En düşük desteklenen sürüm: {version}'**
  String updateMinimumVersion(String version);

  /// No description provided for @updateRecheck.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden denetle'**
  String get updateRecheck;

  /// No description provided for @loginTitle.
  ///
  /// In tr, this message translates to:
  /// **'Giriş yap'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Sipariş vermek için hesabınıza girin.'**
  String get loginSubtitle;

  /// No description provided for @loginEmail.
  ///
  /// In tr, this message translates to:
  /// **'E-posta'**
  String get loginEmail;

  /// No description provided for @loginPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifre'**
  String get loginPassword;

  /// No description provided for @loginRemember.
  ///
  /// In tr, this message translates to:
  /// **'Beni hatırla'**
  String get loginRemember;

  /// No description provided for @loginRememberHelp.
  ///
  /// In tr, this message translates to:
  /// **'Kapalıysa uygulamayı kapattığınızda oturumunuz sonlanır.'**
  String get loginRememberHelp;

  /// No description provided for @loginSubmit.
  ///
  /// In tr, this message translates to:
  /// **'Giriş yap'**
  String get loginSubmit;

  /// No description provided for @loginToRegister.
  ///
  /// In tr, this message translates to:
  /// **'Hesabınız yok mu? Kayıt olun'**
  String get loginToRegister;

  /// No description provided for @loginBrowseMenu.
  ///
  /// In tr, this message translates to:
  /// **'Menüye göz at'**
  String get loginBrowseMenu;

  /// No description provided for @registerTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt ol'**
  String get registerTitle;

  /// No description provided for @registerFirstName.
  ///
  /// In tr, this message translates to:
  /// **'Ad'**
  String get registerFirstName;

  /// No description provided for @registerLastName.
  ///
  /// In tr, this message translates to:
  /// **'Soyad'**
  String get registerLastName;

  /// No description provided for @registerTelephone.
  ///
  /// In tr, this message translates to:
  /// **'Telefon'**
  String get registerTelephone;

  /// No description provided for @registerTelephoneHelp.
  ///
  /// In tr, this message translates to:
  /// **'Başında 0 olmadan 10 hane. Örnek: 5551234567'**
  String get registerTelephoneHelp;

  /// No description provided for @registerPasswordHelp.
  ///
  /// In tr, this message translates to:
  /// **'En az 8 karakter'**
  String get registerPasswordHelp;

  /// No description provided for @registerKvkk.
  ///
  /// In tr, this message translates to:
  /// **'KVKK aydınlatma metnini okudum, kişisel verilerimin işlenmesini kabul ediyorum.'**
  String get registerKvkk;

  /// No description provided for @registerKvkkRequired.
  ///
  /// In tr, this message translates to:
  /// **'Devam etmek için KVKK onayı gerekir.'**
  String get registerKvkkRequired;

  /// No description provided for @registerSubmit.
  ///
  /// In tr, this message translates to:
  /// **'Hesap oluştur'**
  String get registerSubmit;

  /// No description provided for @registerToLogin.
  ///
  /// In tr, this message translates to:
  /// **'Zaten hesabınız var mı? Giriş yapın'**
  String get registerToLogin;

  /// No description provided for @validationRequired.
  ///
  /// In tr, this message translates to:
  /// **'Bu alan boş bırakılamaz.'**
  String get validationRequired;

  /// No description provided for @validationEmail.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir e-posta adresi girin.'**
  String get validationEmail;

  /// No description provided for @validationPasswordShort.
  ///
  /// In tr, this message translates to:
  /// **'Şifre en az 8 karakter olmalı.'**
  String get validationPasswordShort;

  /// No description provided for @validationTelephone.
  ///
  /// In tr, this message translates to:
  /// **'Telefon, başında 0 olmadan 10 hane olmalı.'**
  String get validationTelephone;

  /// No description provided for @navMenu.
  ///
  /// In tr, this message translates to:
  /// **'Menü'**
  String get navMenu;

  /// No description provided for @navOrders.
  ///
  /// In tr, this message translates to:
  /// **'Siparişlerim'**
  String get navOrders;

  /// No description provided for @navAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesabım'**
  String get navAccount;

  /// No description provided for @menuTitle.
  ///
  /// In tr, this message translates to:
  /// **'Menü'**
  String get menuTitle;

  /// No description provided for @menuSearchHint.
  ///
  /// In tr, this message translates to:
  /// **'Ürün ara'**
  String get menuSearchHint;

  /// No description provided for @menuSearchEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Aramanıza uygun ürün yok.'**
  String get menuSearchEmpty;

  /// No description provided for @menuEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Menü şu anda boş.'**
  String get menuEmpty;

  /// No description provided for @menuItemUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Satışta değil'**
  String get menuItemUnavailable;

  /// No description provided for @menuOrderingClosed.
  ///
  /// In tr, this message translates to:
  /// **'Şu anda sipariş alınmıyor. Menüyü inceleyebilirsiniz.'**
  String get menuOrderingClosed;

  /// No description provided for @menuCutoff.
  ///
  /// In tr, this message translates to:
  /// **'Son sipariş saati {time}'**
  String menuCutoff(String time);

  /// No description provided for @menuMinOrderTotal.
  ///
  /// In tr, this message translates to:
  /// **'En az sipariş tutarı {amount}'**
  String menuMinOrderTotal(String amount);

  /// No description provided for @menuCartButton.
  ///
  /// In tr, this message translates to:
  /// **'Sepet · {amount}'**
  String menuCartButton(String amount);

  /// No description provided for @etaDeliveryTitle.
  ///
  /// In tr, this message translates to:
  /// **'Tahmini teslim'**
  String get etaDeliveryTitle;

  /// No description provided for @etaPickupTitle.
  ///
  /// In tr, this message translates to:
  /// **'Tahmini hazır olma'**
  String get etaPickupTitle;

  /// Dakika aralığı ve karşılık gelen saat penceresi.
  ///
  /// In tr, this message translates to:
  /// **'{minutes} dakika · {window} arası'**
  String etaValue(String minutes, String window);

  /// Ölçülmemiş tahmin. 'yaklaşık' öneki bilinçlidir.
  ///
  /// In tr, this message translates to:
  /// **'yaklaşık {minutes} dakika · {window} arası'**
  String etaValueApprox(String minutes, String window);

  /// No description provided for @etaMinutesRange.
  ///
  /// In tr, this message translates to:
  /// **'{min}-{max}'**
  String etaMinutesRange(int min, int max);

  /// No description provided for @etaMeasuredNote.
  ///
  /// In tr, this message translates to:
  /// **'Bu süre son siparişlerin gerçekleşen sürelerinden hesaplandı.'**
  String get etaMeasuredNote;

  /// No description provided for @etaConfiguredNote.
  ///
  /// In tr, this message translates to:
  /// **'Bu süre henüz gerçekleşen siparişlerle ölçülmedi; mutfağın bildirdiği ortalamadır ve değişebilir.'**
  String get etaConfiguredNote;

  /// No description provided for @etaBusyNote.
  ///
  /// In tr, this message translates to:
  /// **'Mutfağımız şu anda yoğun. Süre bu yoğunluğa göre uzatıldı.'**
  String get etaBusyNote;

  /// No description provided for @etaOrderPlacedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Tahmini teslim saati'**
  String get etaOrderPlacedTitle;

  /// No description provided for @etaOrderPickupTitle.
  ///
  /// In tr, this message translates to:
  /// **'Tahmini hazır olma saati'**
  String get etaOrderPickupTitle;

  /// No description provided for @etaOrderWindow.
  ///
  /// In tr, this message translates to:
  /// **'{window} arası'**
  String etaOrderWindow(String window);

  /// No description provided for @productAddToCart.
  ///
  /// In tr, this message translates to:
  /// **'Sepete ekle'**
  String get productAddToCart;

  /// No description provided for @productQuantity.
  ///
  /// In tr, this message translates to:
  /// **'Adet'**
  String get productQuantity;

  /// No description provided for @productNote.
  ///
  /// In tr, this message translates to:
  /// **'Ürün notu (isteğe bağlı)'**
  String get productNote;

  /// No description provided for @productNoteHint.
  ///
  /// In tr, this message translates to:
  /// **'Örn. soğansız'**
  String get productNoteHint;

  /// No description provided for @productOptionPickOne.
  ///
  /// In tr, this message translates to:
  /// **'Bir seçenek seçin'**
  String get productOptionPickOne;

  /// No description provided for @productOptionPickMany.
  ///
  /// In tr, this message translates to:
  /// **'İstediğiniz kadar seçebilirsiniz'**
  String get productOptionPickMany;

  /// No description provided for @productMissingRequiredOption.
  ///
  /// In tr, this message translates to:
  /// **'Zorunlu seçenekleri işaretleyin.'**
  String get productMissingRequiredOption;

  /// No description provided for @productAllergens.
  ///
  /// In tr, this message translates to:
  /// **'Alerjenler: {list}'**
  String productAllergens(String list);

  /// No description provided for @productAdded.
  ///
  /// In tr, this message translates to:
  /// **'{name} sepete eklendi.'**
  String productAdded(String name);

  /// No description provided for @productUnavailableNotice.
  ///
  /// In tr, this message translates to:
  /// **'Bu ürün şu anda satışta değil.'**
  String get productUnavailableNotice;

  /// No description provided for @cartTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sepet'**
  String get cartTitle;

  /// No description provided for @cartEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Sepetiniz boş.'**
  String get cartEmpty;

  /// No description provided for @cartGoToMenu.
  ///
  /// In tr, this message translates to:
  /// **'Menüye git'**
  String get cartGoToMenu;

  /// No description provided for @cartSubtotal.
  ///
  /// In tr, this message translates to:
  /// **'Ara toplam'**
  String get cartSubtotal;

  /// No description provided for @cartClear.
  ///
  /// In tr, this message translates to:
  /// **'Sepeti boşalt'**
  String get cartClear;

  /// No description provided for @cartRemove.
  ///
  /// In tr, this message translates to:
  /// **'Kaldır'**
  String get cartRemove;

  /// No description provided for @cartCheckout.
  ///
  /// In tr, this message translates to:
  /// **'Siparişi tamamla'**
  String get cartCheckout;

  /// No description provided for @cartServerCalculatesTotal.
  ///
  /// In tr, this message translates to:
  /// **'Nihai tutar sipariş oluşturulurken sunucu tarafından hesaplanır.'**
  String get cartServerCalculatesTotal;

  /// No description provided for @cartMinOrderNotMet.
  ///
  /// In tr, this message translates to:
  /// **'En az sipariş tutarı {amount}. {missing} daha eklemeniz gerekiyor.'**
  String cartMinOrderNotMet(String amount, String missing);

  /// No description provided for @cartItemCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} kalem'**
  String cartItemCount(int count);

  /// No description provided for @checkoutTitle.
  ///
  /// In tr, this message translates to:
  /// **'Ödeme'**
  String get checkoutTitle;

  /// No description provided for @checkoutDeliveryType.
  ///
  /// In tr, this message translates to:
  /// **'Teslimat tipi'**
  String get checkoutDeliveryType;

  /// No description provided for @deliveryTypeDelivery.
  ///
  /// In tr, this message translates to:
  /// **'Adrese gönderim'**
  String get deliveryTypeDelivery;

  /// No description provided for @deliveryTypePickup.
  ///
  /// In tr, this message translates to:
  /// **'Gel-al'**
  String get deliveryTypePickup;

  /// No description provided for @checkoutAddressSection.
  ///
  /// In tr, this message translates to:
  /// **'Teslimat adresi'**
  String get checkoutAddressSection;

  /// No description provided for @addressLine1.
  ///
  /// In tr, this message translates to:
  /// **'Adres'**
  String get addressLine1;

  /// No description provided for @addressDistrict.
  ///
  /// In tr, this message translates to:
  /// **'İlçe'**
  String get addressDistrict;

  /// No description provided for @addressDistrictRequired.
  ///
  /// In tr, this message translates to:
  /// **'Teslimat yapılan bir ilçe seçin.'**
  String get addressDistrictRequired;

  /// No description provided for @addressCity.
  ///
  /// In tr, this message translates to:
  /// **'İl'**
  String get addressCity;

  /// No description provided for @addressServiceAreaHelp.
  ///
  /// In tr, this message translates to:
  /// **'Şu an yalnızca Konya Selçuklu ve Karatay\'a teslimat yapıyoruz.'**
  String get addressServiceAreaHelp;

  /// No description provided for @addressNote.
  ///
  /// In tr, this message translates to:
  /// **'Adres tarifi (isteğe bağlı)'**
  String get addressNote;

  /// No description provided for @checkoutRequestedAt.
  ///
  /// In tr, this message translates to:
  /// **'İstenen teslim zamanı'**
  String get checkoutRequestedAt;

  /// No description provided for @checkoutRequestedAtAsap.
  ///
  /// In tr, this message translates to:
  /// **'En kısa sürede'**
  String get checkoutRequestedAtAsap;

  /// No description provided for @checkoutPickDateTime.
  ///
  /// In tr, this message translates to:
  /// **'Zaman seç'**
  String get checkoutPickDateTime;

  /// No description provided for @checkoutClearRequestedAt.
  ///
  /// In tr, this message translates to:
  /// **'Temizle'**
  String get checkoutClearRequestedAt;

  /// No description provided for @checkoutPaymentMethod.
  ///
  /// In tr, this message translates to:
  /// **'Ödeme yöntemi'**
  String get checkoutPaymentMethod;

  /// No description provided for @checkoutPaymentMethodsEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Bu vitrin için açık ödeme yöntemi bildirilmedi.'**
  String get checkoutPaymentMethodsEmpty;

  /// No description provided for @checkoutCustomerNote.
  ///
  /// In tr, this message translates to:
  /// **'Sipariş notu (isteğe bağlı)'**
  String get checkoutCustomerNote;

  /// No description provided for @checkoutSubmit.
  ///
  /// In tr, this message translates to:
  /// **'Siparişi onayla'**
  String get checkoutSubmit;

  /// No description provided for @checkoutOrderingClosed.
  ///
  /// In tr, this message translates to:
  /// **'Şu anda sipariş alınmıyor.'**
  String get checkoutOrderingClosed;

  /// No description provided for @checkoutRedirectNeeded.
  ///
  /// In tr, this message translates to:
  /// **'Ödemeyi tamamlamak için yönlendirilmeniz gerekiyor: {url}'**
  String checkoutRedirectNeeded(String url);

  /// No description provided for @paymentMethodOnline.
  ///
  /// In tr, this message translates to:
  /// **'Online ödeme'**
  String get paymentMethodOnline;

  /// No description provided for @paymentMethodCash.
  ///
  /// In tr, this message translates to:
  /// **'Kapıda ödeme'**
  String get paymentMethodCash;

  /// No description provided for @paymentMethodAccount.
  ///
  /// In tr, this message translates to:
  /// **'Cari hesap'**
  String get paymentMethodAccount;

  /// No description provided for @paymentMethodUnknown.
  ///
  /// In tr, this message translates to:
  /// **'Bilinmeyen yöntem'**
  String get paymentMethodUnknown;

  /// No description provided for @paymentStatusPending.
  ///
  /// In tr, this message translates to:
  /// **'Bekliyor'**
  String get paymentStatusPending;

  /// No description provided for @paymentStatusPaid.
  ///
  /// In tr, this message translates to:
  /// **'Ödendi'**
  String get paymentStatusPaid;

  /// No description provided for @paymentStatusUnknown.
  ///
  /// In tr, this message translates to:
  /// **'Belirsiz'**
  String get paymentStatusUnknown;

  /// No description provided for @orderStatusYeni.
  ///
  /// In tr, this message translates to:
  /// **'Yeni'**
  String get orderStatusYeni;

  /// No description provided for @orderStatusOnaylandi.
  ///
  /// In tr, this message translates to:
  /// **'Onaylandı'**
  String get orderStatusOnaylandi;

  /// No description provided for @orderStatusHazirlaniyor.
  ///
  /// In tr, this message translates to:
  /// **'Hazırlanıyor'**
  String get orderStatusHazirlaniyor;

  /// No description provided for @orderStatusHazir.
  ///
  /// In tr, this message translates to:
  /// **'Hazır'**
  String get orderStatusHazir;

  /// No description provided for @orderStatusYolda.
  ///
  /// In tr, this message translates to:
  /// **'Yolda'**
  String get orderStatusYolda;

  /// No description provided for @orderStatusTeslimEdildi.
  ///
  /// In tr, this message translates to:
  /// **'Teslim edildi'**
  String get orderStatusTeslimEdildi;

  /// No description provided for @orderStatusIptal.
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get orderStatusIptal;

  /// No description provided for @ordersTitle.
  ///
  /// In tr, this message translates to:
  /// **'Siparişlerim'**
  String get ordersTitle;

  /// No description provided for @ordersEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz siparişiniz yok.'**
  String get ordersEmpty;

  /// No description provided for @orderNumberLabel.
  ///
  /// In tr, this message translates to:
  /// **'Sipariş {number}'**
  String orderNumberLabel(String number);

  /// No description provided for @orderPlacedBody.
  ///
  /// In tr, this message translates to:
  /// **'Sipariş numaranız {number}.'**
  String orderPlacedBody(String number);

  /// No description provided for @trackingTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sipariş takibi'**
  String get trackingTitle;

  /// No description provided for @trackingLive.
  ///
  /// In tr, this message translates to:
  /// **'Canlı takip ediliyor'**
  String get trackingLive;

  /// No description provided for @trackingStale.
  ///
  /// In tr, this message translates to:
  /// **'Güncellenemiyor — bağlantı yok.'**
  String get trackingStale;

  /// No description provided for @trackingCancelAction.
  ///
  /// In tr, this message translates to:
  /// **'Siparişi iptal et'**
  String get trackingCancelAction;

  /// No description provided for @trackingCancelConfirmTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sipariş iptal edilsin mi?'**
  String get trackingCancelConfirmTitle;

  /// No description provided for @trackingCancelConfirmBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu işlem geri alınamaz.'**
  String get trackingCancelConfirmBody;

  /// No description provided for @trackingCancelConfirmAction.
  ///
  /// In tr, this message translates to:
  /// **'Siparişi iptal et'**
  String get trackingCancelConfirmAction;

  /// No description provided for @trackingCancelled.
  ///
  /// In tr, this message translates to:
  /// **'Siparişiniz iptal edildi.'**
  String get trackingCancelled;

  /// No description provided for @trackingItems.
  ///
  /// In tr, this message translates to:
  /// **'Ürünler'**
  String get trackingItems;

  /// No description provided for @trackingSubtotal.
  ///
  /// In tr, this message translates to:
  /// **'Ara toplam'**
  String get trackingSubtotal;

  /// No description provided for @trackingDeliveryFee.
  ///
  /// In tr, this message translates to:
  /// **'Teslimat ücreti'**
  String get trackingDeliveryFee;

  /// No description provided for @trackingTotal.
  ///
  /// In tr, this message translates to:
  /// **'Toplam'**
  String get trackingTotal;

  /// No description provided for @trackingPayment.
  ///
  /// In tr, this message translates to:
  /// **'Ödeme'**
  String get trackingPayment;

  /// No description provided for @trackingAddress.
  ///
  /// In tr, this message translates to:
  /// **'Teslimat adresi'**
  String get trackingAddress;

  /// No description provided for @trackingRequestedAt.
  ///
  /// In tr, this message translates to:
  /// **'İstenen teslim zamanı'**
  String get trackingRequestedAt;

  /// No description provided for @trackingCreatedAt.
  ///
  /// In tr, this message translates to:
  /// **'Oluşturulma'**
  String get trackingCreatedAt;

  /// No description provided for @trackingCustomerNote.
  ///
  /// In tr, this message translates to:
  /// **'Sipariş notu'**
  String get trackingCustomerNote;

  /// No description provided for @trackingDeliveryType.
  ///
  /// In tr, this message translates to:
  /// **'Teslimat tipi'**
  String get trackingDeliveryType;

  /// No description provided for @accountTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesabım'**
  String get accountTitle;

  /// No description provided for @accountGuest.
  ///
  /// In tr, this message translates to:
  /// **'Giriş yapmadınız.'**
  String get accountGuest;

  /// No description provided for @accountLogin.
  ///
  /// In tr, this message translates to:
  /// **'Giriş yap'**
  String get accountLogin;

  /// No description provided for @accountLogout.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış yap'**
  String get accountLogout;

  /// No description provided for @accountEmail.
  ///
  /// In tr, this message translates to:
  /// **'E-posta'**
  String get accountEmail;

  /// No description provided for @accountTelephone.
  ///
  /// In tr, this message translates to:
  /// **'Telefon'**
  String get accountTelephone;

  /// No description provided for @accountName.
  ///
  /// In tr, this message translates to:
  /// **'Ad soyad'**
  String get accountName;

  /// Hesabım > adres defteri ekranının başlığı
  ///
  /// In tr, this message translates to:
  /// **'Adreslerim'**
  String get addressBookTitle;

  /// Adres defteri boşken gösterilen metin
  ///
  /// In tr, this message translates to:
  /// **'Henüz kayıtlı adresiniz yok. Eklerseniz ödeme ekranında tek dokunuşla seçebilirsiniz.'**
  String get addressBookEmpty;

  /// Yeni adres ekleme düğmesi
  ///
  /// In tr, this message translates to:
  /// **'Adres ekle'**
  String get addressBookAdd;

  /// Adres düzenleme düğmesi
  ///
  /// In tr, this message translates to:
  /// **'Düzenle'**
  String get addressBookEdit;

  /// Adres silme düğmesi
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get addressBookDelete;

  /// Adres silme onayı
  ///
  /// In tr, this message translates to:
  /// **'Bu adres defterinizden silinsin mi? Geçmiş siparişleriniz etkilenmez.'**
  String get addressBookDeleteConfirm;

  /// Varsayılan adres rozeti
  ///
  /// In tr, this message translates to:
  /// **'Varsayılan'**
  String get addressBookDefault;

  /// Adresi varsayılan yapma seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Varsayılan yap'**
  String get addressBookMakeDefault;

  /// Adres etiketi alanı
  ///
  /// In tr, this message translates to:
  /// **'Adres adı (Ev, Ofis…)'**
  String get addressLabel;

  /// Adres kaydetme düğmesi
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get addressSave;

  /// Yeni adres formunun başlığı
  ///
  /// In tr, this message translates to:
  /// **'Yeni adres'**
  String get addressNewTitle;

  /// Adres düzenleme formunun başlığı
  ///
  /// In tr, this message translates to:
  /// **'Adresi düzenle'**
  String get addressEditTitle;

  /// Ödeme ekranında kayıtlı adres seçici başlığı
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlı adreslerim'**
  String get checkoutSavedAddress;

  /// Kayıtlı adres yerine elle giriş seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Yeni adres gir'**
  String get checkoutNewAddress;

  /// Sanal POS sayfasını açan düğme
  ///
  /// In tr, this message translates to:
  /// **'Ödeme sayfasını aç'**
  String get checkoutOpenPayment;

  /// Ödeme sayfası açılamadığında
  ///
  /// In tr, this message translates to:
  /// **'Ödeme sayfası açılamadı. Siparişiniz oluştu; siparişlerim ekranından tekrar deneyebilirsiniz.'**
  String get checkoutPaymentPageFailed;

  /// Hesabım ekranındaki bildirim bölümü başlığı
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler'**
  String get notificationsSection;

  /// Günlük hatırlatma anahtarı
  ///
  /// In tr, this message translates to:
  /// **'Günlük menü hatırlatması'**
  String get notificationsDailyReminder;

  /// Hatırlatma saati alt metni
  ///
  /// In tr, this message translates to:
  /// **'Her gün {time}'**
  String notificationsDailyReminderAt(String time);

  /// Hatırlatma saatini değiştirme düğmesi
  ///
  /// In tr, this message translates to:
  /// **'Saati değiştir'**
  String get notificationsChangeTime;

  /// Bildirim desteklenmeyen platformda
  ///
  /// In tr, this message translates to:
  /// **'Bu platformda bildirim gösterilemiyor.'**
  String get notificationsUnsupported;

  /// Bildirim izni reddedildiğinde
  ///
  /// In tr, this message translates to:
  /// **'Bildirim izni verilmedi. Cihaz ayarlarından açabilirsiniz.'**
  String get notificationsDenied;

  /// Sipariş hazır bildirimi başlığı
  ///
  /// In tr, this message translates to:
  /// **'Siparişiniz hazır'**
  String get notificationOrderReadyTitle;

  /// Genel sipariş durumu bildirimi başlığı
  ///
  /// In tr, this message translates to:
  /// **'Sipariş durumu değişti'**
  String get notificationOrderUpdatedTitle;

  /// Sipariş durumu bildirimi gövdesi
  ///
  /// In tr, this message translates to:
  /// **'{orderNumber} numaralı siparişiniz: {status}'**
  String notificationOrderBody(String orderNumber, String status);

  /// Harita ile konum seçme ekranının başlığı
  ///
  /// In tr, this message translates to:
  /// **'Teslimat konumu'**
  String get mapPickerTitle;

  /// Harita ekranında ne yapılacağını anlatan yönerge
  ///
  /// In tr, this message translates to:
  /// **'Haritayı kaydırarak iğneyi teslimat noktasına getirin.'**
  String get mapPickerHint;

  /// Haritanın neden hizmet alanıyla sınırlı olduğunu anlatan açıklama
  ///
  /// In tr, this message translates to:
  /// **'Şu an yalnızca Konya\'nın Selçuklu ve Karatay ilçelerine teslimat yapıyoruz; harita bu alanla sınırlıdır.'**
  String get mapPickerServiceArea;

  /// Seçilen noktayı onaylayan düğme
  ///
  /// In tr, this message translates to:
  /// **'Bu konumu kullan'**
  String get mapPickerConfirm;

  /// Kayıtlı koordinatı silen düğme
  ///
  /// In tr, this message translates to:
  /// **'İğneyi kaldır'**
  String get mapPickerClear;

  /// Adres formunda harita ekranını açan düğme
  ///
  /// In tr, this message translates to:
  /// **'Haritadan seç'**
  String get mapPickerSelect;

  /// İğne varken harita ekranını açan düğme
  ///
  /// In tr, this message translates to:
  /// **'Konumu değiştir'**
  String get mapPickerChange;

  /// Adres formunda iğnenin var olduğunu belirten etiket
  ///
  /// In tr, this message translates to:
  /// **'Konum seçildi'**
  String get mapPickerSelected;

  /// Adres formunda iğnenin olmadığını belirten etiket
  ///
  /// In tr, this message translates to:
  /// **'Konum seçilmedi'**
  String get mapPickerNotSelected;

  /// Koordinatın zorunlu olmadığını anlatan açıklama
  ///
  /// In tr, this message translates to:
  /// **'İsteğe bağlı — kuryenin doğru kapıyı bulmasına yardım eder.'**
  String get mapPickerOptional;

  /// OpenStreetMap lisansının gerektirdiği kaynak gösterimi
  ///
  /// In tr, this message translates to:
  /// **'© OpenStreetMap katkıcıları'**
  String get mapPickerAttribution;

  /// No description provided for @mapPickerMyLocation.
  ///
  /// In tr, this message translates to:
  /// **'Konumum'**
  String get mapPickerMyLocation;

  /// No description provided for @mapPickerLocationOff.
  ///
  /// In tr, this message translates to:
  /// **'Konum servisi kapalı. Ayarlardan açabilirsiniz.'**
  String get mapPickerLocationOff;

  /// No description provided for @mapPickerLocationDenied.
  ///
  /// In tr, this message translates to:
  /// **'Konum izni verilmedi. Haritayı elle kaydırabilirsiniz.'**
  String get mapPickerLocationDenied;

  /// No description provided for @mapPickerLocationOutside.
  ///
  /// In tr, this message translates to:
  /// **'Konumunuz hizmet alanının dışında.'**
  String get mapPickerLocationOutside;

  /// No description provided for @mapPickerLocationError.
  ///
  /// In tr, this message translates to:
  /// **'Konum alınamadı. Haritayı elle kaydırabilirsiniz.'**
  String get mapPickerLocationError;

  /// Alt gezinme çubuğundaki keşif sekmesi
  ///
  /// In tr, this message translates to:
  /// **'Ana Sayfa'**
  String get navHome;

  /// Ana sayfa karşılama başlığı
  ///
  /// In tr, this message translates to:
  /// **'Bugün ne yesek?'**
  String get homeGreeting;

  /// Kategori şeridi başlığı
  ///
  /// In tr, this message translates to:
  /// **'Kategoriler'**
  String get homeCategories;

  /// Öne çıkan ürünler şeridi başlığı
  ///
  /// In tr, this message translates to:
  /// **'Bugün öne çıkanlar'**
  String get homeFeatured;

  /// Menüye giden bağlantı
  ///
  /// In tr, this message translates to:
  /// **'Tümünü gör'**
  String get homeSeeAll;

  /// Geçmiş siparişten tekrar sipariş kartının başlığı
  ///
  /// In tr, this message translates to:
  /// **'Son siparişiniz'**
  String get homeLastOrder;

  /// Son siparişi sepete geri koyan düğme
  ///
  /// In tr, this message translates to:
  /// **'Tekrar sipariş ver'**
  String get homeReorder;

  /// Tekrar sipariş sonucu
  ///
  /// In tr, this message translates to:
  /// **'{count} ürün sepete eklendi.'**
  String homeReorderDone(int count);

  /// Tekrar siparişte bazı ürünler bulunamadığında
  ///
  /// In tr, this message translates to:
  /// **'{count} ürün sepete eklendi. {missing} ürün artık menüde yok.'**
  String homeReorderPartial(int count, int missing);

  /// Tekrar siparişte hiçbir ürün bulunamadığında
  ///
  /// In tr, this message translates to:
  /// **'Bu siparişteki ürünlerin hiçbiri şu an menüde yok.'**
  String get homeReorderEmpty;

  /// No description provided for @registerCompanySection.
  ///
  /// In tr, this message translates to:
  /// **'Firma bilgileri'**
  String get registerCompanySection;

  /// No description provided for @registerAccountSection.
  ///
  /// In tr, this message translates to:
  /// **'Giriş bilgileri'**
  String get registerAccountSection;

  /// No description provided for @registerCompanyName.
  ///
  /// In tr, this message translates to:
  /// **'Ticari unvan'**
  String get registerCompanyName;

  /// No description provided for @registerContactPerson.
  ///
  /// In tr, this message translates to:
  /// **'Yetkili kişi'**
  String get registerContactPerson;

  /// No description provided for @registerTaxOffice.
  ///
  /// In tr, this message translates to:
  /// **'Vergi dairesi (opsiyonel)'**
  String get registerTaxOffice;

  /// No description provided for @registerTaxNumber.
  ///
  /// In tr, this message translates to:
  /// **'Vergi / TC no (opsiyonel)'**
  String get registerTaxNumber;

  /// No description provided for @registerCompanyPhone.
  ///
  /// In tr, this message translates to:
  /// **'Kurum telefonu (opsiyonel)'**
  String get registerCompanyPhone;

  /// No description provided for @registerCorporateNote.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca kurumsal hesaplar sipariş verebilir.'**
  String get registerCorporateNote;

  /// No description provided for @registerCompanyRequired.
  ///
  /// In tr, this message translates to:
  /// **'Ticari unvan zorunludur.'**
  String get registerCompanyRequired;

  /// No description provided for @registerContactRequired.
  ///
  /// In tr, this message translates to:
  /// **'Yetkili kişi zorunludur.'**
  String get registerContactRequired;

  /// No description provided for @orderingDisabledTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sipariş kapalı'**
  String get orderingDisabledTitle;

  /// No description provided for @orderingDisabledBody.
  ///
  /// In tr, this message translates to:
  /// **'Hesabınız sipariş vermeye kapalı. Kurumsal onay için bizimle iletişime geçin.'**
  String get orderingDisabledBody;

  /// No description provided for @navSubscriptions.
  ///
  /// In tr, this message translates to:
  /// **'Abonelik'**
  String get navSubscriptions;

  /// No description provided for @accountSubscriptions.
  ///
  /// In tr, this message translates to:
  /// **'Aboneliklerim'**
  String get accountSubscriptions;

  /// No description provided for @accountStatementShortcut.
  ///
  /// In tr, this message translates to:
  /// **'Cari hesabım'**
  String get accountStatementShortcut;

  /// No description provided for @accountCompanyLabel.
  ///
  /// In tr, this message translates to:
  /// **'Firma'**
  String get accountCompanyLabel;

  /// No description provided for @subscriptionsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Aboneliklerim'**
  String get subscriptionsTitle;

  /// No description provided for @subscriptionsEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz aboneliğiniz yok. Kurumsal öğle yemeği için talep oluşturun.'**
  String get subscriptionsEmpty;

  /// No description provided for @subscriptionsNew.
  ///
  /// In tr, this message translates to:
  /// **'Yeni abonelik talebi'**
  String get subscriptionsNew;

  /// No description provided for @subscriptionStatusPending.
  ///
  /// In tr, this message translates to:
  /// **'Onay bekliyor'**
  String get subscriptionStatusPending;

  /// No description provided for @subscriptionStatusActive.
  ///
  /// In tr, this message translates to:
  /// **'Aktif'**
  String get subscriptionStatusActive;

  /// No description provided for @subscriptionStatusPaused.
  ///
  /// In tr, this message translates to:
  /// **'Duraklatıldı'**
  String get subscriptionStatusPaused;

  /// No description provided for @subscriptionStatusCancelled.
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get subscriptionStatusCancelled;

  /// No description provided for @subscriptionQuantityLabel.
  ///
  /// In tr, this message translates to:
  /// **'Günlük {count} porsiyon'**
  String subscriptionQuantityLabel(int count);

  /// No description provided for @subscriptionAgreedPrice.
  ///
  /// In tr, this message translates to:
  /// **'Porsiyon fiyatı'**
  String get subscriptionAgreedPrice;

  /// No description provided for @subscriptionNoPrice.
  ///
  /// In tr, this message translates to:
  /// **'Fiyat onay bekliyor'**
  String get subscriptionNoPrice;

  /// No description provided for @subscriptionDetailTitle.
  ///
  /// In tr, this message translates to:
  /// **'Abonelik'**
  String get subscriptionDetailTitle;

  /// No description provided for @subscriptionPause.
  ///
  /// In tr, this message translates to:
  /// **'Duraklat'**
  String get subscriptionPause;

  /// No description provided for @subscriptionResume.
  ///
  /// In tr, this message translates to:
  /// **'Devam ettir'**
  String get subscriptionResume;

  /// No description provided for @subscriptionCancel.
  ///
  /// In tr, this message translates to:
  /// **'İptal et'**
  String get subscriptionCancel;

  /// No description provided for @subscriptionCancelConfirmTitle.
  ///
  /// In tr, this message translates to:
  /// **'Aboneliği iptal et'**
  String get subscriptionCancelConfirmTitle;

  /// No description provided for @subscriptionCancelConfirmBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu abonelik iptal edilecek. Emin misiniz?'**
  String get subscriptionCancelConfirmBody;

  /// No description provided for @subscriptionCancelled.
  ///
  /// In tr, this message translates to:
  /// **'Abonelik iptal edildi.'**
  String get subscriptionCancelled;

  /// No description provided for @subscriptionPaused.
  ///
  /// In tr, this message translates to:
  /// **'Abonelik duraklatıldı.'**
  String get subscriptionPaused;

  /// No description provided for @subscriptionResumed.
  ///
  /// In tr, this message translates to:
  /// **'Abonelik devam ediyor.'**
  String get subscriptionResumed;

  /// No description provided for @subscriptionPeriod.
  ///
  /// In tr, this message translates to:
  /// **'Dönem'**
  String get subscriptionPeriod;

  /// No description provided for @subscriptionDays.
  ///
  /// In tr, this message translates to:
  /// **'Günler'**
  String get subscriptionDays;

  /// No description provided for @subscriptionDelivery.
  ///
  /// In tr, this message translates to:
  /// **'Teslimat'**
  String get subscriptionDelivery;

  /// No description provided for @subscriptionProducts.
  ///
  /// In tr, this message translates to:
  /// **'Ürünler'**
  String get subscriptionProducts;

  /// No description provided for @subscriptionDeliveryTime.
  ///
  /// In tr, this message translates to:
  /// **'Teslim saati'**
  String get subscriptionDeliveryTime;

  /// No description provided for @subscriptionOpenEnded.
  ///
  /// In tr, this message translates to:
  /// **'süresiz'**
  String get subscriptionOpenEnded;

  /// No description provided for @subscriptionNoProducts.
  ///
  /// In tr, this message translates to:
  /// **'Ürün ekibimizce eklenecek.'**
  String get subscriptionNoProducts;

  /// No description provided for @subscriptionCreateTitle.
  ///
  /// In tr, this message translates to:
  /// **'Abonelik talebi'**
  String get subscriptionCreateTitle;

  /// No description provided for @subscriptionCreateIntro.
  ///
  /// In tr, this message translates to:
  /// **'Ürünleri, günleri ve teslimatı seçin; ekibimiz fiyatlandırıp onaylayacak.'**
  String get subscriptionCreateIntro;

  /// No description provided for @subscriptionCreateDays.
  ///
  /// In tr, this message translates to:
  /// **'Teslimat günleri'**
  String get subscriptionCreateDays;

  /// No description provided for @subscriptionCreateQuantity.
  ///
  /// In tr, this message translates to:
  /// **'Günlük porsiyon'**
  String get subscriptionCreateQuantity;

  /// No description provided for @subscriptionCreateStart.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç tarihi'**
  String get subscriptionCreateStart;

  /// No description provided for @subscriptionCreateSubmit.
  ///
  /// In tr, this message translates to:
  /// **'Talep gönder'**
  String get subscriptionCreateSubmit;

  /// No description provided for @subscriptionCreateNote.
  ///
  /// In tr, this message translates to:
  /// **'Not (opsiyonel)'**
  String get subscriptionCreateNote;

  /// No description provided for @subscriptionCreatePickDay.
  ///
  /// In tr, this message translates to:
  /// **'En az bir gün seçin.'**
  String get subscriptionCreatePickDay;

  /// No description provided for @subscriptionCreateProducts.
  ///
  /// In tr, this message translates to:
  /// **'Ürünler'**
  String get subscriptionCreateProducts;

  /// No description provided for @subscriptionCreateAddProduct.
  ///
  /// In tr, this message translates to:
  /// **'Ürün ekle'**
  String get subscriptionCreateAddProduct;

  /// No description provided for @subscriptionCreateNoProducts.
  ///
  /// In tr, this message translates to:
  /// **'Henüz ürün eklenmedi. Menüden ürün ekleyin.'**
  String get subscriptionCreateNoProducts;

  /// No description provided for @subscriptionCreatePickProduct.
  ///
  /// In tr, this message translates to:
  /// **'En az bir ürün ekleyin.'**
  String get subscriptionCreatePickProduct;

  /// No description provided for @subscriptionCreatePortions.
  ///
  /// In tr, this message translates to:
  /// **'Kaç kişilik? (günlük porsiyon)'**
  String get subscriptionCreatePortions;

  /// No description provided for @subscriptionPortionCount.
  ///
  /// In tr, this message translates to:
  /// **'Günlük {count} kişilik'**
  String subscriptionPortionCount(int count);

  /// No description provided for @subscriptionCreatePickerTitle.
  ///
  /// In tr, this message translates to:
  /// **'Ürün seç'**
  String get subscriptionCreatePickerTitle;

  /// No description provided for @subscriptionRequestSent.
  ///
  /// In tr, this message translates to:
  /// **'Talebiniz alındı; fiyatlandırma sonrası aktifleşecek.'**
  String get subscriptionRequestSent;

  /// No description provided for @dayMon.
  ///
  /// In tr, this message translates to:
  /// **'Pzt'**
  String get dayMon;

  /// No description provided for @dayTue.
  ///
  /// In tr, this message translates to:
  /// **'Sal'**
  String get dayTue;

  /// No description provided for @dayWed.
  ///
  /// In tr, this message translates to:
  /// **'Çar'**
  String get dayWed;

  /// No description provided for @dayThu.
  ///
  /// In tr, this message translates to:
  /// **'Per'**
  String get dayThu;

  /// No description provided for @dayFri.
  ///
  /// In tr, this message translates to:
  /// **'Cum'**
  String get dayFri;

  /// No description provided for @daySat.
  ///
  /// In tr, this message translates to:
  /// **'Cmt'**
  String get daySat;

  /// No description provided for @daySun.
  ///
  /// In tr, this message translates to:
  /// **'Paz'**
  String get daySun;

  /// No description provided for @accountStatementTitle.
  ///
  /// In tr, this message translates to:
  /// **'Cari hesabım'**
  String get accountStatementTitle;

  /// No description provided for @accountBalanceLabel.
  ///
  /// In tr, this message translates to:
  /// **'Güncel bakiye'**
  String get accountBalanceLabel;

  /// No description provided for @accountBalanceDebtNote.
  ///
  /// In tr, this message translates to:
  /// **'Ödenmemiş bakiye'**
  String get accountBalanceDebtNote;

  /// No description provided for @accountBalanceCreditNote.
  ///
  /// In tr, this message translates to:
  /// **'Lehinize bakiye'**
  String get accountBalanceCreditNote;

  /// No description provided for @accountBalanceZeroNote.
  ///
  /// In tr, this message translates to:
  /// **'Bakiye sıfır'**
  String get accountBalanceZeroNote;

  /// No description provided for @accountStatementEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Bu aralıkta hareket yok.'**
  String get accountStatementEmpty;

  /// No description provided for @accountStatementEntries.
  ///
  /// In tr, this message translates to:
  /// **'Hareketler'**
  String get accountStatementEntries;

  /// No description provided for @accountDebit.
  ///
  /// In tr, this message translates to:
  /// **'Borç'**
  String get accountDebit;

  /// No description provided for @accountCredit.
  ///
  /// In tr, this message translates to:
  /// **'Alacak'**
  String get accountCredit;

  /// No description provided for @accountSourceOrder.
  ///
  /// In tr, this message translates to:
  /// **'Sipariş'**
  String get accountSourceOrder;

  /// No description provided for @accountSourceSubscription.
  ///
  /// In tr, this message translates to:
  /// **'Abonelik'**
  String get accountSourceSubscription;

  /// No description provided for @accountSourcePayment.
  ///
  /// In tr, this message translates to:
  /// **'Tahsilat'**
  String get accountSourcePayment;

  /// No description provided for @accountSourceManual.
  ///
  /// In tr, this message translates to:
  /// **'Elle giriş'**
  String get accountSourceManual;

  /// No description provided for @accountSourceAdjustment.
  ///
  /// In tr, this message translates to:
  /// **'Düzeltme'**
  String get accountSourceAdjustment;

  /// Mutfağın günlük tükendi işareti (K-11).
  ///
  /// In tr, this message translates to:
  /// **'Bugünlük tükendi'**
  String get productSoldOutToday;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
