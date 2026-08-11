/// [KdsSettings]'i `shared_preferences` üzerinde saklar.
///
/// Anahtarlar bir kez yayımlandıktan sonra değişmez: değişirse kasadaki
/// ayarlar sessizce varsayılana döner ve yazıcı yolu yanlış olur.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../sound/kds_sound_event.dart';
import 'kds_settings.dart';

class KdsSettingsStore {
  KdsSettingsStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String soundKey = 'kds_sound_enabled';
  static const String pollSecondsKey = 'kds_poll_seconds';
  static const String printerPathKey = 'kds_printer_path';
  static const String warningMinutesKey = 'kds_warning_minutes';
  static const String lateMinutesKey = 'kds_late_minutes';
  static const String volumeKey = 'kds_volume_percent';
  static const String audioSinkKey = 'kds_audio_sink';
  static const String alarmRepeatKey = 'kds_alarm_repeat_seconds';
  static const String alarmMaxRepeatsKey = 'kds_alarm_max_repeats';
  static const String ttsEnabledKey = 'kds_tts_enabled';
  static const String ttsRateKey = 'kds_tts_rate_percent';
  static const String touchModeKey = 'kds_touch_mode';

  final SharedPreferencesAsync _preferences;

  /// Kayıtlı ayarları okur; eksik her alan için [defaults] kullanılır.
  ///
  /// Alan alan okunması bilinçli: JSON blob saklasaydık yeni bir ayar
  /// eklendiğinde eski blob'u ayrıştırmak ya da göç yazmak gerekirdi.
  Future<KdsSettings> read(KdsSettings defaults) async {
    final disabled = <KdsSoundEvent>{};
    for (final event in KdsSoundEvent.values) {
      if (!event.canBeDisabled) continue;

      // Anahtar YOKSA uyarı açıktır. Yeni eklenen bir uyarı, eski
      // kasalarda sessiz doğmasın (bkz. `disabledSoundEvents` yorumu).
      final enabled = await _preferences.getBool(event.settingsKey);
      if (enabled == false) disabled.add(event);
    }

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
      volumePercent:
          await _preferences.getInt(volumeKey) ?? defaults.volumePercent,
      audioSinkName:
          await _preferences.getString(audioSinkKey) ?? defaults.audioSinkName,
      disabledSoundEvents: disabled,
      alarmRepeatSeconds:
          await _preferences.getInt(alarmRepeatKey) ??
          defaults.alarmRepeatSeconds,
      alarmMaxRepeats:
          await _preferences.getInt(alarmMaxRepeatsKey) ??
          defaults.alarmMaxRepeats,
      ttsEnabled: await _preferences.getBool(ttsEnabledKey) ?? defaults.ttsEnabled,
      ttsRatePercent:
          await _preferences.getInt(ttsRateKey) ?? defaults.ttsRatePercent,
      touchMode: await _preferences.getBool(touchModeKey) ?? defaults.touchMode,
    );

    return stored.sanitized(fallback: defaults);
  }

  Future<void> write(KdsSettings settings) async {
    await _preferences.setBool(soundKey, settings.soundEnabled);
    await _preferences.setInt(pollSecondsKey, settings.pollSeconds);
    await _preferences.setString(printerPathKey, settings.printerDevicePath);
    await _preferences.setInt(warningMinutesKey, settings.warningAfterMinutes);
    await _preferences.setInt(lateMinutesKey, settings.lateAfterMinutes);
    await _preferences.setInt(volumeKey, settings.volumePercent);
    await _preferences.setInt(alarmRepeatKey, settings.alarmRepeatSeconds);
    await _preferences.setInt(alarmMaxRepeatsKey, settings.alarmMaxRepeats);
    await _preferences.setBool(ttsEnabledKey, settings.ttsEnabled);
    await _preferences.setInt(ttsRateKey, settings.ttsRatePercent);
    await _preferences.setBool(touchModeKey, settings.touchMode);

    final sink = settings.audioSinkName;
    if (sink == null) {
      await _preferences.remove(audioSinkKey);
    } else {
      await _preferences.setString(audioSinkKey, sink);
    }

    for (final event in KdsSoundEvent.values) {
      if (!event.canBeDisabled) continue;

      await _preferences.setBool(
        event.settingsKey,
        !settings.disabledSoundEvents.contains(event),
      );
    }
  }
}
