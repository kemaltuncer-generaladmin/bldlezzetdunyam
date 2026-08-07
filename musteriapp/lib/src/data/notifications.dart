/// Bildirimler — günlük menü hatırlatması ve sipariş durumu uyarısı.
///
/// ## İki ayrı iş
///
/// - **Günlük hatırlatma** sunucudan bağımsızdır. Her sabah aynı saatte
///   "bugün ne var?" demek için sunucuya soru sormaya gerek yok; yerel
///   zamanlama çevrimdışı da çalışır ve bataryayı yoklamaya harcamaz.
/// - **Sipariş durumu** uygulama açıkken yoklamadan gelir
///   (`orderTrackingProvider`): mutfak KDS'de "hazır" dediği anda müşterinin
///   ekranına bildirim düşer. Uygulama KAPALIYKEN bunu yapmanın tek yolu
///   push'tur ve push Firebase projesi ister — repoda yok, uydurulmaz
///   (`AGENTS.md` §2.2). Token kaydı hazır (`POST /me/push-token`), yalnızca
///   kimlik bilgileri girildiğinde devreye girer.
///
/// ## Neden IANA zaman dilimi veritabanı yüklenmiyor?
///
/// `packages/core/lib/src/turkish_time.dart` bunu bilinçli olarak reddediyor:
/// Türkiye 2016'dan beri sabit UTC+3, yaz saati yok, ~1 MB veri taşımaya
/// değmez. Aynı karar burada da geçerli — `timezone` paketinin API'sini
/// kullanıyoruz ama `initializeTimeZones()` çağırmıyoruz; tek bir sabit
/// ofsetli [tz.Location] elle kuruluyor.
library;

import 'package:bld_core/bld_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Bildirim kimlikleri. Sabit: aynı kimlikle yeniden zamanlamak öncekini
/// değiştirir, üst üste yığmaz.
abstract final class _NotificationId {
  static const int dailyMenu = 1001;

  /// Sipariş bildirimleri sipariş numarasına göre ayrışır ki iki sipariş
  /// birbirinin bildirimini ezmesin. Günlük hatırlatmayla çakışmasın diye
  /// yüksek bir tabandan başlar.
  static int orderStatus(int orderId) => 2000 + orderId;
}

/// Bildirime dokunulduğunda taşınan yük. Yönlendirmeyi bu dosya yapmaz —
/// router'a bağımlı olmamak için çağırana bırakılır.
abstract final class NotificationPayload {
  static const String menu = 'menu';
  static String order(int orderId) => 'order:$orderId';

  /// `order:12` → `12`. Başka her şeyde `null`.
  static int? orderIdOf(String payload) =>
      payload.startsWith('order:') ? int.tryParse(payload.substring(6)) : null;
}

/// Uygulamanın bildirim yüzeyi. Ekranlar doğrudan eklentiyi çağırmaz.
abstract interface class Notifications {
  /// Bu platformda bildirim gösterilebiliyor mu? Ayarlar ekranı `false` ise
  /// anahtarı kapalı ve açıklamalı gösterir — çalışmayan bir düğme göstermek
  /// daha kötü olurdu.
  bool get isSupported;

  /// Kullanıcıdan izin ister. Reddedilirse `false` döner ve çağıran ayarı
  /// açmaz.
  Future<bool> requestPermission();

  /// Her gün aynı saatte tekrarlayan menü hatırlatması kurar.
  Future<void> scheduleDailyMenuReminder({
    required int hour,
    required int minute,
  });

  Future<void> cancelDailyMenuReminder();

  /// Sipariş durumu değiştiğinde anında gösterilir.
  Future<void> showOrderStatus({
    required int orderId,
    required String title,
    required String body,
  });
}

/// Bildirim desteği bulunmayan platformlar için sessiz uygulama.
///
/// Testler ve eklentinin kurulamadığı durumlar bunu kullanır.
class UnsupportedNotifications implements Notifications {
  const UnsupportedNotifications();

  @override
  bool get isSupported => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleDailyMenuReminder({
    required int hour,
    required int minute,
  }) async {}

