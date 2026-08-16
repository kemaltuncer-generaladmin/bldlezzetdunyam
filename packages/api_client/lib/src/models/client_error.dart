/// İstemci hata raporu — `docs/openapi.yaml` §Teşhis (`ClientErrorReport`,
/// `POST /client-errors`).
///
/// Bu tip yalnızca **gönderilir**; sunucu `204` döner ve okunacak bir gövde
/// yoktur. `fromJson` yine de üretiliyor: çevrimdışıyken diske yazılıp sonra
/// gönderilen raporlar geri okunabilmeli.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'client_error.freezed.dart';
part 'client_error.g.dart';

/// Hatanın bilinen türleri — `ClientErrorReport.kind`.
///
/// **Kapalı enum değildir**, bu yüzden `String` sabitleri: sunucu bilinmeyen
/// türü olduğu gibi saklıyor ve enum'a üye eklemek için sözleşmeyi beklemek,
/// yeni bir hata sınıfını haftalarca `unhandled` altında saklamak olurdu.
abstract final class ClientErrorKind {
  /// Yakalanmamış istisna.
  static const String unhandled = 'unhandled';

  /// İstek başarısız.
  static const String network = 'network';

  /// Arayüz çizilemedi.
  static const String render = 'render';

  /// Yanıt ayrıştırılamadı.
  static const String parse = 'parse';

  /// Kullanıcı bildirdi.
  static const String manual = 'manual';
}

/// `POST /client-errors` gövdesi.
///
/// **`source` alanı YOKTUR ve eklenmemelidir.** Raporun hangi uygulamadan
/// geldiğini sunucu `X-App-Id` başlığından türetir. Gövdeye bırakılsaydı web
/// sitesi `mutfakapp` yazan bir rapor üretebilir, mutfağın güvendiği hata
/// monitörüne sahte KDS alarmı düşürebilirdi — o monitör sahada "kasada bir
/// sorun var mı" sorusunun tek cevabı ve zehirlenmesi mutfağı kör eder.
@freezed
abstract class ClientErrorReport with _$ClientErrorReport {
  const factory ClientErrorReport({
    /// Hatanın tek satırlık özeti. Sunucu 500 karakteri aşan metni **keser**,
    /// isteği reddetmez.
    required String message,

    /// Hatanın türü — bilinen değerler [ClientErrorKind] içinde.
    String? kind,

    /// Yığın izi. Sunucu 8000 karakteri aşan kısmı keser.
    String? stack,

    /// Hatanın oluştuğu ekran/rota (`/siparislerim/1234`).
    ///
    /// **Sorgu dizesi olmadan** gönderilmelidir: adres çubuğundaki
    /// parametreler zaman zaman kişisel veri taşır ve hata kaydı onları
    /// saklamak için yanlış yerdir.
    String? route,

    /// Hatanın istemcide oluştuğu an. Sunucu kendi alış anını ayrıca yazar;
    /// ikisi arasındaki fark, çevrimdışıyken biriktirilip sonra gönderilen
    /// raporları ayırt eder.
    DateTime? occurredAt,

    /// Sürüm numarasının altındaki yapı kimliği (build number, commit
    /// kısaltması). `X-App-Version` semver'i aynı kalırken yeniden yayınlanan
    /// bir yapıyı ayırmanın tek yolu budur.
    String? appBuild,

    /// Cihaz/işletim sistemi/tarayıcı özeti. Serbest metin: üç uygulamanın üç
    /// farklı kaynağı var ve tek bir yapıya sıkıştırmak hiçbirine uymuyordu.
    String? device,

    /// Ek bağlam (ekrandaki kayıt kimliği, deneme sayısı gibi).
    ///
    /// **KİŞİSEL VERİ VE SIR KONMAZ** — token, parola, kart bilgisi ya da tam
    /// adres gönderen istemci hata raporunu bir sızıntı kanalına çevirir.
    Map<String, dynamic>? context,
  }) = _ClientErrorReport;

  const ClientErrorReport._();

  factory ClientErrorReport.fromJson(Map<String, dynamic> json) =>
      _$ClientErrorReportFromJson(json);

  /// Sözleşmedeki uzunluk sınırlarına kısılmış kopya.
  ///
  /// NEDEN İSTEMCİDE DE VAR: sunucu zaten kesiyor ve reddetmiyor, ama sekiz
  /// bin karakterlik bir yığın izini tele koymak, hata yolunda olan bir
  /// istemcinin bir de bant genişliğini yakmasıdır. Döngüye girmiş bir ekran
  /// saniyede onlarca rapor üretebilir.
  ClientErrorReport truncated() => copyWith(
    message: _cut(message, 500)!,
    stack: _cut(stack, 8000),
    route: _cut(route, 200),
    appBuild: _cut(appBuild, 40),
    device: _cut(device, 120),
  );

  static String? _cut(String? value, int max) {
    if (value == null) return null;
    return value.length <= max ? value : value.substring(0, max);
  }
}
