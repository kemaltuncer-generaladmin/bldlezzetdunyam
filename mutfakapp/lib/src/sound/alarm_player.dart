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
///
/// ── SESSİZ BAŞARISIZLIK ARTIK YOK (11.08.2026) ────────────────────────
/// Eski sürüm yalnızca **istisna** yakalıyordu. `pw-play` argümanı yanlış
/// olduğu için süreç başlıyor, hata koduyla çıkıyor, istisna atılmıyordu:
/// `isMuted` `false` kalıyor, döngü hemen yeni süreç başlatıyor ve mutfak
/// hem sessiz kalıyor hem işlemci boşa dönüyordu. Artık:
///   * çıkış kodu denetleniyor ([AudioPlayerFailure.playerRejected]),
///   * hata sebebi [muteReason] ile arayüze taşınıyor,
///   * ardışık başarısızlıkta döngü **geri çekiliyor** (sıkı döngü yok),
///   * argümanlar [AudioPlayerCommand] içinde ve testli.
library;

import 'dart:async';
import 'dart:io';

import 'audio_player_command.dart';
import 'kds_sound_event.dart';

/// Yeni sipariş sesinin varlık yolu.
///
/// Geriye dönük uyumluluk için duruyor; yeni kod [KdsSoundEvent] kullanır.
const String alarmAssetPath = 'assets/sounds/yeni_siparis.wav';

/// Sesi çalabilecek komutlar, tercih sırasına göre.
const List<String> alarmPlayerCommands = AudioPlayerCommand.candidates;

/// Ardışık başarısızlıkta döngünün bekleyeceği süre.
///
/// Oynatıcı her seferinde hata koduyla dönüyorsa (yanlış argüman, kopuk
/// ses cihazı) sıkı döngü saniyede yüzlerce süreç açar. Bekleme, hatayı
/// kalıcı olarak susturmadan işlemciyi korur: cihaz geri gelirse ses de
/// geri gelir.
const Duration alarmFailureBackoff = Duration(seconds: 3);

/// Durdurulana kadar çalan alarm.
abstract interface class AlarmPlayer {
  /// Çalmaya başlar. Zaten çalıyorsa hiçbir şey yapmaz.
  Future<void> start();

  /// Susturur. Çalmıyorsa hiçbir şey yapmaz.
  Future<void> stop();

  /// Sesi **bir kez** çalar ve bitmesini bekler.
  ///
  /// Döngüyü sabit bir gecikmeyle kesmek yerine bu var: "2 saniye sonra
  /// durdur" yazmak, parçanın uzunluğunu koda gömmek demekti ve testlerde
  /// asılı zamanlayıcı bırakıyordu. Bağlantı uyarısı bunu kullanıyor —
  /// aralıklı tek uyarı, kesintisiz döngü değil.
  Future<void> playOnce();

  bool get isPlaying;

  /// Ses hiç çalınamıyor mu? (oynatıcı yok, cihaz açılamıyor)
  ///
  /// Arayüz bunu göstermeli: sessiz bir alarm, alarm olmadığını
  /// bilmemekten iyidir.
  bool get isMuted;

  /// Neden çalınamıyor? [isMuted] `false` iken `null`.
  ///
  /// "Ses yok" demek yetmiyor; personel ne yapacağını bilmiyor. Sebep
  /// tanılama ekranında ve uyarı şeridinde yazıyor.
  String? get muteReason;

  /// Seçilen oynatıcı ikilisi — tanılama için. Henüz seçilmediyse `null`.
  String? get playerExecutable;
}

/// Sesi susturulmuş sürüm — test ve "ses kapalı" ayarı için.
class SilentAlarmPlayer implements AlarmPlayer {
  SilentAlarmPlayer({this.muteReason = 'Ses ayarlardan kapatılmış.'});

  bool _playing = false;

  @override
  final String? muteReason;

  @override
  Future<void> start() async => _playing = true;

  @override
  Future<void> stop() async => _playing = false;

  @override
  Future<void> playOnce() async {}

  @override
  bool get isPlaying => _playing;

  @override
  bool get isMuted => true;

  @override
  String? get playerExecutable => null;
}

/// İşletim sisteminin ses oynatıcısını çağıran [AlarmPlayer].
class ProcessAlarmPlayer implements AlarmPlayer {
  ProcessAlarmPlayer({
    this.assetPath = alarmAssetPath,
    required Future<String> Function(String assetPath) materialize,
    List<String>? commands,
    Future<Process> Function(String command, List<String> args)? spawn,
    Future<bool> Function(String command)? probe,
    int volumePercent = 100,
    String? sink,
    Duration repeatDelay = Duration.zero,
    int maxRepeats = 0,
    Duration failureBackoff = alarmFailureBackoff,
  }) : _commands = commands ?? AudioPlayerCommand.candidates,
       _materialize = materialize,
       _spawn = spawn ?? Process.start,
       _probe = probe ?? _whichProbe,
       _volumePercent = volumePercent,
       _sink = sink,
       _repeatDelay = repeatDelay,
       _maxRepeats = maxRepeats,
       _failureBackoff = failureBackoff;

