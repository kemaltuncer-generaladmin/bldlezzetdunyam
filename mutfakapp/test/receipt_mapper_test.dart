/// Sözleşme DTO'sundan ESC/POS şablon girdisine dönüşüm testleri.
///
/// Kritik olan: mutfak fişinde fiyat, gel-al müşteri fişinde adres olmamalı.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_core/escpos.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/printing/receipt_mapper.dart';

final DateTime printedAt = DateTime.utc(2026, 8, 4, 11, 32);

void main() {
  group('Mutfak fişi dönüşümü', () {
    final receipt = KitchenReceipt(
      orderNumber: 'S-5012',
      deliveryType: DeliveryType.delivery,
      requestedAt: DateTime.utc(2026, 8, 5, 6, 30),
      customerNote: 'Fatura kurumsal',
      lines: const [
        ReceiptLine(
          quantity: 2,
          name: 'Tavuk Sote',
          options: ['Büyük'],
          note: 'Az acılı',
        ),
      ],
    );

    test('alanlar birebir taşınır', () {
      final data = toKitchenReceiptData(receipt, printedAt: printedAt);

      expect(data.orderNumber, 'S-5012');
      expect(data.deliveryType, DeliveryType.delivery);
      expect(data.printedAt, printedAt);
      expect(data.requestedAt, receipt.requestedAt);
      expect(data.customerNote, 'Fatura kurumsal');
      expect(data.lines.single.quantity, 2);
      expect(data.lines.single.options, ['Büyük']);
      expect(data.lines.single.note, 'Az acılı');
    });

    test('üretilen fiş basılabilir ve Türkçe karakter taşır', () {
      final bytes = buildKitchenReceipt(
        toKitchenReceiptData(receipt, printedAt: printedAt),
      );
      // "Az acılı" içindeki ı → 0x8D.
      expect(bytes, contains(0x8D));
      expect(bytes.sublist(bytes.length - 4), EscPosCommands.cut);
    });
  });

  group('Müşteri fişi dönüşümü', () {
    CustomerReceipt build({
      required DeliveryType deliveryType,
      Address? address,
      PaymentMethod method = PaymentMethod.cash,
      PaymentStatus status = PaymentStatus.pending,
    }) => CustomerReceipt(
      orderNumber: 'S-5012',
      deliveryType: deliveryType,
      items: const [
        OrderItem(
          menuId: 1,
          name: 'Tavuk Sote',
          quantity: 2,
          unitPrice: 18500,
          lineTotal: 37000,
        ),
      ],
      subtotal: 37000,
      deliveryFee: deliveryType == DeliveryType.delivery ? 4000 : 0,
      total: deliveryType == DeliveryType.delivery ? 41000 : 37000,
      currency: 'TRY',
      payment: Payment(method: method, status: status),
      address: address,
    );

    test('adrese gönderimde adres taşınır', () {
      final data = toCustomerReceiptData(
        build(
          deliveryType: DeliveryType.delivery,
          address: const Address(
            line1: 'Örnek Mah. 12. Sk No:3',
            district: 'Çankaya',
            city: 'Ankara',
          ),
        ),
        printedAt: printedAt,
      );

      expect(data.address?.line1, 'Örnek Mah. 12. Sk No:3');
      expect(data.deliveryFee, 4000);
    });

    test('gel-al siparişte adres yoktur', () {
      final data = toCustomerReceiptData(
        build(deliveryType: DeliveryType.pickup),
        printedAt: printedAt,
      );

      expect(data.address, isNull);
      expect(data.deliveryFee, 0);
    });

    test('ödeme yöntemi ve durumu eşlenir', () {
      final data = toCustomerReceiptData(
        build(
          deliveryType: DeliveryType.pickup,
          method: PaymentMethod.online,
          status: PaymentStatus.paid,
        ),
        printedAt: printedAt,
      );

      expect(data.paymentMethod, ReceiptPaymentMethod.online);
      expect(data.paymentStatus, ReceiptPaymentStatus.paid);
    });

    test('bilinmeyen ödeme değeri çökmeye yol açmaz', () {
      final data = toCustomerReceiptData(
        build(
          deliveryType: DeliveryType.pickup,
          method: PaymentMethod.unknown,
          status: PaymentStatus.unknown,
        ),
        printedAt: printedAt,
      );

      expect(data.paymentMethod, ReceiptPaymentMethod.unknown);
      expect(data.paymentStatus, ReceiptPaymentStatus.unknown);
    });

    test('her ödeme yöntemi için bir fiş karşılığı vardır', () {
      for (final method in PaymentMethod.values) {
        final data = toCustomerReceiptData(
          build(deliveryType: DeliveryType.pickup, method: method),
          printedAt: printedAt,
        );
        expect(data.paymentMethod, isNotNull);
      }
      for (final status in PaymentStatus.values) {
        final data = toCustomerReceiptData(
          build(deliveryType: DeliveryType.pickup, status: status),
          printedAt: printedAt,
        );
        expect(data.paymentStatus, isNotNull);
      }
    });
  });
}
