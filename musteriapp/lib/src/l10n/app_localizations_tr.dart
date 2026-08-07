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
  String get loginRemember => 'Beni hatırla';

  @override
  String get loginRememberHelp =>
      'Kapalıysa uygulamayı kapattığınızda oturumunuz sonlanır.';

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
  String get etaDeliveryTitle => 'Tahmini teslim';

  @override
  String get etaPickupTitle => 'Tahmini hazır olma';

  @override
  String etaValue(String minutes, String window) {
    return '$minutes dakika · $window arası';
  }

  @override
  String etaValueApprox(String minutes, String window) {
    return 'yaklaşık $minutes dakika · $window arası';
  }

  @override
  String etaMinutesRange(int min, int max) {
    return '$min-$max';
  }

  @override
  String get etaMeasuredNote =>
      'Bu süre son siparişlerin gerçekleşen sürelerinden hesaplandı.';

  @override
  String get etaConfiguredNote =>
      'Bu süre henüz gerçekleşen siparişlerle ölçülmedi; mutfağın bildirdiği ortalamadır ve değişebilir.';

  @override
  String get etaBusyNote =>
      'Mutfağımız şu anda yoğun. Süre bu yoğunluğa göre uzatıldı.';

  @override
  String get etaOrderPlacedTitle => 'Tahmini teslim saati';

  @override
  String get etaOrderPickupTitle => 'Tahmini hazır olma saati';

  @override
  String etaOrderWindow(String window) {
    return '$window arası';
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
  String get addressDistrictRequired => 'Teslimat yapılan bir ilçe seçin.';

  @override
  String get addressCity => 'İl';

  @override
  String get addressServiceAreaHelp =>
      'Şu an yalnızca Konya Selçuklu ve Karatay\'a teslimat yapıyoruz.';

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

  @override
  String get addressBookTitle => 'Adreslerim';

  @override
  String get addressBookEmpty =>
      'Henüz kayıtlı adresiniz yok. Eklerseniz ödeme ekranında tek dokunuşla seçebilirsiniz.';

  @override
  String get addressBookAdd => 'Adres ekle';

  @override
  String get addressBookEdit => 'Düzenle';

  @override
  String get addressBookDelete => 'Sil';

  @override
  String get addressBookDeleteConfirm =>
      'Bu adres defterinizden silinsin mi? Geçmiş siparişleriniz etkilenmez.';

  @override
  String get addressBookDefault => 'Varsayılan';

  @override
  String get addressBookMakeDefault => 'Varsayılan yap';

  @override
  String get addressLabel => 'Adres adı (Ev, Ofis…)';

  @override
  String get addressSave => 'Kaydet';

  @override
  String get addressNewTitle => 'Yeni adres';

  @override
  String get addressEditTitle => 'Adresi düzenle';

  @override
  String get checkoutSavedAddress => 'Kayıtlı adreslerim';

  @override
  String get checkoutNewAddress => 'Yeni adres gir';

  @override
  String get checkoutOpenPayment => 'Ödeme sayfasını aç';

  @override
  String get checkoutPaymentPageFailed =>
      'Ödeme sayfası açılamadı. Siparişiniz oluştu; siparişlerim ekranından tekrar deneyebilirsiniz.';

  @override
  String get notificationsSection => 'Bildirimler';

  @override
  String get notificationsDailyReminder => 'Günlük menü hatırlatması';

  @override
  String notificationsDailyReminderAt(String time) {
    return 'Her gün $time';
  }

  @override
  String get notificationsChangeTime => 'Saati değiştir';

  @override
  String get notificationsUnsupported =>
      'Bu platformda bildirim gösterilemiyor.';

  @override
  String get notificationsDenied =>
      'Bildirim izni verilmedi. Cihaz ayarlarından açabilirsiniz.';

  @override
  String get notificationOrderReadyTitle => 'Siparişiniz hazır';

  @override
  String get notificationOrderUpdatedTitle => 'Sipariş durumu değişti';

  @override
  String notificationOrderBody(String orderNumber, String status) {
    return '$orderNumber numaralı siparişiniz: $status';
  }

  @override
  String get mapPickerTitle => 'Teslimat konumu';

  @override
  String get mapPickerHint =>
      'Haritayı kaydırarak iğneyi teslimat noktasına getirin.';

  @override
  String get mapPickerServiceArea =>
      'Şu an yalnızca Konya\'nın Selçuklu ve Karatay ilçelerine teslimat yapıyoruz; harita bu alanla sınırlıdır.';

  @override
  String get mapPickerConfirm => 'Bu konumu kullan';

  @override
  String get mapPickerClear => 'İğneyi kaldır';

  @override
  String get mapPickerSelect => 'Haritadan seç';

  @override
  String get mapPickerChange => 'Konumu değiştir';

  @override
  String get mapPickerSelected => 'Konum seçildi';

  @override
  String get mapPickerNotSelected => 'Konum seçilmedi';

  @override
  String get mapPickerOptional =>
      'İsteğe bağlı — kuryenin doğru kapıyı bulmasına yardım eder.';

  @override
  String get mapPickerAttribution => '© OpenStreetMap katkıcıları';

  @override
  String get navHome => 'Ana Sayfa';

  @override
  String get homeGreeting => 'Bugün ne yesek?';

  @override
  String get homeCategories => 'Kategoriler';

  @override
  String get homeFeatured => 'Bugün öne çıkanlar';

  @override
  String get homeSeeAll => 'Tümünü gör';

  @override
  String get homeLastOrder => 'Son siparişiniz';

  @override
  String get homeReorder => 'Tekrar sipariş ver';

  @override
  String homeReorderDone(int count) {
    return '$count ürün sepete eklendi.';
  }

  @override
  String homeReorderPartial(int count, int missing) {
    return '$count ürün sepete eklendi. $missing ürün artık menüde yok.';
  }

  @override
  String get homeReorderEmpty =>
      'Bu siparişteki ürünlerin hiçbiri şu an menüde yok.';

  @override
  String get registerCompanySection => 'Firma bilgileri';

  @override
  String get registerAccountSection => 'Giriş bilgileri';

  @override
  String get registerCompanyName => 'Ticari unvan';

  @override
  String get registerContactPerson => 'Yetkili kişi';

  @override
  String get registerTaxOffice => 'Vergi dairesi (opsiyonel)';

  @override
  String get registerTaxNumber => 'Vergi / TC no (opsiyonel)';

  @override
  String get registerCompanyPhone => 'Kurum telefonu (opsiyonel)';

  @override
  String get registerCorporateNote =>
      'Yalnızca kurumsal hesaplar sipariş verebilir.';

  @override
  String get registerCompanyRequired => 'Ticari unvan zorunludur.';

  @override
  String get registerContactRequired => 'Yetkili kişi zorunludur.';

  @override
  String get orderingDisabledTitle => 'Sipariş kapalı';

  @override
  String get orderingDisabledBody =>
      'Hesabınız sipariş vermeye kapalı. Kurumsal onay için bizimle iletişime geçin.';

  @override
  String get navSubscriptions => 'Abonelik';

  @override
  String get accountSubscriptions => 'Aboneliklerim';

  @override
  String get accountStatementShortcut => 'Cari hesabım';

  @override
  String get accountCompanyLabel => 'Firma';

  @override
  String get subscriptionsTitle => 'Aboneliklerim';

  @override
  String get subscriptionsEmpty =>
      'Henüz aboneliğiniz yok. Kurumsal öğle yemeği için talep oluşturun.';

  @override
  String get subscriptionsNew => 'Yeni abonelik talebi';

  @override
  String get subscriptionStatusPending => 'Onay bekliyor';

  @override
  String get subscriptionStatusActive => 'Aktif';

  @override
  String get subscriptionStatusPaused => 'Duraklatıldı';

  @override
  String get subscriptionStatusCancelled => 'İptal';

  @override
  String subscriptionQuantityLabel(int count) {
    return 'Günlük $count porsiyon';
  }

  @override
  String get subscriptionAgreedPrice => 'Porsiyon fiyatı';

  @override
  String get subscriptionNoPrice => 'Fiyat onay bekliyor';

  @override
  String get subscriptionDetailTitle => 'Abonelik';

  @override
  String get subscriptionPause => 'Duraklat';

  @override
  String get subscriptionResume => 'Devam ettir';

  @override
  String get subscriptionCancel => 'İptal et';

  @override
  String get subscriptionCancelConfirmTitle => 'Aboneliği iptal et';

  @override
  String get subscriptionCancelConfirmBody =>
      'Bu abonelik iptal edilecek. Emin misiniz?';

  @override
  String get subscriptionCancelled => 'Abonelik iptal edildi.';

  @override
  String get subscriptionPaused => 'Abonelik duraklatıldı.';

  @override
  String get subscriptionResumed => 'Abonelik devam ediyor.';

  @override
  String get subscriptionPeriod => 'Dönem';

  @override
  String get subscriptionDays => 'Günler';

  @override
  String get subscriptionDelivery => 'Teslimat';

  @override
  String get subscriptionProducts => 'Ürünler';

  @override
  String get subscriptionDeliveryTime => 'Teslim saati';

  @override
  String get subscriptionOpenEnded => 'süresiz';

  @override
  String get subscriptionNoProducts => 'Ürün ekibimizce eklenecek.';

  @override
  String get subscriptionCreateTitle => 'Abonelik talebi';

  @override
  String get subscriptionCreateIntro =>
      'Günleri ve günlük adedi seçin; ekibimiz fiyatlandırıp onaylayacak.';

  @override
  String get subscriptionCreateDays => 'Teslimat günleri';

  @override
  String get subscriptionCreateQuantity => 'Günlük porsiyon';

  @override
  String get subscriptionCreateStart => 'Başlangıç tarihi';

  @override
  String get subscriptionCreateSubmit => 'Talep gönder';

  @override
  String get subscriptionCreateNote => 'Not (opsiyonel)';

  @override
  String get subscriptionCreatePickDay => 'En az bir gün seçin.';

  @override
  String get subscriptionRequestSent =>
      'Talebiniz alındı; fiyatlandırma sonrası aktifleşecek.';

  @override
  String get dayMon => 'Pzt';

  @override
  String get dayTue => 'Sal';

  @override
  String get dayWed => 'Çar';

  @override
  String get dayThu => 'Per';

  @override
  String get dayFri => 'Cum';

  @override
  String get daySat => 'Cmt';

  @override
  String get daySun => 'Paz';

  @override
  String get accountStatementTitle => 'Cari hesabım';

  @override
  String get accountBalanceLabel => 'Güncel bakiye';

  @override
  String get accountBalanceDebtNote => 'Ödenmemiş bakiye';

  @override
  String get accountBalanceCreditNote => 'Lehinize bakiye';

  @override
  String get accountBalanceZeroNote => 'Bakiye sıfır';

  @override
  String get accountStatementEmpty => 'Bu aralıkta hareket yok.';

  @override
  String get accountStatementEntries => 'Hareketler';

  @override
  String get accountDebit => 'Borç';

  @override
  String get accountCredit => 'Alacak';

  @override
  String get accountSourceOrder => 'Sipariş';

  @override
  String get accountSourceSubscription => 'Abonelik';

  @override
  String get accountSourcePayment => 'Tahsilat';

  @override
  String get accountSourceManual => 'Elle giriş';

  @override
  String get accountSourceAdjustment => 'Düzeltme';
}
