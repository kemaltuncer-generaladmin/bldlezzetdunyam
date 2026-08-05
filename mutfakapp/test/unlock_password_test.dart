import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/lock/unlock_password.dart';

void main() {
  group('açılış parolası', () {
    test('doğru parola kabul edilir', () {
      expect(unlockPasswordMatches('Bld2026.'), isTrue);
    });

    test('boş girdi reddedilir', () {
      // En kötü hata bu olurdu: kilit varmış gibi görünüp herkesi
      // içeri alması.
      expect(unlockPasswordMatches(''), isFalse);
    });

    test('sondaki nokta parolanın parçasıdır', () {
      expect(unlockPasswordMatches('Bld2026'), isFalse);
    });

    test('büyük/küçük harf duyarlıdır', () {
      expect(unlockPasswordMatches('bld2026.'), isFalse);
      expect(unlockPasswordMatches('BLD2026.'), isFalse);
    });

    test('baştaki/sondaki boşluk kırpılmaz', () {
      // Kırpma yapmıyoruz; yapsaydık " Bld2026. " de geçerdi ve bu
      // davranışın bilinçli olduğu belli olmazdı.
      expect(unlockPasswordMatches(' Bld2026.'), isFalse);
      expect(unlockPasswordMatches('Bld2026. '), isFalse);
    });

    test('özet düz metin parolayı içermez', () {
      // Depo herkese açık: parolanın kendisi kaynakta durmamalı.
      expect(unlockPasswordDigest.contains('Bld2026'), isFalse);
      expect(unlockPasswordDigest, hasLength(64));
    });
  });
}
