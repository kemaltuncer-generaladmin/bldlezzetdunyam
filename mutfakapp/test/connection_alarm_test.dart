/// Bağlantı kopma uyarısı — `docs/05-mutfakapp.md` §3.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/sound/alarm_player.dart';
import 'package:mutfakapp/src/sound/connection_alarm.dart';

/// Kaç kez çalmaya başladığını sayan oynatıcı.
class CountingAlarmPlayer implements AlarmPlayer {
  int starts = 0;
  int stops = 0;
  bool playing = false;

  bool muted = false;

  @override
  Future<void> start() async {
    starts++;
    playing = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    playing = false;
  }

  @override
  Future<void> playOnce() async {
    starts++;
  }

  @override
  bool get isPlaying => playing;

  @override
  bool get isMuted => muted;
}

/// Elle ilerletilen zamanlayıcı — gerçek 45 saniyeyi beklemeyelim.
class FakeTimer implements Timer {
  FakeTimer(this.callback);

  final void Function(Timer) callback;
  bool cancelled = false;

  void fire() {
    if (!cancelled) callback(this);
  }

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;
}

void main() {
  late CountingAlarmPlayer player;
  late List<FakeTimer> timers;

  ConnectionAlarm build() {
    timers = [];

    return ConnectionAlarm(
      player,
      scheduler: (_, cb) {
        final t = FakeTimer(cb);
        timers.add(t);
        return t;
      },
    );
  }

  setUp(() => player = CountingAlarmPlayer());

  test('bağlantı kopunca HEMEN uyarır', () async {
    // Kopmayı 45 saniye sonra duyurmak, kopmanın kendisi kadar zararlı.
    final alarm = build();

    final state = alarm.onConnectionChanged(disconnected: true);
    await pumpEventQueue();

    expect(state.disconnected, isTrue);
    expect(player.starts, 1);
  });

  test('kopukluk sürerken aralıklı tekrarlar', () async {
    final alarm = build();
    alarm.onConnectionChanged(disconnected: true);
    await pumpEventQueue();

    timers.single.fire();
    await pumpEventQueue();

    expect(player.starts, 2, reason: 'Uyarı aralıkla tekrar etmeli.');
    alarm.dispose();
  });

  test('aynı durum tekrar bildirilirse yeniden başlatmaz', () async {
    // Yoklama saniyede bir "hâlâ kopuk" diyor; her seferinde ses başlatmak
    // aralık ayarını anlamsız kılardı.
    final alarm = build();
    alarm.onConnectionChanged(disconnected: true);
    await pumpEventQueue();

    alarm.onConnectionChanged(disconnected: true);
    alarm.onConnectionChanged(disconnected: true);
    await pumpEventQueue();

    expect(player.starts, 1);
    alarm.dispose();
  });

  test('bağlantı gelince susar', () async {
    final alarm = build();
    alarm.onConnectionChanged(disconnected: true);
    await pumpEventQueue();

    final state = alarm.onConnectionChanged(disconnected: false);

    expect(state.disconnected, isFalse);
    expect(timers.single.cancelled, isTrue);
  });

  test('SUSTURULAMAZ — sesi durduran tek şey bağlantının gelmesidir', () async {
    // Yeni sipariş alarmının sustur düğmesi var çünkü personel siparişi
    // görüp onaylayabilir. Bağlantı kopmasında susturmak, tek uyarıyı
    // kapatıp mutfağı kör bırakmak demek ve kopukluk saatlerce sürebilir.
    final alarm = build();
    alarm.onConnectionChanged(disconnected: true);
    await pumpEventQueue();

    // Kopukluk sürdükçe her aralıkta yeniden çalar; durduracak bir yol yok.
    for (var i = 0; i < 3; i++) {
      timers.single.fire();
      await pumpEventQueue();
    }

    expect(player.starts, 4, reason: 'İlk uyarı + üç tekrar.');

    // Yalnızca bağlantının gelmesi susturur.
    alarm.onConnectionChanged(disconnected: false);
    final oncekiBaslangic = player.starts;
    await pumpEventQueue();

    expect(player.starts, oncekiBaslangic);
    alarm.dispose();
  });

  test('ses çalınamıyorsa durum bunu bildirir', () async {
    player.muted = true;
    final alarm = build();

    final state = alarm.onConnectionChanged(disconnected: true);

    expect(state.muted, isTrue);
    expect(
      state.silentWhileDisconnected,
      isTrue,
      reason: 'Kopukken sessizlik arayüzde görünmeli.',
    );
    alarm.dispose();
  });

  test('dispose zamanlayıcıyı bırakmaz', () async {
    final alarm = build();
    alarm.onConnectionChanged(disconnected: true);
    await pumpEventQueue();

    alarm.dispose();

    expect(timers.single.cancelled, isTrue);
  });
}
