/// Sunucudan gelen ayarların yerel ayarlara uygulanması.
///
/// TEK KAYNAK SUNUCUDUR. Yönetici admin panelden değiştirir, kasa uygular.
/// İki taraf da yazabilseydi hangisinin kazandığı zamanlamaya bağlı olurdu
/// ve "değiştirdim ama olmadı" şikâyeti hiç çözülemezdi.
///
/// DOKUNULMAMIŞ ALAN YERELİ EZMEZ. Sunucudan `null` gelen bir alan
/// "yönetici bu ayara dokunmadı" demektir; o alanda kasa kendi değerini
/// korur. `null`'ı "kapat" ya da "varsayılana dön" diye yorumlamak,
/// yönetici tek bir ayarı değiştirdiğinde diğer sekizini sıfırlardı.
///
/// SES ÇIKIŞI (`audio_sink`) VE KİLİT METNİ (`lock_message`) İSTİSNA: boş
/// dize gelirse "varsayılana dön" demektir. Yönetici seçtiği çıkışı ya da
/// yazdığı cümleyi geri alabilmeli ve `null` "dokunmadı" anlamına ayrılmış
/// durumda.
library;

import '../settings/kds_settings.dart';
import 'kitchen_health.dart';

/// Sunucu ayarlarını yerel ayarların üstüne uygular.
///
/// Dönen değer girdiyle aynıysa yazmaya gerek yoktur — çağıran bunu
/// karşılaştırarak anlar ve gereksiz disk yazmasından kaçınır.
KdsSettings applyManagedSettings(
  KdsSettings current,
  KitchenManagedSettings managed,
) {
  if (managed.isEmpty) return current;

  final sink = managed.audioSink;

  final next = current.copyWith(
    soundEnabled: managed.soundEnabled,
    pollSeconds: managed.pollSeconds,
    printerDevicePath: managed.printerDevicePath,
    warningAfterMinutes: managed.warningAfterMinutes,
    lateAfterMinutes: managed.lateAfterMinutes,
    volumePercent: managed.volumePercent,
    audioSinkName: sink,
    clearAudioSink: sink != null && sink.trim().isEmpty,
    ttsEnabled: managed.ttsEnabled,
    ttsRatePercent: managed.ttsRatePercent,
    alarmRepeatSeconds: managed.alarmRepeatSeconds,
    alarmMaxRepeats: managed.alarmMaxRepeats,
    touchMode: managed.touchMode,
    printerCodePage: managed.printerCodePage,
    healthSeconds: managed.healthSeconds,
    connectionAlarmSeconds: managed.connectionAlarmSeconds,
    alarmSilenceable: managed.alarmSilenceable,
    // Kilit politikası (K-21 §2.2). Aynı kural: `null` dokunmadı demek,
    // `false` kilitler. Yerel varsayılan `true` olduğu için yeni alanların
    // gelmesi bugünkü kasaları kilitlemez.
    allowSettings: managed.allowSettings,
    allowServerChange: managed.allowServerChange,
    allowWindowControls: managed.allowWindowControls,
    allowOrderEdit: managed.allowOrderEdit,
    allowManualReprint: managed.allowManualReprint,
    allowSalesControl: managed.allowSalesControl,
    lockMessage: managed.lockMessage,
  );

  // Sınırlar YİNE UYGULANIR. Sunucu da kırpıyor ama ona güvenip
  // atlamak, sözleşme dışı bir değerin (elle veritabanı düzenlemesi,
  // eski sunucu sürümü) kasayı bozmasına izin vermek olurdu.
  return next.sanitized(fallback: current);
}
