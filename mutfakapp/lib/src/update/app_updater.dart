/// K-22 §2 — `update` komutunun kasa tarafı: yeni sürümü indirir ve kurar.
///
/// ## NEDEN `pkexec` YOK
///
/// `docs/05-mutfakapp.md` §9 uzun süre "`pkexec dpkg -i`" dedi ve o cümle
/// **uzaktan çalıştırılabilir bir komut için ölümcül**: `pkexec` mutfak
/// ekranının ortasında grafik bir parola kutusu açar. Kasada o parolayı
/// girecek kimse yoktur (personel siparişi işler, yönetici ofistedir); kutu
/// açık kalır, kurulum hiç bitmez ve komut sonsuza dek "teslim edildi,
/// sonuç bekleniyor" durumunda asılı kalır. Üstelik kutu tam ekran KDS'in
/// üstünde durduğu için mutfak o süre boyunca sipariş de göremez.
///
/// ## KÖK YETKİSİ ZATEN GEREKMİYOR
///
/// Kasadaki kurulum bir systemd **kullanıcı** servisidir ve uygulama
/// `~/.local/opt/mutfakapp` altında durur (`infra/kasa/mutfakapp.service`,
/// `infra/kasa/derle.sh`). Yani dosyaları değiştirmek için root gerekmiyor;
/// `.deb` içeriğini `dpkg-deb -x` ile **açmak** yeterli — o da kök yetkisi
/// istemez, çünkü paketi kurmaz, yalnızca arşivi çıkarır.
///
/// ## BAŞARISIZLIK GÜVENLİ TARAFTA
///
/// Sürüm sorgusu, indirme, doğrulama, çıkarma ve yerleştirme adımlarının
/// herhangi biri düşerse **hiçbir şey değiştirilmez**: kasa eski sürümde
/// çalışmaya devam eder ve komut gerekçesiyle başarısız döner. Yeni sürüm
/// ancak eksiksiz çıkarılıp doğrulandıktan sonra, tek bir `rename` ile
/// devreye girer. "Yarısı kopyalanmış" bir kurulum, hiç güncellenmemiş bir
/// kasadan çok daha kötüdür: mutfak sabaha açılmayan bir ekranla uyanır.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bld_api_client/bld_api_client.dart';

/// Bir dış sürecin sonucu — testte sahtelenir.
class ProcessResultLite {
  const ProcessResultLite(this.exitCode, this.output);

  final int exitCode;
  final String output;

  bool get ok => exitCode == 0;
}

/// Sürüm bilgisini alıp `.deb`'i kuran akış.
///
/// Dış dünyaya açılan her nokta (sürüm sorgusu, indirme, süreç çalıştırma)
/// enjekte ediliyor: test gerçek ağ, gerçek `dpkg-deb` ve gerçek `systemctl`
/// olmadan tüm başarısızlık dallarını ölçebilsin.
class AppUpdater {
  AppUpdater({
    required Future<AppVersionInfo> Function() checkVersion,
    required Future<Uint8List> Function(Uri url) download,
    required Future<ProcessResultLite> Function(String executable, List<String> args) run,
    required this.installDir,
    required this.workDir,
    this.currentVersion,
    this.serviceName = 'mutfakapp',
    this.executableName = 'mutfakapp',
    this.restartDelay = const Duration(seconds: 2),
  }) : _checkVersion = checkVersion,
       _download = download,
       _run = run;

  final Future<AppVersionInfo> Function() _checkVersion;
  final Future<Uint8List> Function(Uri url) _download;
  final Future<ProcessResultLite> Function(String executable, List<String> args) _run;

  /// Uygulamanın kurulu olduğu dizin (`~/.local/opt/mutfakapp`).
  final Directory installDir;

  /// İndirme ve çıkarma için geçici çalışma alanı.
  final Directory workDir;

  /// Çalışan sürüm. `null` ise sürüm karşılaştırması yapılmaz ve kurulum
  /// her koşulda denenir.
  final String? currentVersion;

  final String serviceName;

