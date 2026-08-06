/// Teslim süresi tahmininin arayüz metni.
///
/// İki şey doğrulanır: (1) dakika aralığı doğru saat penceresine çevriliyor,
/// (2) sunucu `eta` göndermediğinde ekranlar tahmini hiç kurmuyor — yani eski
/// bir sunucu veya mock uygulamayı çökertmiyor.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musteriapp/src/core/eta_text.dart';
import 'package:musteriapp/src/l10n/app_localizations_tr.dart';

void main() {
  final l10n = AppLocalizationsTr();

  // TR saatiyle 04.08.2026 12:15.
  final now = DateTime.utc(2026, 8, 4, 9, 15);

  Location buildLocation({
    Map<String, dynamic>? eta,
    bool orderingEnabled = true,
  }) => Location.fromJson({
    'id': 1,
    'name': 'BLD',
    'slug': 'catering',
    'is_open': true,
    'ordering_enabled': orderingEnabled,
    'min_order_total': 0,
    'payment_methods': ['cash'],
    'eta': ?eta,
  });

  const configuredJson = {
    'delivery': {
      'min_minutes': 60,
      'max_minutes': 85,
      'source': 'configured',
      'busy': false,
    },
    'pickup': {
      'min_minutes': 40,
      'max_minutes': 55,
      'source': 'configured',
      'busy': false,
    },
  };

  group('Sipariş öncesi tahmin', () {
    test('dakika aralığı ve saat penceresi birlikte gösterilir', () {
      final eta = buildLocation(
        eta: configuredJson,
      ).etaFor(DeliveryType.delivery)!;
      final view = etaBeforeOrder(eta, DeliveryType.delivery, l10n, now: now);

      expect(view.title, 'Tahmini teslim');
      expect(view.value, 'yaklaşık 60-85 dakika · 13:15-13:40 arası');
    });

    test('gel-al için ayrı aralık ve ayrı başlık', () {
      final eta = buildLocation(
        eta: configuredJson,
      ).etaFor(DeliveryType.pickup)!;
      final view = etaBeforeOrder(eta, DeliveryType.pickup, l10n, now: now);

      expect(view.title, 'Tahmini hazır olma');
      expect(view.value, 'yaklaşık 40-55 dakika · 12:55-13:10 arası');
    });

    test('ölçülmemiş tahmin temkinli dille sunulur', () {
      final eta = buildLocation(
        eta: configuredJson,
      ).etaFor(DeliveryType.delivery)!;
      final view = etaBeforeOrder(eta, DeliveryType.delivery, l10n, now: now);

      expect(view.value, startsWith('yaklaşık'));
      expect(view.sourceNote, contains('ölçülmedi'));
    });

    test('ölçülmüş tahminde "yaklaşık" öneki düşer', () {
      final eta = buildLocation(
        eta: {
          'delivery': {
            'min_minutes': 60,
            'max_minutes': 85,
            'source': 'measured',
            'busy': false,
          },
        },
      ).etaFor(DeliveryType.delivery)!;
      final view = etaBeforeOrder(eta, DeliveryType.delivery, l10n, now: now);

      expect(view.value, '60-85 dakika · 13:15-13:40 arası');
      expect(view.sourceNote, contains('gerçekleşen sürelerinden'));
    });

    test('yoğunluk uyarısı yalnızca busy iken çıkar', () {
      final sakin = buildLocation(
        eta: configuredJson,
      ).etaFor(DeliveryType.delivery)!;
      expect(
        etaBeforeOrder(sakin, DeliveryType.delivery, l10n, now: now).busyNote,
        isNull,
      );

      final yogun = buildLocation(
        eta: {
          'delivery': {
            'min_minutes': 75,
            'max_minutes': 100,
            'source': 'configured',
            'busy': true,
          },
        },
      ).etaFor(DeliveryType.delivery)!;
      final view = etaBeforeOrder(yogun, DeliveryType.delivery, l10n, now: now);

      expect(
        view.busyNote,
        'Mutfağımız şu anda yoğun. Süre bu yoğunluğa göre uzatıldı.',
      );
      // Aralık sunucuda uzatılmış gelir; istemci ayrıca süre eklemez.
      expect(view.value, 'yaklaşık 75-100 dakika · 13:30-13:55 arası');
    });
  });

  group('Sipariş sonrası tahmin', () {
    test('çıpa siparişin oluşturulma anıdır, "şimdi" değil', () {
      final eta = buildLocation(
        eta: configuredJson,
      ).etaFor(DeliveryType.delivery)!;
      // Sipariş 30 dakika önce verildi: pencere de 30 dakika geride olmalı.
      final createdAt = now.subtract(const Duration(minutes: 30));
      final view = etaAfterOrder(
        eta,
        DeliveryType.delivery,
        l10n,
        orderCreatedAt: createdAt,
      );

      expect(view.title, 'Tahmini teslim saati');
      expect(view.value, '12:45-13:10 arası');
    });

    test('gel-al siparişte hazır olma saati gösterilir', () {
      final eta = buildLocation(
        eta: configuredJson,
      ).etaFor(DeliveryType.pickup)!;
      final view = etaAfterOrder(
        eta,
        DeliveryType.pickup,
        l10n,
        orderCreatedAt: now,
      );

      expect(view.title, 'Tahmini hazır olma saati');
      expect(view.value, '12:55-13:10 arası');
    });
  });

  group('eta yokken çökmez', () {
    test('sunucu eta göndermezse hiçbir tahmin kurulmaz', () {
      final location = buildLocation();

      expect(location.eta, isNull);
      expect(location.etaFor(DeliveryType.delivery), isNull);
      expect(location.etaFor(DeliveryType.pickup), isNull);
    });

    test('eski önbellek kaydı (eta alanı olmayan JSON) okunabilir', () {
      final cached = buildLocation(eta: configuredJson).toJson()..remove('eta');

      final location = Location.fromJson(cached);
      expect(location.etaFor(DeliveryType.delivery), isNull);
      expect(location.acceptsOrders, isTrue);
    });

    test('vitrin kapalıyken tahmin gösterilmez', () {
      final location = buildLocation(
        eta: configuredJson,
        orderingEnabled: false,
      );

      expect(location.etaFor(DeliveryType.delivery), isNull);
    });
  });
}
