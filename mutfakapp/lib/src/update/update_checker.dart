/// Saatlik sürüm denetimi — `docs/05-mutfakapp.md` §9.
///
/// ## YALNIZ HABER VERİR, KURMAZ
///
/// Denetim yeni bir sürüm bulduğunda durum çubuğunda rozet çıkarır ve orada
/// durur. Kurulum iki bilinçli yoldan biriyle başlar: ayarlar ekranındaki
/// düğme ya da Kontrol Merkezi'nden gönderilen `update` komutu.
///
/// Kendiliğinden kurmamasının sebebi kurulumun **uygulamayı yeniden
/// başlatması**: mutfak yoğun saatte ekranını birkaç saniyeliğine kaybeder ve
/// o an ekranda duran sipariş görünmez olur. Güncellemenin ne zaman
/// uygulanacağı, mutfağın ne zaman müsait olduğunu bilen insanın kararıdır.
///
/// ## KARŞILAŞTIRMA SIRALI, EŞİTLİK DEĞİL
///
/// "Sunucudaki sürüm benimkinden farklı" yetmez: sunucuda bir kayıt
/// düzeltilip eski bir sürüme dönülmüşse kasa sonsuza kadar "yeni sürüm var"
/// derdi. Rozet yalnızca sunucudaki sürüm **daha yeniyse** çıkar.
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';

/// Sürüm denetiminin son durumu.
class UpdateStatus {
  const UpdateStatus({
    this.latest,
    this.notes,
    this.checkedAt,
    this.error,
    this.checking = false,
    this.updateAvailable = false,
  });

  /// Sunucudaki en yeni sürüm. Hiç denetlenmediyse `null`.
  final String? latest;

  /// Sürüm notu — kullanıcıya "ne değişti" diye gösterilir.
  final String? notes;

  /// Son başarılı denetimin zamanı.
  final DateTime? checkedAt;

  /// Son denetim hata verdiyse gerekçe.
  ///
  /// Hata durum çubuğunda GÖSTERİLMEZ: ağ kopukken saatlik denetim de
  /// düşer ve mutfak zaten bağlantı uyarısını görüyor. İkinci bir kırmızı
  /// rozet, gerçek sorunu gölgeler. Ayarlar ekranı ister ve gösterir.
  final String? error;

  final bool checking;

  /// Sunucudaki sürüm çalışandan daha yeni mi?
  final bool updateAvailable;

  UpdateStatus copyWith({
    String? latest,
    String? notes,
    DateTime? checkedAt,
    String? error,
    bool? checking,
    bool? updateAvailable,
  }) => UpdateStatus(
    latest: latest ?? this.latest,
    notes: notes ?? this.notes,
    checkedAt: checkedAt ?? this.checkedAt,
    // Hata BİLİNÇLİ OLARAK `??` KULLANMIYOR: başarılı bir denetim önceki
    // hatayı temizlemeli, `??` ile temizlenemezdi.
    error: error,
    checking: checking ?? this.checking,
    updateAvailable: updateAvailable ?? this.updateAvailable,
  );
}

/// Sürümü periyodik ve elle denetler.
///
/// Riverpod'u ve widget'ı bilmiyor; sağlayıcı bunu sarar. Testte sahte bir
/// [check] geçilir ve tüm dallar ağ olmadan ölçülür.
class UpdateChecker {
  UpdateChecker({
    required Future<AppVersionInfo> Function() check,
    required this.currentVersion,
  }) : _check = check;

  final Future<AppVersionInfo> Function() _check;

  /// Çalışan sürüm (`AppConfig.appVersion`).
  final String currentVersion;

  /// Bir denetim turu. Hata ATILMAZ, duruma yazılır.
  ///
  /// Saatlik zamanlayıcıdan çağrıldığı için hata yukarı sızarsa denetim
  /// döngüsü sessizce ölür ve kasa bir daha hiç güncelleme aramaz.
  Future<UpdateStatus> run(UpdateStatus previous) async {
    try {
      final info = await _check();

      return previous.copyWith(
        latest: info.latest,
        notes: info.notes,
        checkedAt: DateTime.now(),
        checking: false,
        updateAvailable: isNewer(info.latest, currentVersion),
      );
    } on Object catch (error) {
      return previous.copyWith(
        checking: false,
        error: _kisalt('$error'),
      );
    }
  }

  /// [candidate] sürümü [current]'tan daha yeni mi?
  ///
  /// Ayrıştırılamayan bir sürümde `false` döner — bilinmeyeni "yeni sürüm
  /// var" saymak, kasada sürekli duran ve kimsenin kapatamadığı bir rozet
  /// üretirdi.
  static bool isNewer(String candidate, String current) {
    final yeni = _parse(candidate);
    final simdi = _parse(current);
    if (yeni == null || simdi == null) return false;

    for (var i = 0; i < 3; i++) {
      if (yeni[i] != simdi[i]) return yeni[i] > simdi[i];
    }

    return false;
  }

  /// `1.2.3` → `[1, 2, 3]`. Biçim tutmuyorsa `null`.
  static List<int>? _parse(String value) {
    final parcalar = value.trim().split('.');
    if (parcalar.length != 3) return null;

    final sayilar = <int>[];
    for (final parca in parcalar) {
      final sayi = int.tryParse(parca);
      if (sayi == null || sayi < 0) return null;
      sayilar.add(sayi);
    }

    return sayilar;
  }

  static String _kisalt(String value) {
    final tek = value.replaceAll('\n', ' ').trim();
    return tek.length <= 200 ? tek : tek.substring(0, 200);
  }
}

/// Saatlik denetim aralığı.
///
/// Bir saat, yöneticinin isteği. Daha sık olması gereksiz: sürüm günde
/// birkaç kez değişmiyor ve her denetim kasadan sunucuya bir istek. Daha
/// seyrek olması ise akşam yayınlanan bir yamayı ertesi güne bırakırdı.
const Duration updateCheckInterval = Duration(hours: 1);
