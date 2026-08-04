/// Mutfak ekranı (KDS) giriş noktası — yalnızca Linux desktop (ADR-04).
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'src/app.dart';
import 'src/config/app_config.dart';
import 'src/data/device_session.dart';
import 'src/data/providers.dart';
import 'src/printing/print_queue.dart';
import 'src/window/kiosk_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureKioskWindow();

  final config = AppConfig.fromEnvironment();
  final store = DeviceSessionStore();

  // Kasa görüntü sunucusuz hazırlanabilsin diye token derleme zamanında
  // verilebilir. Verilmemişse eşleme ekranından gelir (`K-07`).
  if (config.provisionedToken.isNotEmpty) {
    await store.tokens.write(config.provisionedToken);
  }

  final session = await store.read(fallbackBaseUrl: config.baseUrl);
  final queue = PrintQueue.open(await _queuePath());

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        deviceSessionStoreProvider.overrideWithValue(store),
        initialDeviceSessionProvider.overrideWithValue(session),
        // Kuyruk **diskte** durur: elektrik kesintisinden sonra basılmamış
        // fişler kaldığı yerden basılır (`docs/05-mutfakapp.md` §5.4).
        printQueueProvider.overrideWithValue(queue),
      ],
      child: const MutfakApp(),
    ),
  );
}

/// Kuyruk veritabanının yolu. Kullanıcının uygulama veri klasöründedir;
/// `/opt/mutfakapp` salt okunur kurulabilsin diye kurulum dizinine yazılmaz.
Future<String> _queuePath() async {
  final directory = await getApplicationSupportDirectory();
  await Directory(directory.path).create(recursive: true);
  return '${directory.path}/print_queue.sqlite';
}
