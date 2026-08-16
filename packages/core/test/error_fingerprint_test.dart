/// Hata parmak izi testleri — `docs/03-api-sozlesmesi.md` §15.6.
///
/// Aynı tarif web sitesinde de uygulanacağı için burada iki şey sınanır:
/// tarifin **davranışı** (neyi aynı, neyi farklı sayar) ve iki sabit **çıktı
/// değeri**. Sabit değerler kilit görevindedir: TypeScript karşılığı aynı
/// girdilerde bu dizeleri üretmiyorsa iki platform ayrışmıştır.
library;

import 'package:bld_core/bld_core.dart';
import 'package:test/test.dart';

/// Mutfak kasasından gelen tipik bir yığın izi.
const List<String> _frames = [
  '#0 OrderPrinter.print (package:mutfakapp/printer.dart:142:7)',
  '#1 KitchenScreen._onTap (package:mutfakapp/screen.dart:88:12)',
  '#2 _rootRun (dart:async/zone.dart:1399:13)',
];

void main() {
  group('Parmak izi biçimi', () {
    test('16 haneli küçük harf onaltılık', () {
      expect(
        fingerprint('unhandled', 'Yazıcı bulunamadı', _frames),
        matches(RegExp(r'^[0-9a-f]{16}$')),
      );
    });

    test('boş girdi de geçerli bir iz üretir', () {
      // Yığın izi olmayan hata (örn. elle bildirim) da raporlanabilmeli.
      expect(fingerprint('', '', const []), matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    test('aynı girdi aynı izi verir', () {
      expect(
        fingerprint('network', 'İstek zaman aşımına uğradı', _frames),
        fingerprint('network', 'İstek zaman aşımına uğradı', _frames),
      );
    });
  });

  group('Neyi aynı sayar', () {
    test('mesajdaki ve çerçevedeki sayılar iz değiştirmez', () {
      // "Sipariş 8421 basılamadı" ile "8422" tek hatanın iki tekrarıdır;
      // satır/sütun numaraları da her yapıda kayar.
      expect(
        fingerprint('unhandled', 'Sipariş 8421 basılamadı', _frames),
        fingerprint('unhandled', 'Sipariş 8422 basılamadı', const [
          '#0 OrderPrinter.print (package:mutfakapp/printer.dart:143:7)',
          '#1 KitchenScreen._onTap (package:mutfakapp/screen.dart:88:12)',
          '#2 _rootRun (dart:async/zone.dart:1399:13)',
        ]),
      );
    });

    test('üçüncüden sonraki çerçeveler dikkate alınmaz', () {
      expect(
        fingerprint('unhandled', 'Yazıcı bulunamadı', [
          ..._frames,
          '#3 main (package:mutfakapp/main.dart:20:3)',
        ]),
        fingerprint('unhandled', 'Yazıcı bulunamadı', _frames),
      );
    });

    test('boşluk farkları iz değiştirmez', () {
      expect(
        fingerprint('unhandled', '  Yazıcı   bulunamadı  ', const [
          '#0   OrderPrinter.print\t(package:mutfakapp/printer.dart)',
        ]),
        fingerprint('unhandled', 'Yazıcı bulunamadı', const [
          '#0 OrderPrinter.print (package:mutfakapp/printer.dart)',
        ]),
      );
    });
  });

  group('Neyi ayırır', () {
    test('tür farkı ayırır', () {
      expect(
        fingerprint('network', 'Yazıcı bulunamadı', _frames),
        isNot(fingerprint('render', 'Yazıcı bulunamadı', _frames)),
      );
    });

    test('mesaj farkı ayırır', () {
      expect(
        fingerprint('unhandled', 'Yazıcı bulunamadı', _frames),
        isNot(fingerprint('unhandled', 'Kasa yanıt vermiyor', _frames)),
      );
    });

    test('ilk üç çerçevedeki fark ayırır', () {
      expect(
        fingerprint('unhandled', 'Yazıcı bulunamadı', _frames),
        isNot(
          fingerprint('unhandled', 'Yazıcı bulunamadı', const [
            '#0 ReceiptQueue.flush (package:mutfakapp/queue.dart)',
            '#1 KitchenScreen._onTap (package:mutfakapp/screen.dart)',
            '#2 _rootRun (dart:async/zone.dart)',
          ]),
        ),
      );
    });

    test('eksik çerçeve boş alana tamamlanır, kayma yapmaz', () {
      // Anahtar her zaman beş alandır; tamamlanmasaydı iki çerçeveli bir hata
      // üç çerçeveli başkasıyla aynı metne katlanabilirdi.
      expect(
        fingerprint('unhandled', 'Yazıcı bulunamadı', _frames.take(2).toList()),
        isNot(fingerprint('unhandled', 'Yazıcı bulunamadı', _frames)),
      );
    });
  });

  group('Diller arası kilit', () {
    // Bu iki değer TypeScript karşılığında da AYNI çıkmalıdır. Tutmuyorsa
    // tarif ayrışmıştır; değeri güncellemeden önce iki uygulamayı karşılaştır.
    test('tipik kasa hatası', () {
      expect(
        fingerprint('unhandled', 'Sipariş 8421 basılamadı', _frames),
        '289df5c81070a74e',
      );
    });

    test('boş girdi', () {
      expect(fingerprint('', '', const []), '34b2f0315c2e8a25');
    });
  });
}
