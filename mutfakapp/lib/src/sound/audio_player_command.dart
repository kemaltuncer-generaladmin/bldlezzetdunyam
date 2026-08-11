/// Sistem ses oynatıcılarının komut satırı sözleşmesi.
///
/// NEDEN AYRI DOSYA: argüman üretimi saf bir işlev; süreç başlatmadan,
/// Flutter motoru kurmadan sınanabilir. Sahada patlayan hata tam da
/// buradaydı ve testi olmadığı için sessizce yaşadı.
///
/// SAHA HATASI (11.08.2026) — `pw-play -q <dosya>`:
/// `aplay` için `-q` "sessiz" demek. `pw-play` için `-q` = `--quality`
/// ve **bir değer bekler**; dosya yolunu kendi değeri sanıp yutuyor,
/// geriye oynatılacak dosya kalmıyor:
///
///     $ pw-play -q /tmp/bld_yeni_siparis.wav
///     error: filename or - argument missing
///     exit=1
///
/// Ubuntu 24.04 PipeWire ile geliyor, `pw-play` tercih listesinde ilk
/// sırada, dolayısıyla kasada alarm **hiç çalmadı**. Üstelik süreç
/// başlatılabildiği için istisna atılmadı, `isMuted` de `false` kaldı —
/// arayüz "ses açık" gösterirken hoparlör susuyordu. Bu yüzden artık
/// **çıkış kodu da denetleniyor** (bkz. [AudioPlayerFailure]).
library;

/// Bir oynatıcı ikilisinin nasıl çağrılacağını bilen değer nesnesi.
class AudioPlayerCommand {
  const AudioPlayerCommand(this.executable);

  /// Tercih sırasına göre denenecek ikililer.
  ///
  /// `pw-play` önce: kasa PipeWire kullanıyor ve `aplay` ALSA üzerinden
  /// giderken cihaz meşgulse sessizce başarısız olabiliyor. `paplay` ve
  /// `ffplay` yedek: PulseAudio'lu ya da ffmpeg kurulu kurulumlarda
  /// hiçbiri yoksa alarm tamamen susmasın.
  static const List<String> candidates = [
    'pw-play',
    'paplay',
    'aplay',
    'ffplay',
  ];

  final String executable;

  /// Oynatıcı kendi akışında ses seviyesi ayarlayabiliyor mu?
  ///
  /// `aplay` ayarlayamaz — ALSA'da seviye cihazın kendisine aittir.
  /// O durumda seviye [SystemAudio] üzerinden hoparlöre uygulanır.
  bool get supportsVolume => executable != 'aplay';

  /// Çıkış cihazı (sink) seçilebiliyor mu?
  bool get supportsSink => executable == 'pw-play' || executable == 'paplay';

  /// Verilen dosyayı çalmak için argüman listesi üretir.
  ///
  /// [volumePercent] 0–100 aralığına kırpılır. [sink] boş/null ise
  /// varsayılan çıkış kullanılır.
  List<String> argsFor({
    required String filePath,
    int volumePercent = 100,
    String? sink,
  }) {
    final volume = volumePercent.clamp(0, 100);
    final target = (sink == null || sink.trim().isEmpty) ? null : sink.trim();

    switch (executable) {
      case 'pw-play':
        return [
          // 0–1.0 aralığı, üç ondalık. `-q` KULLANILMAZ: quality anlamına
          // gelir ve dosya yolunu yutar (dosya başlığındaki saha hatası).
          '--volume=${(volume / 100).toStringAsFixed(3)}',
          if (target != null) '--target=$target',
          filePath,
        ];

      case 'paplay':
        // PulseAudio seviyeyi 0–65536 tamsayısıyla ister.
        return [
          '--volume=${(volume * 65536 / 100).round()}',
          if (target != null) '--device=$target',
          filePath,
        ];

      case 'aplay':
        // `-q` burada gerçekten "sessiz kip" (ilerleme yazdırma).
        return ['-q', filePath];

      case 'ffplay':
        return [
          '-nodisp',
          '-autoexit',
          '-loglevel',
          'quiet',
          '-volume',
          '$volume',
          filePath,
        ];

      default:
        // Bilinmeyen ikili: en güvenli varsayım "yalnız dosya yolu".
        return [filePath];
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AudioPlayerCommand && other.executable == executable;

  @override
  int get hashCode => executable.hashCode;

  @override
  String toString() => executable;
}

/// Oynatma neden başarısız oldu?
///
/// Sessiz başarısızlık kabul edilmiyor: her dal bir sebep üretir ve sebep
/// arayüze kadar taşınır (`docs/05` §5.5 — "sessiz bir alarm, alarm
/// olmadığını bilmemekten iyidir").
enum AudioPlayerFailure {
  /// Kasada hiçbir oynatıcı ikilisi bulunamadı.
  noPlayer,

  /// Ses dosyası diske çıkarılamadı.
  assetUnavailable,

  /// Süreç başlatılamadı (izin, PATH, çatallama hatası).
  spawnFailed,

  /// Süreç başladı ama sıfırdan farklı kodla çıktı — argüman ya da cihaz
  /// hatası. Sahadaki `pw-play -q` hatası tam olarak bu daldı.
  playerRejected;

  String get message => switch (this) {
    AudioPlayerFailure.noPlayer =>
      'Kasada ses oynatıcı bulunamadı '
          '(${AudioPlayerCommand.candidates.join(", ")}).',
    AudioPlayerFailure.assetUnavailable => 'Ses dosyası diske yazılamadı.',
    AudioPlayerFailure.spawnFailed => 'Ses oynatıcı başlatılamadı.',
    AudioPlayerFailure.playerRejected => 'Ses oynatıcı hata koduyla döndü.',
  };
}
