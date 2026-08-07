/// Benim Lezzet Dünyam — müşteri mobil uygulaması.
///
/// Giriş noktası yalnızca eşzamanlı okunması gereken bağımlılıkları hazırlar
/// ve kökü çalıştırır; iş mantığı `lib/src/` altındadır.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/data/notifications.dart';
import 'src/providers/infra_providers.dart';
import 'src/providers/notification_providers.dart';
import 'src/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Token ve sepet açılışın ilk karesinden itibaren okunabilir olmalı; bu
  // yüzden `SharedPreferences` runApp'ten önce çözülür.
  final prefs = await SharedPreferences.getInstance();

  /*
   * Tavuk-yumurta: bildirim servisi kurulurken "dokunulunca nereye gidilecek"
   * geri çağrısını istiyor, ama o karar router'a — yani container'a — bağlı.
   * Container ise bildirim servisini override etmek için servisin kurulmuş
   * olmasını bekliyor.
   *
   * Değiştirilebilir bir kanca ile çözülüyor: servis kurulurken kanca boş,
   * container hazır olur olmaz dolduruluyor. Aradaki mikrosaniyelerde gelen
   * bir dokunma kaybolur — uygulama zaten daha açılmamıştır.
   */
  void Function(String payload)? onTap;
  final notifications = await LocalNotifications.create(
    onTapPayload: (payload) => onTap?.call(payload),
  );

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationsProvider.overrideWithValue(notifications),
    ],
  );

  onTap = (payload) => _openFromNotification(container, payload);

  // Cihaz yeniden başladığında veya uygulama güncellendiğinde zamanlanmış
  // bildirim düşüyor; her açılışta yeniden kurmak en ucuz güvence.
  await container.read(dailyReminderProvider.notifier).restore();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BldCustomerApp(),
    ),
  );
}

/// Bildirime dokunulduğunda ilgili ekranı açar (`docs/07-musteriapp.md` §4).
void _openFromNotification(ProviderContainer container, String payload) {
  final router = container.read(routerProvider);
  final orderId = NotificationPayload.orderIdOf(payload);

  if (orderId != null) {
    router.go(Routes.orderTracking(orderId));
    return;
  }
  if (payload == NotificationPayload.menu) router.go(Routes.menu);
}
