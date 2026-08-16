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

  group('Location.eta', () {
    Map<String, dynamic> baseJson() => {
      'id': 1,
      'name': 'BLD',
      'slug': 'catering',
      'is_open': true,
      'ordering_enabled': true,
      'min_order_total': 0,
      'payment_methods': ['cash'],
    };

    test('sözleşme örneği ayrıştırılır', () {
      final location = Location.fromJson({
        ...baseJson(),
        'eta': {
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
        },
      });

      final delivery = location.etaFor(DeliveryType.delivery)!;
      expect(delivery.minMinutes, 60);
      expect(delivery.maxMinutes, 85);
      expect(delivery.source, EtaSource.configured);
      expect(delivery.isMeasured, isFalse);
      expect(delivery.busy, isFalse);

      final pickup = location.etaFor(DeliveryType.pickup)!;
      expect(pickup.minMinutes, 40);
      expect(pickup.maxMinutes, 55);
    });

    // Alanın eksikliği hata değildir: eski sunucu, mock ve cihazdaki eski
    // önbellek kaydı `eta` göndermez.
    test('eta hiç gelmezse çökmez, null döner', () {
      final location = Location.fromJson(baseJson());

      expect(location.eta, isNull);
      expect(location.etaFor(DeliveryType.delivery), isNull);
      expect(location.etaFor(DeliveryType.pickup), isNull);
      expect(location.acceptsOrders, isTrue);
    });

    test('eta içindeki tek tip eksikse diğeri çalışır', () {
      final location = Location.fromJson({
        ...baseJson(),
        'eta': {
          'pickup': {
            'min_minutes': 40,
            'max_minutes': 55,
            'source': 'measured',
            'busy': true,
          },
        },
      });

      expect(location.etaFor(DeliveryType.delivery), isNull);
      final pickup = location.etaFor(DeliveryType.pickup)!;
      expect(pickup.isMeasured, isTrue);
      expect(pickup.busy, isTrue);
    });

    test('bilinmeyen kaynak çökertmez, ölçülmemiş sayılır', () {
      final location = Location.fromJson({
        ...baseJson(),
        'eta': {
          'delivery': {
            'min_minutes': 60,
            'max_minutes': 85,
            'source': 'harita_servisi',
            'busy': false,
          },
        },
      });

      final delivery = location.etaFor(DeliveryType.delivery)!;
      expect(delivery.source, EtaSource.unknown);
      expect(delivery.isMeasured, isFalse);
    });

    test('source ve busy eksikse varsayılana düşer', () {
      final location = Location.fromJson({
        ...baseJson(),
        'eta': {
          'delivery': {'min_minutes': 60, 'max_minutes': 85},
        },
      });

      final delivery = location.etaFor(DeliveryType.delivery)!;
      expect(delivery.source, EtaSource.unknown);
      expect(delivery.busy, isFalse);
    });

    test('bozuk aralık gösterilmez', () {
      Location build(int min, int max) => Location.fromJson({
        ...baseJson(),
        'eta': {
          'delivery': {'min_minutes': min, 'max_minutes': max},
        },
      });

      expect(build(0, 0).etaFor(DeliveryType.delivery), isNull);
      expect(build(85, 60).etaFor(DeliveryType.delivery), isNull);
      expect(build(60, 85).etaFor(DeliveryType.delivery), isNotNull);
    });

    test('sipariş alınmıyorken tahmin gösterilmez', () {
      final location = Location.fromJson({
        ...baseJson(),
        'ordering_enabled': false,
        'eta': {
          'delivery': {'min_minutes': 60, 'max_minutes': 85},
        },
      });

      expect(location.etaFor(DeliveryType.delivery), isNull);
      // Ham veri yerinde durur; gizleyen yalnızca yardımcıdır.
      expect(location.eta?.delivery, isNotNull);
    });

    test('eta önbelleğe yazılıp geri okunabilir', () {
      final location = Location.fromJson({
        ...baseJson(),
        'eta': {
          'delivery': {
            'min_minutes': 60,
            'max_minutes': 85,
            'source': 'measured',
            'busy': false,
          },
        },
      });

      expect(Location.fromJson(location.toJson()), location);
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
      ApiException withCode(String code) => ApiException.fromResponse({
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
      final payment = Payment.fromJson({'method': 'cash', 'status': 'pending'});
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

  group('Subscription', () {
    test('sözleşme örneği ayrıştırılır', () {
      final subscription = Subscription.fromJson({
        'id': 7,
        'status': 'active',
        'location_id': 1,
        'delivery_type': 'delivery',
        'start_date': '2026-08-15',
        'end_date': null,
        'service_days': [1, 2, 3, 4, 5],
        'delivery_time_from': '12:00',
        'delivery_time_to': '13:00',
        'default_quantity': 20,
        'agreed_unit_price': 15000,
        'payment_mode': 'account',
        'menu_mode': 'fixed_list',
        'lines': [
          {
            'menu_id': 101,
            'quantity': 18,
            'agreed_unit_price': 15000,
            'label': 'Standart',
          },
          {
            'menu_id': null,
            'quantity': 2,
            'agreed_unit_price': null,
            'label': 'Vejetaryen',
          },
        ],
        'delivery_points': [
          {'id': 3, 'address_id': 55, 'quantity': 20, 'note': 'Zemin kat'},
        ],
        'created_at': '2026-08-10T09:00:00Z',
      });

      expect(subscription.id, 7);
      expect(subscription.isActive, isTrue);
      expect(subscription.deliveryType, DeliveryType.delivery);
      expect(subscription.serviceDays, [1, 2, 3, 4, 5]);
      expect(subscription.defaultQuantity, 20);
      expect(subscription.agreedUnitPrice, 15000);
      expect(subscription.paymentMode, 'account');
      expect(subscription.lines, hasLength(2));
      expect(subscription.lines[1].menuId, isNull);
      expect(subscription.lines[1].agreedUnitPrice, isNull);
      expect(subscription.deliveryPoints.single.addressId, 55);
    });

    test('talep (pending) fiyatsız gelir', () {
      final subscription = Subscription.fromJson({
        'id': 8,
        'status': 'pending',
        'location_id': 1,
        'delivery_type': 'pickup',
        'start_date': '2026-09-01',
        'service_days': [1, 3, 5],
        'default_quantity': 10,
        'agreed_unit_price': null,
        'payment_mode': 'account',
        'menu_mode': 'fixed_list',
        'lines': <Map<String, Object?>>[],
        'delivery_points': <Map<String, Object?>>[],
        'created_at': '2026-08-20T06:00:00Z',
      });

      expect(subscription.isPending, isTrue);
      expect(subscription.agreedUnitPrice, isNull);
      expect(subscription.lines, isEmpty);
    });

    test('bilinmeyen durum çökertmez (gevşek enum)', () {
      final subscription = Subscription.fromJson({
        'id': 9,
        'status': 'suspended_for_debt',
        'location_id': 1,
        'delivery_type': 'delivery',
        'start_date': '2026-09-01',
        'service_days': [1],
        'default_quantity': 5,
        'payment_mode': 'account',
        'menu_mode': 'fixed_list',
        'lines': <Map<String, Object?>>[],
        'delivery_points': <Map<String, Object?>>[],
        'created_at': '2026-08-20T06:00:00Z',
      });

      expect(subscription.status, 'suspended_for_debt');
      expect(subscription.isActive, isFalse);
    });

    test('talep gövdesi (SubscriptionCreateRequest) JSON üretir', () {
      final request = SubscriptionCreateRequest(
        locationId: 1,
        deliveryType: DeliveryType.delivery,
        startDate: '2026-09-01',
        serviceDays: const [1, 2, 3, 4, 5],
        defaultQuantity: 20,
        customerNote: 'Öğle 12:30',
      );
      final json = request.toJson();

      expect(json['location_id'], 1);
      expect(json['delivery_type'], 'delivery');
      expect(json['start_date'], '2026-09-01');
      expect(json['service_days'], [1, 2, 3, 4, 5]);
      expect(json['default_quantity'], 20);
      expect(json['customer_note'], 'Öğle 12:30');
    });
  });

  // NOT: "Cari hesap" grubu Faz 0'da KALDIRILDI. Cari hesap satış modelinden
  // çıktı (`AGENTS.md` iş kuralı 1); `AccountSummary`/`AccountStatement`
  // modelleri ve `AccountService` bu paketten silindi. Testleri burada
  // bırakmak, artık var olmayan bir sözleşmeyi korumak olurdu.

  // ─────────────────────────── Günün menüsü (B-19) ──────────────────────────

  group('DailyMenu', () {
    Map<String, dynamic> build() => {
      'id': 77,
      'date': '2026-08-20',
      'title': 'Ev Yemeği Menüsü',
      'description': 'Çorba, ana yemek, pilav, tatlı',
      'image_url': null,
      'package': {
        'menu_id': 900,
        'name': 'Günün Menüsü',
        'price': 22000,
        'is_available': true,
        'sold_out_reason': null,
        'components': [
          {
            'menu_id': 101,
            'name': 'Mercimek Çorbası',
            'quantity': 1,
            'image_url': null,
            'allergens': ['gluten'],
          },
          {'menu_id': 102, 'name': 'Tavuk Sote', 'quantity': 2},
        ],
      },
      'items_total': 26500,
      'currency': 'TRY',
      'closed': false,
      'is_orderable': true,
      'unavailable_reason': null,
      'items': [
        {
          'id': 101,
          'name': 'Mercimek Çorbası',
          'price': 6500,
          'currency': 'TRY',
          'is_available': true,
        },
        {
          'id': 102,
          'name': 'Tavuk Sote',
          'price': 20000,
          'currency': 'TRY',
          'is_available': true,
        },
      ],
    };

    test('sözleşme örneği ayrıştırılır', () {
      final menu = DailyMenu.fromJson(build());

      expect(menu.id, 77);
      expect(menu.date, '2026-08-20');
      expect(menu.exists, isTrue);
      expect(menu.isOrderable, isTrue);
      expect(menu.unavailableReason, DailyMenuUnavailableReason.none);
      expect(menu.items, hasLength(2));
      expect(menu.package?.menuId, 900);
      expect(menu.package?.components, hasLength(2));
      expect(menu.package?.components.first.allergens, ['gluten']);
      // Bileşen `quantity` alanı porsiyon sayısıdır, adet değil.
      expect(menu.package?.portionCount, 3);
    });

    test('JSON gidiş-dönüşü alan kaybetmez', () {
      final menu = DailyMenu.fromJson(build());
      final again = DailyMenu.fromJson(menu.toJson());

      expect(again, menu);
      expect(again.package, menu.package);
      expect(again.items, menu.items);
    });

    test('itemFor kimliğe göre kalemi bulur, yoksa null döner', () {
      final menu = DailyMenu.fromJson(build());

      expect(menu.itemFor(101)?.name, 'Mercimek Çorbası');
      // Dünkü bir derin bağlantı bugün olmayan bir kaleme işaret edebilir;
      // ekran "bulunamadı" gösterebilmeli, çökmemeli.
      expect(menu.itemFor(999), isNull);
    });

    test('paket ÜRÜN karşılığına çevrilir', () {
      final menu = DailyMenu.fromJson(build());
      final item = menu.packageAsMenuItem!;

      // Sipariş satırına giden kimlik PAKETİN kimliği; sunucu içindekileri
      // kendisi açıyor.
      expect(item.id, 900);
      expect(item.name, 'Günün Menüsü');
      expect(item.price, 22000);
      expect(item.currency, 'TRY');
      expect(item.isAvailable, isTrue);

      // Paketin seçeneği yok: kalemleri o günün menüsünde sabit.
      expect(item.options, isEmpty);
    });

    test('paket satılmayan günde ürün karşılığı da yoktur', () {
      final menu = DailyMenu.fromJson({...build(), 'package': null});

      expect(menu.sellsPackage, isFalse);
      expect(menu.packageAsMenuItem, isNull);
    });

    test('tükenmiş paketin ürün karşılığı da satışta DEĞİLDİR', () {
      // Sepet kapısı `MenuItem.is_available`'a bakıyor; bayrak taşınmazsa
      // tükenmiş menü sepete girer ve sunucu siparişi reddederdi.
      final menu = DailyMenu.fromJson({
        ...build(),
        'package': <String, dynamic>{
          ...(build()['package']! as Map<String, dynamic>),
          'is_available': false,
          'sold_out_reason': 'Bugünün menüsü tükendi',
        },
      });

      final item = menu.packageAsMenuItem!;
      expect(item.isAvailable, isFalse);
      expect(item.soldOutReason, 'Bugünün menüsü tükendi');
    });

    test('paket avantajı yalnızca POZİTİFKEN gösterilir', () {
      final ucuz = DailyMenu.fromJson(build());
      expect(ucuz.packageSavingKurus, 4500);

      // Yönetici paket fiyatını kalemlerin toplamından yüksek girebilir;
      // "−45,00 ₺ avantaj" yazmak müşteriye paketi almamasını söylerdi.
      final pahali = DailyMenu.fromJson({
        ...build(),
        'items_total': 20000,
        'package': <String, dynamic>{
          ...(build()['package']! as Map<String, dynamic>),
          'price': 22000,
        },
      });
      expect(pahali.packageSavingKurus, isNull);
    });

    test('menüsü olmayan gün 200 döner ve çökertmez', () {
      final menu = DailyMenu.fromJson({
        'id': null,
        'date': '2026-08-21',
        'title': null,
        'description': null,
        'image_url': null,
        'package': null,
        'items_total': null,
        'currency': 'TRY',
        'closed': false,
        'is_orderable': false,
        'unavailable_reason': 'not_published',
        'items': <dynamic>[],
      });

      expect(menu.exists, isFalse);
      expect(menu.isEmpty, isTrue);
      expect(menu.sellsPackage, isFalse);
      expect(menu.packageSavingKurus, isNull);
      expect(menu.unavailableReason, DailyMenuUnavailableReason.notPublished);
    });

    test('sözleşmedeki bütün sebepler tanınır', () {
      const beklenen = {
        'closed_day': DailyMenuUnavailableReason.closedDay,
        'not_published': DailyMenuUnavailableReason.notPublished,
        'cutoff_passed': DailyMenuUnavailableReason.cutoffPassed,
        'past': DailyMenuUnavailableReason.past,
        'too_far': DailyMenuUnavailableReason.tooFar,
        // 16.08.2026'da eklendi. `no_service_day` ile `closed_day` AYRI:
        // biri "hafta sonu servisimiz yok", öbürü "o gün kapalıyız".
        'no_service_day': DailyMenuUnavailableReason.noServiceDay,
        'sold_out': DailyMenuUnavailableReason.soldOut,
      };

      for (final entry in beklenen.entries) {
        final menu = DailyMenu.fromJson({
          ...build(),
          'is_orderable': false,
          'unavailable_reason': entry.key,
        });
        expect(menu.unavailableReason, entry.value, reason: entry.key);
        expect(
          dailyMenuUnavailableLabelsTr[menu.unavailableReason],
          isNotEmpty,
          reason: '${entry.key} için gösterilecek metin yok.',
        );
      }
    });

    test('bilinmeyen sebep çökertmez (gevşek enum)', () {
      // Sunucu ileride "kontenjan doldu" gibi bir sebep ekleyebilir; eski
      // uygulamanın gün seçiciyi çizmeyi bırakmasının anlamı yok.
      final menu = DailyMenu.fromJson({
        ...build(),
        'is_orderable': false,
        'unavailable_reason': 'kontenjan_doldu',
      });

      expect(menu.unavailableReason, DailyMenuUnavailableReason.unknown);
      expect(menu.isOrderable, isFalse);
      expect(dailyMenuUnavailableLabelsTr[menu.unavailableReason], isNotEmpty);
    });

    test('HER sebebin bir Türkçe karşılığı vardır', () {
      // Sözleşmeye yeni bir sebep eklendiğinde enum'a üye eklemek yetmez;
      // metni de yazılmalı. Yazılmazsa `dailyMenuUnavailableLabelsTr[...]`
      // `null` döner ve gün seçici sebebi hiç göstermez — kullanıcı günün
      // neden kapalı olduğunu asla öğrenemez. Bu döngü onu derleme değil
      // ama TEST zamanında yakalar.
      for (final reason in DailyMenuUnavailableReason.values) {
        expect(
          dailyMenuUnavailableLabelsTr.containsKey(reason),
          isTrue,
          reason: '$reason için metin tablosunda karşılık yok.',
        );
      }

      // `none` bilerek boştur: sebep yokken cümle de yoktur.
      expect(dailyMenuUnavailableLabelsTr[DailyMenuUnavailableReason.none], '');
      for (final reason in DailyMenuUnavailableReason.values) {
        if (reason == DailyMenuUnavailableReason.none) continue;
        expect(
          dailyMenuUnavailableLabelsTr[reason],
          isNotEmpty,
          reason: '$reason gösterilebilir bir cümle taşımıyor.',
        );
      }
    });

    test('bilinmeyen sebep sunucuya GERİ GÖNDERİLMEZ', () {
      // `unknown.wireName` null: kodunu bilmediğimiz bir sebebi saklayıp geri
      // yollamak, saklamamaktan daha dürüst olmazdı. Gidiş-dönüşte alan
      // düşer ve bu KAYIP KABUL EDİLMİŞTİR — sebep yalnızca okunur.
      final menu = DailyMenu.fromJson({
        ...build(),
        'is_orderable': false,
        'unavailable_reason': 'kontenjan_doldu',
      });

      expect(menu.toJson().containsKey('unavailable_reason'), isFalse);
    });

    test('alan hiç gelmezse sebep "yok"tur', () {
      final json = build()..remove('unavailable_reason');
      expect(
        DailyMenu.fromJson(json).unavailableReason,
        DailyMenuUnavailableReason.none,
      );
    });

    test('tükenmiş kalem listede kalır ama sepete eklenemez', () {
      final json = build();
      (json['items']! as List<dynamic>)[1] = {
        'id': 102,
        'name': 'Tavuk Sote',
        'price': 20000,
        'currency': 'TRY',
        'is_available': false,
        'sold_out_today': true,
        'sold_out_reason': 'Tavuk bitti.',
      };

      final menu = DailyMenu.fromJson(json);

      expect(menu.items, hasLength(2), reason: 'Kalem listeden DÜŞMEZ.');
      expect(menu.availableItems, hasLength(1));
      expect(menu.items.last.soldOutToday, isTrue);
    });

    test('paket fiyatı kalem fiyatlarından bağımsızdır', () {
      final menu = DailyMenu.fromJson(build());
      final kalemToplami = menu.items.fold(0, (sum, i) => sum + i.price);

      expect(kalemToplami, 26500);
      expect(menu.package!.price, 22000);
      expect(menu.package!.price, lessThan(kalemToplami));
    });
  });

  // ───────────────────── Kesim anı ve stok (16.08.2026) ─────────────────────

  group('DailyMenu — kesim anı ve stok', () {
    Map<String, dynamic> base() => {
      'id': 77,
      'date': '2026-08-20',
      'currency': 'TRY',
      'closed': false,
      'is_orderable': true,
      'items': <dynamic>[],
    };

    test('kesim MUTLAK AN olarak ayrıştırılır (UTC)', () {
      final menu = DailyMenu.fromJson({
        ...base(),
        'cutoff_at': '2026-08-20T05:00:00Z',
      });

      // 08:00 Europe/Istanbul = 05:00 UTC. İstemci saat DİLİMİ hesabı
      // yapmaz; sunucunun gönderdiği anı olduğu gibi taşır.
      expect(menu.cutoffAt, DateTime.utc(2026, 8, 20, 5));
      expect(menu.cutoffAt!.isUtc, isTrue);
    });

    test('kesim tanımlı değilse null — geri sayım çizilmez', () {
      expect(DailyMenu.fromJson(base()).cutoffAt, isNull);
    });

    test('KALAN PORSİYON: null SINIRSIZ, 0 TÜKENDİ', () {
      // Sözleşmenin en pahalı karışıklığı bu. `null`'ı `0` sayan istemci,
      // tavanı hiç konmamış bir günü tükenmiş gösterir ve satış durur.
      expect(DailyMenu.fromJson(base()).remainingPortions, isNull);
      expect(
        DailyMenu.fromJson({
          ...base(),
          'remaining_portions': 0,
        }).remainingPortions,
        0,
      );
      expect(
        DailyMenu.fromJson({
          ...base(),
          'remaining_portions': 12,
        }).remainingPortions,
        12,
      );
    });

    test('kalem ve paket tavanları ayrı ayrı taşınır', () {
      final menu = DailyMenu.fromJson({
        ...base(),
        'remaining_portions': 40,
        'package': {
          'menu_id': 900,
          'name': 'Günün Menüsü',
          'price': 22000,
          'is_available': true,
          'remaining_portions': 12,
          'components': <dynamic>[],
        },
        'items': [
          {
            'id': 101,
            'name': 'Mercimek Çorbası',
            'price': 6500,
            'currency': 'TRY',
            'is_available': true,
            'remaining_portions': 4,
          },
          {
            'id': 102,
            'name': 'Tavuk Sote',
            'price': 20000,
            'currency': 'TRY',
            'is_available': true,
          },
        ],
      });

      expect(menu.remainingPortions, 40);
      expect(menu.package!.remainingPortions, 12);
      expect(menu.items.first.remainingPortions, 4);
      // Tavanı olmayan kalem SINIRSIZDIR, sıfır değil.
      expect(menu.items.last.remainingPortions, isNull);
    });

    test('paketin tavanı ÜRÜN karşılığına da geçer', () {
      // Sepetin adet sayacı kalem tavanını `MenuItem.remainingPortions`
      // üzerinden okuyor; tavan burada düşerse paket sınırsızmış gibi
      // eklenir ve sunucu siparişi reddeder.
      final menu = DailyMenu.fromJson({
        ...base(),
        'package': {
          'menu_id': 900,
          'name': 'Günün Menüsü',
          'price': 22000,
          'is_available': true,
          'remaining_portions': 3,
          'components': <dynamic>[],
        },
      });

      expect(menu.packageAsMenuItem!.remainingPortions, 3);
    });

    test('görsel ızgarası ayrıştırılır ve gidiş-dönüş yapar', () {
      final menu = DailyMenu.fromJson({
        ...base(),
        'image_urls': [
          'https://ornek.test/1.jpg',
          'https://ornek.test/2.jpg',
          'https://ornek.test/3.jpg',
        ],
      });

      expect(menu.imageUrls, hasLength(3));
      expect(DailyMenu.fromJson(menu.toJson()), menu);
    });

    test('KAPAK varsa ızgaraya tercih edilir', () {
      final kapakli = DailyMenu.fromJson({
        ...base(),
        'image_url': 'https://ornek.test/kapak.jpg',
        'image_urls': ['https://ornek.test/1.jpg', 'https://ornek.test/2.jpg'],
      });

      expect(kapakli.cardImageUrls, ['https://ornek.test/kapak.jpg']);
    });

    test('kapak yoksa ızgara çizilir, dörtten fazlası kesilir', () {
      final menu = DailyMenu.fromJson({
        ...base(),
        'image_urls': [
          'https://ornek.test/1.jpg',
          'https://ornek.test/2.jpg',
          'https://ornek.test/3.jpg',
          'https://ornek.test/4.jpg',
          'https://ornek.test/5.jpg',
        ],
      });

      expect(menu.cardImageUrls, hasLength(4));
      expect(menu.cardImageUrls.last, 'https://ornek.test/4.jpg');
    });

    test('görseli hiç olmayan gün boş liste verir', () {
      expect(DailyMenu.fromJson(base()).cardImageUrls, isEmpty);
      expect(DailyMenu.fromJson(base()).imageUrls, isEmpty);
    });
  });

  group('MenuCalendarDay', () {
    test('sözleşme örneği ayrıştırılır ve gidiş-dönüş yapar', () {
      final gun = MenuCalendarDay.fromJson({
        'date': '2026-08-20',
        'has_menu': true,
        'closed': false,
        'is_orderable': true,
        'title': 'Ev Yemeği Menüsü',
        'package_price': 22000,
        'note': null,
      });

      expect(gun.date, '2026-08-20');
      expect(gun.hasMenu, isTrue);
      expect(gun.packagePrice, 22000);
      expect(MenuCalendarDay.fromJson(gun.toJson()), gun);
    });

    test('kapalı gün menüsüz gelir, notu taşır', () {
      final gun = MenuCalendarDay.fromJson({
        'date': '2026-08-22',
        'has_menu': false,
        'closed': true,
        'is_orderable': false,
        'title': null,
        'package_price': null,
        'note': 'Kurban Bayramı',
      });

      expect(gun.closed, isTrue);
      expect(gun.isOrderable, isFalse);
      expect(gun.isBrowsable, isFalse);
      expect(gun.note, 'Kurban Bayramı');
    });

    test('menüsü olan ama sipariş alınmayan gün GÖRÜNTÜLENEBİLİR', () {
      // Kesim saati geçmiş bugünün menüsüne bakabilmeli; sepete ekleme
      // kapısı `is_orderable`.
      final gun = MenuCalendarDay.fromJson({
        'date': '2026-08-13',
        'has_menu': true,
        'closed': false,
        'is_orderable': false,
      });

      expect(gun.isBrowsable, isTrue);
      expect(gun.isOrderable, isFalse);
    });

    test('kesim anı takvimde de gelir', () {
      // Gün seçici her günü ayrı ayrı sorgulamadan bandı çizebilsin diye.
      final gun = MenuCalendarDay.fromJson({
        'date': '2026-08-20',
        'has_menu': true,
        'closed': false,
        'is_orderable': true,
        'cutoff_at': '2026-08-20T05:00:00Z',
      });

      expect(gun.cutoffAt, DateTime.utc(2026, 8, 20, 5));
      expect(MenuCalendarDay.fromJson(gun.toJson()), gun);
    });

    test('TÜKENMİŞ gün takvimde KALIR ve görüntülenebilir', () {
      // Günü listeden düşürseydik "menü girilmemiş" ile "kapış kapış gitti"
      // aynı boşluğa düşerdi.
      final gun = MenuCalendarDay.fromJson({
        'date': '2026-08-20',
        'has_menu': true,
        'closed': false,
        'is_orderable': false,
        'sold_out': true,
      });

      expect(gun.soldOut, isTrue);
      expect(gun.isBrowsable, isTrue, reason: 'Menü yine okunabilmeli.');
      expect(gun.isOrderable, isFalse);
    });

    test('servis dışı gün işaretlenir; SATIŞ KANALI kapanmaz', () {
      // Cumartesi hücresi servis dışıdır ama o gün pazartesiye sipariş
      // verilebilir — bu alan yalnız HÜCRENİN kendi gününü anlatır.
      final cumartesi = MenuCalendarDay.fromJson({
        'date': '2026-08-22',
        'has_menu': false,
        'closed': false,
        'is_orderable': false,
        'weekend': true,
      });

      expect(cumartesi.weekend, isTrue);
      expect(cumartesi.closed, isFalse, reason: 'Servis yok ≠ kapalıyız.');
    });

    test('yeni alanlar gelmezse eski yanıt çökertmez', () {
      final gun = MenuCalendarDay.fromJson({
        'date': '2026-08-20',
        'has_menu': true,
        'closed': false,
        'is_orderable': true,
      });

      expect(gun.cutoffAt, isNull);
      expect(gun.soldOut, isFalse);
      expect(gun.weekend, isFalse);
    });
  });

  group('Location — günün menüsü şalteri', () {
    Map<String, dynamic> base() => {
      'id': 1,
      'name': 'BLD',
      'slug': 'catering',
      'is_open': true,
      'ordering_enabled': true,
      'min_order_total': 0,
      'payment_methods': ['cash'],
    };

    test('alanlar okunur', () {
      final location = Location.fromJson({
        ...base(),
        'daily_menu_enabled': true,
        'max_lookahead_days': 14,
        'service_weekdays': [1, 2, 3, 4, 5, 6],
      });

      expect(location.dailyMenuEnabled, isTrue);
      expect(location.maxLookaheadDays, 14);
      expect(location.serviceWeekdays, [1, 2, 3, 4, 5, 6]);
    });

    test('eski sunucu yanıtında şalter KAPALI, pencere 7 GÜNDÜR', () {
      // Alanlar sözleşmeye sonradan eklendi; gelmediğinde eski katalog
      // akışı çalışmalı — kendiliğinden açılan bir şalter, menüsü girilmemiş
      // bir vitrini satılamaz hâle getirirdi.
      //
      // Pencerenin varsayılanı 30 DEĞİL 7'dir (16.08.2026): şemadaki
      // `default: 30` katalog dönemine ait tarihsel bir annotasyondur.
      // 30 varsaysaydık eski önbellekten okuyan istemci bir ay ileriye
      // tıklanabilir takvim çizer ve sunucudan `too_far` yerdi.
      final location = Location.fromJson(base());

      expect(location.dailyMenuEnabled, isFalse);
      expect(location.maxLookaheadDays, 7);
    });

    test('servis günleri gelmezse HAFTA İÇİ varsayılır', () {
      // Boş liste varsaymak takvimin HER gününü soluk çizmek olurdu.
      expect(Location.fromJson(base()).serviceWeekdays, [1, 2, 3, 4, 5]);
    });
  });

  group('OrderCreateRequest — servis günü', () {
    test('service_date sözleşmedeki adla gider', () {
      const request = OrderCreateRequest(
        locationId: 1,
        items: [OrderCreateItem(menuId: 900, quantity: 1)],
        deliveryType: DeliveryType.pickup,
        paymentMethod: PaymentMethod.cash,
        serviceDate: '2026-08-20',
      );

      expect(request.toJson()['service_date'], '2026-08-20');
    });

    test('gün seçilmezse alan gövdeye HİÇ girmez', () {
      // Sunucu o zaman `requested_at`in gününü, o da yoksa bugünü kullanır.
      // `null` göndermek de aynı sonucu verirdi ama gövdeyi kirletirdi.
      const request = OrderCreateRequest(
        locationId: 1,
        items: [OrderCreateItem(menuId: 101, quantity: 1)],
        deliveryType: DeliveryType.pickup,
        paymentMethod: PaymentMethod.cash,
      );

      expect(request.toJson().containsKey('service_date'), isFalse);
    });

    test('paket, sıradan bir satır gibi menu_id ile sipariş edilir', () {
      // İstek BİÇİMİ değişmedi: paketin kimliği DailyMenu.package.menu_id.
      const request = OrderCreateRequest(
        locationId: 1,
        items: [OrderCreateItem(menuId: 900, quantity: 2)],
        deliveryType: DeliveryType.delivery,
        paymentMethod: PaymentMethod.cash,
        serviceDate: '2026-08-20',
        address: Address(line1: 'a', district: 'b', city: 'c'),
      );

      final items = request.toJson()['items']! as List<dynamic>;
      final first = items.single as Map<String, dynamic>;
      expect(first['menu_id'], 900);
      expect(first['quantity'], 2);
      expect(first.containsKey('role'), isFalse, reason: 'Rol İSTEKTE yok.');
    });
  });

  group('OrderItem — satır rolü', () {
    Map<String, dynamic> orderJson() => {
      'id': 5013,
      'order_number': 'S-5013',
      'status': 'yeni',
      'items': [
        {
          'menu_id': 900,
          'name': 'Günün Menüsü (20.08)',
          'quantity': 1,
          'unit_price': 22000,
          'line_total': 22000,
          'role': 'package',
          'included_in': null,
          'daily_menu_id': 77,
        },
        {
          'menu_id': 101,
          'name': 'Mercimek Çorbası',
          'quantity': 1,
          'unit_price': 0,
          'line_total': 0,
          'role': 'component',
          'included_in': 0,
          'daily_menu_id': 77,
        },
        {
          'menu_id': 102,
          'name': 'Tavuk Sote',
          'quantity': 2,
          'unit_price': 0,
          'line_total': 0,
          'role': 'component',
          'included_in': 0,
          'daily_menu_id': 77,
        },
        {
          'menu_id': 105,
          'name': 'Ayran',
          'quantity': 1,
          'unit_price': 2500,
          'line_total': 2500,
          'role': 'item',
        },
      ],
      'subtotal': 24500,
      'delivery_fee': 0,
      'total': 24500,
      'currency': 'TRY',
      'delivery_type': 'pickup',
      'service_date': '2026-08-20',
      'payment': {'method': 'cash', 'status': 'pending'},
      'status_history': [
        {'status': 'yeni', 'at': '2026-08-13T11:30:00Z'},
      ],
      'created_at': '2026-08-13T11:30:00Z',
    };

    test('roller ve servis günü ayrıştırılır', () {
      final order = OrderDetail.fromJson(orderJson());

      expect(order.serviceDate, '2026-08-20');
      expect(order.items, hasLength(4));
      expect(order.items[0].isPackageHeader, isTrue);
      expect(order.items[1].isPackageComponent, isTrue);
      expect(order.items[3].isPlainItem, isTrue);
      expect(order.items[0].dailyMenuId, 77);
    });

    test('parayı paket satırı taşır, bileşenler sıfırdır', () {
      final order = OrderDetail.fromJson(orderJson());

      expect(order.items[0].lineTotal, 22000);
      expect(order.items[1].lineTotal, 0);
      expect(order.items[2].lineTotal, 0);
      // Toplam sunucudan gelir; satırlardan toplanmaz.
      expect(order.total, 24500);
    });

    test('bileşenler paketin ALTINA yerleşir, listede ayrı satır olmaz', () {
      final order = OrderDetail.fromJson(orderJson());

      expect(order.topLevelItems.map((i) => i.name), [
        'Günün Menüsü (20.08)',
        'Ayran',
      ]);
      expect(order.componentsOf(0).map((i) => i.name), [
        'Mercimek Çorbası',
        'Tavuk Sote',
      ]);
      expect(order.componentsOf(3), isEmpty);
    });

    test('ROL YOKKEN VARSAYILAN item — eski sunucu yanıtı kırmaz', () {
      // Sözleşmedeki `default: item` budur. Alan gelmediğinde satırlar düz
      // listeye düşer ve ekran bugünkü gibi çizilir; bir satırın rolsüz
      // gelmesi onu gizlemeye ya da bedava göstermeye YOL AÇMAMALI.
      final item = OrderItem.fromJson({
        'menu_id': 101,
        'name': 'Tavuk Sote',
        'quantity': 2,
        'unit_price': 18500,
        'line_total': 37000,
      });

      expect(item.role, 'item');
      expect(item.isPlainItem, isTrue);
      expect(item.isPackageHeader, isFalse);
      expect(item.isPackageComponent, isFalse);
      expect(item.includedIn, isNull);
      expect(item.dailyMenuId, isNull);
    });

    test('bilinmeyen rol sıradan satır sayılır', () {
      // Rolü tanımadığımız bir satırı gizlemek, siparişten bir yemeği yok
      // etmek olurdu.
      final item = OrderItem.fromJson({
        'menu_id': 101,
        'name': 'Tavuk Sote',
        'quantity': 1,
        'unit_price': 18500,
        'line_total': 18500,
        'role': 'gift',
      });

      expect(item.isPlainItem, isTrue);
      expect(item.isPackageHeader, isFalse);
    });

    test('JSON gidiş-dönüşü rolü ve bağı korur', () {
      final item = OrderItem.fromJson({
        'menu_id': 101,
        'name': 'Mercimek Çorbası',
        'quantity': 1,
        'unit_price': 0,
        'line_total': 0,
        'role': 'component',
        'included_in': 0,
        'daily_menu_id': 77,
      });

      expect(OrderItem.fromJson(item.toJson()), item);
    });

    test('service_date gelmeyen eski yanıt çökertmez', () {
      final json = orderJson()..remove('service_date');
      expect(OrderDetail.fromJson(json).serviceDate, isNull);
    });
  });

  group('OrderSummary — servis günü', () {
    Map<String, dynamic> build() => {
      'id': 5013,
      'order_number': 'S-5013',
      'status': 'yeni',
      'total': 24500,
      'currency': 'TRY',
      'item_count': 2,
      'created_at': '2026-08-13T11:30:00Z',
      'service_date': '2026-08-20',
    };

    test('sipariş günü ile servis günü AYRIDIR', () {
      final summary = OrderSummary.fromJson(build());

      expect(summary.createdAt, DateTime.utc(2026, 8, 13, 11, 30));
      expect(summary.serviceDate, '2026-08-20');
      expect(
        BusinessDate.fromUtc(summary.createdAt),
        isNot(summary.serviceDate),
        reason: 'İleri tarihli siparişte ikisi aynı gün değildir.',
      );
    });

    test('alan gelmezse null, çökme yok', () {
      final json = build()..remove('service_date');
      expect(OrderSummary.fromJson(json).serviceDate, isNull);
    });
  });

  // ────────────────────── Yapılandırılmış adres (B-21) ──────────────────────

  group('AddressSuggestion', () {
    Map<String, dynamic> build() => {
      'label': 'Feritpaşa Mah., Kültür Sk. No:12, Selçuklu / Konya',
      'line1': 'Feritpaşa Mah. Kültür Sk. No:12',
      'neighbourhood': 'Feritpaşa Mah.',
      'street': 'Kültür Sk.',
      'district': 'Selçuklu',
      'city': 'Konya',
      'latitude': 37.8842,
      'longitude': 32.4931,
      'source': 'osm_nominatim',
    };

    test('sözleşme örneği ayrıştırılır ve gidiş-dönüş yapar', () {
      final suggestion = AddressSuggestion.fromJson(build());

      expect(suggestion.district, 'Selçuklu');
      expect(suggestion.latitude, 37.8842);
      expect(suggestion.source, 'osm_nominatim');
      expect(AddressSuggestion.fromJson(suggestion.toJson()), suggestion);
    });

    test('bilinmeyen sağlayıcı çökertmez — source kapalı enum değil', () {
      final suggestion = AddressSuggestion.fromJson({
        ...build(),
        'source': 'google_places',
      });
      expect(suggestion.source, 'google_places');
    });

    test('öneri kayda çevrilirken gösterim satırı ETİKET olmaz', () {
      // Aksi halde defterde "Feritpaşa Mah., Kültür Sk. No:12, Selçuklu /
      // Konya" ADINDA bir adres oluşurdu; etiket müşterinin verdiği addır.
      final input = AddressSuggestion.fromJson(build()).toInput();

      expect(input.label, isNull);
      expect(input.line1, 'Feritpaşa Mah. Kültür Sk. No:12');
      expect(input.neighbourhood, 'Feritpaşa Mah.');
      expect(input.street, 'Kültür Sk.');
      expect(input.latitude, 37.8842);
    });

    test('müşterinin verdiği ad korunur', () {
      final input = AddressSuggestion.fromJson(
        build(),
      ).toInput(addressLabel: 'Ofis', note: 'Zili çalmayın');

      expect(input.label, 'Ofis');
      expect(input.note, 'Zili çalmayın');
    });
  });

  group('Yapılandırılmış adres alanları', () {
    test('sipariş adresi beş alanı da taşır', () {
      final address = Address.fromJson({
        'line1': 'Feritpaşa Mah. Kültür Sk. No:12/A Kat:3 D:7',
        'neighbourhood': 'Feritpaşa Mah.',
        'street': 'Kültür Sk.',
        'building_no': '12/A',
        'floor': '3',
        'door_no': '7',
        'district': 'Selçuklu',
        'city': 'Konya',
      });

      expect(address.neighbourhood, 'Feritpaşa Mah.');
      expect(address.buildingNo, '12/A');
      expect(address.floor, '3');
      expect(address.doorNo, '7');
      expect(Address.fromJson(address.toJson()), address);
    });

    test('kat METİN olarak taşınır — "Zemin" geçerli bir değerdir', () {
      final address = Address.fromJson({
        'line1': 'a',
        'district': 'b',
        'city': 'c',
        'floor': 'Zemin',
      });
      expect(address.floor, 'Zemin');
    });

    test('eski kayıtta alanlar null gelir ve öyle kalır', () {
      final saved = SavedAddress.fromJson({
        'id': 1,
        'line1': 'Atatürk Caddesi No:12',
        'district': 'Nilüfer',
        'city': 'Bursa',
        'is_default': true,
      });

      expect(saved.neighbourhood, isNull);
      expect(saved.doorNo, isNull);
      expect(saved.line1, 'Atatürk Caddesi No:12');
    });

    test(
      'defterden siparişe kopyalanırken yapılandırılmış alanlar taşınır',
      () {
        // Taşınmazsa kurye fişinde daire numarası kaybolur ve müşteri, adres
        // defterinde doğru yazdığı kapıyı bulamayan bir kuryeyle karşılaşır.
        const saved = SavedAddress(
          id: 1,
          line1: 'Feritpaşa Mah. Kültür Sk. No:12/A',
          district: 'Selçuklu',
          city: 'Konya',
          isDefault: true,
          neighbourhood: 'Feritpaşa Mah.',
          street: 'Kültür Sk.',
          buildingNo: '12/A',
          floor: 'Zemin',
          doorNo: '2',
        );

        final order = saved.toOrderAddress();

        expect(order.neighbourhood, 'Feritpaşa Mah.');
        expect(order.street, 'Kültür Sk.');
        expect(order.buildingNo, '12/A');
        expect(order.floor, 'Zemin');
        expect(order.doorNo, '2');
      },
    );

    test('girdide beş alan da AÇIKÇA null gönderilir', () {
      // Koordinatlarla aynı kural: alan yok = koru, alan null = sil. Onsuz
      // müşteri yanlış girdiği kat numarasını boşaltamazdı.
      const input = SavedAddressInput(
        line1: 'Atatürk Caddesi No:12',
        district: 'Nilüfer',
        city: 'Bursa',
      );

      final json = input.toJson();

      for (final key in [
        'neighbourhood',
        'street',
        'building_no',
        'floor',
        'door_no',
      ]) {
        expect(
          json.containsKey(key),
          isTrue,
          reason: '$key gönderilemezse alan hiç silinemez.',
        );
        expect(json[key], isNull);
      }

      // İstisna diğer alanlara SIZMAMALI (bkz. address_pin_test.dart).
      expect(json.containsKey('label'), isFalse);
    });

    test('dolu alanlar gövdeye girer', () {
      const input = SavedAddressInput(
        line1: 'Feritpaşa Mah. Kültür Sk. No:12/A',
        district: 'Selçuklu',
        city: 'Konya',
        neighbourhood: 'Feritpaşa Mah.',
        street: 'Kültür Sk.',
        buildingNo: '12/A',
        floor: 'Zemin',
        doorNo: '2',
      );

      final json = input.toJson();

      expect(json['neighbourhood'], 'Feritpaşa Mah.');
      expect(json['building_no'], '12/A');
      expect(json['floor'], 'Zemin');
      expect(json['door_no'], '2');
    });
  });

  // ─────────────────── Ödeme akışı — sıradaki adım (Faz 3) ──────────────────

  group('Payment — sıradaki adım', () {
    test('tahsilat kimliği sipariş kimliğinden AYRIDIR', () {
      final payment = Payment.fromJson({
        'method': 'online',
        'status': 'pending',
        'payment_id': 4412,
        'next_action': 'three_ds',
        'redirect_url': 'https://sanalpos.example/3ds/abc',
      });

      expect(payment.paymentId, 4412);
      expect(payment.nextAction, PaymentNextAction.threeDs);
      expect(payment.requiresRedirect, isTrue);
    });

    test('kapıda ödemede kimlik ve adım YOKTUR', () {
      final payment = Payment.fromJson({'method': 'cash', 'status': 'pending'});

      expect(payment.paymentId, isNull);
      expect(payment.nextAction, PaymentNextAction.none);
      expect(payment.nextAction.requiresCustomerStep, isFalse);
    });

    test('null adım "adım yok" demektir', () {
      final payment = Payment.fromJson({
        'method': 'cash',
        'status': 'paid',
        'next_action': null,
      });

      expect(payment.nextAction, PaymentNextAction.none);
    });

    test('BİLİNMEYEN adım none SAYILMAZ', () {
      // Sözleşmenin en tehlikeli kenar durumu: bilinmeyen adımı `none`
      // saymak, atlanmış bir doğrulamayı "ödeme bitti" diye göstermektir.
      final payment = Payment.fromJson({
        'method': 'online',
        'status': 'pending',
        'next_action': 'biometric',
      });

      expect(payment.nextAction, PaymentNextAction.unknown);
      expect(payment.nextAction, isNot(PaymentNextAction.none));
      expect(payment.nextAction.requiresCustomerStep, isTrue);
      expect(payment.nextAction.isSupported, isFalse);
      expect(paymentNextActionLabelsTr[payment.nextAction], isNotEmpty);
    });

    test('bilinmeyen adım sunucuya GERİ GÖNDERİLMEZ', () {
      final payment = Payment.fromJson({
        'method': 'online',
        'status': 'pending',
        'next_action': 'biometric',
      });

      expect(payment.toJson().containsKey('next_action'), isFalse);
    });

    test('HER adımın bir Türkçe karşılığı vardır', () {
      for (final action in PaymentNextAction.values) {
        expect(
          paymentNextActionLabelsTr.containsKey(action),
          isTrue,
          reason: '$action için metin tablosunda karşılık yok.',
        );
      }
      // `none` bilerek boştur: adım yokken cümle de yoktur.
      expect(paymentNextActionLabelsTr[PaymentNextAction.none], '');
    });
  });

  // ──────────── Abonelik: istisna, ödeme, sözleşme (16.08.2026) ─────────────

  group('SubscriptionException', () {
    test('atlanan gün ayrıştırılır ve gidiş-dönüş yapar', () {
      final exception = SubscriptionException.fromJson({
        'service_date': '2026-09-03',
        'skip': true,
        'quantity_override': null,
        'created_at': '2026-08-28T11:15:00Z',
      });

      expect(exception.serviceDate, '2026-09-03');
      expect(exception.skip, isTrue);
      expect(exception.effectiveQuantity(20), 0);
      expect(SubscriptionException.fromJson(exception.toJson()), exception);
    });

    test('adet değiştirilen gün varsayılanı EZER', () {
      final exception = SubscriptionException.fromJson({
        'service_date': '2026-09-04',
        'skip': false,
        'quantity_override': 8,
      });

      expect(exception.effectiveQuantity(20), 8);
    });

    test('override yoksa aboneliğin varsayılanı geçerlidir', () {
      final exception = SubscriptionException.fromJson({
        'service_date': '2026-09-05',
        'skip': false,
      });

      expect(exception.quantityOverride, isNull);
      expect(exception.effectiveQuantity(20), 20);
    });
  });

  group('Subscription — ara durumlar ve gömülü özetler', () {
    Map<String, dynamic> base() => {
      'id': 12,
      'status': 'awaiting_contract',
      'location_id': 1,
      'delivery_type': 'delivery',
      'start_date': '2026-09-01',
      'service_days': [1, 2, 3, 4, 5],
      'default_quantity': 20,
      'agreed_unit_price': 15000,
      'payment_mode': 'prepaid_monthly',
      'menu_mode': 'daily_menu',
      'lines': <dynamic>[],
      'delivery_points': <dynamic>[],
      'created_at': '2026-08-20T06:00:00Z',
    };

    test('sözleşme onayı bekleyen abonelik', () {
      final subscription = Subscription.fromJson({
        ...base(),
        'contract': {
          'status': 'sent',
          'version': 2,
          'sent_at': '2026-08-25T08:00:00Z',
          'approved_at': null,
        },
      });

      expect(subscription.isAwaitingContract, isTrue);
      expect(subscription.isPending, isFalse);
      expect(subscription.isActive, isFalse);
      expect(subscription.contract!.isAwaitingApproval, isTrue);
      expect(subscription.contract!.version, 2);
      expect(subscription.contract!.approvedAt, isNull);
    });

    test('ödeme bekleyen abonelik dönem özetini taşır', () {
      final subscription = Subscription.fromJson({
        ...base(),
        'status': 'awaiting_payment',
        'payment': {
          'payment_id': null,
          'period': '2026-09',
          'amount': 660000,
          'currency': 'TRY',
          'status': 'pending',
          'due_date': '2026-09-05',
        },
      });

      expect(subscription.isAwaitingPayment, isTrue);
      expect(subscription.payment!.period, '2026-09');
      expect(subscription.payment!.amount, 660000);
      // Ödeme henüz BAŞLATILMADI: `null` ile `0` karıştırılmaz.
      expect(subscription.payment!.paymentId, isNull);
      expect(subscription.payment!.isStarted, isFalse);
      expect(subscription.payment!.isPaid, isFalse);
      expect(subscription.payment!.dueDate, '2026-09-05');
    });

    test('fiyatlanmamış talepte ödeme ve sözleşme YOKTUR', () {
      final subscription = Subscription.fromJson({
        ...base(),
        'status': 'pending',
        'agreed_unit_price': null,
      });

      expect(subscription.isPending, isTrue);
      expect(subscription.payment, isNull);
      expect(subscription.contract, isNull);
      expect(subscription.exceptions, isEmpty);
    });

    test('istisnalar geri OKUNUR — atlanan gün ekranda görünebilir', () {
      // Faz 0 öncesi açık: istisna yazılıyordu ama hiçbir uç geri
      // okumuyordu; abone atladığını göremediği için aynı günü tekrar
      // tekrar atlıyordu.
      final subscription = Subscription.fromJson({
        ...base(),
        'status': 'active',
        'exceptions': [
          {'service_date': '2026-09-03', 'skip': true},
          {'service_date': '2026-09-04', 'skip': false, 'quantity_override': 8},
        ],
      });

      expect(subscription.exceptions, hasLength(2));
      expect(subscription.exceptionFor('2026-09-03')!.skip, isTrue);
      expect(subscription.quantityFor('2026-09-03'), 0);
      expect(subscription.quantityFor('2026-09-04'), 8);
      // İstisnası olmayan gün varsayılan adedi alır.
      expect(subscription.exceptionFor('2026-09-07'), isNull);
      expect(subscription.quantityFor('2026-09-07'), 20);
    });

    test('bilinmeyen durum hâlâ çökertmez', () {
      final subscription = Subscription.fromJson({
        ...base(),
        'status': 'suspended_for_debt',
      });

      expect(subscription.status, 'suspended_for_debt');
      expect(subscription.isActive, isFalse);
      expect(subscription.isAwaitingContract, isFalse);
      expect(subscription.isAwaitingPayment, isFalse);
    });
  });

  group('SubscriptionPayment', () {
    Map<String, dynamic> base() => {
      'payment_id': 501,
      'subscription_id': 12,
      'period': '2026-09',
      'amount': 660000,
      'currency': 'TRY',
      'status': 'pending',
      'next_action': 'none',
      'created_at': '2026-08-28T09:00:00Z',
    };

    test('sözleşme örneği ayrıştırılır ve gidiş-dönüş yapar', () {
      final payment = SubscriptionPayment.fromJson(base());

      expect(payment.paymentId, 501);
      expect(payment.subscriptionId, 12);
      expect(payment.period, '2026-09');
      expect(payment.amount, 660000);
      expect(payment.nextAction, PaymentNextAction.none);
      expect(payment.isPaid, isFalse);
      expect(payment.shouldPoll, isTrue);
      expect(SubscriptionPayment.fromJson(payment.toJson()), payment);
    });

    test('OTP adımı SMS kodu ister', () {
      final payment = SubscriptionPayment.fromJson({
        ...base(),
        'next_action': 'otp',
      });

      expect(payment.needsOtp, isTrue);
      expect(payment.needsRedirect, isFalse);
    });

    test('3-D Secure ADRESSİZ yönlendirme sayılmaz', () {
      // Adres olmadan "yönlendirileceksiniz" demek, açılacak sayfası
      // olmayan bir düğme çizmektir.
      expect(
        SubscriptionPayment.fromJson({
          ...base(),
          'next_action': 'three_ds',
        }).needsRedirect,
        isFalse,
      );
      expect(
        SubscriptionPayment.fromJson({
          ...base(),
          'next_action': 'three_ds',
          'redirect_url': 'https://sanalpos.example/3ds/xyz',
        }).needsRedirect,
        isTrue,
      );
    });

    test('ödendikten sonra yoklama biter', () {
      final payment = SubscriptionPayment.fromJson({
        ...base(),
        'status': 'paid',
        'redirect_url': null,
        'paid_at': '2026-08-28T09:04:00Z',
      });

      expect(payment.isPaid, isTrue);
      expect(payment.shouldPoll, isFalse);
      expect(payment.paidAt, DateTime.utc(2026, 8, 28, 9, 4));
    });

    test('başarısızlık sebebi Türkçe ve gösterilebilir', () {
      final payment = SubscriptionPayment.fromJson({
        ...base(),
        'failure_reason': 'Kart limiti yetersiz.',
      });

      expect(payment.failureReason, 'Kart limiti yetersiz.');
    });
  });

  group('SubscriptionContract', () {
    Map<String, dynamic> base() => {
      'status': 'sent',
      'version': 1,
      'body': '# Abonelik Sözleşmesi\n\nTaraflar ...',
      'body_format': 'markdown',
      'service_days': [1, 2, 3, 4, 5],
      'unit_price': 15000,
      'currency': 'TRY',
      'customer_label': 'Örnek Mühendislik A.Ş.',
      'masked_phone': '0555 *** ** 33',
      'start_date': '2026-09-01',
      'end_date': null,
      'default_quantity': 20,
      'monthly_estimate': 660000,
      'expires_at': '2026-09-01T20:59:59Z',
      'approved_at': null,
    };

    test('sözleşme örneği ayrıştırılır ve gidiş-dönüş yapar', () {
      final contract = SubscriptionContract.fromJson(base());

      expect(contract.version, 1);
      expect(contract.isMarkdown, isTrue);
      expect(contract.unitPrice, 15000);
      expect(contract.monthlyEstimate, 660000);
      expect(contract.canApprove, isTrue);
      expect(contract.isApproved, isFalse);
      expect(SubscriptionContract.fromJson(contract.toJson()), contract);
    });

    test('yanıt DAR: kimlik, adres ve e-posta alanı YOK', () {
      // Uç kimlik gerektirmiyor; bağlantıyı ele geçiren biri yalnız
      // sözleşmeyi ve MASKELİ telefonu görmeli.
      final json = SubscriptionContract.fromJson(base()).toJson();

      for (final yasak in [
        'customer_id',
        'email',
        'address',
        'telephone',
        'phone',
      ]) {
        expect(
          json.containsKey(yasak),
          isFalse,
          reason: '$yasak sözleşme görünümünde BULUNMAMALI.',
        );
      }
      expect(json['masked_phone'], '0555 *** ** 33');
    });

    test('süresi dolmuş bağlantı 200 + expired döner, hata DEĞİL', () {
      final contract = SubscriptionContract.fromJson({
        ...base(),
        'status': 'expired',
      });

      expect(contract.isExpired, isTrue);
      expect(contract.canApprove, isFalse);
      expect(contract.isCancelled, isFalse, reason: 'İkisi AYRI durumdur.');
    });

    test('iptal ile süre dolumu ayrı — yapılacak iş farklı', () {
      final iptal = SubscriptionContract.fromJson({
        ...base(),
        'status': 'cancelled',
      });

      expect(iptal.isCancelled, isTrue);
      expect(iptal.isExpired, isFalse);
      expect(iptal.canApprove, isFalse);
    });

    test('onaylanan sözleşme terminaldir', () {
      final contract = SubscriptionContract.fromJson({
        ...base(),
        'status': 'approved',
        'approved_at': '2026-08-26T12:30:00Z',
      });

      expect(contract.isApproved, isTrue);
      expect(contract.canApprove, isFalse);
      expect(contract.approvedAt, DateTime.utc(2026, 8, 26, 12, 30));
    });

    test('bilinmeyen biçim DÜZ METİN sayılır', () {
      // Biçimlendirmeyi yanlış tahmin etmek, hiç biçimlendirmemekten kötü.
      final contract = SubscriptionContract.fromJson({
        ...base(),
        'body_format': 'html',
      });

      expect(contract.isMarkdown, isFalse);
    });
  });

  // ────────────────────────────── Duyuru (Faz 4) ────────────────────────────

  group('Announcement', () {
    Map<String, dynamic> base() => {
      'id': 31,
      'placement': 'home',
      'body': 'Yarın servisimiz yoktur.',
      'dismissible': true,
      'seen': false,
      'dismissed': false,
    };

    test('sözleşme örneği ayrıştırılır ve gidiş-dönüş yapar', () {
      final duyuru = Announcement.fromJson({
        ...base(),
        'severity': 'critical',
        'title': 'Servis duyurusu',
        'action_label': 'Menüye git',
        'action_url': '/menu',
        'starts_at': '2026-08-17T06:00:00Z',
        'ends_at': '2026-08-18T21:00:00Z',
        'created_at': '2026-08-16T18:00:00Z',
      });

      expect(duyuru.id, 31);
      expect(duyuru.severity, AnnouncementSeverity.critical);
      expect(duyuru.isFor(AnnouncementPlacement.home), isTrue);
      expect(duyuru.hasAction, isTrue);
      expect(Announcement.fromJson(duyuru.toJson()), duyuru);
    });

    test('ton gelmezse info varsayılır', () {
      expect(Announcement.fromJson(base()).severity, AnnouncementSeverity.info);
    });

    test('bilinmeyen ton çökertmez, en sakin tona düşer', () {
      // Bilinmeyen ton yüzünden duyuruyu hiç göstermemek, yanlış renkle
      // göstermekten çok daha pahalıdır.
      final duyuru = Announcement.fromJson({...base(), 'severity': 'panic'});

      expect(duyuru.severity, AnnouncementSeverity.info);
      expect(duyuru.body, 'Yarın servisimiz yoktur.');
    });

    test('kritik duyuru KAPANMAZ demek değildir', () {
      final duyuru = Announcement.fromJson({
        ...base(),
        'severity': 'critical',
        'dismissible': true,
      });

      expect(duyuru.severity, AnnouncementSeverity.critical);
      expect(duyuru.dismissible, isTrue);
    });

    test('etiketsiz adres ve adressiz etiket düğme ÇİZDİRMEZ', () {
      expect(
        Announcement.fromJson({...base(), 'action_url': '/menu'}).hasAction,
        isFalse,
      );
      expect(
        Announcement.fromJson({...base(), 'action_label': 'Git'}).hasAction,
        isFalse,
      );
      expect(Announcement.fromJson(base()).hasAction, isFalse);
    });

    test('bilinmeyen yerleşim çökertmez — kapalı enum DEĞİL', () {
      final duyuru = Announcement.fromJson({
        ...base(),
        'placement': 'yeni_ekran',
      });

      expect(duyuru.placement, 'yeni_ekran');
      expect(duyuru.isFor(AnnouncementPlacement.home), isFalse);
    });
  });

  // ────────────────────────────── Teşhis (Faz 4) ────────────────────────────

  group('ClientErrorReport', () {
    test('gövde sözleşmedeki adlarla üretilir', () {
      final report = ClientErrorReport(
        message: 'Menü çizilemedi',
        kind: ClientErrorKind.render,
        route: '/menu/2026-08-20',
        occurredAt: DateTime.utc(2026, 8, 20, 9, 15),
        appBuild: '1042',
        device: 'Android 15 / Pixel 8',
        context: const {'attempt': 2},
      );

      final json = report.toJson();

      expect(json['message'], 'Menü çizilemedi');
      expect(json['kind'], 'render');
      expect(json['route'], '/menu/2026-08-20');
      expect(json['occurred_at'], '2026-08-20T09:15:00.000Z');
      expect(json['app_build'], '1042');
      expect(json['device'], 'Android 15 / Pixel 8');
      expect(json['context'], {'attempt': 2});
    });

    test('SOURCE alanı gövdede BULUNMAZ', () {
      // Sunucu bunu `X-App-Id` başlığından türetiyor. Gövdede taşınsaydı
      // web sitesi `mutfakapp` yazan bir rapor üretip mutfağın güvendiği
      // hata monitörüne sahte KDS alarmı düşürebilirdi.
      final json = const ClientErrorReport(message: 'Hata').toJson();

      expect(json.containsKey('source'), isFalse);
    });

    test('sınırı aşan alanlar KESİLİR, rapor atılmaz', () {
      final report = ClientErrorReport(
        message: 'a' * 900,
        stack: 'b' * 9000,
        route: 'c' * 400,
        appBuild: 'd' * 80,
        device: 'e' * 300,
      ).truncated();

      expect(report.message.length, 500);
      expect(report.stack!.length, 8000);
      expect(report.route!.length, 200);
      expect(report.appBuild!.length, 40);
      expect(report.device!.length, 120);
    });

    test('sınır altındaki değerler dokunulmadan geçer', () {
      const report = ClientErrorReport(message: 'Kısa', route: '/sepet');

      expect(report.truncated().message, 'Kısa');
      expect(report.truncated().route, '/sepet');
      expect(report.truncated().stack, isNull);
    });
  });

  // ──────────────────── Cari hesap kaldırıldı — kalıntılar ──────────────────

  group('Customer — can_order alanı korunur ama okunmaz', () {
    test('alan sözleşmede duruyor ve ayrıştırılıyor', () {
      // Cari hesap kalktı, `CustomerGate` kalktı; alan EKLEYİCİ sözleşme
      // gereği duruyor (`AGENTS.md` §2.3). Yeni kod ona BAKMAZ.
      final customer = Customer.fromJson({
        'id': 4,
        'first_name': 'Veysel',
        'last_name': 'Tuncer',
        'email': 'veysel@ornek.test',
        'telephone': '05551112233',
        'can_order': false,
      });

      expect(customer.canOrder, isFalse);
      expect(customer.toJson()['can_order'], isFalse);
    });

    test('alan gelmezse true — sipariş yolu kapanmaz', () {
      final customer = Customer.fromJson({
        'id': 4,
        'first_name': 'Veysel',
        'last_name': 'Tuncer',
        'email': 'veysel@ornek.test',
        'telephone': '05551112233',
      });

      expect(customer.canOrder, isTrue);
    });
  });
}
