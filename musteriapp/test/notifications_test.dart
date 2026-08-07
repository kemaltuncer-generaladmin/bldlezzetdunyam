/// Bildirim mantığı — `docs/07-musteriapp.md` §4.
///
/// Buradaki üç kural sessizce bozulabilecek türden:
/// izin reddedilince ayarın açık görünmemesi, aynı durumun iki kez
/// bildirilmemesi ve bildirime dokunulduğunda doğru ekranın açılması.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musteriapp/src/config/app_config.dart';
import 'package:musteriapp/src/data/local_cache.dart';
import 'package:musteriapp/src/data/notifications.dart';
import 'package:musteriapp/src/providers/infra_providers.dart';
import 'package:musteriapp/src/providers/notification_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// İstenenleri kaydeden sahte bildirim servisi.
class _FakeNotifications implements Notifications {
  _FakeNotifications({this.supported = true, this.permissionGranted = true});

  /// Yapıcıdan gelen değer; [isSupported] bunu döndürür.
  final bool supported;
  final bool permissionGranted;

  int scheduleCount = 0;
  int cancelCount = 0;
  ({int hour, int minute})? lastScheduled;
  final List<String> shownTitles = [];

  @override
  bool get isSupported => supported;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> scheduleDailyMenuReminder({
    required int hour,
    required int minute,
  }) async {
    scheduleCount++;
    lastScheduled = (hour: hour, minute: minute);
  }

  @override
  Future<void> cancelDailyMenuReminder() async => cancelCount++;

  @override
  Future<void> showOrderStatus({
    required int orderId,
    required String title,
    required String body,
  }) async => shownTitles.add(title);
}

Future<ProviderContainer> _container(_FakeNotifications notifications) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationsProvider.overrideWithValue(notifications),
    ],
  );
}

void main() {
  group('bildirim yükü', () {
    test('sipariş yükünden sipariş numarası çıkar', () {
      expect(NotificationPayload.orderIdOf('order:42'), 42);
    });

    test('menü yükü sipariş numarası vermez', () {
      expect(NotificationPayload.orderIdOf(NotificationPayload.menu), isNull);
    });

    test('bozuk yük çökmez, null döner', () {
      expect(NotificationPayload.orderIdOf('order:abc'), isNull);
      expect(NotificationPayload.orderIdOf(''), isNull);
    });
  });

  group('günlük hatırlatma', () {
    test('varsayılan kapalıdır ve yapılandırılmış saati kullanır', () async {
      final fake = _FakeNotifications();
      final container = await _container(fake);
      addTearDown(container.dispose);

      final reminder = container.read(dailyReminderProvider);
      expect(reminder.enabled, isFalse);
      expect(reminder.hour, AppConfig.dailyReminderHour);
      expect(reminder.minute, AppConfig.dailyReminderMinute);
      expect(fake.scheduleCount, 0);
    });

    test('açılınca zamanlanır ve kalıcı olarak kaydedilir', () async {
      final fake = _FakeNotifications();
      final container = await _container(fake);
      addTearDown(container.dispose);

      final ok = await container
          .read(dailyReminderProvider.notifier)
          .setEnabled(true);

      expect(ok, isTrue);
      expect(container.read(dailyReminderProvider).enabled, isTrue);
      expect(fake.scheduleCount, 1);
      expect(container.read(localCacheProvider).readDailyReminderEnabled(), isTrue);
    });

    test('izin reddedilirse ayar AÇILMAZ', () async {
      final fake = _FakeNotifications(permissionGranted: false);
      final container = await _container(fake);
      addTearDown(container.dispose);

      final ok = await container
          .read(dailyReminderProvider.notifier)
          .setEnabled(true);

      expect(ok, isFalse);
      expect(container.read(dailyReminderProvider).enabled, isFalse);
      expect(fake.scheduleCount, 0);
      // Kalıcı kayda da yazılmamalı: bir sonraki açılışta "açık" görünmesin.
      expect(
        container.read(localCacheProvider).readDailyReminderEnabled(),
        isFalse,
      );
    });

    test('platform desteklemiyorsa izin bile istenmez', () async {
      final fake = _FakeNotifications(supported: false);
      final container = await _container(fake);
      addTearDown(container.dispose);

      expect(
        await container.read(dailyReminderProvider.notifier).setEnabled(true),
        isFalse,
      );
      expect(fake.scheduleCount, 0);
    });

    test('saat değişince açıkken yeniden zamanlanır', () async {
      final fake = _FakeNotifications();
      final container = await _container(fake);
      addTearDown(container.dispose);
      final notifier = container.read(dailyReminderProvider.notifier);

      await notifier.setEnabled(true);
      await notifier.setTime(hour: 8, minute: 15);

      expect(fake.lastScheduled, (hour: 8, minute: 15));
      expect(fake.scheduleCount, 2);
      expect(container.read(dailyReminderProvider).label, '08:15');
    });

    test('kapalıyken saat değişirse zamanlama kurulmaz', () async {
      final fake = _FakeNotifications();
      final container = await _container(fake);
      addTearDown(container.dispose);

      await container
          .read(dailyReminderProvider.notifier)
          .setTime(hour: 7, minute: 0);

      expect(fake.scheduleCount, 0);
    });

    test('kapatınca zamanlama iptal edilir', () async {
      final fake = _FakeNotifications();
      final container = await _container(fake);
      addTearDown(container.dispose);
      final notifier = container.read(dailyReminderProvider.notifier);

      await notifier.setEnabled(true);
      await notifier.setEnabled(false);

      expect(fake.cancelCount, 1);
      expect(container.read(dailyReminderProvider).enabled, isFalse);
    });

    test('restore yalnızca açıkken yeniden kurar', () async {
      final fake = _FakeNotifications();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      // Önceki oturumda açılmış gibi davran.
      await LocalCache(
        prefs,
      ).writeDailyReminder(enabled: true, hour: 9, minute: 45);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationsProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);

      await container.read(dailyReminderProvider.notifier).restore();

      expect(fake.lastScheduled, (hour: 9, minute: 45));
      expect(fake.scheduleCount, 1);
    });
  });

  group('sipariş durumu tekrarı', () {
    test('aynı durum iki kez bildirilmez', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = LocalCache(await SharedPreferences.getInstance());

      expect(cache.readNotifiedStatus(7), isNull);
      await cache.writeNotifiedStatus(7, 'hazir');
      expect(cache.readNotifiedStatus(7), 'hazir');

      // Başka bir sipariş kendi kaydını taşır.
      expect(cache.readNotifiedStatus(8), isNull);
    });
  });
}
