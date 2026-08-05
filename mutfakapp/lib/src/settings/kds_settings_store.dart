/// [KdsSettings]'i `shared_preferences` üzerinde saklar.
///
/// Anahtarlar bir kez yayımlandıktan sonra değişmez: değişirse kasadaki
/// ayarlar sessizce varsayılana döner ve yazıcı yolu yanlış olur.
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'kds_settings.dart';

class KdsSettingsStore {
  KdsSettingsStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String soundKey = 'kds_sound_enabled';
  static const String pollSecondsKey = 'kds_poll_seconds';
  static const String printerPathKey = 'kds_printer_path';
  static const String warningMinutesKey = 'kds_warning_minutes';
  static const String lateMinutesKey = 'kds_late_minutes';

  final SharedPreferencesAsync _preferences;

  /// Kayıtlı ayarları okur; eksik her alan için [defaults] kullanılır.
  ///
  /// Alan alan okunması bilinçli: JSON blob saklasaydık yeni bir ayar
  /// eklendiğinde eski blob'u ayrıştırmak ya da göç yazmak gerekirdi.
  Future<KdsSettings> read(KdsSettings defaults) async {
    final stored = KdsSettings(
      soundEnabled:
          await _preferences.getBool(soundKey) ?? defaults.soundEnabled,
      pollSeconds:
          await _preferences.getInt(pollSecondsKey) ?? defaults.pollSeconds,
      printerDevicePath:
          await _preferences.getString(printerPathKey) ??
          defaults.printerDevicePath,
      warningAfterMinutes:
          await _preferences.getInt(warningMinutesKey) ??
          defaults.warningAfterMinutes,
      lateAfterMinutes:
          await _preferences.getInt(lateMinutesKey) ??
          defaults.lateAfterMinutes,
    );

    return stored.sanitized(fallback: defaults);
  }

  Future<void> write(KdsSettings settings) async {
    await _preferences.setBool(soundKey, settings.soundEnabled);
    await _preferences.setInt(pollSecondsKey, settings.pollSeconds);
    await _preferences.setString(printerPathKey, settings.printerDevicePath);
    await _preferences.setInt(warningMinutesKey, settings.warningAfterMinutes);
    await _preferences.setInt(lateMinutesKey, settings.lateAfterMinutes);
  }
}