  @override
  Future<void> cancelDailyMenuReminder() async {}

  @override
  Future<void> showOrderStatus({
    required int orderId,
    required String title,
    required String body,
  }) async {}
}

/// `flutter_local_notifications` üzerinden Android, iOS ve web.
class LocalNotifications implements Notifications {
  LocalNotifications(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  /// Sabit UTC+3 — gerekçe dosya başlığında. Tek geçiş temsil edilebilir en
  /// erken ana kurulur; yani pratikte hiç geçiş yok.
  static final tz.Location _istanbul = tz.Location(
    'Europe/Istanbul',
    <int>[tz.minTime],
    <int>[0],
    <tz.TimeZone>[
      tz.TimeZone(istanbulOffset, isDst: false, abbreviation: '+03'),
    ],
  );

  static const NotificationDetails _dailyDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'bld_gunluk_menu',
      'Günlük menü hatırlatması',
      channelDescription: 'Her gün o günün menüsünü hatırlatır.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
    web: WebNotificationDetails(),
  );

  static const NotificationDetails _orderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'bld_siparis_durumu',
      'Sipariş durumu',
      channelDescription: 'Siparişiniz hazırlandığında ve yola çıktığında.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
    web: WebNotificationDetails(),
  );

  /// Eklentiyi kurar. Kurulum başarısız olursa [UnsupportedNotifications]
  /// döner: bildirim kuramamak uygulamanın açılmasını engellememeli.
  static Future<Notifications> create({
    required void Function(String payload) onTapPayload,
  }) async {
    final plugin = FlutterLocalNotificationsPlugin();
    try {
      await plugin.initialize(
        settings: const InitializationSettings(
          // `@mipmap/ic_launcher`: uygulamanın kendi simgesi. Olmayan bir
          // kaynağa işaret etmek Android'de bildirimin hiç görünmemesine yol
          // açar.
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            // İzin açılışta değil, kullanıcı ayarı açtığında istenir.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          web: WebInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) onTapPayload(payload);
        },
      );
    } on Exception catch (error) {
      debugPrint('[bildirim] kurulamadı, bildirimler kapalı: $error');
      return const UnsupportedNotifications();
    }
    return LocalNotifications(plugin);
  }

  @override
  bool get isSupported => true;

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      final web = _plugin
          .resolvePlatformSpecificImplementation<
            WebFlutterLocalNotificationsPlugin
          >();
      return await web?.requestNotificationsPermission() ?? false;
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  @override
  Future<void> scheduleDailyMenuReminder({
    required int hour,
    required int minute,
  }) => _plugin.zonedSchedule(
    id: _NotificationId.dailyMenu,
    title: 'Bugün mutfakta ne var?',
    body: 'Günün menüsü hazır. Siparişinizi öğlene yetiştirin.',
    scheduledDate: _nextOccurrence(hour, minute),
    notificationDetails: _dailyDetails,
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    // Saat bileşeni eşleşince her gün tekrarlar; her açılışta yeniden kurmak
    // gerekmez.
    matchDateTimeComponents: DateTimeComponents.time,
    payload: NotificationPayload.menu,
  );

  @override
  Future<void> cancelDailyMenuReminder() =>
      _plugin.cancel(id: _NotificationId.dailyMenu);

  @override
  Future<void> showOrderStatus({
    required int orderId,
    required String title,
    required String body,
  }) => _plugin.show(
    id: _NotificationId.orderStatus(orderId),
    title: title,
    body: body,
    notificationDetails: _orderDetails,
    payload: NotificationPayload.order(orderId),
  );

  /// Verilen duvar saatinin bugünkü ya da yarınki karşılığı.
  ///
  /// Saat geçmişse yarına atılır: geçmiş bir ana kurulan zamanlama bildirimi
  /// hemen gösterirdi ve kullanıcı ayarı açar açmaz ekranına hatırlatma
  /// düşerdi.
  static tz.TZDateTime _nextOccurrence(int hour, int minute) {
    final now = tz.TZDateTime.now(_istanbul);
    var next = tz.TZDateTime(
      _istanbul,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next;
  }
}
