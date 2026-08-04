import 'package:bld_core/escpos.dart';
import 'package:test/test.dart';

void main() {
  group('PC857 — Türkçe harfler', () {
    // `docs/05-mutfakapp.md` §5.2: "ç ğ ı ö ş ü İ Ş Ğ Ü Ö Ç doğru basılmalı."
    // Beklenen bayt değerleri Unicode Konsorsiyumu'nun CP857.TXT eşlemesinden
    // alınmıştır; burada elle tekrarlanması bilinçlidir — tabloyu bozan bir
    // düzenleme testi kırar.
    const expected = <String, int>{
      'ç': 0x87,
      'ğ': 0xA7,
      'ı': 0x8D,
      'ö': 0x94,
      'ş': 0x9F,
      'ü': 0x81,
      'Ç': 0x80,
      'Ğ': 0xA6,
      'İ': 0x98,
      'Ö': 0x99,
      'Ş': 0x9E,
      'Ü': 0x9A,
    };

    for (final entry in expected.entries) {
      test(
        '"${entry.key}" → 0x${entry.value.toRadixString(16).toUpperCase()}',
        () {
          expect(Pc857.encode(entry.key), [entry.value]);
        },
      );
    }

    test('12 harfin tamamı tek baytla kodlanır', () {
      expect(Pc857.turkishLetters.length, 12);
      expect(Pc857.encode(Pc857.turkishLetters), hasLength(12));
      expect(Pc857.canEncode(Pc857.turkishLetters), isTrue);
    });

    test('gerçek ürün adları doğru kodlanır', () {
      // "Mercimek Çorbası" — Ç ve ı aynı satırda.
      expect(Pc857.encode('Mercimek Çorbası'), [
        0x4D, 0x65, 0x72, 0x63, 0x69, 0x6D, 0x65, 0x6B, // Mercimek
        0x20,
        0x80, 0x6F, 0x72, 0x62, 0x61, 0x73, 0x8D, // Çorbası
      ]);
    });
  });

  group('PC857 — ASCII ve sınırlar', () {
    test('ASCII aralığı birebir geçer', () {
      expect(Pc857.encode('S-5012'), [0x53, 0x2D, 0x35, 0x30, 0x31, 0x32]);
    });

    test('çarpı işareti fişteki adet ayracıdır', () {
      expect(Pc857.encode('×'), [0xE8]);
    });

    test('boş metin boş dizi verir', () {
      expect(Pc857.encode(''), isEmpty);
    });

    test('kod sayfasında olmayan karakter "?" olur, istisna atmaz', () {
      expect(Pc857.encode('日'), [Pc857.replacementByte]);
      expect(Pc857.canEncode('日'), isFalse);
    });

    test('lira işareti "TL" olarak sadeleşir', () {
      expect(Pc857.encode('₺'), [0x54, 0x4C]);
    });

    test('tipografik tırnak ve tire sadeleşir', () {
      expect(Pc857.encode('’'), [0x27]);
      expect(Pc857.encode('—'), [0x2D]);
      expect(Pc857.encode('…'), [0x2E, 0x2E, 0x2E]);
    });

    test('tanımsız PC857 konumları tabloda yoktur', () {
      // 0xD5, 0xE7 ve 0xF2 CP857'de tanımsızdır; hiçbir karakter oraya
      // eşlenmemelidir, yoksa yazıcı çöp basar.
      const undefinedBytes = {0xD5, 0xE7, 0xF2};
      final produced = <int>{};
      for (var codeUnit = 0xA0; codeUnit <= 0x2600; codeUnit++) {
        final character = String.fromCharCode(codeUnit);
        if (!Pc857.canEncode(character)) continue;
        produced.addAll(Pc857.encode(character));
      }
      expect(produced.intersection(undefinedBytes), isEmpty);
    });

    test('eşleme birebirdir — iki karakter aynı bayta düşmez', () {
      final seen = <int, int>{};
      for (var codeUnit = 0x80; codeUnit <= 0x2600; codeUnit++) {
        final character = String.fromCharCode(codeUnit);
        if (!Pc857.canEncode(character)) continue;
        final byte = Pc857.encode(character).single;
        expect(
          seen.containsKey(byte),
          isFalse,
          reason:
              'U+${codeUnit.toRadixString(16)} ve '
              'U+${seen[byte]?.toRadixString(16)} aynı bayta eşlendi: '
              '0x${byte.toRadixString(16)}',
        );
        seen[byte] = codeUnit;
      }
    });
  });

  group('TurkishCase', () {
    test('i → İ, ı → I', () {
      expect(TurkishCase.toUpperCase('Mercimek Çorbası'), 'MERCİMEK ÇORBASI');
      expect(TurkishCase.toUpperCase('ıspanak'), 'ISPANAK');
      expect(TurkishCase.toUpperCase('şiş'), 'ŞİŞ');
    });

    test('küçültme de Türkçe kurallarına uyar', () {
      expect(TurkishCase.toLowerCase('MERCİMEK ÇORBASI'), 'mercimek çorbası');
      expect(TurkishCase.toLowerCase('ISPANAK'), 'ıspanak');
    });

    test('Dart varsayılanı yanlış olduğu için bu sınıf var', () {
      expect('Mercimek Çorbası'.toUpperCase(), 'MERCIMEK ÇORBASI');
      expect(
        TurkishCase.toUpperCase('Mercimek Çorbası'),
        isNot('Mercimek Çorbası'.toUpperCase()),
      );
    });

    test('büyük harfe çevrilen metin PC857 ile kodlanabilir', () {
      expect(TurkishCase.toUpperCase(Pc857.turkishLetters), 'ÇĞIÖŞÜÇĞİÖŞÜ');
      expect(
        Pc857.canEncode(TurkishCase.toUpperCase(Pc857.turkishLetters)),
        isTrue,
      );
    });
  });
}
