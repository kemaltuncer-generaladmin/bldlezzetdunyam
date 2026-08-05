/// Ayarlar ekranındaki "test fişi bas" çıktısı (`docs/05-mutfakapp.md` §8).
///
/// Amaç kâğıt harcamak değil **iki soruyu birden** cevaplamak:
/// 1. Cihaz dosyasına yazılabiliyor mu? (yol doğru mu, izin var mı)
/// 2. Kod sayfası doğru mu? (Türkçe harfler glif mi basıyor, boşluk mu)
///
/// İkincisi sahada bir kez pahalıya patladı: `ESC t 13` Türkçe baytları
/// boşluk bastı ve bu ancak gerçek bir fişte görüldü (`docs/05` §5.2). Test
/// fişi bütün Türkçe harfleri tek satırda basar; personel bakar, eksik varsa
/// kod sayfası yanlıştır.
///
/// Yan etkisizdir: yalnızca bayt üretir, cihaza yazmaz.
library;

import 'dart:typed_data';

import 'package:bld_core/bld_core.dart';
import 'package:bld_core/escpos.dart';

/// Fişte basılacak tüm Türkçe harfler — `docs/05` §5.2'deki tablo.
///
/// Sabit metin ama `l10n`'a girmez: bu bir arayüz metni değil, **donanım
/// testi verisi**. Çevrilmesi fişi anlamsız kılardı.
const String turkishGlyphProbe = 'çÇ ğĞ ıI İi öÖ şŞ üÜ';

/// Test fişinin ESC/POS baytları.
///
/// [devicePath] fişe basılır ki iki yazıcılı bir kasada hangisinin çıktı
/// verdiği belli olsun.
Uint8List buildTestReceipt({
  required String devicePath,
  required DateTime printedAt,
  ReceiptStyle style = ReceiptStyle.standard,
}) {
  final builder =
      EscPosBuilder(columns: style.columns, codePage: style.codePage)
        ..reset()
        ..align(EscPosAlign.center)
        ..doubleSize(on: true)
        ..bold(on: true)
        ..line('TEST FİŞİ')
        ..bold(on: false)
        ..doubleSize(on: false)
        ..line(style.businessName)
        ..align(EscPosAlign.left)
        ..rule()
        ..line('Tarih   : ${TurkishTime.dateTime(printedAt)}')
        ..line('Yazıcı  : $devicePath')
        ..line('Kod sf. : ${style.codePage}')
        ..line('Genişlik: ${style.columns} karakter')
        ..rule()
        ..line('Türkçe karakter denetimi:')
        ..bold(on: true)
        ..line(turkishGlyphProbe)
        ..bold(on: false)
        ..line('Harfler eksik ya da boşluksa kod sayfası')
        ..line('yanlıştır (infra/kasa/kodsayfasi-tara.sh).')
        ..rule()
        ..align(EscPosAlign.center)
        ..line('Bu bir sipariş fişi değildir.')
        ..feed(style.feedBeforeCut)
        ..cut();

  return builder.build();
}
