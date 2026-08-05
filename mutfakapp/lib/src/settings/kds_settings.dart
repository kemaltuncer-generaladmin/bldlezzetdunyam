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

/// Personelin yönettiği ayarların tamamı.
class KdsSettings {
  const KdsSettings({
    required this.soundEnabled,
    required this.pollSeconds,
    required this.printerDevicePath,
    required this.warningAfterMinutes,
    required this.lateAfterMinutes,
  });

  // ── Sınırlar ────────────────────────────────────────────────────────────
  //
  // Ayar ekranı bir metin kutusu değil; yine de diskteki değer bozulabilir
  // (elle düzenleme, eski sürüm, yarım yazma). Sınırlar tek yerde durur ve
  // hem arayüz hem [sanitized] onları kullanır.

  /// 1 saniyenin altı sunucuyu boşuna yorar, 60 saniyenin üstünde mutfak
  /// siparişi geç görür.
  static const int minPollSeconds = 2;
  static const int maxPollSeconds = 60;

  static const int minThresholdMinutes = 1;
  static const int maxThresholdMinutes = 480;

  final bool soundEnabled;

  /// Sipariş çekme aralığı, saniye (`docs/05` §4).
  final int pollSeconds;

  /// Termal yazıcının cihaz dosyası, ör. `/dev/thermal0`.
  final String printerDevicePath;

  /// Kaç dakika sonra kart sarıya döner.
  final int warningAfterMinutes;

  /// Kaç dakika sonra kart kırmızıya döner ve yanıp söner.
  final int lateAfterMinutes;

  Duration get pollInterval => Duration(seconds: pollSeconds);
  Duration get warningAfter => Duration(minutes: warningAfterMinutes);
  Duration get lateAfter => Duration(minutes: lateAfterMinutes);

  KdsSettings copyWith({
    bool? soundEnabled,
    int? pollSeconds,
    String? printerDevicePath,
    int? warningAfterMinutes,
    int? lateAfterMinutes,
  }) => KdsSettings(
    soundEnabled: soundEnabled ?? this.soundEnabled,
    pollSeconds: pollSeconds ?? this.pollSeconds,
    printerDevicePath: printerDevicePath ?? this.printerDevicePath,
    warningAfterMinutes: warningAfterMinutes ?? this.warningAfterMinutes,
    lateAfterMinutes: lateAfterMinutes ?? this.lateAfterMinutes,
  );

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

    return KdsSettings(
      soundEnabled: soundEnabled,
      pollSeconds: pollSeconds.clamp(minPollSeconds, maxPollSeconds),
      printerDevicePath: path.isEmpty ? fallback.printerDevicePath : path,
      warningAfterMinutes: warning,
      lateAfterMinutes: late,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is KdsSettings &&
      other.soundEnabled == soundEnabled &&
      other.pollSeconds == pollSeconds &&
      other.printerDevicePath == printerDevicePath &&
      other.warningAfterMinutes == warningAfterMinutes &&
      other.lateAfterMinutes == lateAfterMinutes;

  @override
  int get hashCode => Object.hash(
    soundEnabled,
    pollSeconds,
    printerDevicePath,
    warningAfterMinutes,
    lateAfterMinutes,
  );

  @override
  String toString() =>
      'KdsSettings(sound: $soundEnabled, poll: ${pollSeconds}s, '
      'printer: $printerDevicePath, '
      'warn: ${warningAfterMinutes}dk, late: ${lateAfterMinutes}dk)';
}
