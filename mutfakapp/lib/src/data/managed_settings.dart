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
/// SES ÇIKIŞI (`audio_sink`) İSTİSNA: boş dize gelirse "varsayılan çıkışa
/// dön" demektir. Yönetici seçtiği çıkışı geri alabilmeli ve `null`
/// "dokunmadı" anlamına ayrılmış durumda.
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
  );

  // Sınırlar YİNE UYGULANIR. Sunucu da kırpıyor ama ona güvenip
  // atlamak, sözleşme dışı bir değerin (elle veritabanı düzenlemesi,
  // eski sunucu sürümü) kasayı bozmasına izin vermek olurdu.
  return next.sanitized(fallback: current);
}
