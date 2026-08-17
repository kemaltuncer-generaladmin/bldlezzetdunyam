/// Gün atlama şeridinin karar tablosu.
///
/// Şeridin çizimi değil KURALI sınanıyor: dönem penceresi, servis günü, kapalı
/// gün ve **kesim**. Kesim kuralı buradaki tek gerçek risk — kesimi geçmiş bir
/// günü atlanabilir göstermek, aboneye gelmeyeceğini bildirdiğini sandırıp
/// mutfağa o porsiyonu pişirtirdi.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musteriapp/src/features/subscriptions/subscription_detail_screen.dart';

/// 2026-08-17 Pazartesi başlangıçlı, hafta içi (Pzt–Cum) abonelik.
Subscription _subscription({
  List<SubscriptionException> exceptions = const [],
  DateTime? endDate,
  List<int> serviceDays = const [1, 2, 3, 4, 5],
}) {
  return Subscription(
    id: 1,
    status: 'active',
    locationId: 1,
    deliveryType: DeliveryType.delivery,
    startDate: DateTime.utc(2026, 8, 17),
    endDate: endDate,
    serviceDays: serviceDays,
    defaultQuantity: 20,
    paymentMode: 'prepaid_monthly',
    menuMode: 'daily_menu',
    exceptions: exceptions,
    createdAt: DateTime.utc(2026, 8, 1),
  );
}

MenuCalendarDay _day(String date, {DateTime? cutoffAt, bool closed = false}) {
  return MenuCalendarDay(
    date: date,
    hasMenu: !closed,
    closed: closed,
    isOrderable: !closed,
    cutoffAt: cutoffAt,
  );
}

/// 18 Ağustos 2026 sabahı, kesimden önce.
final _beforeCutoff = DateTime.utc(2026, 8, 18, 3);

