/// BBD Store köprüsü — K-16.
///
/// BBD Store bir **kitap e-ticaret sitesi**; köprünün tek varlık sebebi
/// termal yazıcıyı paylaşmak. İki kural pahalı: **basım başarısızsa ack
/// gönderilmemeli** (fiş kaybolur) ve **beş fiş için beş kez ses
/// çalınmamalı** (personel sesi kapatır).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/data/bbd_monitor.dart';
import 'package:mutfakapp/src/data/bbd_source.dart';

import 'fake_system_audio.dart';

BbdOrder order({
  int id = 1,
  String external = 'BBD-1',
  String number = 'BBD-1',
  int? amount,
  String? phone,
  List<BbdOrderItem> items = const [
    BbdOrderItem(
      name: "Türkiye'nin Yakın Tarihi — Cilt II",
      quantity: 2,
      sku: '9789750718533',
    ),
  ],
  String? cargo,
  String? tracking,
}) => BbdOrder(
  id: id,
  externalId: external,
  orderNumber: number,
  items: items,
  amountKurus: amount,
  customerPhone: phone,
  cargoCompany: cargo,
  trackingNumber: tracking,
);

/// Basım çağrılarını kaydeden, istenirse patlayan yazıcı.
class _Printer {
  final List<List<int>> writes = [];
  bool fail = false;

  Future<void> call(List<int> bytes) async {
    if (fail) throw StateError('yazıcı kapalı');
    writes.add(bytes);
  }
}

