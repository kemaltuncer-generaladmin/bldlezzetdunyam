/// Açılış parolası — `docs/05-mutfakapp.md` §8.
///
/// NEDEN SUNUCUYA SORMUYORUZ: bu parola kasanın **fiziksel** kilididir,
/// bir kimlik doğrulama değil. İnternet yokken de çalışmalı; mutfak
/// sabah açılırken bağlantı beklemek kabul edilemez. Sunucu tarafındaki
/// yetki zaten cihaz token'ıdır (`kitchen` kapsamı).
///
/// NEDEN DÜZ METİN DEĞİL: bu depo **herkese açık**. Parolanın kendisi
/// repoya girerse arama motorları ve gizli-tarama botları bulur. Kodda
/// yalnızca tuzlanmış özet duruyor.
///
/// Bunun gerçek bir kriptografik koruma OLMADIĞINI biliyoruz: parola
/// kısa ve özet herkese açık, bilen biri saniyeler içinde kırar. Asıl
/// koruma kasanın kilitli mutfakta durmasıdır. Buradaki amaç, yoldan
/// geçenin ekrana dokunup sipariş durumu değiştirmesini engellemek.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Parolanın tuzlanmış SHA-256 özeti.
///
/// Değiştirmek için:
/// `python3 -c "import hashlib;print(hashlib.sha256(('bld-mutfak-kasasi-v1'+'YENİ').encode()).hexdigest())"`
const String unlockPasswordDigest =
    'de39c15c3978b071b0033eb6393f1039160ed3590085518bed0affacf1b28214';

/// Tuz, aynı parolanın başka bir projede üretilen özetiyle eşleşmesini
/// engeller. Gizli değildir, gizli olması da gerekmez.
const String _salt = 'bld-mutfak-kasasi-v1';

/// Girilen parola doğru mu?
bool unlockPasswordMatches(String input) {
  final digest = sha256.convert(utf8.encode('$_salt$input')).toString();

  // Sabit süreli karşılaştırma: parola kısa ve saldırgan ekranın başında
  // olduğu için zamanlama saldırısı gerçekçi değil, ama doğru alışkanlığı
  // burada da koruyoruz — maliyeti yok.
  if (digest.length != unlockPasswordDigest.length) return false;

  var fark = 0;
  for (var i = 0; i < digest.length; i++) {
    fark |= digest.codeUnitAt(i) ^ unlockPasswordDigest.codeUnitAt(i);
  }

  return fark == 0;
}
