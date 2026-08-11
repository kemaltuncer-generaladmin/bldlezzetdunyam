/// Kasada saklanan, personelin değiştirebildiği ayarlar
/// (`docs/05-mutfakapp.md` §8).
///
/// **Neden `AppConfig`'ten ayrı:** `AppConfig` derleme zamanı
/// (`--dart-define`) değerlerini taşır ve çalışırken değişmez. Buradaki
/// değerler diskte durur ve derlemeyi **ezer** — yazıcı yolu değişince
/// mutfağın yeni bir `.deb` beklemesi kabul edilemez. Kaydedilmiş değer
/// yoksa `AppConfig` varsayılan olarak kullanılır.
///
/// Sunucu adresi burada DEĞİL: o `DeviceSessionStore`'a aittir çünkü cihaz
/// token'ıyla birlikte anlam taşır (adres değişirse token geçersizdir).
library;

import 'package:flutter/foundation.dart' show setEquals;

import '../sound/kds_sound_event.dart';
import '../sound/tts_announcer.dart';

/// Personelin yönettiği ayarların tamamı.
class KdsSettings {
  const KdsSettings({
    required this.soundEnabled,
    required this.pollSeconds,
    required this.printerDevicePath,
    required this.warningAfterMinutes,
    required this.lateAfterMinutes,
    this.volumePercent = defaultVolumePercent,
    this.audioSinkName,
    this.disabledSoundEvents = const <KdsSoundEvent>{},
    this.alarmRepeatSeconds = defaultAlarmRepeatSeconds,
    this.alarmMaxRepeats = 0,
    this.ttsEnabled = false,
    this.ttsRatePercent = 100,
    this.touchMode = false,
    this.printerCodePage,
    this.healthSeconds = defaultHealthSeconds,
    this.connectionAlarmSeconds = defaultConnectionAlarmSeconds,
    this.alarmSilenceable = true,
  });

  // ── Sınırlar ────────────────────────────────────────────────────────────
  //
  // Ayar ekranı bir metin kutusu değil; yine de diskteki değer bozulabilir
  // (elle düzenleme, eski sürüm, yarım yazma). Sınırlar tek yerde durur ve
  // hem arayüz hem [sanitized] onları kullanır.

  /// Yoklama aralığının alt ve üst sınırı.
  ///
  /// ALT SINIR 2'DEN 3'E ÇIKTI (12.08.2026). 2 saniyelik yoklama saatte
  /// **1800 istek** demek; BBD kuyruğu, sağlık, heartbeat ve satış
  /// şalteriyle birlikte sunucudaki `bld-kitchen` sınırını (2000/saat)
  /// aşıyordu. Aşıldığında kasa `429` alıyor ve **mutfak sipariş
  /// görmüyor** — ayarı değiştiren personel farkında olmadan kendi
  /// ekranını kör ediyordu.
  ///
  /// 3 saniye 1200 istek/saat ve mutfakta 2 ile arasında fark yok:
  /// personelin yeni siparişe tepki süresi zaten saniyelerle ölçülüyor.
  /// Bütçenin tamamı `test/request_budget_test.dart` içinde sabitli.
  ///
  /// 60 saniyenin üstünde mutfak siparişi geç görür.
  static const int minPollSeconds = 3;
  static const int maxPollSeconds = 60;

  static const int minThresholdMinutes = 1;
  static const int maxThresholdMinutes = 480;

  /// Varsayılan %80: mutfak gürültülü, ama %100 bozuk hoparlörde cızırdıyor.
  static const int defaultVolumePercent = 80;

  /// Alarm tekrarları arasındaki bekleme.
  ///
  /// 0 = beklemeden hemen tekrar (eski davranış). Üst sınır 120 sn: daha
  /// uzun bir aralık "ısrarcı alarm" olmaktan çıkar.
  static const int defaultAlarmRepeatSeconds = 0;
  static const int maxAlarmRepeatSeconds = 120;

  /// Sağlık bildirimi aralığı (`docs/05` §8 sınırları: 10–300 sn).
  static const int defaultHealthSeconds = 60;
  static const int minHealthSeconds = 10;
  static const int maxHealthSeconds = 300;

  /// Bağlantı uyarısının tekrar aralığı (10–600 sn).
  static const int defaultConnectionAlarmSeconds = 45;
  static const int minConnectionAlarmSeconds = 10;
  static const int maxConnectionAlarmSeconds = 600;

  final bool soundEnabled;

  /// Sipariş çekme aralığı, saniye (`docs/05` §4).
  final int pollSeconds;

  /// Termal yazıcının cihaz dosyası, ör. `/dev/thermal0`.
  final String printerDevicePath;

  /// Kaç dakika sonra kart sarıya döner.
  final int warningAfterMinutes;

  /// Kaç dakika sonra kart kırmızıya döner ve yanıp söner.
  final int lateAfterMinutes;

  /// Uygulama içi ses seviyesi (0–100). Oynatıcıya `--volume` olarak gider.
  final int volumePercent;