void main() {
  late _Printer printer;
  late int soundCount;

  BbdMonitor build(FakeBbdApi api) => BbdMonitor(
    api: api,
    print: printer.call,
    playSound: () async => soundCount++,
    clock: () => DateTime.utc(2026, 8, 12, 11, 32),
  );

  setUp(() {
    printer = _Printer();
    soundCount = 0;
  });

  test('kuyruk boşken ses çalmaz, fiş basmaz', () async {
    await build(FakeBbdApi()).poll();

    expect(soundCount, 0);
    expect(printer.writes, isEmpty);
  });

  test('gelen fiş basılır ve onaylanır', () async {
    final api = FakeBbdApi(orders: [order()]);

    final state = await build(api).poll();

    expect(printer.writes, hasLength(1));
    expect(api.acked, [1]);
    expect(state.printedToday, 1);
    expect(state.pending, 0);
  });

  test('SES BİR KEZ çalar — fiş başına değil', () async {
    // Beş fiş için beş kez üst üste ses çalmak, mutfağı sesi kapatmaya
    // iter.
    final api = FakeBbdApi(
      orders: [
        order(id: 1, external: 'BBD-1'),
        order(id: 2, external: 'BBD-2'),
        order(id: 3, external: 'BBD-3'),
      ],
    );

    await build(api).poll();

    expect(soundCount, 1);
    expect(printer.writes, hasLength(3));
  });

  test('BASIM BAŞARISIZSA ACK GÖNDERİLMEZ — fiş kaybolmaz', () async {
    // Ack gönderilseydi sunucu fişi "basıldı" işaretler ve kâğıt hiç
    // çıkmadan kuyruktan düşerdi.
    final api = FakeBbdApi(orders: [order()]);
    printer.fail = true;

    final state = await build(api).poll();

    expect(api.acked, isEmpty);
    expect(state.printedToday, 0);
    expect(state.lastError, isNotNull);
  });

  test('bir fiş patlarsa SONRAKİLER de bekletilir', () async {
    // Sırayı bozmamak için: ikinci fiş basılıp birincisi bekleseydi,
    // mutfak kâğıtları yanlış sırada alırdı.
    final api = FakeBbdApi(
      orders: [order(id: 1), order(id: 2)],
    );
    printer.fail = true;

    await build(api).poll();

    expect(api.acked, isEmpty);
  });

  test('ağ hatası çökertmez, sebebi durumda kalır', () async {
    final api = FakeBbdApi()..failPending = true;

    final state = await build(api).poll();

    expect(state.lastError, contains('ağ yok'));
    expect(printer.writes, isEmpty);
  });

  test('başarılı turdan sonra hata temizlenir', () async {
    final api = FakeBbdApi()..failPending = true;
    final monitor = build(api);

    await monitor.poll();
    expect(monitor.state.lastError, isNotNull);

    api.failPending = false;
    final state = await monitor.poll();

    expect(state.lastError, isNull);
  });

  test('basılan sayacı turlar arasında birikir', () async {
    final monitor = build(FakeBbdApi(orders: [order(id: 1)]));
    await monitor.poll();

    final api2 = FakeBbdApi(orders: [order(id: 2, external: 'BBD-2')]);
    final monitor2 = BbdMonitor(
      api: api2,
      print: printer.call,
      playSound: () async => soundCount++,
    );
    await monitor2.poll();

    expect(printer.writes, hasLength(2));
  });

  group('Fiş içeriği', () {
    String render(List<int> bytes) =>
        String.fromCharCodes(bytes.where((b) => b >= 32 && b < 127));

    test('BBD STORE başlığı basılır — BLD fişiyle karışmasın', () async {
      // Bu sipariş KDS panosunda YOK; kâğıdı karıştıran personel panoda
      // olmayan bir siparişi arar.
      final api = FakeBbdApi(orders: [order()]);
      await build(api).poll();

      expect(render(printer.writes.single), contains('BBD STORE'));
    });

    test('TUTAR gönderilmediyse satır basılmaz', () async {
      final api = FakeBbdApi(orders: [order()]);
      await build(api).poll();

      expect(render(printer.writes.single), isNot(contains('TUTAR')));
    });

    test('tutar gönderildiyse basılır', () async {
      final api = FakeBbdApi(orders: [order(amount: 18500)]);
      await build(api).poll();

      expect(render(printer.writes.single), contains('TUTAR'));
    });

    test('telefon fişe geçer', () async {
      final api = FakeBbdApi(
        orders: [order(phone: '0555 123 45 67')],
      );
      await build(api).poll();

      expect(render(printer.writes.single), contains('0555 123 45 67'));
    });

    test('STOK KODU fişe geçer — raftan bulmanın en hızlı yolu', () async {
      final api = FakeBbdApi(orders: [order()]);
      await build(api).poll();

      expect(render(printer.writes.single), contains('9789750718533'));
    });

    test('KARGO bilgisi fişe geçer', () async {
      // Kitapta `delivery` kurye değil kargo demek; paketleyen kişi
      // doğru poşeti seçmek zorunda.
      final api = FakeBbdApi(
        orders: [order(cargo: 'Yurtiçi Kargo', tracking: '1234567890123')],
      );
      await build(api).poll();

      final text = render(printer.writes.single);
      expect(text, contains('Kargo'));
      expect(text, contains('1234567890123'));
    });
  });

  group('BbdOrder.fromJson', () {
    test('sunucu gövdesinden alanları çıkarır', () {
      final parsed = BbdOrder.fromJson({
        'id': 42,
        'external_id': 'BBD-2026-1',
        'payload': {
          'order_number': 'BBD-99',
          'customer_label': 'Ayşe Y.',
          'phone': '0555 111 22 33',
          'delivery_type': 'delivery',
          'address': 'Örnek Mah.',
          'amount_kurus': 12500,
          'items': [
            {
              'name': 'Sessiz Ev',
              'quantity': 3,
              'sku': '9789750802942',
              'attributes': ['Orhan Pamuk'],
            },
          ],
          'cargo_company': 'Aras Kargo',
          'tracking_number': '9876543210',
          'payment_label': 'Ödendi (kredi kartı)',
        },
      });

      expect(parsed.id, 42);
      expect(parsed.externalId, 'BBD-2026-1');
      expect(parsed.orderNumber, 'BBD-99');
      expect(parsed.amountKurus, 12500);
      expect(parsed.items.single.quantity, 3);
      expect(parsed.items.single.sku, '9789750802942');
      expect(parsed.items.single.attributes, ['Orhan Pamuk']);
      expect(parsed.cargoCompany, 'Aras Kargo');
      expect(parsed.trackingNumber, '9876543210');
      expect(parsed.paymentLabel, 'Ödendi (kredi kartı)');
    });

    test('gövde eksikse çökmez, sipariş numarası kimliğe düşer', () {
      // BBD'nin gövdesi bizim şemamız değil; eksik alan sessizce
      // tolere edilmeli, fiş yine basılmalı.
      final parsed = BbdOrder.fromJson({
        'id': 7,
        'external_id': 'BBD-7',
        'payload': <String, Object?>{},
      });

      expect(parsed.orderNumber, 'BBD-7');
      expect(parsed.items, isEmpty);
      expect(parsed.amountKurus, isNull);
    });
  });
}
