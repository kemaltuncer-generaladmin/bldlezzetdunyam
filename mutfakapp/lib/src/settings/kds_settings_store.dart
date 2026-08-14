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

  // ── Sunucudan yönetilen ama diske YAZILMAYAN dört alan (K-21) ──────────
  //
  // Bu dördü sözleşmede ve modelde vardı, yalnızca burada yoktu: kasa her
  // yeniden başlatıldığında derleme varsayılanına dönüyor, sunucu bir
  // sağlık turu sonra düzeltiyordu. Aradaki pencerede YANLIŞ KOD SAYFASIYLA
  // fiş basılıyor ve Türkçe harfler boşluğa dönüyordu.
  static const String printerCodePageKey = 'kds_printer_code_page';
  static const String healthSecondsKey = 'kds_health_seconds';
  static const String connectionAlarmKey = 'kds_connection_alarm_seconds';
  static const String alarmSilenceableKey = 'kds_alarm_silenceable';

  // ── Kilit politikası (K-21 §2.2) ───────────────────────────────────────
  //
  // KİLİT DE DİSKE YAZILIR. Ağsız açılan bir kasa sunucuya ulaşamaz ve ilk
  // sağlık turu `healthSeconds` (varsayılan 60 sn) sonra gelir. Kilit
  // yalnızca bellekte tutulsaydı kasa o pencerede SERBEST açılırdı — ve
  // kilidi aşmak isteyen için yapılacak tek şey kasayı kapatıp açmak
  // olurdu, yani kilidin amacı tam da bu pencerede boşa çıkardı.
  //
  // Ters yönde risk yok: anahtar hiç yazılmamışsa okuma `defaults`a
  // düşer, o da serbesttir (`KdsSettings.allow*` = `true`).
  static const String allowSettingsKey = 'kds_allow_settings';
  static const String allowServerChangeKey = 'kds_allow_server_change';
  static const String allowWindowControlsKey = 'kds_allow_window_controls';
  static const String allowOrderEditKey = 'kds_allow_order_edit';
  static const String allowManualReprintKey = 'kds_allow_manual_reprint';
  static const String allowSalesControlKey = 'kds_allow_sales_control';
  static const String lockMessageKey = 'kds_lock_message';

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
      ttsEnabled:
          await _preferences.getBool(ttsEnabledKey) ?? defaults.ttsEnabled,
      ttsRatePercent:
          await _preferences.getInt(ttsRateKey) ?? defaults.ttsRatePercent,
      touchMode: await _preferences.getBool(touchModeKey) ?? defaults.touchMode,
      printerCodePage:
          await _preferences.getInt(printerCodePageKey) ??
          defaults.printerCodePage,
      healthSeconds:
          await _preferences.getInt(healthSecondsKey) ?? defaults.healthSeconds,
      connectionAlarmSeconds:
          await _preferences.getInt(connectionAlarmKey) ??
          defaults.connectionAlarmSeconds,
      alarmSilenceable:
          await _preferences.getBool(alarmSilenceableKey) ??
          defaults.alarmSilenceable,
      allowSettings:
          await _preferences.getBool(allowSettingsKey) ??
          defaults.allowSettings,
      allowServerChange:
          await _preferences.getBool(allowServerChangeKey) ??
          defaults.allowServerChange,
      allowWindowControls:
          await _preferences.getBool(allowWindowControlsKey) ??
          defaults.allowWindowControls,
      allowOrderEdit:
          await _preferences.getBool(allowOrderEditKey) ??
          defaults.allowOrderEdit,
      allowManualReprint:
          await _preferences.getBool(allowManualReprintKey) ??
          defaults.allowManualReprint,
      allowSalesControl:
          await _preferences.getBool(allowSalesControlKey) ??
          defaults.allowSalesControl,
      lockMessage:
          await _preferences.getString(lockMessageKey) ?? defaults.lockMessage,
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
    await _preferences.setInt(healthSecondsKey, settings.healthSeconds);
    await _preferences.setInt(
      connectionAlarmKey,
      settings.connectionAlarmSeconds,
    );
    await _preferences.setBool(alarmSilenceableKey, settings.alarmSilenceable);
    await _preferences.setBool(allowSettingsKey, settings.allowSettings);
    await _preferences.setBool(
      allowServerChangeKey,
      settings.allowServerChange,
    );
    await _preferences.setBool(
      allowWindowControlsKey,
      settings.allowWindowControls,
    );
    await _preferences.setBool(allowOrderEditKey, settings.allowOrderEdit);
    await _preferences.setBool(
      allowManualReprintKey,
      settings.allowManualReprint,
    );
    await _preferences.setBool(
      allowSalesControlKey,
      settings.allowSalesControl,
    );
    // Boş dize de yazılır: "özel metin yok" bir değerdir ve anahtarı silmek
    // onu "hiç ayarlanmadı"dan ayırt edilemez kılardı.
    await _preferences.setString(lockMessageKey, settings.lockMessage);

    // Kod sayfasının YEREL VARSAYILANI YOK (`KdsSettings.printerCodePage`
    // yorumu): `null` "derleme değerini kullan" demek. 0 yazmak geçerli
    // ama YANLIŞ bir kod sayfası dayatırdı, bu yüzden anahtar silinir.
    final codePage = settings.printerCodePage;
    if (codePage == null) {
      await _preferences.remove(printerCodePageKey);
    } else {
      await _preferences.setInt(printerCodePageKey, codePage);
    }

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
