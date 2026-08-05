/// Yeni sipariş alarmı — `docs/05-mutfakapp.md` §3.
///
/// DAVRANIŞ: yeni sipariş geldiğinde ses **personel onaylayana kadar
/// durmaz**. Tek bir "bip" mutfakta duyulmaz; ocak başındaki kişi elleri
/// doluyken ekrana bakmaz ve sipariş fark edilmeden bekler. Yemek sipariş
/// uygulamalarının hepsi bu yüzden ısrarcı alarm kullanır.
///
/// NEDEN SİSTEM OYNATICISI, NEDEN PUB PAKETİ DEĞİL:
/// `audioplayers` gibi paketler Linux'ta GStreamer geliştirme kitaplıkları
/// ister ve bunlar kurulu değilse `flutter build linux` **derleme anında**
/// patlar. Kasa tek amaçlı bir Ubuntu makinesi; üzerinde `pw-play` ve
/// `aplay` zaten var (ikisi de sahada doğrulandı). Yeni bir bağımlılık
/// eklemek, kurulumu kırılgan hâle getirmekten başka bir şey kazandırmıyor.
///
/// NEDEN DÖNGÜYÜ KENDİMİZ KURUYORUZ: `aplay` ve `pw-play` döngü seçeneği
/// sunmuyor. Süreç bitince yenisini başlatıyoruz. Bir sonrakini **önceki
/// bitmeden** başlatmak sesleri üst üste bindirirdi.
library;

import 'dart:async';
import 'dart:io';

/// Yeni sipariş sesinin varlık yolu.
const String alarmAssetPath = 'assets/sounds/yeni_siparis.wav';

/// Sesi çalabilecek komutlar, tercih sırasına göre.
///
/// `pw-play` önce: kasa PipeWire kullanıyor ve `aplay` ALSA üzerinden
/// giderken cihaz meşgulse sessizce başarısız olabiliyor.
const List<String> alarmPlayerCommands = ['pw-play', 'aplay'];

/// Durdurulana kadar çalan alarm.
abstract interface class AlarmPlayer {
  /// Çalmaya başlar. Zaten çalıyorsa hiçbir şey yapmaz.
  Future<void> start();

  /// Susturur. Çalmıyorsa hiçbir şey yapmaz.
  Future<void> stop();

  bool get isPlaying;

  /// Ses hiç çalınamıyor mu? (oynatıcı yok, cihaz açılamıyor)
  ///
  /// Arayüz bunu göstermeli: sessiz bir alarm, alarm olmadığını
  /// bilmemekten iyidir.
  bool get isMuted;
}

/// Sesi susturulmuş sürüm — test ve "ses kapalı" ayarı için.
class SilentAlarmPlayer implements AlarmPlayer {
  bool _playing = false;

  @override
  Future<void> start() async => _playing = true;

  @override
  Future<void> stop() async => _playing = false;

  @override
  bool get isPlaying => _playing;

  @override
  bool get isMuted => true;
}

/// İşletim sisteminin ses oynatıcısını çağıran [AlarmPlayer].
class ProcessAlarmPlayer implements AlarmPlayer {
  ProcessAlarmPlayer({
    this.assetPath = alarmAssetPath,
    required Future<String> Function(String assetPath) materialize,
    List<String>? commands,
    Future<Process> Function(String command, List<String> args)? spawn,
  }) : _commands = commands ?? alarmPlayerCommands,
       _materialize = materialize,
       _spawn = spawn ?? Process.start;

  final String assetPath;
  final List<String> _commands;
  final Future<String> Function(String assetPath) _materialize;
  final Future<Process> Function(String command, List<String> args) _spawn;

  String? _filePath;
  String? _command;
  Process? _current;
  bool _wanted = false;
  bool _muted = false;

  @override
  bool get isPlaying => _wanted;

  @override
  bool get isMuted => _muted;

  @override
  Future<void> start() async {
    if (_wanted) return;
    _wanted = true;

    unawaited(_loop());
  }

  @override
  Future<void> stop() async {
    _wanted = false;

    // Süreci ÖLDÜRÜYORUZ, bitmesini beklemiyoruz. Personel onayladıysa ses
    // o anda kesilmeli; kalan üç saniyeyi dinletmek onaylamanın işe
    // yaramadığı izlenimi verir.
    _current?.kill();
    _current = null;
  }

  Future<void> _loop() async {
    while (_wanted) {
      final path = _filePath ??= await _materializeQuietly();
      if (path == null) return;

      final command = _command ??= await _pickCommand();
      if (command == null) {
        _muted = true;
        _wanted = false;
        return;
      }

      try {
        final process = await _spawn(command, ['-q', path]);
        _current = process;
        await process.exitCode;
      } on Object {
        _muted = true;
        _wanted = false;
        return;
      } finally {
        _current = null;
      }
    }
  }

  Future<String?> _materializeQuietly() async {
    try {
      return await _materialize(assetPath);
    } on Object {
      _muted = true;
      _wanted = false;
      return null;
    }
  }

  /// İlk çalışan oynatıcıyı seçer.
  ///
  /// Varlığını `which` ile değil, çalıştırarak sınamıyoruz: `--version`
  /// çağrısı bile bazı kurulumlarda ses cihazını açıyor ve gereksiz
  /// gecikme yaratıyor. Yol araması yeterli.
  Future<String?> _pickCommand() async {
    for (final command in _commands) {
      final result = await Process.run('which', [command]);
      if (result.exitCode == 0) return command;
    }

    return null;
  }
}
