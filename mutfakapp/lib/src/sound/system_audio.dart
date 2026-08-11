/// Kasanın hoparlör denetimi — çıkış cihazı listesi ve sistem ses seviyesi.
///
/// NEDEN GEREKLİ: uygulama içi seviye (`--volume`) yalnızca kendi akışını
/// kısar. Hoparlörün kendisi kısıksa ya da yanlış çıkışa (HDMI monitör
/// hoparlörü, kullanılmayan hat çıkışı) yönlenmişse mutfakta hiçbir şey
/// duyulmaz ve uygulama bunu bilemez. Personel kasada terminal açmayacak;
/// denetim ayar ekranında olmalı.
///
/// NEDEN ALT SÜREÇ: `ProcessAlarmPlayer` ile aynı gerekçe — ses için pub
/// paketi eklemek `flutter build linux` bağımlılıklarını kırılganlaştırır
/// (`docs/05` §5.5). PipeWire'ın `wpctl`'i ve PulseAudio'nun `pactl`'i
/// kasada zaten var.
library;

import 'dart:convert';
import 'dart:io';

/// Bir ses çıkışı (sink).
class AudioSink {
  const AudioSink({required this.name, required this.label, this.isDefault = false});

  /// Oynatıcıya `--target` / `--device` olarak verilecek ad.
  final String name;

  /// Ayar ekranında görünen okunabilir ad.
  final String label;

  final bool isDefault;

  @override
  bool operator ==(Object other) =>
      other is AudioSink &&
      other.name == name &&
      other.label == label &&
      other.isDefault == isDefault;

  @override
  int get hashCode => Object.hash(name, label, isDefault);

  @override
  String toString() => 'AudioSink($name, $label, default: $isDefault)';
}

/// `wpctl` / `pactl` çıktısını ayrıştıran, süreç çalıştıran servis.
class SystemAudio {
  SystemAudio({
    Future<ProcessResult> Function(String command, List<String> args)? run,
    Future<bool> Function(String command)? probe,
  }) : _run = run ?? Process.run,
       _probe = probe ?? _whichProbe;

  final Future<ProcessResult> Function(String command, List<String> args) _run;
  final Future<bool> Function(String command) _probe;

  /// Kullanılabilir çıkışları listeler. Hiçbir araç yoksa boş liste döner.
  ///
  /// `pactl` önce: makine tarafından okunacak sabit bir biçimi var
  /// (`pactl list short sinks`). `wpctl status` insan için biçimlenmiş
  /// ağaç basar; ayrıştırması kırılgan ama PipeWire-only kurulumlarda
  /// (Ubuntu 24.04 varsayılanı) tek seçenek.
  Future<List<AudioSink>> listSinks() async {
    if (await _probe('pactl')) {
      final result = await _runQuietly('pactl', ['list', 'short', 'sinks']);
      if (result != null && result.exitCode == 0) {
        final sinks = parsePactlSinks(_stdout(result));
        if (sinks.isNotEmpty) return sinks;
      }
    }

    if (await _probe('wpctl')) {
      final result = await _runQuietly('wpctl', ['status']);
      if (result != null && result.exitCode == 0) {
        return parseWpctlSinks(_stdout(result));
      }
    }

    return const [];
  }

  /// Varsayılan çıkışın seviyesi (0–100). Okunamazsa `null`.
  Future<int?> currentVolume() async {
    if (await _probe('wpctl')) {
      final result = await _runQuietly('wpctl', [
        'get-volume',
        '@DEFAULT_AUDIO_SINK@',
      ]);
      if (result != null && result.exitCode == 0) {
        final value = parseWpctlVolume(_stdout(result));
        if (value != null) return value;
      }
    }

    if (await _probe('amixer')) {
      final result = await _runQuietly('amixer', ['get', 'Master']);
      if (result != null && result.exitCode == 0) {
        return parseAmixerVolume(_stdout(result));
      }
    }

    return null;
  }

  /// Varsayılan çıkışın seviyesini ayarlar ve sesi açar (unmute).
  ///
  /// Sessize alınmış bir hoparlörde seviye ayarlamak hiçbir şey yapmaz;
  /// personel "seviyeyi açtım ama ses yok" der. Bu yüzden aynı çağrıda
  /// sessiz kip de kaldırılır.
  Future<bool> setVolume(int percent) async {
    final value = percent.clamp(0, 100);

    if (await _probe('wpctl')) {
      final unmute = await _runQuietly('wpctl', [
        'set-mute',
        '@DEFAULT_AUDIO_SINK@',
        '0',
      ]);
      final set = await _runQuietly('wpctl', [
        'set-volume',
        '@DEFAULT_AUDIO_SINK@',
        (value / 100).toStringAsFixed(2),
      ]);
      if (set != null && set.exitCode == 0) return true;
      if (unmute != null && unmute.exitCode != 0) return false;
    }

    if (await _probe('amixer')) {
      final result = await _runQuietly('amixer', [
        'set',
        'Master',
        '$value%',
        'unmute',
      ]);
      return result != null && result.exitCode == 0;
    }

    return false;
  }

