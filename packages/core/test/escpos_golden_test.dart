/// ESC/POS golden testleri — `AGENTS.md` §5, `docs/05-mutfakapp.md` §10.
///
/// İki fiş tipi × iki teslimat tipi = dört sabit bayt dizisi. Beklenen çıktılar
/// `test/golden/*.hex` dosyalarındadır; şablonda istemeden yapılan her değişim
/// bu testleri kırar.
///
/// Golden dosyaları yenilemek (yalnızca bilinçli bir şablon değişiminden sonra):
///
/// ```bash
/// BLD_UPDATE_GOLDEN=1 dart test test/escpos_golden_test.dart
/// git diff packages/core/test/golden   # değişimi satır satır gözden geçir
/// ```
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:bld_core/bld_core.dart';
import 'package:bld_core/escpos.dart';
import 'package:test/test.dart';

/// Fişteki tarih: 04.08.2026 14:32 (Türkiye) = 11:32 UTC.
final DateTime printedAt = DateTime.utc(2026, 8, 4, 11, 32);

/// İstenen teslim: 05.08 09:30 (Türkiye) = 06:30 UTC.
final DateTime requestedAt = DateTime.utc(2026, 8, 5, 6, 30);

final KitchenReceiptData kitchenDelivery = KitchenReceiptData(
  orderNumber: 'S-5012',
  deliveryType: DeliveryType.delivery,
  printedAt: printedAt,
  requestedAt: requestedAt,
  customerNote: 'Fatura kurumsal',
  lines: const [
    KitchenReceiptLine(
      quantity: 2,
      name: 'Tavuk Sote',
      options: ['Normal'],
      note: 'Az acılı',
    ),
    KitchenReceiptLine(quantity: 1, name: 'Mercimek Çorbası'),
  ],
);

final KitchenReceiptData kitchenPickup = KitchenReceiptData(
  orderNumber: 'S-5013',
  deliveryType: DeliveryType.pickup,
  printedAt: printedAt,
  lines: const [
    KitchenReceiptLine(quantity: 12, name: 'Karnıyarık'),
    KitchenReceiptLine(
      quantity: 3,
      name: 'Şehriye Çorbası',
      options: ['Büyük', 'Limonlu'],
    ),
  ],
);

final CustomerReceiptData customerDelivery = CustomerReceiptData(
  orderNumber: 'S-5012',
  deliveryType: DeliveryType.delivery,
  printedAt: printedAt,
  requestedAt: requestedAt,
  lines: const [
    CustomerReceiptLine(quantity: 2, name: 'Tavuk Sote', lineTotal: 37000),
    CustomerReceiptLine(quantity: 1, name: 'Mercimek Çorbası', lineTotal: 8500),
  ],
  subtotal: 45500,
  deliveryFee: 4000,
  total: 49500,
  paymentMethod: ReceiptPaymentMethod.online,
  paymentStatus: ReceiptPaymentStatus.paid,
  address: const ReceiptAddress(
    line1: 'Örnek Mah. 12. Sk No:3',
    district: 'Çankaya',
    city: 'Ankara',
  ),
);

/// Haritadan iğne bırakılmış sipariş — fişe QR basılmalı.
final CustomerReceiptData customerDeliveryWithPin = CustomerReceiptData(
  orderNumber: 'S-5014',
  deliveryType: DeliveryType.delivery,
  printedAt: printedAt,
  lines: const [
    CustomerReceiptLine(quantity: 2, name: 'Tavuk Sote', lineTotal: 37000),
  ],
  subtotal: 37000,
  deliveryFee: 4000,
  total: 41000,
  paymentMethod: ReceiptPaymentMethod.cash,
  paymentStatus: ReceiptPaymentStatus.pending,
  address: const ReceiptAddress(
    line1: 'Örnek Mah. 12. Sk No:3',
    district: 'Çankaya',
    city: 'Ankara',
    latitude: 40.2114567,
    longitude: 28.9876543,
  ),
);

final CustomerReceiptData customerPickup = CustomerReceiptData(
  orderNumber: 'S-5013',
  deliveryType: DeliveryType.pickup,
  printedAt: printedAt,
  lines: const [
    CustomerReceiptLine(quantity: 12, name: 'Karnıyarık', lineTotal: 108000),
    CustomerReceiptLine(
      quantity: 3,
      name: 'Şehriye Çorbası',
      lineTotal: 25500,
      options: ['Büyük', 'Limonlu'],
    ),
  ],
  subtotal: 133500,
  deliveryFee: 0,
  total: 133500,
  paymentMethod: ReceiptPaymentMethod.cash,
  paymentStatus: ReceiptPaymentStatus.pending,
);