  /// Çıkış cihazı (PipeWire/PulseAudio sink). `null` = sistem varsayılanı.
  final String? audioSinkName;

  /// Personelin kapattığı sesli uyarılar.
  ///
  /// Kapalı olanları tutuyoruz, açık olanları değil: yeni bir uyarı
  /// eklendiğinde eski kasalarda **açık** gelir. Ters kurgu, eklenen her
  /// uyarının sessiz doğması demekti.
  final Set<KdsSoundEvent> disabledSoundEvents;

  /// Alarm tekrarları arasındaki bekleme (saniye).
  final int alarmRepeatSeconds;

  /// En fazla kaç kez tekrar edilir? 0 = sınırsız (onaylanana kadar).
  final int alarmMaxRepeats;

  /// Sesli anons açık mı?
  final bool ttsEnabled;

  /// Anons hızı, yüzde (100 = aracın varsayılanı).
  final int ttsRatePercent;

  /// Dokunmatik monitör kipi (K-10).
  ///
  /// Kapalıyken bugünkü klavye öncelikli düzen aynen kalır; açıkken
  /// dokunma hedefleri büyür, açılır menüler alt sayfaya döner ve ekran
  /// klavyesi devreye girer.
  final bool touchMode;

  /// Termal yazıcının kod sayfası (`ESC t n`). `null` = derleme değeri.
  ///
  /// Sunucudan yönetilebiliyor ama YEREL VARSAYILAN YOK: yanlış bir kod
  /// sayfası Türkçe karakterleri bozar ve doğru değer donanıma özgüdür
  /// (`docs/05` §5.2 — sahada `29` ölçüldü).
  final int? printerCodePage;

  /// Sağlık bildirimi aralığı, saniye.
  final int healthSeconds;

  /// Bağlantı uyarısının tekrar aralığı, saniye.
  final int connectionAlarmSeconds;

  /// Yeni sipariş alarmı susturulabilir mi?
  ///
  /// Yönetici kapatabilir: susturmanın alışkanlığa dönüştüğü bir mutfakta
  /// alarmın hiç çalmamasıyla aynı sonuç doğar.
  final bool alarmSilenceable;

  Duration get pollInterval => Duration(seconds: pollSeconds);
  Duration get warningAfter => Duration(minutes: warningAfterMinutes);
  Duration get lateAfter => Duration(minutes: lateAfterMinutes);
  Duration get alarmRepeatDelay => Duration(seconds: alarmRepeatSeconds);
  Duration get healthInterval => Duration(seconds: healthSeconds);
  Duration get connectionAlarmInterval =>
      Duration(seconds: connectionAlarmSeconds);

  /// Bu uyarı çalacak mı? Genel şalter ve olay bazlı şalter birlikte.
  ///
  /// Bağlantı uyarısı genel şaltere bakmaz (`docs/05` §5.5): ekran son
  /// bilinen listeyi gösterir ve DOĞRU görünür; tek uyarıyı kapatmak
  /// mutfağı kör bırakır.
  bool soundEnabledFor(KdsSoundEvent event) {
    if (!event.canBeDisabled) return true;
    if (!soundEnabled) return false;

    return !disabledSoundEvents.contains(event);
  }

  KdsSettings copyWith({
    bool? soundEnabled,
    int? pollSeconds,
    String? printerDevicePath,
    int? warningAfterMinutes,
    int? lateAfterMinutes,
    int? volumePercent,
    String? audioSinkName,
    bool clearAudioSink = false,
    Set<KdsSoundEvent>? disabledSoundEvents,
    int? alarmRepeatSeconds,
    int? alarmMaxRepeats,
    bool? ttsEnabled,
    int? ttsRatePercent,
    bool? touchMode,
    int? printerCodePage,
    int? healthSeconds,
    int? connectionAlarmSeconds,
    bool? alarmSilenceable,
  }) => KdsSettings(
    soundEnabled: soundEnabled ?? this.soundEnabled,
    pollSeconds: pollSeconds ?? this.pollSeconds,
    printerDevicePath: printerDevicePath ?? this.printerDevicePath,
    warningAfterMinutes: warningAfterMinutes ?? this.warningAfterMinutes,
    lateAfterMinutes: lateAfterMinutes ?? this.lateAfterMinutes,
    volumePercent: volumePercent ?? this.volumePercent,
    audioSinkName: clearAudioSink ? null : (audioSinkName ?? this.audioSinkName),
    disabledSoundEvents: disabledSoundEvents ?? this.disabledSoundEvents,
    alarmRepeatSeconds: alarmRepeatSeconds ?? this.alarmRepeatSeconds,
    alarmMaxRepeats: alarmMaxRepeats ?? this.alarmMaxRepeats,
    ttsEnabled: ttsEnabled ?? this.ttsEnabled,
    ttsRatePercent: ttsRatePercent ?? this.ttsRatePercent,
    touchMode: touchMode ?? this.touchMode,
    printerCodePage: printerCodePage ?? this.printerCodePage,
    healthSeconds: healthSeconds ?? this.healthSeconds,
    connectionAlarmSeconds:
        connectionAlarmSeconds ?? this.connectionAlarmSeconds,
    alarmSilenceable: alarmSilenceable ?? this.alarmSilenceable,
  );