  /// Paketin içinde aranacak çalıştırılabilir dosyanın adı.
  final String executableName;

  /// Servis yeniden başlatılmadan önceki bekleme.
  ///
  /// Yeniden başlatma KENDİ SÜRECİMİZİ ÖLDÜRÜR. `restart` komutuyla aynı
  /// desen: hemen değil kısa bir gecikmeyle yapılıyor ki çağıran sonucu
  /// döndürebilsin ve komut "çalıştırılamadı" görünmesin.
  final Duration restartDelay;

  /// `.deb` bir `ar` arşividir ve her zaman bu sekiz baytla başlar.
  ///
  /// TEK BAŞINA YETMEZ ama ucuz ve kesin bir eleme: sunucu yanlışlıkla bir
  /// HTML hata sayfası ya da yarım inmiş bir dosya döndürdüğünde
  /// `dpkg-deb`'i hiç çağırmadan anlaşılır. Asıl doğrulama `dpkg-deb`'in
  /// kendisidir — bozuk bir arşivi o zaten reddeder.
  static const String debMagic = '!<arch>\n';

  /// Kurulumu yapar. `null` = başarı, metin = başarısızlık gerekçesi.
  ///
  /// Dönüş tipi `CommandActions` sözleşmesiyle aynı: yöneticinin panelde
  /// göreceği mesaj budur, dolayısıyla gerekçeler "bir hata oluştu" değil
  /// ne yapılacağını söyleyen cümleler.
  Future<String?> install() async {
    final AppVersionInfo info;
    try {
      info = await _checkVersion();
    } on Object catch (error) {
      return 'Sürüm bilgisi alınamadı: $error';
    }

    final url = info.downloadUrl;
    if (url == null || url.trim().isEmpty) {
      // Sunucudaki `veykemtu_app_releases` satırı yoksa uç `download_url:
      // null` dönüyor (`AppVersionController::fallback`). Bu bir hata
      // değil, eksik bir kayıt — mesaj da onu söylemeli.
      return 'Sunucuda kurulum dosyası tanımlı değil (download_url boş).';
    }

    // ZATEN GÜNCELSE HİÇBİR ŞEY YAPILMAZ. Yeniden kurmak, mutfak ekranını
    // servis ortasında hiçbir kazanç olmadan birkaç saniye karartırdı.
    if (currentVersion != null && info.latest.trim() == currentVersion) {
      return null;
    }

    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) {
      return 'Kurulum adresi geçersiz: $url';
    }

    Directory? scratch;
    try {
      scratch = await workDir.createTemp('mutfakapp-guncelleme-');

      final bytes = await _download(uri);
      final gecersiz = _verify(bytes);
      if (gecersiz != null) return gecersiz;

      final deb = File('${scratch.path}/paket.deb');
      await deb.writeAsBytes(bytes, flush: true);

      final cikarilan = Directory('${scratch.path}/cikarilan');
      await cikarilan.create(recursive: true);

      // `-x` KURMAZ, YALNIZCA ÇIKARIR: root gerekmez, `dpkg` veritabanına
      // dokunulmaz ve bozuk arşiv burada sıfır olmayan çıkış koduyla
      // yakalanır.
      final cikar = await _run('dpkg-deb', ['-x', deb.path, cikarilan.path]);
      if (!cikar.ok) {
        return 'Paket açılamadı: ${_kisalt(cikar.output)}';
      }

      final paket = await _findBundle(cikarilan);
      if (paket == null) {
        return 'Pakette "$executableName" çalıştırılabiliri bulunamadı.';
      }

      final yerlestirme = await _swapIn(paket);
      if (yerlestirme != null) return yerlestirme;
    } on Object catch (error) {
      return 'Güncelleme başarısız: ${_kisalt('$error')}';
    } finally {
      // Geçici dizin HER KOŞULDA siliniyor: bir `.deb` onlarca megabayt ve
      // kasa disk alanı sınırlı; başarısız denemelerin birikmesi zamanla
      // kuyruk veritabanının yazamamasına kadar gider.
      if (scratch != null) {
        try {
          await scratch.delete(recursive: true);
        } on Object {
          // Silinemedi — güncelleme yine de başarılı. Burada patlamak,
          // olmuş bitmiş bir kurulumu "başarısız" göstermek olurdu.
        }
      }
    }

