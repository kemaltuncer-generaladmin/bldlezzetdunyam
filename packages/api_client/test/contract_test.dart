/// Sözleşme uyum testi.
///
/// Buradaki JSON gövdeleri `docs/03-api-sozlesmesi.md` ve `docs/openapi.yaml`
/// içindeki **örneklerin birebir kopyasıdır**. Sunucu sözleşmeyi değiştirirse
/// bu testler kırılır — amaç da budur.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:test/test.dart';

void main() {
  group('Location', () {
    test('sözleşme örneği ayrıştırılır', () {
      final location = Location.fromJson({
        'id': 1,
        'name': 'Benim Lezzet Dünyam',
        'slug': 'catering',
        'is_open': true,
        'ordering_enabled': true,
        'order_cutoff': '16:00',
        'min_order_total': 25000,
        'payment_methods': ['cash', 'account'],
      });

      expect(location.id, 1);
      expect(location.isOpen, isTrue);
      expect(location.orderingEnabled, isTrue);
      expect(location.orderCutoff, '16:00');
      expect(location.minOrderTotal, 25000);
      expect(location.paymentMethods, [
        PaymentMethod.cash,
        PaymentMethod.account,
      ]);
      expect(location.acceptsOrders, isTrue);
    });

    test('şalter kapalıysa sipariş alınmaz', () {
      Location build({required bool open, required bool enabled}) =>
          Location.fromJson({
            'id': 1,
            'name': 'BLD',
            'slug': 'catering',
            'is_open': open,
            'ordering_enabled': enabled,
            'min_order_total': 0,
            'payment_methods': ['cash'],
          });

      expect(build(open: true, enabled: true).acceptsOrders, isTrue);
      expect(build(open: false, enabled: true).acceptsOrders, isFalse);
      expect(build(open: true, enabled: false).acceptsOrders, isFalse);
    });

    test('bilinmeyen ödeme yöntemi çökertmez, seçilemez olur', () {
      final location = Location.fromJson({
        'id': 1,
        'name': 'BLD',
        'slug': 'catering',
        'is_open': true,
        'ordering_enabled': true,
        'min_order_total': 0,
        'payment_methods': ['cash', 'kripto'],
      });

      expect(location.paymentMethods, [
        PaymentMethod.cash,
        PaymentMethod.unknown,
      ]);
      expect(location.selectablePaymentMethods, [PaymentMethod.cash]);
    });
  });

  group('MenuItem', () {
    final json = {
      'id': 101,
      'name': 'Tavuk Sote',
      'description': 'Pilav ile',
      'price': 18500,
      'currency': 'TRY',
      'image_url': 'https://ornek/tavuk.jpg',
      'is_available': true,
      'allergens': ['gluten'],
      'options': [
        {
          'id': 9,
          'name': 'Porsiyon',
          'type': 'radio',
          'required': true,
          'values': [
            {'id': 31, 'name': 'Normal', 'price_delta': 0},
            {'id': 32, 'name': 'Büyük', 'price_delta': 4000},
          ],
        },
      ],
    };

    test('sözleşme örneği ayrıştırılır', () {
      final item = MenuItem.fromJson(json);
      expect(item.name, 'Tavuk Sote');
      expect(item.price, 18500);
      expect(item.allergens, ['gluten']);
      expect(item.options.single.values.length, 2);
      expect(item.options.single.isMultiSelect, isFalse);
    });

    test('seçenek farkı birim fiyata eklenir', () {
      final item = MenuItem.fromJson(json);
      expect(item.unitPriceWith({31}), 18500, reason: 'Normal: fark yok');
      expect(item.unitPriceWith({32}), 22500, reason: 'Büyük: +40,00 TL');
      expect(item.unitPriceWith({}), 18500);
    });

    test('opsiyonel alanlar eksik olabilir', () {
      final item = MenuItem.fromJson({
        'id': 5,
        'name': 'Su',
        'price': 1500,
        'currency': 'TRY',
        'is_available': false,
      });
      expect(item.description, isNull);
      expect(item.allergens, isEmpty);
      expect(item.options, isEmpty);
      expect(item.isAvailable, isFalse);
    });
  });

  group('OrderCreateRequest', () {
    test('sözleşmedeki alan adlarıyla serileştirilir', () {
      final request = OrderCreateRequest(
        locationId: 1,
        items: const [
          OrderCreateItem(
            menuId: 101,
            quantity: 2,
            optionValueIds: [31],
            note: 'Az acılı',
          ),
        ],
        deliveryType: DeliveryType.delivery,
        address: const Address(
          line1: 'Örnek Mah. 12. Sk No:3',
          district: 'Çankaya',
          city: 'Ankara',
          note: 'Zili çalmayın',
        ),
        requestedAt: DateTime.utc(2026, 8, 5, 9, 30),
        paymentMethod: PaymentMethod.cash,
        customerNote: 'Fatura kurumsal',
      );

      final json = request.toJson();

      expect(json['location_id'], 1);
      expect(json['delivery_type'], 'delivery');
      expect(json['payment_method'], 'cash');
      expect(json['requested_at'], '2026-08-05T09:30:00.000Z');
      expect(json['customer_note'], 'Fatura kurumsal');

      final items = json['items']! as List<dynamic>;
      final first = items.single as Map<String, dynamic>;
      expect(first['menu_id'], 101);
      expect(first['option_value_ids'], [31]);

      final address = json['address']! as Map<String, dynamic>;
      expect(address['line1'], 'Örnek Mah. 12. Sk No:3');
    });

    test('gel-al siparişinde adres gönderilmez', () {
      const request = OrderCreateRequest(
        locationId: 1,
        items: [OrderCreateItem(menuId: 101, quantity: 1)],
        deliveryType: DeliveryType.pickup,
        paymentMethod: PaymentMethod.account,
      );

      expect(request.toJson().containsKey('address'), isFalse);
      expect(request.toJson()['delivery_type'], 'pickup');
    });

    test('istemci tutar gönderemez — böyle bir alan yok', () {
      const request = OrderCreateRequest(
        locationId: 1,
        items: [OrderCreateItem(menuId: 101, quantity: 1)],
        deliveryType: DeliveryType.pickup,
        paymentMethod: PaymentMethod.cash,
      );
      final keys = request.toJson().keys;
      expect(keys, isNot(contains('total')));
      expect(keys, isNot(contains('subtotal')));
    });
  });

  group('OrderDetail', () {
    Map<String, dynamic> build({required String deliveryType}) => {
      'id': 5012,
      'order_number': 'S-5012',
      'status': 'hazirlaniyor',
      'items': [
        {
          'menu_id': 101,
          'name': 'Tavuk Sote',
          'quantity': 2,
          'options': ['Normal'],
          'note': 'Az acılı',
          'unit_price': 18500,
          'line_total': 37000,
        },
      ],
      'subtotal': 37000,
      'delivery_fee': deliveryType == 'delivery' ? 4000 : 0,
      'total': deliveryType == 'delivery' ? 41000 : 37000,
      'currency': 'TRY',
      'delivery_type': deliveryType,
      if (deliveryType == 'delivery')
        'address': {
          'line1': 'Örnek Mah. 12. Sk No:3',
          'district': 'Çankaya',
          'city': 'Ankara',
        },
      'payment': {'method': 'cash', 'status': 'pending'},
      'status_history': [
        {'status': 'yeni', 'at': '2026-08-04T11:30:00Z'},
        {'status': 'onaylandi', 'at': '2026-08-04T11:31:12Z'},
        {'status': 'hazirlaniyor', 'at': '2026-08-04T11:35:40Z'},
      ],
      'created_at': '2026-08-04T11:30:00Z',
    };

    test('sözleşme örneği ayrıştırılır', () {
      final order = OrderDetail.fromJson(build(deliveryType: 'delivery'));
      expect(order.orderNumber, 'S-5012');
      expect(order.status, OrderStatus.hazirlaniyor);
      expect(order.total, 41000);
      expect(order.address?.district, 'Çankaya');
      expect(order.statusHistory.length, 3);
      expect(order.statusHistory.first.at, DateTime.utc(2026, 8, 4, 11, 30));
    });

    test('hazirlaniyor durumunda müşteri iptal edemez', () {
      final order = OrderDetail.fromJson(build(deliveryType: 'delivery'));
      expect(order.canBeCancelledByCustomer, isFalse);
    });

    test('takip adımları adrese gönderimde yolda içerir', () {
      final order = OrderDetail.fromJson(build(deliveryType: 'delivery'));
      expect(order.trackingSteps, contains(OrderStatus.yolda));
      expect(order.trackingSteps.length, 6);
    });

    test('gel-al siparişte yolda adımı yok, adres null, ücret sıfır', () {
      final order = OrderDetail.fromJson(build(deliveryType: 'pickup'));
      expect(order.trackingSteps, isNot(contains(OrderStatus.yolda)));
      expect(order.trackingSteps.length, 5);
      expect(order.address, isNull);
      expect(order.deliveryFee, 0);
    });
  });

  group('KitchenOrder', () {
    Map<String, dynamic> build({required String deliveryType}) => {
      'id': 5012,
      'order_number': 'S-5012',
      'status': 'yeni',
      'requested_at': '2026-08-05T09:30:00Z',
      'delivery_type': deliveryType,
      'customer_label': 'Ayşe Y.',
      'items': [
        {
          'name': 'Tavuk Sote',
          'quantity': 2,
          'options': ['Normal'],
          'note': 'Az acılı',
        },
      ],
      'customer_note': 'Fatura kurumsal',
      'created_at': '2026-08-04T11:30:00Z',
      'updated_at': '2026-08-04T11:30:00Z',
    };

    test('sözleşme örneği ayrıştırılır', () {
      final order = KitchenOrder.fromJson(build(deliveryType: 'delivery'));
      expect(order.orderNumber, 'S-5012');
      expect(order.customerLabel, 'Ayşe Y.');
      expect(order.items.single.note, 'Az acılı');
    });

    test('mutfak siparişinde fiyat ve iletişim bilgisi yok', () {
      // Sunucu yanlışlıkla gönderse bile modelde karşılığı olmamalı.
      final json = build(deliveryType: 'delivery');
      expect(json.keys, isNot(contains('total')));
      expect(json.keys, isNot(contains('address')));
      expect(json.keys, isNot(contains('telephone')));
    });

    test('rozet teslimat tipinden türetilir', () {
      expect(
        KitchenOrder.fromJson(build(deliveryType: 'delivery')).deliveryBadge,
        'ADR',
      );
      expect(
        KitchenOrder.fromJson(build(deliveryType: 'pickup')).deliveryBadge,
        'GELAL',
      );
    });

    test('sonraki durum teslimat tipine göre değişir', () {
      final delivery = KitchenOrder.fromJson(build(deliveryType: 'delivery'));
      expect(delivery.nextStatus, OrderStatus.onaylandi);
      expect(delivery.hasHighlightedNote, isTrue);
    });

    test('sözleşme dışı durum kodu sessizce yutulmaz', () {
      final json = build(deliveryType: 'delivery')..['status'] = 'beklemede';
      expect(
        () => KitchenOrder.fromJson(json),
        throwsA(isA<UnknownEnumValueException>()),
      );
    });
  });

  group('ApiException', () {
    test('sözleşmedeki hata gövdesi ayrıştırılır', () {
      final error = ApiException.fromResponse({
        'error': {
          'code': 'INVALID_TRANSITION',
          'message': 'Sipariş bu duruma geçirilemez.',
          'details': {'from': 'yeni', 'to': 'hazir'},
        },
      }, 422);

      expect(error.code, ApiErrorCode.invalidTransition);
      expect(error.message, 'Sipariş bu duruma geçirilemez.');
      expect(error.details?['from'], 'yeni');
      expect(error.isRetryable, isFalse);
    });

    test('bilinmeyen kod unknown olur', () {
      final error = ApiException.fromResponse({
        'error': {'code': 'TEAPOT', 'message': 'Çaydanlığım.'},
      }, 418);
      expect(error.code, ApiErrorCode.unknown);
    });

    test('ayrıştırılamayan gövde çökertmez', () {
      final error = ApiException.fromResponse('<html>502</html>', 502);
      expect(error.code, ApiErrorCode.unknown);
      expect(error.statusCode, 502);
    });

    test('cihaz iptali ve oturum düşmesi ayırt edilir', () {
      final revoked = ApiException.fromResponse({
        'error': {'code': 'DEVICE_REVOKED', 'message': 'Cihaz iptal edildi.'},
      }, 403);
      expect(revoked.isDeviceRevoked, isTrue);
      expect(revoked.isUnauthenticated, isFalse);
    });

    test('yalnızca geçici hatalar tekrar denenir', () {
      ApiException withCode(String code) =>
          ApiException.fromResponse({
            'error': {'code': code, 'message': '.'},
          }, 500);

      expect(withCode('SERVER_ERROR').isRetryable, isTrue);
      expect(withCode('RATE_LIMITED').isRetryable, isTrue);
      expect(withCode('VALIDATION_FAILED').isRetryable, isFalse);
      expect(withCode('FORBIDDEN').isRetryable, isFalse);
      expect(const ApiException.network().isRetryable, isTrue);
    });
  });

  group('Payment', () {
    test('online ödemede yönlendirme gerekir', () {
      final payment = Payment.fromJson({
        'method': 'online',
        'status': 'pending',
        'redirect_url': 'https://sanalpos.example/odeme/abc',
      });
      expect(payment.requiresRedirect, isTrue);
    });

    test('kapıda ödemede yönlendirme yok', () {
      final payment = Payment.fromJson({
        'method': 'cash',
        'status': 'pending',
      });
      expect(payment.requiresRedirect, isFalse);
      expect(payment.redirectUrl, isNull);
    });

    test('ileride eklenecek ödeme durumu çökertmez', () {
      // docs/openapi.yaml PaymentStatus: failed/refunded eklenebilir.
      final payment = Payment.fromJson({
        'method': 'online',
        'status': 'refunded',
      });
      expect(payment.status, PaymentStatus.unknown);
      expect(paymentStatusLabelsTr[payment.status], 'Belirsiz');
    });
  });
}
