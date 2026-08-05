/// Test fişi bayt testleri.
///
/// Test fişinin tek işi donanımı doğrulamak; kendisi bozuksa yanlış teşhis
/// koydurur. Bu yüzden komut iskeleti (sıfırla → kod sayfası → … → kes) ve
/// Türkçe harflerin PC857 baytlarına dönüştüğü burada ölçülür — gerçek
/// yazıcıda kâğıt harcamadan.
library;

import 'dart:typed_data';

import 'package:bld_core/escpos.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/printing/test_receipt.dart';

void main() {
  final printedAt = DateTime.utc(2026, 8, 5, 11, 32);

  Uint8List build({int codePage = EscPosCommands.turkishCodePage}) =>
      buildTestReceipt(
        devicePath: '/dev/thermal0',
        printedAt: printedAt,
        style: ReceiptStyle(codePage: codePage),
      );

  test('fiş sıfırlama ve kod sayfası seçimiyle başlar', () {
    final bytes = build();

    expect(bytes.sublist(0, 2), [0x1B, 0x40]);
    // `ESC t 29` — sahada doğrulanan Türkçe kod sayfası (`docs/05` §5.2).
    expect(bytes.sublist(2, 5), [0x1B, 0x74, 29]);
  });

  test('ayarlardan gelen kod sayfası numarası kullanılır', () {
    // Yazıcı değişirse numara değişir; şablon bunu geçirmek zorunda.
    expect(build(codePage: 13).sublist(2, 5), [0x1B, 0x74, 13]);
  });

  test('fiş kağıt kesme komutuyla biter', () {
    final bytes = build();
    expect(bytes.sublist(bytes.length - 4), [0x1D, 0x56, 0x42, 0x00]);
  });

  test('kesiciden önce kağıt beslenir', () {
    const style = ReceiptStyle(feedBeforeCut: 4);
    final bytes = buildTestReceipt(
      devicePath: '/dev/thermal0',
      printedAt: printedAt,
      style: style,
    );

    // Kesme komutundan hemen önce dört satır beslemesi durmalı; yoksa son
    // satırlar yazı kafasının üstünde kalıp kesilir.
    final beforeCut = bytes.sublist(bytes.length - 8, bytes.length - 4);
    expect(beforeCut, List<int>.filled(4, EscPosCommands.lineFeed));
  });

  test('Türkçe harfler PC857 baytlarına çevrilir', () {
    final bytes = build();

    // `docs/05` §5.2 tablosu: ç=87, Ç=80, ğ=A7, İ=98, ş=9F, ü=81.
    for (final expected in [0x87, 0x80, 0xA7, 0x98, 0x9F, 0x81]) {
      expect(
        bytes,
        contains(expected),
        reason: 'Türkçe glif baytı 0x${expected.toRadixString(16)} yok',
      );
    }
  });

  test(
    'yazıcı yolu fişe basılır — iki yazıcılı kasada hangisi belli olsun',
    () {
      final bytes = build();
      expect(bytes, containsAllInOrder(Pc857.encode('/dev/thermal0')));
    },
  );

  test('basım zamanı Türkiye saatiyle basılır', () {
    // 11:32 UTC → 14:32 Türkiye. Yanlış saat, teşhiste yanlış iz sürdürür.
    expect(bytesContainText(build(), '05.08.2026 14:32'), isTrue);
  });

  test('kod sayfası numarası fişin üstünde yazar', () {
    expect(bytesContainText(build(codePage: 29), 'Kod sf. : 29'), isTrue);
  });
}

/// [bytes] içinde [text]'in PC857 karşılığı geçiyor mu?
bool bytesContainText(Uint8List bytes, String text) {
  final needle = Pc857.encode(text);
  for (var i = 0; i + needle.length <= bytes.length; i++) {
    var matched = true;
    for (var j = 0; j < needle.length; j++) {
      if (bytes[i + j] != needle[j]) {
        matched = false;
        break;
      }
    }
    if (matched) return true;
  }
  return false;
}