void main() {
  // Golden klasörü çalışma dizininden yukarı doğru aranarak bulunur.
  //
  // NEDEN `Isolate.resolvePackageUri` DEĞİL: o çözüm `dart test` altında
  // çalışıyordu ama `mutfakapp` pub workspace'e katılınca testler
  // `flutter test` ile koşmaya başladı ve orada
  // `Isolate.resolvePackageUriSync` desteklenmiyor — tüm golden testleri
  // setUpAll'da patlıyordu.
  //
  // Yukarı arama her iki koşucuda da, hem paket içinden hem repo kökünden
  // çalışır ve hiçbir SDK ayrıntısına bağlı değildir.
  setUpAll(() {
    var dizin = Directory.current;

    for (var i = 0; i < 6; i++) {
      final aday = Directory('${dizin.path}/packages/core/test/golden');
      if (aday.existsSync()) {
        _goldenDir = aday;
        return;
      }

      final yerel = Directory('${dizin.path}/test/golden');
      if (yerel.existsSync() && dizin.path.endsWith('core')) {
        _goldenDir = yerel;
        return;
      }

      final ust = dizin.parent;
      if (ust.path == dizin.path) break;
      dizin = ust;
    }

    fail(
      'Golden klasörü bulunamadı. Çalışma dizini: ${Directory.current.path}',
    );
  });

  group('Golden — mutfak fişi', () {
    test('adrese gönderim', () {
      expectGolden(
        'receipt_mutfak_delivery',
        buildKitchenReceipt(kitchenDelivery),
      );
    });

    test('gel-al', () {
      expectGolden('receipt_mutfak_pickup', buildKitchenReceipt(kitchenPickup));
    });
  });

  group('Golden — müşteri fişi', () {
    test('adrese gönderim', () {
      expectGolden(
        'receipt_musteri_delivery',
        buildCustomerReceipt(customerDelivery),
      );
    });

    test('gel-al', () {
      expectGolden(
        'receipt_musteri_pickup',
        buildCustomerReceipt(customerPickup),
      );
    });

    test('haritadan seçilmiş konumla (QR)', () {
      expectGolden(
        'receipt_musteri_delivery_qr',
        buildCustomerReceipt(customerDeliveryWithPin),
      );
    });
  });

  group('QR kod', () {
    test('iğne yoksa QR komutu hiç basılmaz', () {
      // Koordinatsız sipariş fişinde QR bloğu bulunmamalı; boş bir QR
      // yazıcıda çöp sembol üretir.
      final bytes = buildCustomerReceipt(customerDelivery);
      expect(_contains(bytes, EscPosCommands.qrPrint), isFalse);
    });

    test('iğne varsa QR basma komutu bulunur', () {
      final bytes = buildCustomerReceipt(customerDeliveryWithPin);
      expect(_contains(bytes, EscPosCommands.qrPrint), isTrue);
    });

    test('QR verisi harita bağlantısını taşır', () {
      final bytes = buildCustomerReceipt(customerDeliveryWithPin);
      final url = customerDeliveryWithPin.address!.mapUrl;

      expect(_contains(bytes, url.codeUnits), isTrue);
      // Yedi ondalık korunmalı: yuvarlama iğneyi metrelerce kaydırır.
      expect(url, contains('40.2114567,28.9876543'));
    });

    test('uzunluk baytı cn+fn+m dahil sayılır', () {
      // En sık yapılan hata yalnızca veri uzunluğunu yazmak. O durumda
      // yazıcı eksik bayt bekler, sonraki komutları veri sanar ve fişin
      // geri kalanı çöp basar.
      final store = EscPosCommands.qrStore(List<int>.filled(10, 0x41));

      expect(store[3], 13, reason: 'pL = veri + 3 olmalı');
      expect(store[4], 0, reason: 'pH');
      expect(store.length, 18);
    });

    test('uzunluk 255i aşınca pH kullanılır', () {
      // Uzun bir URL (ör. ondalıkları tam koordinat + ek parametre) 255
      // baytı aşabilir; tek baytlık uzunluk sessizce taşardı.
      final store = EscPosCommands.qrStore(List<int>.filled(300, 0x41));

      expect(store[3], (303) & 0xFF);
      expect(store[4], (303) >> 8);
    });
  });

  group('Şablon değişmezleri', () {
    test('mutfak fişinde fiyat geçmez', () {
      final text = _decode(buildKitchenReceipt(kitchenDelivery));
      expect(text, isNot(contains('370,00')));
      expect(text, isNot(contains('TOPLAM')));
      expect(text, isNot(contains('Ödeme')));
    });

    test('mutfak fişinde adres ve telefon geçmez', () {
      final text = _decode(buildKitchenReceipt(kitchenDelivery));
      expect(text, isNot(contains('Teslimat:')));
      expect(text, isNot(contains('Ankara')));
    });

    test('gel-al müşteri fişinde teslimat ücreti satırı yoktur', () {
      final text = _decode(buildCustomerReceipt(customerPickup));
      expect(text, isNot(contains('Teslimat')));
      expect(text, contains('GEL-AL'));
    });

    test('adrese gönderim müşteri fişinde adres bloğu vardır', () {
      final text = _decode(buildCustomerReceipt(customerDelivery));
      expect(text, contains('Teslimat:'));
      expect(text, contains('Örnek Mah. 12. Sk No:3'));
      expect(text, contains('Çankaya / Ankara'));
      expect(text, isNot(contains('GEL-AL')));
    });

    test('her fiş sıfırlama ile başlar, kesme ile biter', () {
      for (final bytes in [
        buildKitchenReceipt(kitchenDelivery),
        buildKitchenReceipt(kitchenPickup),
        buildCustomerReceipt(customerDelivery),
        buildCustomerReceipt(customerPickup),
      ]) {
        expect(bytes.sublist(0, 5), [
          ...EscPosCommands.initialize,
          ...EscPosCommands.selectCodePage(EscPosCommands.turkishCodePage),
        ]);
        expect(bytes.sublist(bytes.length - 4), EscPosCommands.cut);
      }
    });

    test('sipariş notu asla kırpılmaz', () {
      final data = KitchenReceiptData(
        orderNumber: 'S-9001',
        deliveryType: DeliveryType.pickup,
        printedAt: printedAt,
        customerNote:
            'Kapıda arayın, asansör bozuk, üçüncü kata elden çıkarılacak '
            've fatura kurumsal kesilecek',
        lines: const [KitchenReceiptLine(quantity: 1, name: 'Ayran')],
      );
      final text = _decode(buildKitchenReceipt(data)).replaceAll('\n', ' ');
      expect(text, contains('elden çıkarılacak'));
      expect(text, contains('fatura kurumsal kesilecek'));
    });

    test('uzun ürün adı satıra sığdırılır, taşma yapmaz', () {
      final data = CustomerReceiptData(
        orderNumber: 'S-9002',
        deliveryType: DeliveryType.pickup,
        printedAt: printedAt,
        lines: const [
          CustomerReceiptLine(
            quantity: 1,
            name: 'Fırında Kaşarlı Karnıyarık Özel Porsiyon Büyük Boy',
            lineTotal: 19900,
          ),
        ],
        subtotal: 19900,
        deliveryFee: 0,
        total: 19900,
        paymentMethod: ReceiptPaymentMethod.account,
        paymentStatus: ReceiptPaymentStatus.pending,
      );
      for (final line in _decode(buildCustomerReceipt(data)).split('\n')) {
        expect(line.length, lessThanOrEqualTo(ReceiptStyle.standard.columns));
      }
    });

    test('şablonlar saftır — aynı girdi aynı baytları verir', () {
      expect(
        buildCustomerReceipt(customerDelivery),
        buildCustomerReceipt(customerDelivery),
      );
    });
  });
}