  final String assetPath;
  final List<String> _commands;
  final Future<String> Function(String assetPath) _materialize;
  final Future<Process> Function(String command, List<String> args) _spawn;
  final Future<bool> Function(String command) _probe;
  final Duration _failureBackoff;

  int _volumePercent;
  String? _sink;
  Duration _repeatDelay;
  int _maxRepeats;

  String? _filePath;
  AudioPlayerCommand? _command;
  Process? _current;
  bool _wanted = false;
  AudioPlayerFailure? _failure;

  /// Ses seviyesi (0–100). Ayar değişince çalarken de uygulanır — bir
  /// sonraki tekrar yeni seviyeyle çalar.
  set volumePercent(int value) => _volumePercent = value.clamp(0, 100);

  /// Çıkış cihazı (PipeWire/PulseAudio sink adı). `null` = varsayılan.
  set sink(String? value) => _sink = value;

  /// İki tekrar arasındaki bekleme. `Duration.zero` = aralıksız.
  set repeatDelay(Duration value) => _repeatDelay = value;

  /// En fazla kaç tekrar? 0 = sınırsız (onaylanana kadar).
  set maxRepeats(int value) => _maxRepeats = value < 0 ? 0 : value;

  @override
  bool get isPlaying => _wanted;

  @override
  bool get isMuted => _failure != null;

  @override
  String? get muteReason {
    final failure = _failure;
    if (failure == null) return null;

    final command = _command;
    if (failure == AudioPlayerFailure.playerRejected && command != null) {
      return '${failure.message} (${command.executable})';
    }

    return failure.message;
  }

  @override
  String? get playerExecutable => _command?.executable;

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

  @override
  Future<void> playOnce() async => _playOnce();

  /// Tek bir çalma denemesi. Başarılıysa `true`.
  ///
  /// Döngü bayrağına DOKUNMAZ: [playOnce] tek atışlık kullanımda (bağlantı
  /// uyarısı) döngüyü kapatmamalı.
  Future<bool> _playOnce() async {
    final path = _filePath ??= await _materializeQuietly();
    if (path == null) return false;

    final command = _command ??= await _pickCommand();
    if (command == null) {
      _failure = AudioPlayerFailure.noPlayer;
      return false;
    }

    final args = command.argsFor(
      filePath: path,
      volumePercent: _volumePercent,
      sink: command.supportsSink ? _sink : null,
    );

    try {
      final process = await _spawn(command.executable, args);
      _current = process;

      final exitCode = await process.exitCode;

      // ÇIKIŞ KODU DENETİMİ — sahadaki sessiz hatanın yakalandığı yer.
      // Süreç başlamış olması sesin çıktığı anlamına gelmiyor.
      if (exitCode != 0) {
        _failure = AudioPlayerFailure.playerRejected;
        return false;
      }

      _failure = null;
      return true;
    } on Object {
      _failure = AudioPlayerFailure.spawnFailed;
      return false;
    } finally {
      _current = null;
    }
  }

  Future<void> _loop() async {
    var played = 0;

    while (_wanted) {
      final ok = await _playOnce();

      if (ok) {
        played++;

        // Tekrar sınırı: personel uzun süre gelemiyorsa hoparlörü sonsuza
        // kadar çaldırmak, sesin fişini çektirir. 0 = sınırsız (varsayılan,
        // "onaylayana kadar susmaz" kuralı).
        if (_maxRepeats > 0 && played >= _maxRepeats) {
          _wanted = false;
          return;
        }

        if (_repeatDelay > Duration.zero) {
          await Future<void>.delayed(_repeatDelay);
        }

        continue;
      }

      // Oynatıcı hiç yoksa ya da dosya çıkarılamıyorsa denemeye devam
      // etmek anlamsız — durum kendi kendine düzelmez.
      if (_failure == AudioPlayerFailure.noPlayer ||
          _failure == AudioPlayerFailure.assetUnavailable) {
        _wanted = false;
        return;
      }

      // Geçici olabilecek hata (cihaz meşgul, süreç reddetti): geri çekil,
      // sıkı döngüye girme. Susturmuyoruz; cihaz gelirse ses de gelir.
      await Future<void>.delayed(_failureBackoff);
    }
  }

  Future<String?> _materializeQuietly() async {
    try {
      return await _materialize(assetPath);
    } on Object {
      _failure = AudioPlayerFailure.assetUnavailable;
      return null;
    }
  }

  /// İlk bulunan oynatıcıyı seçer.
  ///
  /// Varlığını çalıştırarak değil yol aramasıyla sınıyoruz: `--version`
  /// çağrısı bile bazı kurulumlarda ses cihazını açıyor ve gereksiz
  /// gecikme yaratıyor.
  Future<AudioPlayerCommand?> _pickCommand() async {
    for (final command in _commands) {
      if (await _probe(command)) return AudioPlayerCommand(command);
    }

    return null;
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
