import 'package:bld_core/escpos.dart';
import 'package:test/test.dart';

void main() {
  group('Komut tablosu — docs/05-mutfakapp.md §5.2', () {
    test('başlat/sıfırla = 1B 40', () {
      expect(EscPosCommands.initialize, [0x1B, 0x40]);
    });

    test('hizalama sol/orta/sağ = 1B 61 00/01/02', () {
      expect(EscPosCommands.align(EscPosAlign.left), [0x1B, 0x61, 0x00]);
      expect(EscPosCommands.align(EscPosAlign.center), [0x1B, 0x61, 0x01]);
      expect(EscPosCommands.align(EscPosAlign.right), [0x1B, 0x61, 0x02]);
    });

    test('kalın aç/kapa = 1B 45 01 / 1B 45 00', () {
      expect(EscPosCommands.boldOn, [0x1B, 0x45, 0x01]);
      expect(EscPosCommands.boldOff, [0x1B, 0x45, 0x00]);
    });

    test('çift boy = 1D 21 11, normal = 1D 21 00', () {
      expect(EscPosCommands.doubleSizeOn, [0x1D, 0x21, 0x11]);
      expect(EscPosCommands.doubleSizeOff, [0x1D, 0x21, 0x00]);
    });

    test('satır besle = 0A', () {
      expect(EscPosCommands.lineFeed, 0x0A);
    });

    test('kağıt kes = 1D 56 42 00', () {
      expect(EscPosCommands.cut, [0x1D, 0x56, 0x42, 0x00]);
    });

    test('Türkçe kod sayfası = 1B 74 1D (ESC t 29)', () {
      // Doküman başta 13 diyordu; sahadaki yazıcıda (0483:5720) o değer
      // Türkçe harfleri boş bastı. 0..47 taraması 29'u verdi
      // (`docs/05-mutfakapp.md` §5.2, `infra/kasa/kodsayfasi-tara.sh`).
      expect(EscPosCommands.turkishCodePage, 29);
      expect(EscPosCommands.selectCodePage(EscPosCommands.turkishCodePage), [
        0x1B,
        0x74,
        0x1D,
      ]);
    });

    test('kod sayfası numarası değiştirilebilir', () {
      expect(EscPosCommands.selectCodePage(13), [0x1B, 0x74, 0x0D]);
    });
  });

  group('EscPosBuilder', () {
    test('reset önce sıfırlar sonra kod sayfasını seçer', () {
      final builder = EscPosBuilder()..reset();
      expect(builder.build(), [0x1B, 0x40, 0x1B, 0x74, 0x1D]);
    });

    test('kod sayfası yapıcıdan verilebilir', () {
      final builder = EscPosBuilder(codePage: 17)..reset();
      expect(builder.build(), [0x1B, 0x40, 0x1B, 0x74, 0x11]);
    });

    test('line metni kodlayıp satır besler', () {
      final builder = EscPosBuilder()..line('Şu');
      expect(builder.build(), [0x9E, 0x75, 0x0A]);
    });

    test('boş line yalnızca satır besler', () {
      final builder = EscPosBuilder()..line();
      expect(builder.build(), [0x0A]);
    });

    test('feed istenen sayıda satır besler', () {
      final builder = EscPosBuilder()..feed(3);
      expect(builder.build(), [0x0A, 0x0A, 0x0A]);
    });

    test('rule satır genişliğinde ayraç basar', () {
      final builder = EscPosBuilder(columns: 4)..rule();
      expect(builder.build(), [0x2D, 0x2D, 0x2D, 0x2D, 0x0A]);
    });

    test('varsayılan genişlik 80 mm Font A değeridir', () {
      expect(EscPosBuilder.defaultColumns, 48);
    });

    test('text satır beslemez', () {
      final builder = EscPosBuilder()..text('AB');
      expect(builder.build(), [0x41, 0x42]);
    });
  });

  group('Raster görsel', () {
    test('başlık genişliği BAYT, yüksekliği satır sayar', () {
      // 16 nokta = 2 bayt; 3 satır. Genişliği piksel olarak yazmak en sık
      // yapılan hata: yazıcı 16 baytlık satır bekler ve görsel dağılır.
      final builder = EscPosBuilder()
        ..bitImage(List<bool>.filled(16 * 3, false), width: 16);

      expect(builder.build().sublist(0, 8), [
        0x1D, 0x76, 0x30, 0x00, //
        2, 0, // xL xH — bayt sayısı
        3, 0, // yL yH — satır sayısı
      ]);
    });

    test('en anlamlı bit soldaki noktadır', () {
      final row = List<bool>.filled(8, false);
      row[0] = true;

      final builder = EscPosBuilder()..bitImage(row, width: 8);

      expect(builder.build().last, 0x80);
    });

    test('genişlik 8in katı değilse satır sonu beyazla tamamlanır', () {
      // Dolgu yapılmazsa sonraki satırın bitleri kayar ve tüm görsel
      // çapraz bir çizgiye döner.
      final builder = EscPosBuilder()
        ..bitImage(List<bool>.filled(9 * 2, true), width: 9);

      final bytes = builder.build();
      expect(bytes.sublist(4, 6), [2, 0], reason: '9 nokta = 2 bayt');
      expect(bytes.sublist(8), [0xFF, 0x80, 0xFF, 0x80]);
    });
  });
}
