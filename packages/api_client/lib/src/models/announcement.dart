/// Uygulama-içi duyuru DTO'ları — `docs/openapi.yaml` §Duyuru
/// (`Announcement`, `GET /announcements`).
///
/// **Push (FCM) YOKTUR** (16.08.2026): duyuru yalnız istemci açıkken çekilir.
/// Bu, "duyuru okundu mu" sorusunun cevabını da değiştirir — görüldü işareti
/// bildirimin tesliminden değil, duyurunun ekranda çizilmesinden doğar.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'announcement.freezed.dart';
part 'announcement.g.dart';

/// Duyurunun tonu — `Announcement.severity`.
///
/// **Gevşek enum** (`converters.dart` §katılık politikası): bilinmeyen değer
/// [info]'ya düşer. Sözleşmede kapalı bir enum olarak duruyor ama üye eklemek
/// kırıcı sayılmıyor ve bilinmeyen bir ton yüzünden duyuruyu hiç göstermemek,
/// yanlış renkle göstermekten çok daha pahalıdır — duyurunun işi metni
/// iletmek, rengi süslemektir.
enum AnnouncementSeverity {
  info('info'),
  warning('warning'),
  critical('critical');

  const AnnouncementSeverity(this.wireName);

  final String wireName;

  /// Bilinmeyen ya da eksik değer [info]'dur: en sakin ton.
  static AnnouncementSeverity parse(String? value) {
    if (value == null || value.isEmpty) return info;
    for (final severity in AnnouncementSeverity.values) {
      if (severity.wireName == value) return severity;
    }
    return info;
  }
}

class AnnouncementSeverityConverter
    implements JsonConverter<AnnouncementSeverity, String?> {
  const AnnouncementSeverityConverter();

  @override
  AnnouncementSeverity fromJson(String? json) =>
      AnnouncementSeverity.parse(json);

  @override
  String? toJson(AnnouncementSeverity object) => object.wireName;
}

/// Duyurunun gösterileceği bilinen yerler — `Announcement.placement`.
///
/// **Kapalı bir enum DEĞİLDİR ve bu yüzden `String` sabitleri olarak duruyor.**
/// Yerleşimler panelde tanımlanıyor; yeni bir ekran açıldığında sözleşmeyi
/// beklemek, duyurunun haftalarca yayınlanamaması demek olurdu.
///
/// İstemci **tanımadığı yerleşimi hiç çizmez** — bilmediği bir yeri "ana
/// sayfa" sayıp duyuruyu yanlış ekrana koymak, sessizce atlamaktan kötüdür.
abstract final class AnnouncementPlacement {
  /// Ana sayfa bandı.
  static const String home = 'home';

  /// Gün seçicinin üstü.
  static const String menu = 'menu';

  static const String cart = 'cart';

  /// Ödeme adımı.
  static const String checkout = 'checkout';

  static const String orders = 'orders';

  static const String subscription = 'subscription';
}

/// `GET /announcements` listesindeki tek duyuru.
@freezed
abstract class Announcement with _$Announcement {
  const factory Announcement({
    required int id,

    /// Duyurunun gösterileceği yer; bilinen değerler
    /// [AnnouncementPlacement] içinde. Kapalı enum değildir.
    required String placement,

    /// Duyuru metni (düz metin). Biçimlendirme istemcinindir.
    required String body,

    /// Kullanıcı bu duyuruyu kapatabilir mi?
    ///
    /// `false` ise duyuru yayın penceresi boyunca ekranda kalır — hizmet
    /// kesintisi gibi duyurular kapatıldıktan sonra bir daha görünmezse
    /// müşteri aynı soruyu telefonla sorar.
    required bool dismissible,

    /// Bu müşteri duyuruyu daha önce gördü mü?
    required bool seen,

    /// Bu müşteri duyuruyu kapattı mı?
    ///
    /// Kapatılan duyuru listeye **girmez**; alan, istemcinin iyimser
    /// güncellemesini geri alabilmesi ve yönetim görünümleri için duruyor.
    required bool dismissed,

    /// Duyurunun tonu; istemci rengi ve ikonu buna göre seçer.
    ///
    /// [AnnouncementSeverity.critical] **kapanmaz** demek değildir;
    /// kapanabilirliği [dismissible] söyler. İkisi ayrı çünkü kritik ama bir
    /// kez okunması yeten duyurular var ("yarın servis yok").
    @AnnouncementSeverityConverter()
    @Default(AnnouncementSeverity.info)
    AnnouncementSeverity severity,
    String? title,
    String? actionLabel,

    /// Duyurunun düğmesi. [actionLabel] boşsa düğme çizilmez. Adresin
    /// **uygulama içi** bir yola işaret etmesi beklenir; istemci tanımadığı
    /// adresi tarayıcıda açar.
    String? actionUrl,
    String? imageUrl,
    DateTime? startsAt,

    /// Yayın penceresinin sonu; süresizse `null`.
    ///
    /// İstemci **kendi saatine göre eleme YAPMAZ**: pencere dışına çıkmış
    /// duyuru listeye zaten girmez. Alan yalnız "şu tarihe kadar geçerli"
    /// cümlesini kurmak için var — saati kaymış bir telefonda eleme yapmak,
    /// geçerli duyuruyu gizlerdi.
    DateTime? endsAt,
    DateTime? createdAt,
  }) = _Announcement;

  const Announcement._();

  factory Announcement.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementFromJson(json);

  /// Düğme çizilecek mi?
  ///
  /// İkisi birden gerekli: etiketsiz bir adres tıklanacak bir şey vermez,
  /// adressiz bir etiket hiçbir yere gitmeyen bir düğmedir.
  bool get hasAction =>
      actionLabel != null &&
      actionLabel!.isNotEmpty &&
      actionUrl != null &&
      actionUrl!.isNotEmpty;

  /// Bu duyuru verilen yerleşime mi ait?
  ///
  /// Karşılaştırma tek yerde: yerleşim kapalı bir enum olmadığı için her ekran
  /// kendi dizesini yazsaydı bir harf farkı duyuruyu sessizce yok ederdi.
  bool isFor(String placement) => this.placement == placement;
}
