/// API hata durumlarının kullanıcı mesajına çevrilmesi —
/// `docs/07-musteriapp.md` §7 ikinci madde.
///
/// Sözleşmedeki her `ErrorCode` için Türkçe bir karşılık **olmak zorundadır**;
/// bu dosya bunu enum üzerinden bütünüyle denetler, tek tek örnekle değil.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musteriapp/src/core/api_error_text.dart';
import 'package:musteriapp/src/l10n/app_localizations.dart';
import 'package:musteriapp/src/l10n/app_localizations_tr.dart';

void main() {
  final AppLocalizations l10n = AppLocalizationsTr();

  ApiException error(ApiErrorCode code, {String message = '', int? status}) =>
      ApiException(code: code, message: message, statusCode: status);

  group('apiErrorMessage', () {
    test('her hata kodunun boş olmayan bir Türkçe karşılığı vardır', () {
      for (final code in ApiErrorCode.values) {
        final text = apiErrorMessage(error(code, status: 400), l10n);
        expect(text.trim(), isNotEmpty, reason: 'Karşılıksız kod: $code');
      }
    });

    test('kodlar birbirinden farklı metinlere eşlenir', () {
      final texts = {
        for (final code in ApiErrorCode.values)
          apiErrorMessage(error(code, status: 400), l10n),
      };

      expect(texts.length, ApiErrorCode.values.length);
    });

    test('sözleşmedeki kodlar beklenen metni verir', () {
      expect(
        apiErrorMessage(error(ApiErrorCode.unauthenticated), l10n),
        l10n.errorUnauthenticated,
      );
      expect(
        apiErrorMessage(error(ApiErrorCode.forbidden), l10n),
        l10n.errorForbidden,
      );
      expect(
        apiErrorMessage(error(ApiErrorCode.notFound), l10n),
        l10n.errorNotFound,
      );
      expect(
        apiErrorMessage(error(ApiErrorCode.validationFailed), l10n),
        l10n.errorValidationFailed,
      );
      expect(
        apiErrorMessage(error(ApiErrorCode.invalidTransition), l10n),
        l10n.errorInvalidTransition,
      );
      expect(
        apiErrorMessage(error(ApiErrorCode.locationClosed), l10n),
        l10n.errorLocationClosed,
      );
      expect(
        apiErrorMessage(error(ApiErrorCode.itemUnavailable), l10n),
        l10n.errorItemUnavailable,
      );
      expect(
        apiErrorMessage(error(ApiErrorCode.deviceRevoked), l10n),
        l10n.errorDeviceRevoked,
      );
      expect(
        apiErrorMessage(error(ApiErrorCode.rateLimited), l10n),
        l10n.errorRateLimited,
      );
      expect(
        apiErrorMessage(error(ApiErrorCode.serverError), l10n),
        l10n.errorServerError,
      );
    });

    test('yanıtsız kalan istek ağ mesajı verir', () {
      expect(
        apiErrorMessage(const ApiException.network(), l10n),
        l10n.errorNetwork,
      );
    });

    test('ayrıştırılamayan yanıt genel hata mesajı verir', () {
      // Sunucu yanıt üretti (durum kodu var) ama gövde sözleşmeye uymuyor.
      final parsed = ApiException.fromResponse('<html>500</html>', 500);

      expect(parsed.code, ApiErrorCode.unknown);
      expect(apiErrorMessage(parsed, l10n), l10n.errorUnknown);
    });
  });

  group('apiErrorDisplayMessage', () {
    test('bağlama bağlı hatalarda sunucunun açıklaması gösterilir', () {
      const serverText = 'En az sipariş tutarı 250,00 ₺.';

      for (final code in [
        ApiErrorCode.validationFailed,
        ApiErrorCode.locationClosed,
        ApiErrorCode.itemUnavailable,
        ApiErrorCode.invalidTransition,
      ]) {
        expect(
          apiErrorDisplayMessage(
            error(code, message: serverText, status: 422),
            l10n,
          ),
          serverText,
        );
      }
    });

    test('sunucu açıklaması boşsa yerel metne düşer', () {
      expect(
        apiErrorDisplayMessage(
          error(ApiErrorCode.validationFailed, message: '   ', status: 422),
          l10n,
        ),
        l10n.errorValidationFailed,
      );
    });

    test('oturum ve ağ hatalarında sunucu metni kullanılmaz', () {
      expect(
        apiErrorDisplayMessage(
          error(
            ApiErrorCode.unauthenticated,
            message: 'Token expired',
            status: 401,
          ),
          l10n,
        ),
        l10n.errorUnauthenticated,
      );
    });
  });

  group('isOfflineError', () {
    test('durum kodu olmayan bilinmeyen hata çevrimdışıdır', () {
      expect(isOfflineError(const ApiException.network()), isTrue);
    });

    test('sunucudan gelen hata çevrimdışı değildir', () {
      expect(
        isOfflineError(error(ApiErrorCode.serverError, status: 500)),
        isFalse,
      );
      expect(isOfflineError(error(ApiErrorCode.unknown, status: 502)), isFalse);
    });

    test('API dışı istisnalar çevrimdışı sayılmaz', () {
      expect(isOfflineError(Exception('boom')), isFalse);
    });
  });

  group('sözleşme gövdesinden çeviri', () {
    test('{"error":{code,message}} biçimi doğru kodu üretir', () {
      final parsed = ApiException.fromResponse({
        'error': {
          'code': 'LOCATION_CLOSED',
          'message': 'Sipariş saatleri dışındasınız.',
          'details': {'cutoff': '16:00'},
        },
      }, 422);

      expect(parsed.code, ApiErrorCode.locationClosed);
      expect(parsed.details, {'cutoff': '16:00'});
      expect(
        apiErrorDisplayMessage(parsed, l10n),
        'Sipariş saatleri dışındasınız.',
      );
    });

    test('sözleşmede olmayan kod bilinmeyene düşer, çökmez', () {
      final parsed = ApiException.fromResponse({
        'error': {'code': 'TEAPOT', 'message': 'x'},
      }, 418);

      expect(parsed.code, ApiErrorCode.unknown);
      expect(apiErrorMessage(parsed, l10n), l10n.errorUnknown);
    });
  });
}
