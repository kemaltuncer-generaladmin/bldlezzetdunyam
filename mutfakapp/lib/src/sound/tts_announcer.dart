/// Türkçe sesli anons — "üç numaralı yeni sipariş, dört kalem".
///
/// NEDEN: alarm sesi "bir şey oldu" der, ne olduğunu söylemez. Ocak
/// başındaki kişi elleri doluyken ekrana gidip bakmak zorunda kalır.
/// Anons, ekrana hiç bakmadan sipariş numarasını ve büyüklüğünü verir.
///
/// NEDEN ALT SÜREÇ, NEDEN PUB PAKETİ DEĞİL: `flutter_tts` Linux'ta
/// desteklenmiyor; desteklense bile GStreamer/speech-dispatcher
/// bağımlılıklarını derleme zamanına taşırdı (`docs/05` §5.5'teki
/// `audioplayers` kararının aynısı). `spd-say` Ubuntu'da
/// `speech-dispatcher` ile hazır geliyor.
///
/// İKİLİ YOKSA SESSİZCE DEVRE DIŞI: anons bir kolaylık, alarm değil.
/// Yokluğu mutfağı kör bırakmaz — ama tanılama ekranında görünür ki
/// "neden konuşmuyor" sorusu cevapsız kalmasın.
library;

import 'dart:async';
import 'dart:io';

/// Anons ikilileri, tercih sırasına göre.
const List<String> ttsCommands = ['spd-say', 'espeak-ng', 'espeak'];

/// Konuşma hızı sınırları (yüzde; 100 = ikilinin varsayılanı).
const int minTtsRatePercent = 50;
const int maxTtsRatePercent = 200;

/// Türkçe metni sesli okuyan servis.
abstract interface class TtsAnnouncer {
  /// Metni okur. Önceki anons sürüyorsa **iptal edilir** — mutfakta güncel
  /// bilgi eskisinden değerlidir ve üst üste binen iki ses anlaşılmaz.
  Future<void> announce(String text);

  /// Konuşulamıyor mu?
  bool get isUnavailable;

  /// Neden konuşulamıyor? Kullanılabiliyorsa `null`.
  String? get unavailableReason;

  /// Seçilen ikili — tanılama için.
  String? get executable;
}

/// Hiçbir şey söylemeyen sürüm — test ve "anons kapalı" ayarı için.
class SilentTtsAnnouncer implements TtsAnnouncer {
  const SilentTtsAnnouncer({this.unavailableReason = 'Sesli anons kapalı.'});

  @override
  Future<void> announce(String text) async {}

  @override
  bool get isUnavailable => true;

  @override
  final String? unavailableReason;

  @override
  String? get executable => null;
}

/// `spd-say` / `espeak-ng` çağıran [TtsAnnouncer].
class ProcessTtsAnnouncer implements TtsAnnouncer {
  ProcessTtsAnnouncer({
    List<String>? commands,
    Future<Process> Function(String command, List<String> args)? spawn,
    Future<bool> Function(String command)? probe,
    int ratePercent = 100,
  }) : _commands = commands ?? ttsCommands,
       _spawn = spawn ?? Process.start,
       _probe = probe ?? _whichProbe,
       _ratePercent = ratePercent;

  final List<String> _commands;
  final Future<Process> Function(String command, List<String> args) _spawn;
  final Future<bool> Function(String command) _probe;

  int _ratePercent;
  String? _command;
  bool _probed = false;
  Process? _current;
  String? _reason;

  set ratePercent(int value) =>
      _ratePercent = value.clamp(minTtsRatePercent, maxTtsRatePercent);

  @override
  bool get isUnavailable => _probed && _command == null;

  @override
  String? get unavailableReason => _reason;

  @override
  String? get executable => _command;

  @override
  Future<void> announce(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final command = await _resolve();
    if (command == null) return;

    // Süren anonsu kesiyoruz: iki sipariş arka arkaya düştüğünde ikinci
    // anons birincinin üstüne binerse ikisi de anlaşılmaz.
    _current?.kill();
    _current = null;

    try {
      final process = await _spawn(
        command,
        ttsArgsFor(command, trimmed, _ratePercent),
      );
      _current = process;
      await process.exitCode;
    } on Object {
      _reason = 'Sesli anons başlatılamadı ($command).';
    } finally {
      _current = null;
    }
  }

  Future<String?> _resolve() async {
    if (_probed) return _command;

    for (final command in _commands) {
      if (await _probe(command)) {
        _command = command;
        break;
      }
    }

    _probed = true;
    if (_command == null) {
      _reason =
          'Sesli anons aracı bulunamadı (${ttsCommands.join(", ")}). '
          'Kurmak için: sudo apt install speech-dispatcher';
    }

    return _command;
  }

  static Future<bool> _whichProbe(String command) async {
    try {
      final result = await Process.run('which', [command]);
      return result.exitCode == 0;
    } on Object {
      return false;
    }
  }
}

/// Anons ikilisi için argüman listesi üretir (saf — testli).
///
/// `spd-say`: `-l tr` dil, `-r` hız **-100..100** aralığında, `-w` bitene
/// kadar bekler (beklemezsek `exitCode` hemen döner ve üst üste binmeyi
/// engelleyemeyiz).
/// `espeak-ng`: `-v tr` dil, `-s` **dakikada kelime** (varsayılan 175).
List<String> ttsArgsFor(String command, String text, int ratePercent) {
  final rate = ratePercent.clamp(minTtsRatePercent, maxTtsRatePercent);

  switch (command) {
    case 'spd-say':
      // %50 → -50, %100 → 0, %200 → +100 doğrusal eşleme.
      return ['-l', 'tr', '-r', '${(rate - 100).clamp(-100, 100)}', '-w', text];

    case 'espeak-ng':
    case 'espeak':
      return ['-v', 'tr', '-s', '${(175 * rate / 100).round()}', text];

    default:
      return [text];
  }
}
