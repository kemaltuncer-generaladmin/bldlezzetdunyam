/// Kiosk pencere davranışı — `docs/05-mutfakapp.md` §6.
///
/// Açılışta tam ekran ve her zaman üstte; pencere kapatma düğmesi devre dışı.
/// Uygulamadan çıkış yalnızca ayarlardaki gizli menüyle (`K-08`) ya da
/// `systemd` servisini durdurmakla olur.
library;

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/app_localizations.dart';

/// Pencereyi kiosk moduna alır. `runApp`'ten **önce** çağrılır.
Future<void> configureKioskWindow() async {
  await windowManager.ensureInitialized();

  // Başlık da sabit metindir; `l10n`'dan alınır (AGENTS.md §4). Burada
  // BuildContext yok, bu yüzden delege doğrudan yüklenir.
  final l10n = await AppL10n.delegate.load(const Locale('tr'));

  final options = WindowOptions(
    title: l10n.appTitle,
    fullScreen: true,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setFullScreen(true);
    await windowManager.setAlwaysOnTop(true);
    // Mutfak personeli yanlışlıkla kapatmasın; kapatma yetkisi PIN arkasında.
    await windowManager.setPreventClose(true);
    await windowManager.show();
    await windowManager.focus();
  });
}
