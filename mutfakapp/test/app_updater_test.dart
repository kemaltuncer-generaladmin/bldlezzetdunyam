/// K-22 §2 — `update` komutu: kurulum akışı ve başarısızlık dalları.
///
/// TESTİN ASIL SORUSU "kurulum çalışıyor mu" DEĞİL, **"kurulum
/// çalışmadığında kasa eski sürümde kalıyor mu"**. Sahada bunun tersi çok
/// daha pahalı: yarısı kopyalanmış bir kurulum, mutfağın sabaha açılmayan
/// bir ekranla uyanması demek.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/update/app_updater.dart';

const AppVersionInfo yeniSurum = AppVersionInfo(
  appId: 'mutfakapp',
  latest: '1.1.0',
  minSupported: '1.0.0',
  downloadUrl: 'https://ornek/mutfakapp_1.1.0.deb',
);

/// Geçerli bir `.deb`'in ilk baytları — `ar` arşiv imzası.
Uint8List gecerliDeb() =>
    Uint8List.fromList([...AppUpdater.debMagic.codeUnits, 1, 2, 3, 4]);

/// Kurulu sürümü taklit eden dizin: içinde çalıştırılabilir ve `lib/`.
Future<Directory> kurulumYap(Directory kok, String isaret) async {
  final dir = Directory('${kok.path}/kurulu');
  await Directory('${dir.path}/lib').create(recursive: true);
  await File('${dir.path}/mutfakapp').writeAsString(isaret);

  return dir;
}

