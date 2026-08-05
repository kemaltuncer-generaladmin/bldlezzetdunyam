/// Yeni sipariş alarmının karar mantığı.
///
/// Müşterinin kuralı: *"onaylaya basana kadar susmuyor."* Buradaki her test o
/// cümlenin bir parçasını sabitler.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/sound/alarm_player.dart';
import 'package:mutfakapp/src/sound/new_order_alarm.dart';

import 'fake_kitchen_service.dart';

/// Başlatma/durdurma çağrılarını sayan oynatıcı.
class SpyPlayer implements AlarmPlayer {
  int starts = 0;
  int stops = 0;
  bool _playing = false;
  bool muted = false;

  @override
  bool get isPlaying => _playing;

  @override
  bool get isMuted => muted;

  @override
  Future<void> start() async {
    if (_playing) return;
    _playing = true;
    starts++;
  }

  @override
  Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    stops++;
  }
}

KitchenOrder yeni(int id) => makeOrder(id: id, status: OrderStatus.yeni);

void main() {
  group('NewOrderAlarmPolicy', () {
    test('bekleyen sipariş yokken çalmaz', () {
      final policy = NewOrderAlarmPolicy();
      expect(policy.apply(const []), isFalse);
      expect(policy.pendingCount, isZero);
    });

    test('tek bir `yeni` sipariş alarmı başlatır', () {
      final policy = NewOrderAlarmPolicy();
      expect(policy.apply([yeni(1)]), isTrue);
      expect(policy.pendingCount, 1);
    });

    test('AÇILIŞTA zaten bekleyen sipariş varsa çalar', () {
      // Elektrik kesintisi sonrası: ilk yayın "zaten oradaydı" diye
      // yutulamaz, o sipariş hâlâ onay bekliyor.
      final policy = NewOrderAlarmPolicy();
      expect(policy.apply([yeni(1), yeni(2)]), isTrue);
    });

    test('onaylanmış siparişler alarm üretmez', () {
      final policy = NewOrderAlarmPolicy();
      final sound = policy.apply([
        makeOrder(id: 1, status: OrderStatus.onaylandi),
        makeOrder(id: 2, status: OrderStatus.hazirlaniyor),
        makeOrder(id: 3, status: OrderStatus.hazir),
      ]);

      expect(sound, isFalse);
      expect(policy.pendingCount, isZero);
    });

    test('tek bekleyen onaylanınca susar', () {
      final policy = NewOrderAlarmPolicy()..apply([yeni(1)]);
      final sound = policy.apply([
        makeOrder(id: 1, status: OrderStatus.onaylandi),
      ]);

      expect(sound, isFalse);
    });

    test('başka bekleyen kaldıysa çalmaya DEVAM eder', () {
      final policy = NewOrderAlarmPolicy()..apply([yeni(1), yeni(2)]);
      final sound = policy.apply([
        makeOrder(id: 1, status: OrderStatus.onaylandi),
        yeni(2),
      ]);

      expect(sound, isTrue);
      expect(policy.pendingCount, 1);
    });

    test('susturma o anki siparişleri kapsar', () {
      final policy = NewOrderAlarmPolicy()..apply([yeni(1), yeni(2)]);

      expect(policy.silence(), isFalse);
      expect(policy.isSilenced, isTrue);
      // Aynı liste yeniden gelirse sessizlik korunur; yoklama her beş saniyede
      // aynı siparişleri getirdiği için bu şart.
      expect(policy.apply([yeni(1), yeni(2)]), isFalse);
    });

    test('susturmadan SONRA düşen sipariş alarmı geri getirir', () {
      final policy = NewOrderAlarmPolicy()
        ..apply([yeni(1)])
        ..silence();

      expect(policy.apply([yeni(1), yeni(2)]), isTrue);
    });

    test('susturma kalıcı değildir: liste boşalıp dolunca yeniden çalar', () {
      final policy = NewOrderAlarmPolicy()
        ..apply([yeni(1)])
        ..silence();

      expect(policy.apply(const []), isFalse);
      expect(policy.apply([yeni(2)]), isTrue);
    });

    test('susturma kümesi sınırsız büyümez', () {
      final policy = NewOrderAlarmPolicy();
      for (var id = 0; id < 100; id++) {
        policy
          ..apply([yeni(id)])
          ..silence();
      }

      policy.apply(const []);
      expect(policy.pendingIds, isEmpty);
      // Yüz siparişten sonra yeni bir kimlik hâlâ alarm üretmeli.
      expect(policy.apply([yeni(1000)]), isTrue);
    });

    test('iptal edilen sipariş bekleyenlerden düşer', () {
      final policy = NewOrderAlarmPolicy()..apply([yeni(1)]);
      expect(
        policy.apply([makeOrder(id: 1, status: OrderStatus.iptal)]),
        isFalse,
      );
    });
  });

  group('NewOrderAlarm', () {
    test('kararı oynatıcıya bağlar', () async {
      final player = SpyPlayer();
      final alarm = NewOrderAlarm(player);

      alarm.onOrders([yeni(1)]);
      expect(player.starts, 1);
      expect(alarm.state.sounding, isTrue);
      expect(alarm.state.pendingCount, 1);

      alarm.onOrders([makeOrder(id: 1, status: OrderStatus.onaylandi)]);
      expect(player.stops, 1);
      expect(alarm.state.sounding, isFalse);
    });

    test('aynı liste iki kez gelirse ikinci ses açılmaz', () {
      // Yoklama her beş saniyede aynı listeyi getiriyor; her seferinde yeni
      // bir süreç açmak sesleri üst üste bindirirdi.
      final player = SpyPlayer();
      final alarm = NewOrderAlarm(player);

      alarm
        ..onOrders([yeni(1)])
        ..onOrders([yeni(1)])
        ..onOrders([yeni(1)]);

      expect(player.starts, 1);
    });

    test('susturma durumu bildirir ama bekleyeni gizlemez', () {
      final player = SpyPlayer();
      final alarm = NewOrderAlarm(player)..onOrders([yeni(1)]);

      final state = alarm.silence();
      expect(state.sounding, isFalse);
      expect(state.silenced, isTrue);
      expect(state.pendingCount, 1, reason: 'Sipariş hâlâ onay bekliyor.');
      expect(player.stops, 1);
    });

    test('ses çıkmıyorsa durum bunu söyler', () {
      final player = SpyPlayer()..muted = true;
      final alarm = NewOrderAlarm(player)..onOrders([yeni(1)]);

      expect(alarm.state.muted, isTrue);
      expect(alarm.state.sounding, isFalse);
      expect(alarm.state.silentWhileWaiting, isTrue);
    });

    test('sessizlik sonradan anlaşılırsa `refresh` yakalar', () {
      // `ProcessAlarmPlayer` "oynatıcı yok" kararını `start()` döndükten sonra
      // veriyor; arayüz o ana kadar sessizliği bilemez.
      final player = SpyPlayer();
      final alarm = NewOrderAlarm(player)..onOrders([yeni(1)]);
      expect(alarm.state.muted, isFalse);

      player.muted = true;
      expect(alarm.refresh().muted, isTrue);
    });

    test('elden çıkarma sesi keser', () async {
      final player = SpyPlayer();
      final alarm = NewOrderAlarm(player)..onOrders([yeni(1)]);

      await alarm.dispose();
      expect(player.isPlaying, isFalse);
    });
  });
}