// ───────────────────────────── Golden altyapısı ─────────────────────────────

/// Golden dosyalarının bulunduğu klasör; `setUpAll` doldurur.
late Directory _goldenDir;

void expectGolden(String name, Uint8List actual) {
  final file = File('${_goldenDir.path}/$name.hex');

  if (Platform.environment['BLD_UPDATE_GOLDEN'] == '1') {
    _goldenDir.createSync(recursive: true);
    file.writeAsStringSync(_toHexDump(name, actual));
    return;
  }

  if (!file.existsSync()) {
    fail(
      'Golden dosyası yok: ${file.path}\n'
      'Bilinçli bir şablon değişimiyse: BLD_UPDATE_GOLDEN=1 dart test',
    );
  }

  final expected = _parseHexDump(file.readAsStringSync());
  expect(
    actual,
    expected,
    reason:
        'Fiş çıktısı ${file.path} ile uyuşmuyor.\n'
        '── Üretilen ──\n${_decode(actual)}\n'
        '── Beklenen ──\n${_decode(Uint8List.fromList(expected))}',
  );
}

/// Baytları gözden geçirilebilir bir hex dökümüne çevirir.
///
/// Ham `.bin` yerine hex metin tutulur: `git diff` okunabilir olsun, fişin
/// hangi satırının değiştiği review'da görülebilsin.
String _toHexDump(String name, Uint8List bytes) {
  final buffer = StringBuffer()
    ..writeln('# $name — beklenen ESC/POS baytları (${bytes.length} bayt)')
    ..writeln('# Üreten: packages/core/test/escpos_golden_test.dart')
    ..writeln('# Yenileme: BLD_UPDATE_GOLDEN=1 dart test')
    ..writeln('#')
    ..writeln('# Okunabilir karşılığı (kontrol baytları noktayla gösterilir):');

  for (final line in _decode(bytes).split('\n')) {
    buffer.writeln('#   $line');
  }
  buffer.writeln();

  for (var offset = 0; offset < bytes.length; offset += 16) {
    final end = (offset + 16 < bytes.length) ? offset + 16 : bytes.length;
    buffer.writeln(
      bytes
          .sublist(offset, end)
          .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
          .join(' '),
    );
  }
  return buffer.toString();
}