void main() {
  group('dönem penceresi', () {
    test('başlangıçtan önceki gün dönem dışıdır', () {
      final result = subscriptionSkipDay(
        date: '2026-08-14',
        subscription: _subscription(),
        day: _day('2026-08-14'),
        now: _beforeCutoff,
      );
      expect(result.state, SubscriptionSkipDayState.outside);
      expect(result.editable, isFalse);
    });

    test('bitişten sonraki gün dönem dışıdır', () {
      final result = subscriptionSkipDay(
        date: '2026-09-01',
        subscription: _subscription(endDate: DateTime.utc(2026, 8, 31)),
        day: _day('2026-09-01'),
        now: _beforeCutoff,
      );
      expect(result.state, SubscriptionSkipDayState.outside);
    });

    test('bitişin kendisi dönem İÇİNDEDİR', () {
      // 31 Ağustos 2026 Pazartesi.
      final result = subscriptionSkipDay(
        date: '2026-08-31',
        subscription: _subscription(endDate: DateTime.utc(2026, 8, 31)),
        day: _day('2026-08-31'),
        now: _beforeCutoff,
      );
      expect(result.state, SubscriptionSkipDayState.scheduled);
      expect(result.editable, isTrue);
    });
  });

  group('servis günü', () {
    test('servis günü olmayan gün atlanamaz', () {
      // 22 Ağustos 2026 Cumartesi; abonelik Pzt–Cum.
      final result = subscriptionSkipDay(
        date: '2026-08-22',
        subscription: _subscription(),
        day: _day('2026-08-22'),
        now: _beforeCutoff,
      );
      expect(result.state, SubscriptionSkipDayState.notServiceDay);
      expect(result.editable, isFalse);
    });

    test('servis günü atlanabilir', () {
      final result = subscriptionSkipDay(
        date: '2026-08-20',
        subscription: _subscription(),
        day: _day('2026-08-20'),
        now: _beforeCutoff,
      );
      expect(result.state, SubscriptionSkipDayState.scheduled);
      expect(result.editable, isTrue);
    });
  });

  group('kapalı gün', () {
    test('mutfak kapalıysa atlanacak bir şey yoktur', () {
      final result = subscriptionSkipDay(
        date: '2026-08-20',
        subscription: _subscription(),
        day: _day('2026-08-20', closed: true),
        now: _beforeCutoff,
      );
      expect(result.state, SubscriptionSkipDayState.closed);
      expect(result.editable, isFalse);
    });
  });

  group('kesim', () {
    test('kesimi geçmiş gün kilitlidir', () {
      final result = subscriptionSkipDay(
        date: '2026-08-18',
        subscription: _subscription(),
        day: _day('2026-08-18', cutoffAt: DateTime.utc(2026, 8, 18, 5)),
        now: DateTime.utc(2026, 8, 18, 6),
      );
      expect(result.state, SubscriptionSkipDayState.locked);
      expect(result.editable, isFalse);
    });

    test('kesim anının kendisi GEÇMİŞ sayılır', () {
      final cutoff = DateTime.utc(2026, 8, 18, 5);
      final result = subscriptionSkipDay(
        date: '2026-08-18',
        subscription: _subscription(),
        day: _day('2026-08-18', cutoffAt: cutoff),
        now: cutoff,
      );
      expect(result.state, SubscriptionSkipDayState.locked);
    });

    test('kesimden önce atlanabilir', () {
      final result = subscriptionSkipDay(
        date: '2026-08-18',
        subscription: _subscription(),
        day: _day('2026-08-18', cutoffAt: DateTime.utc(2026, 8, 18, 5)),
        now: _beforeCutoff,
      );
      expect(result.state, SubscriptionSkipDayState.scheduled);
      expect(result.editable, isTrue);
    });

    test('takvimde olmayan gün KİLİTLİ DEĞİLDİR', () {
      // İleri görüş penceresi kısa olduğunda şeridin sonundaki günler
      // takvimde hiç dönmüyor. Onları kilitlemek, atlanabilecek günlerin
      // çoğunu kapatırdı.
      final result = subscriptionSkipDay(
        date: '2026-09-10',
        subscription: _subscription(),
        day: null,
        now: _beforeCutoff,
      );
      expect(result.state, SubscriptionSkipDayState.scheduled);
      expect(result.editable, isTrue);
    });

    test('kesimi olmayan takvim günü kilitlenmez', () {
      final result = subscriptionSkipDay(
        date: '2026-08-20',
        subscription: _subscription(),
        day: _day('2026-08-20'),
        now: _beforeCutoff,
      );
      expect(result.state, SubscriptionSkipDayState.scheduled);
    });
  });

  group('atlanmış gün', () {
    test('atlanan gün atlanmış görünür ve geri alınabilir', () {
      final result = subscriptionSkipDay(
        date: '2026-08-20',
        subscription: _subscription(
          exceptions: const [
            SubscriptionException(serviceDate: '2026-08-20', skip: true),
          ],
        ),
        day: _day('2026-08-20', cutoffAt: DateTime.utc(2026, 8, 20, 5)),
        now: _beforeCutoff,
      );
      expect(result.state, SubscriptionSkipDayState.skipped);
      expect(result.editable, isTrue);
    });

    test('kesimi geçmiş atlama GÖRÜNÜR ama geri alınamaz', () {
      final result = subscriptionSkipDay(
        date: '2026-08-18',
        subscription: _subscription(
          exceptions: const [
            SubscriptionException(serviceDate: '2026-08-18', skip: true),
          ],
        ),
        day: _day('2026-08-18', cutoffAt: DateTime.utc(2026, 8, 18, 5)),
        now: DateTime.utc(2026, 8, 18, 6),
      );
      expect(result.state, SubscriptionSkipDayState.skipped);
      expect(result.editable, isFalse);
    });

    test('adet değişikliği atlama DEĞİLDİR', () {
      final result = subscriptionSkipDay(
        date: '2026-08-20',
        subscription: _subscription(
          exceptions: const [
            SubscriptionException(
              serviceDate: '2026-08-20',
              skip: false,
              quantityOverride: 5,
            ),
          ],
        ),
        day: _day('2026-08-20'),
        now: _beforeCutoff,
      );
      expect(result.state, SubscriptionSkipDayState.scheduled);
    });
  });
}
