/// Sesli anons — argüman üretimi ve üst üste binmeme kuralı.
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/sound/alarm_player.dart';
import 'package:mutfakapp/src/sound/new_order_alarm.dart';
import 'package:mutfakapp/src/sound/tts_announcer.dart';

import 'alarm_player_test.dart' show FakeProcess, waitUntil;
import 'fake_kitchen_service.dart';

KitchenOrder order(int id, {int items = 1}) => makeOrder(
  id: id,
  items: [
    for (var i = 0; i < items; i++)
      KitchenOrderItem(name: 'Ürün $i', quantity: 1),
  ],
);

/// Anonsları kaydeden sahte.
class SpyAnnouncer implements TtsAnnouncer {
  final List<String> spoken = [];

  @override
  Future<void> announce(String text) async => spoken.add(text);

  @override
  bool get isUnavailable => false;

  @override
  String? get unavailableReason => null;

  @override
  String? get executable => 'spy';
}

void main() {
  group('argümanlar', () {
    test('spd-say Türkçe dil ve -w bekleme alır', () {
      final args = ttsArgsFor('spd-say', 'merhaba', 100);

      expect(args, containsAllInOrder(['-l', 'tr']));
      expect(args, contains('-w'));
      expect(args.last, 'merhaba');
    });

    test('spd-say hızı -100..100 aralığına eşlenir', () {
      expect(ttsArgsFor('spd-say', 'x', 100), containsAllInOrder(['-r', '0']));
      expect(ttsArgsFor('spd-say', 'x', 50), containsAllInOrder(['-r', '-50']));
      expect(ttsArgsFor('spd-say', 'x', 200), containsAllInOrder(['-r', '100']));
    });

    test('espeak-ng dakikada kelime ister', () {
      // 175 varsayılan; %200 iki katı.
      expect(
        ttsArgsFor('espeak-ng', 'x', 200),
        containsAllInOrder(['-s', '350']),
      );
    });

    test('sınır dışı hız kırpılır', () {
      expect(ttsArgsFor('spd-say', 'x', 5000), containsAllInOrder(['-r', '100']));
    });
  });

  group('ProcessTtsAnnouncer', () {
    test('araç yoksa sessizce geçer ve sebebini söyler', () async {
      final announcer = ProcessTtsAnnouncer(
        commands: const ['yok-boyle-bir-sey'],
        probe: (_) async => false,
        spawn: (_, _) async => throw StateError('çağrılmamalı'),
      );

      await announcer.announce('merhaba');

      expect(announcer.isUnavailable, isTrue);
      expect(announcer.unavailableReason, contains('bulunamadı'));
    });

    test('boş metin süreç açmaz', () async {
      var spawns = 0;
      final announcer = ProcessTtsAnnouncer(
        probe: (_) async => true,
        spawn: (c, a) async {
          spawns++;
          return FakeProcess(c, a)..finish();
        },
      );

      await announcer.announce('   ');

      expect(spawns, 0);
    });

    test('süren anonsu keser — iki ses üst üste binmez', () async {
      final processes = <FakeProcess>[];
      final announcer = ProcessTtsAnnouncer(
        probe: (_) async => true,
        spawn: (c, a) async {
          final p = FakeProcess(c, a);
          processes.add(p);
          return p;
        },
      );

      unawaited(announcer.announce('birinci'));
      await waitUntil(() => processes.isNotEmpty);

      unawaited(announcer.announce('ikinci'));
      await waitUntil(() => processes.length >= 2);

      expect(processes.first.killed, isTrue);
    });
  });

  group('yeni sipariş anonsu', () {
    test('AÇILIŞTA bekleyenler okunmaz — 12 sipariş arka arkaya okunamaz', () {
      final spy = SpyAnnouncer();
      final alarm = NewOrderAlarm(_MutePlayer(), announcer: spy);

      alarm.onOrders([order(1), order(2), order(3)]);

      expect(spy.spoken, isEmpty);
    });

    test('sonradan düşen sipariş okunur', () {
      final spy = SpyAnnouncer();
      final alarm = NewOrderAlarm(_MutePlayer(), announcer: spy);

      alarm.onOrders([order(1)]);
      alarm.onOrders([order(1), order(7, items: 3)]);

      expect(spy.spoken, hasLength(1));
      expect(spy.spoken.single, '7 numaralı yeni sipariş, 3 ürün');
    });

    test('aynı sipariş iki kez okunmaz', () {
      final spy = SpyAnnouncer();
      final alarm = NewOrderAlarm(_MutePlayer(), announcer: spy);

      alarm.onOrders([order(1)]);
      alarm.onOrders([order(1), order(2)]);
      alarm.onOrders([order(1), order(2)]);

      expect(spy.spoken, hasLength(1));
    });

    test('anons kapalıyken alarm yine de çalar', () {
      final player = _MutePlayer();
      final alarm = NewOrderAlarm(player, announcer: const SilentTtsAnnouncer());

      alarm.onOrders([order(1)]);

      expect(player.started, isTrue);
    });
  });
}

/// Ses çalmadan yalnız çağrıları kaydeden oynatıcı.
class _MutePlayer implements AlarmPlayer {
  bool started = false;

  @override
  Future<void> start() async => started = true;

  @override
  Future<void> stop() async => started = false;

  @override
  Future<void> playOnce() async {}

  @override
  bool get isPlaying => started;

  @override
  bool get isMuted => false;

  @override
  String? get muteReason => null;

  @override
  String? get playerExecutable => 'test';
}
