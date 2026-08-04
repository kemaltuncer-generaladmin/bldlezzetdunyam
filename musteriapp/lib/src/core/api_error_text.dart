/// API hatalarının kullanıcı metnine çevrilmesi.
///
/// Uygulama HTTP durum koduna değil [ApiErrorCode]'a bakar
/// (`packages/api_client/lib/src/api_exception.dart`). Metinler `l10n`'dendir;
/// bu dosyada gömülü Türkçe dize yoktur.
library;

import 'package:bld_api_client/bld_api_client.dart';

import '../l10n/app_localizations.dart';

/// Hata kodunun yerel karşılığı. Sunucunun gönderdiği metinden bağımsızdır.
///
/// Sunucuya hiç ulaşılamadığında da bir metin üretebilmek için gereklidir:
/// `ApiException.network` kodu [ApiErrorCode.unknown]'dır ve `statusCode`
/// taşımaz.
String apiErrorMessage(ApiException error, AppLocalizations l10n) {
  return switch (error.code) {
    ApiErrorCode.unauthenticated => l10n.errorUnauthenticated,
    ApiErrorCode.forbidden => l10n.errorForbidden,
    ApiErrorCode.notFound => l10n.errorNotFound,
    ApiErrorCode.validationFailed => l10n.errorValidationFailed,
    ApiErrorCode.invalidTransition => l10n.errorInvalidTransition,
    ApiErrorCode.locationClosed => l10n.errorLocationClosed,
    ApiErrorCode.itemUnavailable => l10n.errorItemUnavailable,
    ApiErrorCode.deviceRevoked => l10n.errorDeviceRevoked,
    ApiErrorCode.rateLimited => l10n.errorRateLimited,
    ApiErrorCode.serverError => l10n.errorServerError,
    // Yanıtsız kalan istek ile ayrıştırılamayan yanıt aynı kodu taşır ama
    // kullanıcı için farklı şeylerdir: ilkinde yapabileceği bir şey var.
    ApiErrorCode.unknown => isOfflineError(error)
        ? l10n.errorNetwork
        : l10n.errorUnknown,
  };
}

/// Ekranda gösterilecek metin.
///
/// Bağlama bağlı hatalarda (hangi ürün tükendi, neden kapalı, hangi alan
/// hatalı) sunucunun açıklaması yerel genel metinden daha faydalıdır ve
/// sözleşme onu "kullanıcıya gösterilebilir Türkçe metin" olarak tanımlar
/// (`docs/openapi.yaml` `Error.message`). Kalan kodlarda yerel metin kullanılır:
/// oturum/ağ/oran hatalarında sunucu mesajı ya yoktur ya da bir şey eklemez.
String apiErrorDisplayMessage(ApiException error, AppLocalizations l10n) {
  const serverExplains = {
    ApiErrorCode.validationFailed,
    ApiErrorCode.locationClosed,
    ApiErrorCode.itemUnavailable,
    ApiErrorCode.invalidTransition,
  };

  if (serverExplains.contains(error.code) && error.message.trim().isNotEmpty) {
    return error.message;
  }
  return apiErrorMessage(error, l10n);
}

/// Hata "cihaz ağa çıkamadı" anlamına mı geliyor?
///
/// Sunucu bir yanıt üretebilmişse (durum kodu var) sorun ağ değildir; bu ayrım
/// çevrimdışı rozetinin yanlış yanmasını engeller.
bool isOfflineError(Object error) =>
    error is ApiException &&
    error.code == ApiErrorCode.unknown &&
    error.statusCode == null;