List<int> _parseHexDump(String content) => content
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('#'))
    .expand((line) => line.trim().split(RegExp(r'\s+')))
    .where((token) => token.isNotEmpty)
    .map((token) => int.parse(token, radix: 16))
    .toList(growable: false);

/// Baytları insan okuması için geri çevirir.
///
/// Kontrol dizileri (`ESC ...`, `GS ...`) atılır, satır beslemesi `\n` olur,
/// PC857 baytları Unicode'a döner. Yalnızca teşhis içindir.
/// [bytes] içinde [pattern] dizisi geçiyor mu?
///
/// Metne çevirip aramıyoruz: QR komutları yazdırılabilir olmayan baytlar
/// içeriyor ve PC857 çözümü onları bozar.
bool _contains(List<int> bytes, List<int> pattern) {
  if (pattern.isEmpty || pattern.length > bytes.length) return false;

  for (var i = 0; i <= bytes.length - pattern.length; i++) {
    var eslesti = true;
    for (var j = 0; j < pattern.length; j++) {
      if (bytes[i + j] != pattern[j]) {
        eslesti = false;
        break;
      }
    }
    if (eslesti) return true;
  }
  return false;
}

String _decode(List<int> bytes) {
  final buffer = StringBuffer();
  var index = 0;

  while (index < bytes.length) {
    final byte = bytes[index];

    if (byte == 0x1B) {
      // ESC @ iki bayt, diğerleri (ESC a n / ESC E n / ESC t n) üç bayt.
      index += (index + 1 < bytes.length && bytes[index + 1] == 0x40) ? 2 : 3;
      continue;
    }
    if (byte == 0x1D) {
      // GS ! n üç bayt, GS V B n dört bayt.
      index += (index + 1 < bytes.length && bytes[index + 1] == 0x56) ? 4 : 3;
      continue;
    }
    if (byte == EscPosCommands.lineFeed) {
      buffer.write('\n');
      index++;
      continue;
    }

    buffer.write(_reverseTable[byte] ?? String.fromCharCode(byte));
    index++;
  }

  return buffer.toString();
}

/// PC857 baytı → karakter. [Pc857.encode] üzerinden türetilir ki tablonun tek
/// kaynağı kalsın.
final Map<int, String> _reverseTable = {
  for (var codeUnit = 0xA0; codeUnit <= 0x2600; codeUnit++)
    if (Pc857.canEncode(String.fromCharCode(codeUnit)))
      Pc857.encode(String.fromCharCode(codeUnit)).single: String.fromCharCode(
        codeUnit,
      ),
};