  /// Bir sesli uyarıyı açar/kapatır.
  KdsSettings withSoundEvent(KdsSoundEvent event, {required bool enabled}) {
    if (!event.canBeDisabled) return this;

    final next = Set<KdsSoundEvent>.of(disabledSoundEvents);
    if (enabled) {
      next.remove(event);
    } else {
      next.add(event);
    }

    return copyWith(disabledSoundEvents: next);
  }

  /// Değerleri geçerli aralığa çeker.
  ///
  /// Gecikme eşiği uyarı eşiğinin **altına** düşemez: düşerse kart doğrudan
  /// kırmızıya atlar ve sarı hiç görünmez — mutfak uyarı penceresini kaybeder.
  KdsSettings sanitized({required KdsSettings fallback}) {
    final warning = warningAfterMinutes.clamp(
      minThresholdMinutes,
      maxThresholdMinutes,
    );
    final late = lateAfterMinutes.clamp(warning, maxThresholdMinutes);
    final path = printerDevicePath.trim();
    final sink = audioSinkName?.trim();

    return KdsSettings(
      soundEnabled: soundEnabled,
      pollSeconds: pollSeconds.clamp(minPollSeconds, maxPollSeconds),
      printerDevicePath: path.isEmpty ? fallback.printerDevicePath : path,
      warningAfterMinutes: warning,
      lateAfterMinutes: late,
      volumePercent: volumePercent.clamp(0, 100),
      audioSinkName: (sink == null || sink.isEmpty) ? null : sink,
      // Kapatılamayan uyarılar kapalı listesinde duramaz: diskte öyle
      // yazsa bile yok sayılır.
      disabledSoundEvents: disabledSoundEvents
          .where((event) => event.canBeDisabled)
          .toSet(),
      alarmRepeatSeconds: alarmRepeatSeconds.clamp(0, maxAlarmRepeatSeconds),
      alarmMaxRepeats: alarmMaxRepeats < 0 ? 0 : alarmMaxRepeats,
      ttsEnabled: ttsEnabled,
      ttsRatePercent: ttsRatePercent.clamp(minTtsRatePercent, maxTtsRatePercent),
      touchMode: touchMode,
      printerCodePage: printerCodePage?.clamp(0, 255),
      healthSeconds: healthSeconds.clamp(minHealthSeconds, maxHealthSeconds),
      connectionAlarmSeconds: connectionAlarmSeconds.clamp(
        minConnectionAlarmSeconds,
        maxConnectionAlarmSeconds,
      ),
      alarmSilenceable: alarmSilenceable,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is KdsSettings &&
      other.soundEnabled == soundEnabled &&
      other.pollSeconds == pollSeconds &&
      other.printerDevicePath == printerDevicePath &&
      other.warningAfterMinutes == warningAfterMinutes &&
      other.lateAfterMinutes == lateAfterMinutes &&
      other.volumePercent == volumePercent &&
      other.audioSinkName == audioSinkName &&
      setEquals(other.disabledSoundEvents, disabledSoundEvents) &&
      other.alarmRepeatSeconds == alarmRepeatSeconds &&
      other.alarmMaxRepeats == alarmMaxRepeats &&
      other.ttsEnabled == ttsEnabled &&
      other.ttsRatePercent == ttsRatePercent &&
      other.touchMode == touchMode &&
      other.printerCodePage == printerCodePage &&
      other.healthSeconds == healthSeconds &&
      other.connectionAlarmSeconds == connectionAlarmSeconds &&
      other.alarmSilenceable == alarmSilenceable;

  @override
  int get hashCode => Object.hash(
    soundEnabled,
    pollSeconds,
    printerDevicePath,
    warningAfterMinutes,
    lateAfterMinutes,
    volumePercent,
    audioSinkName,
    Object.hashAllUnordered(disabledSoundEvents),
    alarmRepeatSeconds,
    alarmMaxRepeats,
    ttsEnabled,
    ttsRatePercent,
    touchMode,
    printerCodePage,
    healthSeconds,
    connectionAlarmSeconds,
    alarmSilenceable,
  );

  @override
  String toString() =>
      'KdsSettings(sound: $soundEnabled, poll: ${pollSeconds}s, '
      'printer: $printerDevicePath, '
      'warn: ${warningAfterMinutes}dk, late: ${lateAfterMinutes}dk, '
      'volume: $volumePercent%, sink: ${audioSinkName ?? "varsayılan"}, '
      'kapalı sesler: ${disabledSoundEvents.map((e) => e.name).join(",")}, '
      'tts: $ttsEnabled, dokunmatik: $touchMode)';
}
