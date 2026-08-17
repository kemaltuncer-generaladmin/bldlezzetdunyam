/// Benim Lezzet Dünyam — müşteri mobil uygulaması.
///
/// Giriş noktası yalnızca eşzamanlı okunması gereken bağımlılıkları hazırlar
/// ve kökü çalıştırır; iş mantığı `lib/src/` altındadır.
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/data/crash_reporter.dart';
import 'src/data/notifications.dart';
import 'src/providers/infra_providers.dart';
import 'src/providers/notification_providers.dart';
import 'src/router/app_router.dart';

/// Hata kancalarının kullandığı raportör.
///
/// Zone hata işleyicisi `runZonedGuarded`'a GEÇİLİRKEN kuruluyor, oysa
/// raportör zone'un İÇİNDE doğuyor (container'a bağlı). Bu yüzden değişken
/// dışarıda duruyor ve `null` başlıyor: kurulumun ilk mikrosaniyelerinde
/// düşen bir hata raporlanamaz — orada bir `SharedPreferences` bile yok,
/// yazacak yer de yok.
CrashReporter? _reporter;

Future<void> main() async {
  /*
   * ÜÇ KANCA, TEK RAPORTÖR — ve üçü de gerekli, hiçbiri ötekini kapsamıyor:
   *
   *   * `FlutterError.onError`      → çizim/düzen/gesture katmanındaki
   *                                    hatalar (senkron, framework içi).
   *   * `PlatformDispatcher.onError` → motora kadar ulaşan yakalanmamış
   *                                    hatalar; `runZonedGuarded` olmadan
   *                                    da çalışan tek kanca.
   *   * `runZonedGuarded`            → zone içinde başlayıp `await`
   *                                    edilmeyen asenkron hatalar
   *                                    (`unawaited` bir Future patlarsa).
   *
   * `runZonedGuarded` ZORUNLU ve `runApp` onun İÇİNDE olmalı:
   * `WidgetsFlutterBinding.ensureInitialized()` bağlamayı çağrıldığı zone'a
   * kilitliyor. Bağlama bir zone'da kurulup uygulama başka bir zone'da
   * çalıştırılırsa Flutter açılışta "Zone mismatch" ile duruyor — bu yüzden
   * kurulumun tamamı aynı zone'un içinde.
   */
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Token ve sepet açılışın ilk karesinden itibaren okunabilir olmalı; bu
      // yüzden `SharedPreferences` runApp'ten önce çözülür.
      final prefs = await SharedPreferences.getInstance();

      /*
       * Tavuk-yumurta: bildirim servisi kurulurken "dokunulunca nereye
       * gidilecek" geri çağrısını istiyor, ama o karar router'a — yani
       * container'a — bağlı. Container ise bildirim servisini override etmek
       * için servisin kurulmuş olmasını bekliyor.
       *
       * Değiştirilebilir bir kanca ile çözülüyor: servis kurulurken kanca boş,
       * container hazır olur olmaz dolduruluyor. Aradaki mikrosaniyelerde
       * gelen bir dokunma kaybolur — uygulama zaten daha açılmamıştır.
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

      // Raportör kancalardan ÖNCE kuruluyor: aşağıdaki iki kanca kurulduğu
      // andan itibaren ateşlenebilir ve `null` bir raportöre düşerlerse ilk
      // hata sessizce kaybolur.
      _reporter = container.read(crashReporterProvider);

      FlutterError.onError = (details) {
        /*
         * HATA AYIKLAMADA `presentError` KALIYOR. Varsayılan davranış
         * kırmızı ekranı çizip hatayı konsola basmak; onu susturmak
         * geliştiricinin gördüğü tek anlık geri bildirimi almak olurdu.
         * Üretimde ise konsolu okuyan kimse yok — asıl kanal rapor.
         */
        if (kDebugMode) FlutterError.presentError(details);

        _reporter?.report(
          details.exception,
          details.stack,
          kind: ClientErrorKind.render,
          context: {
            // `library` ve `context` hatanın hangi katmandan geldiğini
            // söylüyor ("widgets library", "during layout"); mesajın kendisi
            // çoğu zaman aynı olduğu için ayırt edici bilgi bu.
            if (details.library != null) 'library': details.library,
            if (details.context != null) 'phase': details.context.toString(),
          },
        );
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        _reporter?.report(error, stack);
        // `true`: hata ele alındı. `false` dönmek motorun süreci
        // sonlandırmasına yol açar — raporu gönderdik, kullanıcıyı da
        // uygulamadan atmanın bir faydası yok.
        return true;
      };

      // Cihaz yeniden başladığında veya uygulama güncellendiğinde zamanlanmış
      // bildirim düşüyor; her açılışta yeniden kurmak en ucuz güvence.
      await container.read(dailyReminderProvider.notifier).restore();

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const BldCustomerApp(),
        ),
      );
    },
    (error, stack) {
      // Zone'a düşen hata: `await` edilmemiş bir Future patladı ve yukarıdaki
      // iki kancanın hiçbiri görmedi.
      _reporter?.report(error, stack);
    },
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
