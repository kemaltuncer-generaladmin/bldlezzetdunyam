// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Benim Lezzet Dünyam';

  @override
  String get commonRetry => 'Tekrar dene';

  @override
  String get commonCancel => 'Vazgeç';

  @override
  String get commonRequired => 'Zorunlu';

  @override
  String get offlineBadge => 'Çevrimdışı';

  @override
  String get offlineMenuNotice =>
      'Çevrimdışısınız. Menü son kaydedilen haliyle gösteriliyor.';

  @override
  String get offlineOrderBlocked =>
      'Sipariş vermek için internet bağlantısı gerekir.';

  @override
  String get errorUnauthenticated =>
      'Oturumunuzun süresi doldu. Lütfen tekrar giriş yapın.';

  @override
  String get errorForbidden => 'Bu işlem için yetkiniz yok.';

  @override
  String get errorNotFound => 'Aradığınız kayıt bulunamadı.';

  @override
  String get errorValidationFailed =>
      'Gönderilen bilgilerde eksik veya hatalı alan var.';

  @override
  String get errorInvalidTransition =>
      'Sipariş bu aşamada bu işleme uygun değil.';

  @override
  String get errorLocationClosed => 'Şu anda sipariş alınmıyor.';

  @override
  String get errorItemUnavailable =>
      'Sepetinizdeki bir ürün şu anda satışta değil.';

  @override
  String get errorDeviceRevoked => 'Cihaz erişimi kaldırıldı.';

  @override
  String get errorRateLimited =>
      'Çok fazla deneme yaptınız. Lütfen biraz sonra tekrar deneyin.';

  @override
  String get errorServerError =>
      'Sunucuda bir hata oluştu. Lütfen daha sonra tekrar deneyin.';

  @override
  String get errorNetwork => 'Bağlantı kurulamadı. İnternetinizi kontrol edin.';

  @override
  String get errorUnknown => 'Beklenmeyen bir hata oluştu.';

  @override
  String get splashChecking => 'Bağlanılıyor…';

  @override
  String get updateTitle => 'Güncelleme gerekli';

  @override
  String get updateBody =>
      'Uygulamanın bu sürümü artık desteklenmiyor. Devam etmek için Google Play üzerinden güncelleyin.';

  @override
  String updateCurrentVersion(String version) {
    return 'Yüklü sürüm: $version';
  }

  @override
  String updateMinimumVersion(String version) {
    return 'En düşük desteklenen sürüm: $version';
  }

  @override
  String get updateRecheck => 'Yeniden denetle';

  @override
  String get loginTitle => 'Giriş yap';

  @override
  String get loginSubtitle => 'Sipariş vermek için hesabınıza girin.';

  @override
  String get loginEmail => 'E-posta';

  @override
  String get loginPassword => 'Şifre';

  @override
  String get loginSubmit => 'Giriş yap';

  @override
  String get loginToRegister => 'Hesabınız yok mu? Kayıt olun';

  @override
  String get loginBrowseMenu => 'Menüye göz at';

  @override
  String get registerTitle => 'Kayıt ol';

  @override
  String get registerFirstName => 'Ad';

  @override
  String get registerLastName => 'Soyad';

  @override
  String get registerTelephone => 'Telefon';

  @override
  String get registerTelephoneHelp =>
      'Başında 0 olmadan 10 hane. Örnek: 5551234567';

  @override
  String get registerPasswordHelp => 'En az 8 karakter';

  @override
  String get registerKvkk =>
      'KVKK aydınlatma metnini okudum, kişisel verilerimin işlenmesini kabul ediyorum.';

  @override
  String get registerKvkkRequired => 'Devam etmek için KVKK onayı gerekir.';

  @override
  String get registerSubmit => 'Hesap oluştur';

  @override
  String get registerToLogin => 'Zaten hesabınız var mı? Giriş yapın';

  @override
  String get validationRequired => 'Bu alan boş bırakılamaz.';

  @override
  String get validationEmail => 'Geçerli bir e-posta adresi girin.';

  @override
  String get validationPasswordShort => 'Şifre en az 8 karakter olmalı.';

  @override
  String get validationTelephone =>
      'Telefon, başında 0 olmadan 10 hane olmalı.';

  @override
  String get navMenu => 'Menü';

  @override
  String get navOrders => 'Siparişlerim';

  @override
  String get navAccount => 'Hesabım';

  @override
  String get menuTitle => 'Menü';

  @override
  String get menuSearchHint => 'Ürün ara';

  @override
  String get menuSearchEmpty => 'Aramanıza uygun ürün yok.';

  @override
  String get menuEmpty => 'Menü şu anda boş.';

  @override
  String get menuItemUnavailable => 'Satışta değil';

  @override
  String get menuOrderingClosed =>
      'Şu anda sipariş alınmıyor. Menüyü inceleyebilirsiniz.';

  @override
  String menuCutoff(String time) {
    return 'Son sipariş saati $time';
  }

  @override
  String menuMinOrderTotal(String amount) {
    return 'En az sipariş tutarı $amount';
  }

  @override
  String menuCartButton(String amount) {
    return 'Sepet · $amount';
  }

  @override
  String get productAddToCart => 'Sepete ekle';

  @override
  String get productQuantity => 'Adet';

  @override
  String get productNote => 'Ürün notu (isteğe bağlı)';

  @override
  String get productNoteHint => 'Örn. soğansız';

  @override
  String get productOptionPickOne => 'Bir seçenek seçin';

  @override
  String get productOptionPickMany => 'İstediğiniz kadar seçebilirsiniz';

  @override
  String get productMissingRequiredOption => 'Zorunlu seçenekleri işaretleyin.';

  @override
  String productAllergens(String list) {
    return 'Alerjenler: $list';
  }

  @override
  String productAdded(String name) {
    return '$name sepete eklendi.';
  }

  @override
  String get productUnavailableNotice => 'Bu ürün şu anda satışta değil.';

  @override
  String get cartTitle => 'Sepet';

  @override
  String get cartEmpty => 'Sepetiniz boş.';

  @override
  String get cartGoToMenu => 'Menüye git';

  @override
  String get cartSubtotal => 'Ara toplam';

  @override
  String get cartClear => 'Sepeti boşalt';

  @override
  String get cartRemove => 'Kaldır';

  @override
  String get cartCheckout => 'Siparişi tamamla';

  @override
  String get cartServerCalculatesTotal =>
      'Nihai tutar sipariş oluşturulurken sunucu tarafından hesaplanır.';

  @override
  String cartMinOrderNotMet(String amount, String missing) {
    return 'En az sipariş tutarı $amount. $missing daha eklemeniz gerekiyor.';
  }

  @override
  String cartItemCount(int count) {
    return '$count kalem';
  }

  @override
  String get checkoutTitle => 'Ödeme';

  @override
  String get checkoutDeliveryType => 'Teslimat tipi';

  @override
  String get deliveryTypeDelivery => 'Adrese gönderim';

  @override
  String get deliveryTypePickup => 'Gel-al';

  @override
  String get checkoutAddressSection => 'Teslimat adresi';

  @override
  String get addressLine1 => 'Adres';

  @override
  String get addressDistrict => 'İlçe';

  @override
  String get addressCity => 'İl';

  @override
  String get addressNote => 'Adres tarifi (isteğe bağlı)';

  @override
  String get checkoutRequestedAt => 'İstenen teslim zamanı';

  @override
  String get checkoutRequestedAtAsap => 'En kısa sürede';

  @override
  String get checkoutPickDateTime => 'Zaman seç';

  @override
  String get checkoutClearRequestedAt => 'Temizle';

  @override
  String get checkoutPaymentMethod => 'Ödeme yöntemi';

  @override
  String get checkoutPaymentMethodsEmpty =>
      'Bu vitrin için açık ödeme yöntemi bildirilmedi.';

  @override
  String get checkoutCustomerNote => 'Sipariş notu (isteğe bağlı)';

  @override
  String get checkoutSubmit => 'Siparişi onayla';

  @override
  String get checkoutOrderingClosed => 'Şu anda sipariş alınmıyor.';

  @override
  String checkoutRedirectNeeded(String url) {
    return 'Ödemeyi tamamlamak için yönlendirilmeniz gerekiyor: $url';
  }

  @override
  String get paymentMethodOnline => 'Online ödeme';

  @override
  String get paymentMethodCash => 'Kapıda ödeme';

  @override
  String get paymentMethodAccount => 'Cari hesap';

  @override
  String get paymentMethodUnknown => 'Bilinmeyen yöntem';

  @override
  String get paymentStatusPending => 'Bekliyor';

  @override
  String get paymentStatusPaid => 'Ödendi';

  @override
  String get paymentStatusUnknown => 'Belirsiz';

  @override
  String get orderStatusYeni => 'Yeni';

  @override
  String get orderStatusOnaylandi => 'Onaylandı';

  @override
  String get orderStatusHazirlaniyor => 'Hazırlanıyor';

  @override
  String get orderStatusHazir => 'Hazır';

  @override
  String get orderStatusYolda => 'Yolda';

  @override
  String get orderStatusTeslimEdildi => 'Teslim edildi';

  @override
  String get orderStatusIptal => 'İptal';

  @override
  String get ordersTitle => 'Siparişlerim';

  @override
  String get ordersEmpty => 'Henüz siparişiniz yok.';

  @override
  String orderNumberLabel(String number) {
    return 'Sipariş $number';
  }

  @override
  String orderPlacedBody(String number) {
    return 'Sipariş numaranız $number.';
  }

  @override
  String get trackingTitle => 'Sipariş takibi';

  @override
  String get trackingLive => 'Canlı takip ediliyor';

  @override
  String get trackingStale => 'Güncellenemiyor — bağlantı yok.';

  @override
  String get trackingCancelAction => 'Siparişi iptal et';

  @override
  String get trackingCancelConfirmTitle => 'Sipariş iptal edilsin mi?';

  @override
  String get trackingCancelConfirmBody => 'Bu işlem geri alınamaz.';

  @override
  String get trackingCancelConfirmAction => 'Siparişi iptal et';

  @override
  String get trackingCancelled => 'Siparişiniz iptal edildi.';

  @override
  String get trackingItems => 'Ürünler';

  @override
  String get trackingSubtotal => 'Ara toplam';

  @override
  String get trackingDeliveryFee => 'Teslimat ücreti';

  @override
  String get trackingTotal => 'Toplam';

  @override
  String get trackingPayment => 'Ödeme';

  @override
  String get trackingAddress => 'Teslimat adresi';

  @override
  String get trackingRequestedAt => 'İstenen teslim zamanı';

  @override
  String get trackingCreatedAt => 'Oluşturulma';

  @override
  String get trackingCustomerNote => 'Sipariş notu';

  @override
  String get trackingDeliveryType => 'Teslimat tipi';

  @override
  String get accountTitle => 'Hesabım';

  @override
  String get accountGuest => 'Giriş yapmadınız.';

  @override
  String get accountLogin => 'Giriş yap';

  @override
  String get accountLogout => 'Çıkış yap';

  @override
  String get accountEmail => 'E-posta';

  @override
  String get accountTelephone => 'Telefon';

  @override
  String get accountName => 'Ad soyad';
}
