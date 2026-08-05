/// Kiosk pencere davranışı — `docs/05-mutfakapp.md` §6.
///
/// Açılışta tam ekran ve her zaman üstte. Personel gerektiğinde pencereyi
/// küçültebilir ya da tam ekrandan çıkabilir (durum çubuğundaki düğmeler);
/// kasa tek amaçlı bir makine ama arada masaüstüne inmek gerekiyor —
/// yazıcı ayarı, ağ, güncelleme. Kapatmaya karşı koruma duruyor: yanlışlıkla
/// kapatmak mutfağın sipariş göremediği anlamına gelir.
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
    // Mutfak personeli yanlışlıkla kapatmasın.
    await windowManager.setPreventClose(true);
    await windowManager.show();
    await windowManager.focus();
  });
}

/// Durum çubuğundaki pencere düğmelerinin yaptığı işler.
///
/// Tek yerde toplanmalarının sebebi: "tam ekrandan çık" tek bir ayar
/// değil, birlikte değişmesi gereken iki ayar.
class KioskWindow {
  const KioskWindow();

  /// Pencereyi görev çubuğuna indirir.
  ///
  /// ÖNCE `alwaysOnTop` KAPATILIR. Kapatılmazsa pencere küçülür ve hemen
  /// geri gelir; kullanıcıya "düğme çalışmıyor" gibi görünür.
  Future<void> minimize() async {
    await windowManager.setAlwaysOnTop(false);
    await windowManager.minimize();
  }

  Future<bool> isFullScreen() => windowManager.isFullScreen();

  /// Tam ekran ↔ pencere. `alwaysOnTop` tam ekranla birlikte gider:
  /// pencere modunda üstte kalan bir KDS, altındaki ayar penceresini
  /// kullanılamaz hâle getirirdi.
  Future<bool> toggleFullScreen() async {
    final full = await windowManager.isFullScreen();

    await windowManager.setFullScreen(!full);
    await windowManager.setAlwaysOnTop(!full);

    if (full) {
      // Tam ekrandan çıkan pencere bazı masaüstlerinde kullanılamayacak
      // kadar küçük kalıyor; makul bir boyuta oturtuyoruz.
      await windowManager.setSize(const Size(1280, 800));
      await windowManager.center();
    }

    return !full;
  }
}