    // Buradan sonrası geri dönüşsüz; sonucu bildirebilmek için yeniden
    // başlatma gecikmeli ve beklenmiyor.
    unawaited(_restartLater());

    return null;
  }

  /// İndirilen baytların bir `.deb` olduğunu sınar. Sorun varsa gerekçe.
  String? _verify(Uint8List bytes) {
    if (bytes.isEmpty) {
      return 'Kurulum dosyası boş indi.';
    }

    if (bytes.length < debMagic.length) {
      return 'Kurulum dosyası eksik indi (${bytes.length} bayt).';
    }

    final magic = String.fromCharCodes(bytes.take(debMagic.length));
    if (magic != debMagic) {
      // Sahada en olası hâli: adres bir giriş sayfasına ya da 404 HTML'ine
      // yönleniyor ve indirme "başarılı" görünüyor.
      return 'İndirilen dosya .deb değil (imza tutmadı).';
    }

    return null;
  }

  /// Çıkarılan ağaçta uygulama paketinin kökünü bulur.
  ///
  /// Paketin dosyaları `/opt`, `/usr/lib` ya da `~/.local/opt` altına
  /// yerleşmiş olabilir; hangisi olduğunu VARSAYMIYORUZ. Aranan tek şey
  /// [executableName] adında bir dosya — Flutter Linux paketi her zaman
  /// çalıştırılabilirin yanında `lib/` ve `data/` taşır.
  Future<Directory?> _findBundle(Directory root) async {
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (entity.uri.pathSegments.last != executableName) continue;

      final parent = entity.parent;
      if (await Directory('${parent.path}/lib').exists() ||
          await Directory('${parent.path}/data').exists()) {
        return parent;
      }
    }

    return null;
  }

  /// Yeni paketi kurulum dizininin yerine geçirir.
  ///
  /// ÜÇ ADIMLI TAKAS, ve sırası önemli:
  ///   1. yeni paket `<kurulum>.yeni` olarak yerine KOPYALANIR,
  ///   2. eski kurulum `<kurulum>.eski` adına çekilir,
  ///   3. `<kurulum>.yeni` kurulum adını alır.
  ///
  /// Kopyalama en uzun ve en kırılgan adım (disk dolabilir); o adım
  /// bitmeden çalışan kuruluma DOKUNULMUYOR. Süreç 1. adımda ölürse geride
  /// yalnızca bir `.yeni` dizini kalır ve kasa eski sürümle açılmaya devam
  /// eder. 2. ile 3. arasındaki pencere ise iki `rename` arası: aynı dosya
  /// sisteminde atomik ve mikrosaniyeler sürüyor.
  Future<String?> _swapIn(Directory bundle) async {
    final yeni = Directory('${installDir.path}.yeni');
    final eski = Directory('${installDir.path}.eski');

    for (final artik in [yeni, eski]) {
      if (await artik.exists()) await artik.delete(recursive: true);
    }

    // `cp -a` ile kopyalıyoruz: `Directory.rename` farklı dosya sistemleri
    // arasında (geçici dizin `/tmp` tmpfs'te olabilir) çalışmaz ve Dart'ta
    // dizin kopyalayan bir çağrı yok. `-a` çalıştırma bitlerini korur —
    // korunmazsa kurulum sessizce "izin reddedildi" ile açılmaz.
    final kopya = await _run('cp', ['-a', '${bundle.path}/.', yeni.path]);
    if (!kopya.ok) {
      return 'Yeni sürüm kopyalanamadı: ${_kisalt(kopya.output)}';
    }

    if (!await File('${yeni.path}/$executableName').exists()) {
      return 'Kopyalanan pakette çalıştırılabilir yok; kurulum yapılmadı.';
    }

    final vardi = await installDir.exists();
    if (vardi) await installDir.rename(eski.path);

    try {
      await yeni.rename(installDir.path);
    } on Object catch (error) {
      // Adlandırma düştüyse eski kurulumu GERİ KOYUYORUZ: aksi hâlde kasa
      // hiç uygulaması olmayan bir makineye dönerdi ve sahada elle
      // kurtarılana kadar mutfak sipariş göremezdi.
      if (vardi) await eski.rename(installDir.path);
      return 'Yeni sürüm yerine konamadı: ${_kisalt('$error')}';
    }

    if (vardi) {
      try {
        await eski.delete(recursive: true);
      } on Object {
        // Eski sürüm silinemedi — yeni sürüm zaten yerinde ve çalışacak.
        // Bir temizlik hatası yüzünden başarılı kurulumu geri almak,
        // riski azaltmaz artırır.
      }
    }

    return null;
  }

  /// Servisi kısa bir gecikmeyle yeniden başlatır.
  ///
  /// `systemctl --user restart` KULLANILIYOR (`pkexec` değil): servis bir
  /// kullanıcı birimi, dolayısıyla yetki yükseltmesi gerekmiyor.
  ///
  /// YEDEK PLAN OLARAK `exit(0)`: `systemctl` bulunamaz ya da reddederse
  /// süreci kendimiz sonlandırıyoruz. Birim `Restart=always` ile tanımlı
  /// (`infra/kasa/mutfakapp.service`), yani systemd beş saniye içinde yeni
  /// baytlarla geri getirir. Bu yedek olmadan kasa yeni sürümü diskte
  /// taşıyıp eski sürümü çalıştırmaya devam ederdi ve yönetici "kurdum ama
  /// değişmedi" derdi.
  Future<void> _restartLater() async {
    await Future<void>.delayed(restartDelay);

    try {
      final sonuc = await _run('systemctl', ['--user', 'restart', serviceName]);
      if (sonuc.ok) return;
    } on Object {
      // Aşağıdaki yedek plana düşülüyor.
    }

    exit(0);
  }

  static String _kisalt(String value) {
    final tek = value.replaceAll('\n', ' ').trim();
    return tek.length <= 200 ? tek : tek.substring(0, 200);
  }
}

