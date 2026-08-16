/// Saatlik sürüm denetimi — `docs/05-mutfakapp.md` §9.
///
/// TESTİN ASIL SORUSU "yeni sürümü buluyor mu" DEĞİL, **"bulmadığı hâlde
/// bulduğunu söylüyor mu"**. Kasada sürekli duran ve kimsenin
/// kapatamadığı bir güncelleme rozeti, hiç rozet olmamasından daha kötü:
/// personel bir süre sonra onu görmezden gelmeyi öğrenir ve gerçek bir
/// güncelleme geldiğinde de fark etmez.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/update/update_checker.dart';

AppVersionInfo surum(String latest, {String minSupported = '1.0.0'}) =>
    AppVersionInfo(
      appId: 'mutfakapp',
      latest: latest,
      minSupported: minSupported,
    );

UpdateChecker denetci(
  Future<AppVersionInfo> Function() check, {
  String current = '1.0.0',
}) => UpdateChecker(check: check, currentVersion: current);

void main() {
  group('isNewer', () {
    test('daha büyük yama sürümü yenidir', () {
      expect(UpdateChecker.isNewer('1.0.1', '1.0.0'), isTrue);
    });

    test('daha büyük ara sürüm yenidir', () {
      expect(UpdateChecker.isNewer('1.1.0', '1.0.9'), isTrue);
    });

    test('aynı sürüm yeni DEĞİLDİR', () {
      expect(UpdateChecker.isNewer('1.2.3', '1.2.3'), isFalse);
    });

    /// Sunucuda bir kayıt düzeltilip eski sürüme dönülmüş olabilir. Eşitlik
    /// karşılaştırması burada "yeni sürüm var" derdi ve rozet sonsuza kadar
    /// ekranda kalırdı.
    test('daha eski sürüm yeni DEĞİLDİR', () {
      expect(UpdateChecker.isNewer('1.0.0', '1.1.0'), isFalse);
    });

    /// Sayısal karşılaştırma, metin karşılaştırması değil: `'10' < '9'`
    /// metinde doğru, sürümde yanlış.
    test('iki basamaklı sürüm metin olarak değil sayı olarak karşılaştırılır', () {
      expect(UpdateChecker.isNewer('1.10.0', '1.9.0'), isTrue);
      expect(UpdateChecker.isNewer('1.9.0', '1.10.0'), isFalse);
    });

    test('ayrıştırılamayan sürüm yeni SAYILMAZ', () {
      expect(UpdateChecker.isNewer('sürüm-yok', '1.0.0'), isFalse);
      expect(UpdateChecker.isNewer('1.0', '1.0.0'), isFalse);
      expect(UpdateChecker.isNewer('1.0.0', 'bozuk'), isFalse);
    });
  });

  group('run', () {
    test('yeni sürüm bulunca rozeti açar ve notu taşır', () async {
      final checker = denetci(
        () async => AppVersionInfo(
          appId: 'mutfakapp',
          latest: '1.1.0',
          minSupported: '1.0.0',
          notes: 'Fiş kod sayfası düzeltmesi',
        ),
      );

      final sonuc = await checker.run(const UpdateStatus());

      expect(sonuc.updateAvailable, isTrue);
      expect(sonuc.latest, '1.1.0');
      expect(sonuc.notes, 'Fiş kod sayfası düzeltmesi');
      expect(sonuc.checking, isFalse);
      expect(sonuc.error, isNull);
      expect(sonuc.checkedAt, isNotNull);
    });

    test('güncel sürümde rozet açılmaz', () async {
      final checker = denetci(() async => surum('1.0.0'));

      final sonuc = await checker.run(const UpdateStatus());

      expect(sonuc.updateAvailable, isFalse);
      expect(sonuc.latest, '1.0.0');
    });

    /// Hata YUKARI ATILMAMALI: `run` saatlik zamanlayıcıdan çağrılıyor ve
    /// sızan bir istisna denetim döngüsünü sessizce öldürür — kasa bir daha
    /// hiç güncelleme aramaz.
    test('ağ hatası atılmaz, duruma yazılır', () async {
      final checker = denetci(() async => throw Exception('bağlantı yok'));

      final sonuc = await checker.run(const UpdateStatus());

      expect(sonuc.error, contains('bağlantı yok'));
      expect(sonuc.checking, isFalse);
      expect(sonuc.updateAvailable, isFalse);
    });

    /// Ağ koptuğunda bilinen son sürüm kaybolmamalı: rozet, bağlantı geri
    /// gelene kadar ekranda kalmaya devam etmeli.
    test('hata önceki bilinen sürümü silmez', () async {
      final onceki = await denetci(
        () async => surum('1.1.0'),
      ).run(const UpdateStatus());

      final sonra = await denetci(
        () async => throw Exception('kopuk'),
      ).run(onceki);

      expect(sonra.latest, '1.1.0');
      expect(sonra.updateAvailable, isTrue);
      expect(sonra.error, isNotNull);
    });

    /// Başarılı denetim önceki hatayı TEMİZLEMELİ; `copyWith`'te `error`
    /// bilinçli olarak `??` kullanmıyor, bu test onu tutuyor.
    test('başarılı denetim önceki hatayı temizler', () async {
      final hatali = await denetci(
        () async => throw Exception('kopuk'),
      ).run(const UpdateStatus());
      expect(hatali.error, isNotNull);

      final duzelen = await denetci(() async => surum('1.0.0')).run(hatali);

      expect(duzelen.error, isNull);
    });
  });
}