void main() {
  late Directory kok;

  setUp(() async {
    kok = await Directory.systemTemp.createTemp('app-updater-test-');
  });

  tearDown(() async {
    if (kok.existsSync()) await kok.delete(recursive: true);
  });

  /// Çağrılan süreçleri kaydeden, hepsine başarı dönen çalıştırıcı.
  ///
  /// `dpkg-deb -x` gerçekten çıkarmadığı için paketin içeriğini biz
  /// yerleştiriyoruz; testin ölçtüğü şey `dpkg-deb`'in kendisi değil,
  /// çevresindeki karar zinciri.
  ({
    List<String> cagrilar,
    Future<ProcessResultLite> Function(String, List<String>) run,
  })
  sahteSurec({
    Map<String, ProcessResultLite> sonuclar = const {},
    Future<void> Function(String hedef)? cikarken,
  }) {
    final cagrilar = <String>[];

    Future<ProcessResultLite> run(String exe, List<String> args) async {
      cagrilar.add('$exe ${args.join(' ')}');

      final hazir = sonuclar[exe];
      if (hazir != null) return hazir;

      if (exe == 'dpkg-deb' && cikarken != null) {
        await cikarken(args.last);
      }

      // `cp -a <kaynak>/. <hedef>` — gerçek kopyalama, çünkü takasın
      // doğru dizini taşıdığını ölçmek istiyoruz.
      if (exe == 'cp') {
        final kaynak = args[1].substring(0, args[1].length - 2);
        final hedef = args[2];
        await Directory(hedef).create(recursive: true);
        final sonuc = await Process.run('cp', ['-a', '$kaynak/.', hedef]);
        return ProcessResultLite(sonuc.exitCode, '${sonuc.stderr}');
      }

      return const ProcessResultLite(0, '');
    }

    return (cagrilar: cagrilar, run: run);
  }

  AppUpdater build({
    required Future<ProcessResultLite> Function(String, List<String>) run,
    required Directory installDir,
    AppVersionInfo? info,
    Object? versionError,
    Uint8List? bytes,
    Object? downloadError,
    String? currentVersion,
  }) => AppUpdater(
    checkVersion: () async {
      if (versionError != null) throw versionError;
      return info ?? yeniSurum;
    },
    download: (_) async {
      if (downloadError != null) throw downloadError;
      return bytes ?? gecerliDeb();
    },
    run: run,
    installDir: installDir,
    workDir: kok,
    currentVersion: currentVersion ?? '1.0.0',
    // Testte gerçek `systemctl` çağrılmasın ve süreç 2 saniye beklemesin.
    restartDelay: Duration.zero,
  );

  test('SÜRÜM SORGUSU DÜŞERSE kurulum hiç başlamaz', () async {
    final kurulum = await kurulumYap(kok, 'eski');
    final surec = sahteSurec();

    final hata = await build(
      run: surec.run,
      installDir: kurulum,
      versionError: ApiException.network('Sunucuya ulaşılamadı'),
    ).install();

    expect(hata, contains('Sürüm bilgisi alınamadı'));
    expect(surec.cagrilar, isEmpty, reason: 'Hiçbir süreç açılmamalı.');
    expect(File('${kurulum.path}/mutfakapp').readAsStringSync(), 'eski');
  });

  test('download_url YOKSA gerekçeyle başarısız olur', () async {
    // Sunucuda sürüm kaydı girilmemişse uç `download_url: null` dönüyor.
    // Bu bir hata değil eksik bir kayıt; mesaj da onu söylemeli.
    final kurulum = await kurulumYap(kok, 'eski');

    final hata = await build(
      run: sahteSurec().run,
      installDir: kurulum,
      info: const AppVersionInfo(
        appId: 'mutfakapp',
        latest: '1.1.0',
        minSupported: '1.0.0',
      ),
    ).install();

    expect(hata, contains('kurulum dosyası tanımlı değil'));
    expect(File('${kurulum.path}/mutfakapp').readAsStringSync(), 'eski');
  });

  test('ZATEN GÜNCELSE hiçbir şey yapılmaz', () async {
    // Servis ortasında mutfak ekranını hiçbir kazanç olmadan karartmak
    // yanlış olurdu.
    final kurulum = await kurulumYap(kok, 'eski');
    final surec = sahteSurec();

    final hata = await build(
      run: surec.run,
      installDir: kurulum,
      currentVersion: '1.1.0',
    ).install();

    expect(hata, isNull);
    expect(surec.cagrilar, isEmpty);
  });

  test('İNDİRİLEN DOSYA .deb DEĞİLSE kurulmaz', () async {
    // Sahadaki en olası hâli: adres bir 404 HTML'ine yönleniyor ve
    // indirme "başarılı" görünüyor.
    final kurulum = await kurulumYap(kok, 'eski');
    final surec = sahteSurec();

    final hata = await build(
      run: surec.run,
      installDir: kurulum,
      bytes: Uint8List.fromList('<!doctype html>'.codeUnits),
    ).install();

    expect(hata, contains('.deb değil'));
    expect(surec.cagrilar, isEmpty, reason: 'dpkg-deb hiç çağrılmamalı.');
    expect(File('${kurulum.path}/mutfakapp').readAsStringSync(), 'eski');
  });

  test('BOŞ İNDİRME reddedilir', () async {
    final kurulum = await kurulumYap(kok, 'eski');

    final hata = await build(
      run: sahteSurec().run,
      installDir: kurulum,
      bytes: Uint8List(0),
    ).install();

    expect(hata, contains('boş indi'));
  });

  test('PAKET AÇILAMAZSA kasa eski sürümde kalır', () async {
    final kurulum = await kurulumYap(kok, 'eski');
    final surec = sahteSurec(
      sonuclar: {
        'dpkg-deb': const ProcessResultLite(2, 'bozuk arşiv: veri bölümü yok'),
      },
    );

    final hata = await build(run: surec.run, installDir: kurulum).install();

    expect(hata, contains('Paket açılamadı'));
    expect(hata, contains('bozuk arşiv'));
    expect(File('${kurulum.path}/mutfakapp').readAsStringSync(), 'eski');
    expect(
      surec.cagrilar.any((c) => c.startsWith('cp')),
      isFalse,
      reason: 'Çıkarma düştüyse kopyalamaya hiç geçilmemeli.',
    );
  });

  test('PAKETTE ÇALIŞTIRILABİLİR YOKSA kurulum yapılmaz', () async {
    final kurulum = await kurulumYap(kok, 'eski');

    // `dpkg-deb` başarılı dönüyor ama içerik beklediğimiz gibi değil
    // (yanlış paket yüklenmiş olabilir).
    final surec = sahteSurec(
      cikarken: (hedef) async =>
          File('$hedef/usr/share/doc/README').create(recursive: true),
    );

    final hata = await build(run: surec.run, installDir: kurulum).install();

    expect(hata, contains('bulunamadı'));
    expect(File('${kurulum.path}/mutfakapp').readAsStringSync(), 'eski');
  });

  test('BAŞARILI KURULUM dizini yeni sürümle değiştirir', () async {
    final kurulum = await kurulumYap(kok, 'eski');

    final surec = sahteSurec(
      cikarken: (hedef) async {
        await Directory('$hedef/opt/mutfakapp/lib').create(recursive: true);
        await File('$hedef/opt/mutfakapp/mutfakapp').writeAsString('yeni');
      },
    );

    final hata = await build(run: surec.run, installDir: kurulum).install();

    expect(hata, isNull);
    expect(File('${kurulum.path}/mutfakapp').readAsStringSync(), 'yeni');

    // Ara dizinler ARKADA BIRAKILMAZ: `.deb` onlarca megabayt ve kasanın
    // disk alanı sınırlı.
    expect(Directory('${kurulum.path}.yeni').existsSync(), isFalse);
    expect(Directory('${kurulum.path}.eski').existsSync(), isFalse);
  });

  test('kurulum PKEXEC KULLANMAZ', () async {
    // Kasada parola kutusunu açacak kimse yok; kutu açılırsa komut
    // sonsuza dek "sonuç bekleniyor" durumunda asılı kalır ve tam ekran
    // KDS'in üstünü kapattığı için mutfak sipariş de göremez.
    final kurulum = await kurulumYap(kok, 'eski');

    final surec = sahteSurec(
      cikarken: (hedef) async {
        await Directory('$hedef/opt/mutfakapp/lib').create(recursive: true);
        await File('$hedef/opt/mutfakapp/mutfakapp').writeAsString('yeni');
      },
    );

    await build(run: surec.run, installDir: kurulum).install();

    // Yeniden başlatma BEKLENMEDEN tetikleniyor (sonuç bildirilebilsin
    // diye); olay kuyruğunu bir tur döndürmeden çağrı henüz görünmez.
    await pumpEventQueue();

    expect(surec.cagrilar.any((c) => c.contains('pkexec')), isFalse);
    expect(surec.cagrilar.any((c) => c.contains('sudo')), isFalse);
    expect(
      surec.cagrilar.any((c) => c.startsWith('systemctl --user restart')),
      isTrue,
      reason: 'Servis kullanıcı birimi olarak yeniden başlatılmalı.',
    );
  });

  test('KURULUM HİÇ YOKKEN de kurar (ilk yükleme)', () async {
    final kurulum = Directory('${kok.path}/henuz-yok');

    final surec = sahteSurec(
      cikarken: (hedef) async {
        await Directory('$hedef/opt/mutfakapp/lib').create(recursive: true);
        await File('$hedef/opt/mutfakapp/mutfakapp').writeAsString('ilk');
      },
    );

    final hata = await build(run: surec.run, installDir: kurulum).install();

    expect(hata, isNull);
    expect(File('${kurulum.path}/mutfakapp').readAsStringSync(), 'ilk');
  });

  // ── Bütünlük doğrulaması ────────────────────────────────────────────────
  //
  // `.deb` imzası tek başına yetmiyordu: yarım inmiş ama doğru başlayan bir
  // dosya o kontrolü geçiyor ve bozuk paket `dpkg-deb`'e kadar gidiyordu.
  // Asıl tehlike ise doğru BİÇİMLİ yanlış paket — `dpkg-deb` onu memnuniyetle
  // açar ve kasaya başka bir uygulamayı kurar.
  group('sha256 doğrulaması', () {
    /// Paketin özetini gerçekten hesaplayan yardımcı; testin beklediği değer
    /// elle yazılmış bir sabit olsaydı, `_verify` bozulduğunda da geçerdi.
    String ozet(Uint8List bytes) => sha256.convert(bytes).toString();

    AppVersionInfo surumOzetli(String? hash, {int? boyut}) => AppVersionInfo(
      appId: 'mutfakapp',
      latest: '1.1.0',
      minSupported: '1.0.0',
      downloadUrl: 'https://ornek/mutfakapp_1.1.0.deb',
      sha256: hash,
      sizeBytes: boyut,
    );

    test('ÖZET TUTMAZSA kurulum hiç başlamaz', () async {
      final kurulum = await kurulumYap(kok, 'eski');
      final surec = sahteSurec();

      final hata = await build(
        run: surec.run,
        installDir: kurulum,
        info: surumOzetli('0' * 64),
      ).install();

      expect(hata, contains('sha256'));
      expect(
        surec.cagrilar,
        isEmpty,
        reason: 'Doğrulama düştüyse dpkg-deb hiç çağrılmamalı.',
      );
      expect(File('${kurulum.path}/mutfakapp').readAsStringSync(), 'eski');
    });

    test('ÖZET TUTARSA kurulur', () async {
      final paket = gecerliDeb();
      final kurulum = await kurulumYap(kok, 'eski');

      final surec = sahteSurec(
        cikarken: (hedef) async {
          await Directory('$hedef/opt/mutfakapp/lib').create(recursive: true);
          await File('$hedef/opt/mutfakapp/mutfakapp').writeAsString('yeni');
        },
      );

      final hata = await build(
        run: surec.run,
        installDir: kurulum,
        bytes: paket,
        info: surumOzetli(ozet(paket)),
      ).install();

      expect(hata, isNull);
      expect(File('${kurulum.path}/mutfakapp').readAsStringSync(), 'yeni');
    });

    /// Özet girilmemiş bir sürüm kaydı, sahadaki kasayı KİLİTLEMEMELİ.
    /// Yönetici acil bir yamayı özet yüzünden indiremez duruma düşmemeli;
    /// elde kalan `.deb` imzası ve boyut kontrolü hâlâ yürürlükte.
    test('ÖZET YOKSA doğrulama atlanır ama kurulum yapılır', () async {
      final kurulum = await kurulumYap(kok, 'eski');

      final surec = sahteSurec(
        cikarken: (hedef) async {
          await Directory('$hedef/opt/mutfakapp/lib').create(recursive: true);
          await File('$hedef/opt/mutfakapp/mutfakapp').writeAsString('yeni');
        },
      );

      final hata = await build(
        run: surec.run,
        installDir: kurulum,
        info: surumOzetli(null),
      ).install();

      expect(hata, isNull);
      expect(File('${kurulum.path}/mutfakapp').readAsStringSync(), 'yeni');
    });

    test('BOYUT TUTMAZSA özet hesaplanmadan reddedilir', () async {
      final paket = gecerliDeb();
      final kurulum = await kurulumYap(kok, 'eski');
      final surec = sahteSurec();

      final hata = await build(
        run: surec.run,
        installDir: kurulum,
        bytes: paket,
        // Doğru özet ama yanlış boyut: kesilmiş indirmenin tarifi.
        info: surumOzetli(ozet(paket), boyut: paket.length + 100),
      ).install();

      expect(hata, contains('eksik indi'));
      expect(surec.cagrilar, isEmpty);
      expect(File('${kurulum.path}/mutfakapp').readAsStringSync(), 'eski');
    });
  });
}
