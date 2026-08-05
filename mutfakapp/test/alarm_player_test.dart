/// Yeni sipariş alarmı — `docs/05-mutfakapp.md` §3.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/sound/alarm_player.dart';

/// Gerçek süreç yerine denetlenebilir bir sahte.
class FakeProcess implements Process {
  FakeProcess(this.command);

  final String command;
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

void main() {
  late List<FakeProcess> spawned;

  ProcessAlarmPlayer build({
    Future<String> Function(String)? materialize,
    List<String>? commands,
  }) => ProcessAlarmPlayer(
    materialize: materialize ?? (_) async => '/tmp/ses.wav',
    commands: commands ?? ['aplay'],
    spawn: (command, args) async {
      final p = FakeProcess(command);
      spawned.add(p);
      return p;
    },
  );

  setUp(() => spawned = []);

  test('başlayınca çalar', () async {
    final player = build();
    await player.start();
    await pumpEventQueue();

    expect(player.isPlaying, isTrue);
    expect(spawned, hasLength(1));
  });

  test('ses bitince YENİDEN başlar — onaylanana kadar susmaz', () async {
    // Tek bir bip mutfakta duyulmaz. Israrcı alarmın tamamı bu davranışta.
    final player = build();
    await player.start();
    await pumpEventQueue();

    spawned.first.finish();
    await pumpEventQueue();

    expect(spawned, hasLength(2), reason: 'Parça bitince yenisi başlamalı.');
    await player.stop();
  });

  test('bir sonraki ses öncekinden ÖNCE başlamaz', () async {
    // Üst üste binen sesler alarmı gürültüye çevirir.
    final player = build();
    await player.start();
    await pumpEventQueue();
    await pumpEventQueue();

    expect(spawned, hasLength(1));
    await player.stop();
  });

  test('durdurunca süreci öldürür ve döngü biter', () async {
    final player = build();
    await player.start();
    await pumpEventQueue();

    await player.stop();
    await pumpEventQueue();

    expect(spawned.first.killed, isTrue, reason: 'Onaylayınca ses o an kesilmeli.');
    expect(player.isPlaying, isFalse);
    expect(spawned, hasLength(1), reason: 'Durdurulduktan sonra yeni ses başlamamalı.');
  });

  test('iki kez başlatmak iki ses açmaz', () async {
    final player = build();
    await player.start();
    await player.start();
    await pumpEventQueue();

    expect(spawned, hasLength(1));
    await player.stop();
  });

  test('oynatıcı yoksa susturulmuş sayılır ve çökmez', () async {
    final player = build(commands: ['boyle-bir-komut-yok']);
    await player.start();
    await pumpEventQueue();

    expect(player.isMuted, isTrue);
    expect(player.isPlaying, isFalse);
  });

  test('ses dosyası açılamazsa susturulmuş sayılır ve çökmez', () async {
    // Mutfak, ses çalınamıyor diye sipariş göremez hâle gelemez.
    final player = build(
      materialize: (_) async => throw const FileSystemException('yok'),
    );
    await player.start();
    await pumpEventQueue();

    expect(player.isMuted, isTrue);
    expect(player.isPlaying, isFalse);
  });

  test('sessiz sürüm hiçbir şey çalmaz ama durumu bildirir', () async {
    final player = SilentAlarmPlayer();
    await player.start();

    expect(player.isPlaying, isTrue);
    expect(player.isMuted, isTrue);

    await player.stop();
    expect(player.isPlaying, isFalse);
  });
}
