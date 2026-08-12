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
  String get deviceInfoServer => 'Sunucu';

  @override
  String get deviceInfoVersion => 'Sürüm';

  @override
  String get close => 'Kapat';

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

  @override
  String get alarmSilence => 'SESİ SUSTUR';

  @override
  String get alarmSilenceTooltip =>
      'Yalnızca şu anki alarmı susturur. Bir sonraki yeni sipariş yeniden çalar.';

  @override
  String alarmSounding(int count) {
    return '$count sipariş onay bekliyor';
  }

  @override
  String alarmSilenced(int count) {
    return 'Alarm susturuldu · $count sipariş hâlâ onay bekliyor';
  }

  @override
  String get alarmMutedTitle => 'ALARM ÇALMIYOR';

  @override
  String get alarmMutedBody =>
      'Yeni sipariş sessiz düşer. Ekranı gözle takip edin ya da ayarlardan sesi açın.';

  @override
  String get alarmMutedBadge => 'SES KAPALI';

  @override
  String get boardLoading => 'Siparişler yükleniyor';

  @override
  String get boardLoadingHint =>
      'Sunucuya ilk bağlantı kuruluyor. Bu ekran bir kaç saniye içinde dolacak.';

  @override
  String itemsDone(int done, int total) {
    return '$done/$total hazır';
  }

  @override
  String get itemToggleTooltip => 'Kalemi hazır / beklemede yap';

  @override
  String get cardNoteBadge => 'NOTLU';

  @override
  String prepTargetLabel(int minutes) {
    return 'Hedef $minutes dk';
  }

  @override
  String prepActualLabel(int minutes) {
    return 'Hazırlandı: $minutes dk';
  }

  @override
  String get lastUpdateNever => 'Hiç güncellenmedi';

  @override
  String get lastUpdateNow => 'Şimdi güncellendi';

  @override
  String lastUpdateAgo(int minutes) {
    return '$minutes dk önce güncellendi';
  }

  @override
  String get refreshNow => 'Yenile';

  @override
  String refreshFailed(String message) {
    return 'Yenilenemedi: $message';
  }

  @override
  String get statusChangeConflict =>
      'Bu sipariş başka bir yerden güncellenmiş. Liste tazelendi.';

  @override
  String get shortcutsTitle => 'Klavye kısayolları';

  @override
  String get shortcutsHint => 'F1';

  @override
  String get shortcutSelect => 'Kart seç';

  @override
  String get shortcutAdvance => 'Seçili kartı bir adım ilerlet';

  @override
  String get shortcutSearch => 'Aramaya geç';

  @override
  String get shortcutClear => 'Aramayı temizle / seçimi bırak';

  @override
  String get shortcutRefresh => 'Listeyi yenile';

  @override
  String get shortcutSilence => 'Alarmı sustur';

  @override
  String get shortcutSummary => 'Vardiya özeti';

  @override
  String get shortcutHelp => 'Bu pencere';

  @override
  String get shiftSummaryTitle => 'Vardiya özeti';

  @override
  String get shiftSummaryHint =>
      'Sayaçlar uygulama açıldığından beri sayar; yeniden başlatma sıfırlar.';

  @override
  String get shiftSeen => 'Görülen sipariş';

  @override
  String get shiftReady => 'Hazırlanan sipariş';

  @override
  String get shiftAverage => 'Ortalama hazırlanma';

  @override
  String get shiftSlowest => 'En uzun süren';

  @override
  String get shiftNone => 'Henüz veri yok';

  @override
  String get queueBacklogTitle => 'FİŞLER BASILAMIYOR';

  @override
  String queueBacklogBody(int count) {
    return '$count fiş yazıcıya gönderilemedi. Kâğıdı, kapağı ve kabloyu denetleyin; işler kuyrukta duruyor.';
  }

  @override
  String get settingsSoundStop => 'Sesi durdur';

  @override
  String get settingsSoundUnavailable =>
      'Ses çalınamıyor: kasada pw-play ya da aplay bulunamadı.';

  @override
  String get healthTitle => 'Sistem durumu';

  @override
  String get healthOpen => 'Sistem durumu (F6)';

  @override
  String get healthPrinter => 'Yazıcı';

  @override
  String get healthServer => 'Sunucu';

  @override
  String get healthOrdersToday => 'Bugünkü sipariş';

  @override
  String get healthSound => 'Alarm sesi';

  @override
  String healthPrinterQueue(int pending) {
    return 'Kuyrukta $pending fiş';
  }

  @override
  String healthPrinterFailed(int count) {
    return '$count fiş basılamadı';
  }

  @override
  String get healthServerOk => 'Ulaşılıyor';

  @override
  String get healthServerDown => 'Ulaşılamıyor';

  @override
  String get healthServerUnknown => 'Deneniyor';

  @override
  String healthLastContact(String time) {
    return 'Son iletişim: $time';
  }

  @override
  String get healthNoContact => 'Henüz iletişim kurulmadı';

  @override
  String healthActiveOrders(int count) {
    return '$count sipariş ekranda';
  }

  @override
  String get healthTodayUnknown => '—';

  @override
  String get healthTodayHint => 'İptaller hariç, Türkiye günü.';

  @override
  String get healthSoundOk => 'Çalışıyor';

  @override
  String get healthSoundMuted => 'Sessiz';

  @override
  String get healthSoundHint => 'Yeni sipariş, onaylanana kadar sesle uyarır.';

  @override
  String get healthRefresh => 'Şimdi bildir';

  @override
  String get shortcutHealth => 'Sistem durumu';

  @override
  String statusToday(int count) {
    return 'Bugün: $count';
  }

  @override
  String get cardSubscriptionBadge => 'ABONE';

  @override
  String get subscriptionBannerTitle => 'Bugün abonelik var';

  @override
  String subscriptionBannerBreakdown(int today, int tomorrow) {
    return 'Bugün $today · Yarın $tomorrow — ayrıntı için dokunun';
  }

  @override
  String get settingsSectionSound => 'Ses ve hoparlör';

  @override
  String get settingsSoundVolume => 'Uygulama ses seviyesi';

  @override
  String get settingsSoundVolumeHint =>
      'Alarmın kendi seviyesi. Hoparlör kısıksa bu ayar tek başına yetmez.';

  @override
  String get settingsSpeakerVolume => 'Hoparlör (sistem) seviyesi';

  @override
  String get settingsSpeakerVolumeHint =>
      'Kasanın kendi seviyesi. Değiştirmek tüm sistemi etkiler.';

  @override
  String get settingsSpeakerApply => 'Uygula';

  @override
  String get settingsSpeakerUnknown => 'Okunamadı';

  @override
  String get settingsSpeakerFailed => 'Hoparlör seviyesi ayarlanamadı.';

  @override
  String get settingsAudioOutput => 'Ses çıkışı';

  @override
  String get settingsAudioOutputDefault => 'Sistem varsayılanı';

  @override
  String get settingsAudioOutputEmpty => 'Çıkış listesi alınamadı.';

  @override
  String get settingsSoundEvents => 'Hangi olaylarda ses çalsın?';

  @override
  String get settingsSoundEventAlways => 'Kapatılamaz';

  @override
  String get settingsAlarmRepeat => 'Tekrarlar arası bekleme';

  @override
  String get settingsAlarmRepeatHint =>
      '0 = aralıksız. Alarm sipariş onaylanana kadar çalar.';

  @override
  String get settingsAlarmMaxRepeats => 'En fazla tekrar';

  @override
  String get settingsAlarmMaxRepeatsHint =>
      '0 = sınırsız. Sınır koymak, kimse gelmediğinde hoparlörün fişini çektirmeyi önler.';

  @override
  String settingsTimes(int count) {
    return '$count kez';
  }

  @override
  String settingsPercent(int count) {
    return '%$count';
  }

  @override
  String get settingsTts => 'Sesli anons';

  @override
  String get settingsTtsHint =>
      'Yeni siparişi Türkçe okur: \"12 numaralı yeni sipariş, 4 ürün\".';

  @override
  String get settingsTtsRate => 'Anons hızı';

  @override
  String get settingsTtsTest => 'Anonsu dene';

  @override
  String get settingsTtsUnavailable =>
      'Sesli anons aracı yok. Kurmak için: sudo apt install speech-dispatcher';

  @override
  String get settingsSoundDiagnostics => 'Ses tanılama';

  @override
  String get settingsSoundPlayer => 'Oynatıcı';

  @override
  String get settingsSoundPlayerMissing => 'bulunamadı';

  @override
  String get settingsSoundFolder => 'Ses klasörü';

  @override
  String get settingsSoundProblem => 'Sorun';

  @override
  String get settingsSoundOk => 'Ses çalışıyor.';

  @override
  String get settingsSoundNotProbed => 'Henüz denenmedi';

  @override
  String get settingsSectionTouch => 'Dokunmatik';

  @override
  String get settingsTouchMode => 'Dokunmatik kip';

  @override
  String get settingsTouchModeHint =>
      'Düğmeler büyür, açılır menüler alt sayfaya döner, klavye gerektiren alanlarda ekran klavyesi açılır.';

  @override
  String undoPrompt(String status) {
    return '$status durumuna';
  }

  @override
  String get undoAction => 'GERİ AL';

  @override
  String get undoDismiss => 'Kapat';

  @override
  String get undoFailed =>
      'Geri alınamadı — süre doldu ya da sipariş başka yerden değiştirildi.';

  @override
  String get salesTitle => 'Satış kontrolü';

  @override
  String get salesOpenTitle => 'Sipariş alınıyor';

  @override
  String get salesOpenBody => 'Web ve mobil uygulamadan sipariş verilebiliyor.';

  @override
  String get salesClosedTitle => 'SİPARİŞ ALINMIYOR';

  @override
  String get salesClosedIndefinite => 'Elle açılana kadar kapalı.';

  @override
  String salesClosedUntil(String time, String remaining) {
    return 'Otomatik açılış: $time (kalan $remaining)';
  }

  @override
  String get salesStop => 'SATIŞI DURDUR';

  @override
  String get salesResume => 'SATIŞI AÇ';

  @override
  String get salesReasonTitle => 'Neden durduruluyor?';

  @override
  String get salesDurationTitle => 'Ne kadar süreyle?';

  @override
  String get salesPasswordTitle => 'Açılış şifresi';

  @override
  String get salesPasswordHint =>
      'Satışı durdurmak ciroyu keser. Kasanın açılış şifresini girin.';

  @override
  String get salesPasswordWrong => 'Şifre yanlış.';

  @override
  String get salesReasonBusy => 'Yoğunluk';

  @override
  String get salesReasonFault => 'Arıza (yazıcı, ocak, kasa)';

  @override
  String get salesReasonStock => 'Malzeme bitti';

  @override
  String get salesReasonOther => 'Diğer';

  @override
  String get salesStopped => 'Satış durduruldu.';

  @override
  String get salesResumed => 'Satış yeniden açıldı.';

  @override
  String salesFailed(String message) {
    return 'İşlem başarısız: $message';
  }

  @override
  String salesBannerClosed(String detail) {
    return 'SİPARİŞ ALINMIYOR — $detail';
  }

  @override
  String get salesProducts => 'Ürünler';

  @override
  String get salesSoldOut => 'Bugün tükendi';

  @override
  String get salesNotListed => 'Menüde değil (yönetici kapattı)';

  @override
  String get salesProductSearch => 'Ürün ara';

  @override
  String get salesProductsEmpty => 'Ürün bulunamadı.';

  @override
  String salesRemainingMinutes(int count) {
    return '$count dk';
  }

  @override
  String salesRemainingHours(int hours, int minutes) {
    return '$hours sa $minutes dk';
  }

  @override
  String get shortcutSales => 'Satış kontrolü (durdur/aç, tükendi)';

  @override
  String get receiptTypeCourier => 'Kurye fişi';

  @override
  String get reprintCourier => 'Kurye fişini yeniden bas';

  @override
  String orderRevised(int count) {
    return 'REVİZE #$count';
  }

  @override
  String get editTitle => 'Siparişi düzenle';

  @override
  String get editAction => 'DÜZENLE';

  @override
  String get editPhoneHint => 'Kaydetmeden ÖNCE müşteriyi arayın ve anlaşın.';

  @override
  String get editSubscriptionWarning =>
      'Bu bir abonelik siparişi. Değişiklik YALNIZ bugünü etkiler; abonelik tanımı değişmez.';

  @override
  String get editItems => 'Kalemler';

  @override
  String get editAddProduct => 'Ürün ekle';

  @override
  String get editRemove => 'Kaldır';

  @override
  String get editReason => 'Değişiklik sebebi';

  @override
  String get editReasonRequired => 'Sebep seçmeden kaydedilemez.';

  @override
  String get editNote => 'İç not (isteğe bağlı)';

  @override
  String get editNoRequestedAt => 'Saat belirtilmemiş';

  @override
  String get editChangeNote => 'Notu düzenle';

  @override
  String get editNoNote => 'Not yok';

  @override
  String get editSave => 'KAYDET VE FİŞ BAS';

  @override
  String get editNoChange => 'Hiçbir şey değişmedi.';

  @override
  String get editConfirmTitle => 'Değişikliği kaydet';

  @override
  String editRefund(String amount) {
    return 'Müşteriye iade edilecek: $amount';
  }

  @override
  String editExtraCharge(String amount) {
    return 'Tahsil edilecek fark: $amount';
  }

  @override
  String editSaved(int count) {
    return 'Revizyon #$count kaydedildi. Fişler yeniden basılıyor.';
  }

  @override
  String editFailed(String message) {
    return 'Kaydedilemedi: $message';
  }

  @override
  String editSettlementManual(String message) {
    return 'Para farkı elle tamamlanacak: $message';
  }

  @override
  String get editSettlementFailed =>
      'Sipariş güncellendi ama iade başlatılamadı. Yönetici panelinden takip edin.';

  @override
  String get editProductSearch => 'Ürün ara';

  @override
  String get editEmptyItems =>
      'Sipariş boş bırakılamaz. Tümünü kaldırmak için siparişi iptal edin.';

  @override
  String get editRequestedAt => 'Teslimat saati';

  @override
  String get editChangeTime => 'Saati değiştir';

  @override
  String get planTitle => 'Abonelik üretim planı';

  @override
  String get planToday => 'Bugün';

  @override
  String get planTomorrow => 'Yarın';

  @override
  String get planWeek => 'Bu hafta';

  @override
  String get planTotals => 'Hazırlanacak toplam';

  @override
  String get planDeliveries => 'Teslimat çizelgesi';

  @override
  String get planWarnings => 'Dikkat';

  @override
  String get planEmpty => 'Bu gün için abonelik siparişi yok.';

  @override
  String get planPrint => 'ÜRETİM PLANI FİŞİ BAS';

  @override
  String get planPrinted => 'Üretim planı yazıcıya gönderildi.';

  @override
  String planPrintFailed(String message) {
    return 'Plan fişi basılamadı: $message';
  }

  @override
  String planPortions(int count) {
    return '$count porsiyon';
  }

  @override
  String get planNoTime => 'Saat yok';

  @override
  String planFailed(String message) {
    return 'Plan alınamadı: $message';
  }

  @override
  String get planOpen => 'Abonelik planı';

  @override
  String bbdPrinted(int count) {
    return 'BBD: $count';
  }

  @override
  String get bbdTooltip =>
      'BBD Store fişleri — bu siparişler panoda görünmez, yalnız fiş basılır.';

  @override
  String bbdPending(int count) {
    return 'BBD kuyruğunda $count fiş bekliyor';
  }

  @override
  String get keyboardTitle => 'Metin girin';

  @override
  String get actionsTitle => 'İşlemler';
}
