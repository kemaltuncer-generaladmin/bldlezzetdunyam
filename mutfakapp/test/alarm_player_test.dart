/// Yeni sipariş alarmı — `docs/05-mutfakapp.md` §3.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/sound/alarm_player.dart';
import 'package:mutfakapp/src/sound/audio_player_command.dart';

/// Gerçek süreç yerine denetlenebilir bir sahte.
class FakeProcess implements Process {
  FakeProcess(this.command, this.args);

  final String command;
  final List<String> args;
  final Completer<int> _exit = Completer<int>();
  bool killed = false;

  void finish([int code = 0]) {
    if (!_exit.isCompleted) _exit.complete(code);
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    finish(-15);
    return true;
  }

  @override
  int get pid => 1;

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  Stream<List<int>> get stdout => const Stream.empty();

  @override
  IOSink get stdin => throw UnsupportedError('Bu testte kullanılmıyor');
}

/// [condition] gerçekleşene kadar **gerçek zamanda** bekler.
///
/// `pumpEventQueue` yalnızca mikro görev kuyruğunu boşaltır. Oynatıcı
/// döngüsü gerçek gecikmeler kullanıyor (geri çekilme, tekrar arası
/// bekleme); tek bir `pumpEventQueue` bitmesini beklemiyordu ve test dolu
/// bir paket koşusunda rastgele düşüyordu.
Future<void> waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late List<FakeProcess> spawned;

  ProcessAlarmPlayer build({
    Future<String> Function(String)? materialize,
    List<String>? commands,
    Set<String> available = const {'aplay'},
    int exitCode = 0,
    bool autoFinish = false,
    int volumePercent = 100,
    String? sink,
    Duration repeatDelay = Duration.zero,
    int maxRepeats = 0,
    Duration failureBackoff = const Duration(milliseconds: 20),
  }) => ProcessAlarmPlayer(
    materialize: materialize ?? (_) async => '/tmp/ses.wav',
    commands: commands ?? ['aplay'],
    // `which` YERİNE enjekte edilen sonda: gerçek makinede hangi ikilinin
    // kurulu olduğuna bağlı test, başka bir kasada sessizce başka şeyi
    // sınar. Sonda testin denetiminde olmalı.
    probe: (command) async => available.contains(command),
    volumePercent: volumePercent,
    sink: sink,
    repeatDelay: repeatDelay,
    maxRepeats: maxRepeats,
    failureBackoff: failureBackoff,
    spawn: (command, args) async {
      final p = FakeProcess(command, args);
      spawned.add(p);
      if (autoFinish) p.finish(exitCode);
      return p;
    },
  );

  setUp(() => spawned = []);

  test('başlayınca çalar', () async {
    final player = build();
    await player.start();
    await waitUntil(() => spawned.isNotEmpty);

    expect(player.isPlaying, isTrue);
    expect(spawned, hasLength(1));
    await player.stop();
  });

  test('ses bitince YENİDEN başlar — onaylanana kadar susmaz', () async {
    // Tek bir bip mutfakta duyulmaz. Israrcı alarmın tamamı bu davranışta.
    final player = build();
    await player.start();
    await waitUntil(() => spawned.isNotEmpty);

    spawned.first.finish();
    await waitUntil(() => spawned.length >= 2);

    expect(spawned, hasLength(2), reason: 'Parça bitince yenisi başlamalı.');
    await player.stop();
  });

  test('bir sonraki ses öncekinden ÖNCE başlamaz', () async {
    // Üst üste binen sesler alarmı gürültüye çevirir.
    final player = build();
    await player.start();
    await waitUntil(() => spawned.isNotEmpty);
    await pumpEventQueue();

    expect(spawned, hasLength(1));
    await player.stop();
  });

  test('durdurunca süreci öldürür ve döngü biter', () async {
    final player = build();
    await player.start();
    await waitUntil(() => spawned.isNotEmpty);

    await player.stop();
    await pumpEventQueue();

    expect(
      spawned.first.killed,
      isTrue,
      reason: 'Onaylayınca ses o an kesilmeli.',
    );
    expect(player.isPlaying, isFalse);
    expect(
      spawned,
      hasLength(1),
      reason: 'Durdurulduktan sonra yeni ses başlamamalı.',
    );
  });

  test('iki kez başlatmak iki ses açmaz', () async {
    final player = build();
    await player.start();
    await player.start();
    await waitUntil(() => spawned.isNotEmpty);

    expect(spawned, hasLength(1));
    await player.stop();
  });

  test('oynatıcı yoksa susturulmuş sayılır ve sebebi söyler', () async {
    final player = build(commands: ['boyle-bir-komut-yok'], available: {});
    await player.start();
    await waitUntil(() => player.isMuted);

    expect(player.isMuted, isTrue);
    expect(player.isPlaying, isFalse);
    expect(player.muteReason, contains('bulunamadı'));
  });

  test('ses dosyası açılamazsa susturulmuş sayılır ve çökmez', () async {
    // Mutfak, ses çalınamıyor diye sipariş göremez hâle gelemez.
    final player = build(
      materialize: (_) async => throw const FileSystemException('yok'),
    );
    await player.start();
    await waitUntil(() => player.isMuted);

    expect(player.isMuted, isTrue);
    expect(player.isPlaying, isFalse);
    expect(player.muteReason, contains('diske yazılamadı'));
  });

  test('sessiz sürüm hiçbir şey çalmaz ama durumu bildirir', () async {
    final player = SilentAlarmPlayer();
    await player.start();

    expect(player.isPlaying, isTrue);
    expect(player.isMuted, isTrue);
    expect(player.muteReason, isNotNull);

    await player.stop();
    expect(player.isPlaying, isFalse);
  });

  // ── Saha hatası: süreç başlıyor ama ses çıkmıyor (11.08.2026) ──────────

  group('oynatıcı hata koduyla dönerse', () {
    test('SESSİZ SAYILIR — süreç başladı diye ses çıktı sanılmaz', () async {
      // Sahadaki `pw-play -q <dosya>` tam olarak buydu: süreç başladı,
      // istisna atılmadı, `isMuted` false kaldı, hoparlör sustu.
      final player = build(exitCode: 1, autoFinish: true);
      await player.start();
      await waitUntil(() => player.isMuted);

      expect(player.isMuted, isTrue);
      expect(player.muteReason, contains('hata koduyla'));
      await player.stop();
    });

    test('SIKI DÖNGÜYE GİRMEZ — geri çekilerek dener', () async {
      // Geri çekilme olmasaydı saniyede yüzlerce süreç açılırdı.
      final player = build(
        exitCode: 1,
        autoFinish: true,
        failureBackoff: const Duration(milliseconds: 60),
      );
      await player.start();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await player.stop();

      expect(
        spawned.length,
        lessThan(6),
        reason: 'Hata geri çekilmeli, sıkı döngüye girmemeli.',
      );
      expect(
        spawned.length,
        greaterThanOrEqualTo(2),
        reason: 'Geçici hata kalıcı susturma değildir; denemeye devam eder.',
      );
    });
  });

  test('tekrar sınırı dolunca döngü durur', () async {
    final player = build(autoFinish: true, maxRepeats: 3);
    await player.start();
    await waitUntil(() => !player.isPlaying);

    expect(spawned, hasLength(3));
    expect(player.isPlaying, isFalse);
  });

  test('seviye ve çıkış cihazı komuta geçer', () async {
    final player = build(
      commands: ['pw-play'],
      available: {'pw-play'},
      volumePercent: 40,
      sink: 'hoparlor-1',
    );
    await player.start();
    await waitUntil(() => spawned.isNotEmpty);

    expect(spawned.first.args, contains('--volume=0.400'));
    expect(spawned.first.args, contains('--target=hoparlor-1'));
    await player.stop();
  });

  test('tercih sırasına göre ilk BULUNAN ikili seçilir', () async {
    // pw-play yoksa aplay'e düşmeli; ikisi de yoksa susmalı.
    final player = build(
      commands: const ['pw-play', 'paplay', 'aplay'],
      available: {'aplay'},
    );
    await player.start();
    await waitUntil(() => spawned.isNotEmpty);

    expect(player.playerExecutable, 'aplay');
    await player.stop();
  });

  // ── Argüman üretimi (saf) ─────────────────────────────────────────────

  group('komut argümanları', () {
    test('pw-play `-q` ALMAZ — `-q` orada quality demek, dosyayı yutar', () {
      // Bu tam olarak sahadaki hatanın regresyon testi.
      final args = const AudioPlayerCommand('pw-play').argsFor(
        filePath: '/tmp/a.wav',
        volumePercent: 100,
      );

      expect(args, isNot(contains('-q')));
      expect(args.last, '/tmp/a.wav', reason: 'Dosya yolu argüman olarak kalmalı.');
    });

    test('aplay `-q` ALIR — orada gerçekten sessiz kip', () {
      final args = const AudioPlayerCommand('aplay').argsFor(
        filePath: '/tmp/a.wav',
      );

      expect(args, ['-q', '/tmp/a.wav']);
    });

    test('paplay seviyeyi 0-65536 aralığında ister', () {
      final args = const AudioPlayerCommand('paplay').argsFor(
        filePath: '/tmp/a.wav',
        volumePercent: 50,
      );

      expect(args, contains('--volume=32768'));
    });

    test('aplay seviye desteklemez, çıkış cihazı da almaz', () {
      const command = AudioPlayerCommand('aplay');

      expect(command.supportsVolume, isFalse);
      expect(command.supportsSink, isFalse);
      expect(
        command.argsFor(filePath: '/a.wav', volumePercent: 10, sink: 'x'),
        ['-q', '/a.wav'],
      );
    });

    test('boş çıkış cihazı argüman üretmez', () {
      final args = const AudioPlayerCommand('pw-play').argsFor(
        filePath: '/a.wav',
        sink: '   ',
      );

      expect(args.where((a) => a.startsWith('--target')), isEmpty);
    });

    test('seviye 0-100 dışına taşamaz', () {
      final args = const AudioPlayerCommand('pw-play').argsFor(
        filePath: '/a.wav',
        volumePercent: 480,
      );

      expect(args, contains('--volume=1.000'));
    });
  });
}
