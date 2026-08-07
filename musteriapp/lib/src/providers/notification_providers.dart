/// Bildirim sağlayıcıları — günlük hatırlatma ayarı ve push token kaydı.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../data/notifications.dart';
import 'infra_providers.dart';

/// `main()` içinde `overrideWithValue` ile doldurulur.
///
/// Eklenti kurulumu asenkron; bunu bir `FutureProvider` yapsaydık her ekran
/// bildirim servisine erişmek için beklemek zorunda kalırdı. Açılışta bir kez
/// kurulup buraya konuyor.
final notificationsProvider = Provider<Notifications>((ref) {
  throw StateError('notificationsProvider must be overridden in main().');
});

/// Günlük menü hatırlatmasının kullanıcı ayarı.
@immutable
class DailyReminder {
  const DailyReminder({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;

  /// `"10:30"`
  String get label =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  DailyReminder copyWith({bool? enabled, int? hour, int? minute}) =>
      DailyReminder(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  @override
  bool operator ==(Object other) =>
      other is DailyReminder &&
      other.enabled == enabled &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(enabled, hour, minute);
}

/// Ayarı okur, yazar ve zamanlamayı buna göre kurar/kaldırır.
///
/// Ayarın kaydı ile eklentideki zamanlama tek yerden yönetilir; iki tarafı
/// ayrı ayrı güncelleyen kod, kullanıcı "açık" görürken bildirimin hiç
/// kurulmadığı bir duruma düşerdi.
class DailyReminderNotifier extends Notifier<DailyReminder> {
  @override
  DailyReminder build() {
    final cache = ref.watch(localCacheProvider);
    final time = cache.readDailyReminderTime();
    return DailyReminder(
      enabled: cache.readDailyReminderEnabled(),
      hour: time?.hour ?? AppConfig.dailyReminderHour,
      minute: time?.minute ?? AppConfig.dailyReminderMinute,
    );
  }

  /// Açılışta çağrılır: kullanıcı daha önce açtıysa zamanlamayı yeniden kurar.
  ///
  /// Gerekmiyor gibi görünebilir — Android zamanlanmış bildirimi saklıyor. Ama
  /// cihaz yeniden başlatıldığında ya da uygulama güncellendiğinde zamanlama
  /// düşüyor; her açılışta yeniden kurmak en ucuz güvence.
  Future<void> restore() async {
    if (!state.enabled) return;
    await ref
        .read(notificationsProvider)
        .scheduleDailyMenuReminder(hour: state.hour, minute: state.minute);
  }

  /// Açar/kapatır. Açarken izin reddedilirse ayar açılmaz ve `false` döner —
  /// kullanıcı "açık" yazan ama çalışmayan bir anahtar görmemeli.
  Future<bool> setEnabled(bool enabled) async {
    final notifications = ref.read(notificationsProvider);

    if (enabled) {
      if (!notifications.isSupported) return false;
      final granted = await notifications.requestPermission();
      if (!granted) return false;
      await notifications.scheduleDailyMenuReminder(
        hour: state.hour,
        minute: state.minute,
      );
    } else {
      await notifications.cancelDailyMenuReminder();
    }

    state = state.copyWith(enabled: enabled);
    await _persist();
    return true;
  }

  Future<void> setTime({required int hour, required int minute}) async {
    state = state.copyWith(hour: hour, minute: minute);
    await _persist();
    if (state.enabled) {
      await ref
          .read(notificationsProvider)
          .scheduleDailyMenuReminder(hour: hour, minute: minute);
    }
  }

  Future<void> _persist() => ref
      .read(localCacheProvider)
      .writeDailyReminder(
        enabled: state.enabled,
        hour: state.hour,
        minute: state.minute,
      );
}

final dailyReminderProvider =
    NotifierProvider<DailyReminderNotifier, DailyReminder>(
      DailyReminderNotifier.new,
    );

/// Push token'ını sunucuya bildirir — `POST /me/push-token`.
///
/// ## Neden token üretilmiyor?
///
/// Token'ı Firebase Cloud Messaging üretir ve FCM bir Firebase projesi,
/// `google-services.json` ve iOS için APNs anahtarı ister. Bunların hiçbiri
/// repoda yok ve uydurulamaz (`AGENTS.md` §2.2). Sahte bir token göndermek
/// sunucuda geçersiz bir kayıt bırakır ve bildirim gitmeyince kimse nedenini
/// anlayamaz.
///
/// Bu yüzden burada yalnızca **kayıt yolu** hazır: FCM eklendiğinde token'ı
/// [register] fonksiyonuna vermek yetiyor, sözleşme tarafında değişiklik
/// gerekmiyor.
class PushRegistration {
  const PushRegistration(this._api);

  final BldApi _api;

  /// Sunucuya token'ı bildirir. Hata yutulur: push kaydı başarısız diye
  /// kullanıcının siparişi engellenmemeli.
  Future<bool> register({required String token, required String platform}) async {
    try {
      await _api.auth.registerPushToken(
        PushTokenRequest(fcmToken: token, platform: platform),
      );
      return true;
    } on ApiException catch (error) {
      debugPrint('[push] token kaydedilemedi: ${error.message}');
      return false;
    }
  }
}

final pushRegistrationProvider = Provider<PushRegistration>(
  (ref) => PushRegistration(ref.watch(apiProvider)),
);
