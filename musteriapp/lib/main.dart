/// Benim Lezzet Dünyam — müşteri mobil uygulaması (Android).
///
/// Giriş noktası yalnızca eşzamanlı okunması gereken bağımlılığı hazırlar ve
/// kökü çalıştırır; iş mantığı `lib/src/` altındadır.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/providers/infra_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Token ve sepet açılışın ilk karesinden itibaren okunabilir olmalı; bu
  // yüzden `SharedPreferences` runApp'ten önce çözülür.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const BldCustomerApp(),
    ),
  );
}