/// Gerçek süreç çalıştırıcı — `stdout` ve `stderr` birlikte döner.
///
/// İkisi ayrı tutulmuyor: `dpkg-deb` hatayı `stderr`'a, `cp` bazen
/// `stdout`'a yazıyor ve yöneticinin panelde göreceği mesajın hangi akıştan
/// geldiğinin bir önemi yok.
Future<ProcessResultLite> runProcess(
  String executable,
  List<String> args,
) async {
  final result = await Process.run(executable, args);

  return ProcessResultLite(
    result.exitCode,
    '${result.stdout}\n${result.stderr}'.trim(),
  );
}

/// `.deb`'i indiren varsayılan istemci.
///
/// `dio` KULLANILMIYOR: mutfakapp'in doğrudan bağımlısı değil ve öyle
/// davranmak `depend_on_referenced_packages` ihlali olurdu (aynı gerekçe
/// `kitchen_health.dart` başlığında). Ayrıca burada gereken tek şey ham
/// bayt akışı; `dio`'nun JSON/interceptor katmanının bir katkısı yok.
Future<Uint8List> downloadBytes(Uri url, {Duration? timeout}) async {
  final sure = timeout ?? const Duration(minutes: 5);
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);

  try {
    final request = await client.getUrl(url);
    // Sözleşmenin zorunlu başlıkları burada YOK ve olmamalı: indirme adresi
    // bir dosya sunucusuna işaret edebilir, API'ye değil.
    final response = await request.close().timeout(sure);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Kurulum dosyası indirilemedi (HTTP ${response.statusCode}).',
        uri: url,
      );
    }

    final builder = BytesBuilder(copy: false);
    await for (final parca in response.timeout(sure)) {
      builder.add(parca);
    }

    return builder.takeBytes();
  } finally {
    client.close(force: true);
  }
}