  Future<ProcessResult?> _runQuietly(String command, List<String> args) async {
    try {
      return await _run(command, args);
    } on Object {
      return null;
    }
  }

  static String _stdout(ProcessResult result) {
    final out = result.stdout;
    if (out is String) return out;
    if (out is List<int>) return utf8.decode(out, allowMalformed: true);
    return out.toString();
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

// ─────────────────────────── Ayrıştırıcılar (saf) ───────────────────────────
//
// Süreçten ayrı tutuldu: kasada çalıştırmadan, kaydedilmiş çıktı üzerinde
// sınanabilsin. Biçim değişirse testler haber verir.

/// `pactl list short sinks` çıktısını ayrıştırır.
///
/// Satır biçimi sekmeyle ayrılmış:
/// `43\talsa_output.pci-0000_00_1f.3.analog-stereo\tmodule\tformat\tRUNNING`
List<AudioSink> parsePactlSinks(String output) {
  final sinks = <AudioSink>[];

  for (final line in const LineSplitter().convert(output)) {
    final parts = line.split('\t');
    if (parts.length < 2) continue;

    final name = parts[1].trim();
    if (name.isEmpty) continue;

    sinks.add(AudioSink(name: name, label: _humanizeSinkName(name)));
  }

  return sinks;
}

/// `wpctl status` çıktısındaki "Sinks:" bloğunu ayrıştırır.
///
/// Blok şöyle görünür:
/// ```
///  ├─ Sinks:
///  │      *   49. Built-in Audio Analog Stereo    [vol: 0.65]
///  │          52. HDMI / DisplayPort              [vol: 1.00]
/// ```
/// `*` varsayılanı, sayı düğüm kimliğini gösterir. `--target` düğüm
/// kimliğini de kabul eder, o yüzden ad olarak kimliği kullanıyoruz.
List<AudioSink> parseWpctlSinks(String output) {
  final sinks = <AudioSink>[];
  var inSinks = false;

  for (final raw in const LineSplitter().convert(output)) {
    final line = raw.replaceAll(RegExp(r'[│├└─]'), ' ').trim();

    if (line.endsWith('Sinks:')) {
      inSinks = true;
      continue;
    }

    if (!inSinks) continue;

    // Blok, bir sonraki başlıkta (Sources:, Filters:, Streams:) biter.
    if (line.endsWith(':') && !line.endsWith('Sinks:')) break;
    if (line.isEmpty) continue;

    final match = RegExp(r'^(\*?)\s*(\d+)\.\s+(.+?)\s*(\[vol:.*\])?$')
        .firstMatch(line);
    if (match == null) continue;

    final label = match.group(3)!.trim();
    if (label.isEmpty) continue;

    sinks.add(
      AudioSink(
        name: match.group(2)!,
        label: label,
        isDefault: match.group(1) == '*',
      ),
    );
  }

  return sinks;
}

/// `wpctl get-volume @DEFAULT_AUDIO_SINK@` → `Volume: 0.65` (ya da
/// `Volume: 0.65 [MUTED]`).
///
/// Sessize alınmışsa 0 döner: personelin gördüğü değer, duyduğu sesle
/// tutarlı olmalı.
int? parseWpctlVolume(String output) {
  final match = RegExp(r'Volume:\s*([0-9]*\.?[0-9]+)').firstMatch(output);
  if (match == null) return null;

  if (output.contains('[MUTED]')) return 0;

  final value = double.tryParse(match.group(1)!);
  if (value == null) return null;

  return (value * 100).round().clamp(0, 100);
}

/// `amixer get Master` çıktısındaki ilk `[65%]` değerini okur.
int? parseAmixerVolume(String output) {
  if (output.contains('[off]')) return 0;

  final match = RegExp(r'\[(\d{1,3})%\]').firstMatch(output);
  if (match == null) return null;

  return int.parse(match.group(1)!).clamp(0, 100);
}

/// `alsa_output.pci-0000_00_1f.3.analog-stereo` → `Analog Stereo`.
String _humanizeSinkName(String name) {
  final tail = name.split('.').last.replaceAll('_', ' ').replaceAll('-', ' ');
  if (tail.trim().isEmpty) return name;

  return tail
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}
