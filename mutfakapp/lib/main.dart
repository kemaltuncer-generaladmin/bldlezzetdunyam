/// Mutfak ekranı (KDS) giriş noktası — yalnızca Linux desktop (ADR-04).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/config/app_config.dart';
import 'src/data/providers.dart';
import 'src/data/token_store.dart';
import 'src/window/kiosk_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureKioskWindow();

  final config = AppConfig.fromEnvironment();
  final tokenStore = SharedPreferencesTokenStore();

  // Kasa görüntü sunucusuz hazırlanabilsin diye token derleme zamanında
  // verilebilir. Verilmemişse eşleme ekranından (`K-07`) gelir.
  if (config.provisionedToken.isNotEmpty) {
    await tokenStore.write(config.provisionedToken);
  }

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        tokenStoreProvider.overrideWithValue(tokenStore),
      ],
      child: const MutfakApp(),
    ),
  );
}
