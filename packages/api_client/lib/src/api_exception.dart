/// Hata modeli — `docs/03-api-sozlesmesi.md` §1.2.
///
/// Sunucu **tüm** hataları tek biçimde döner. Bu dosya o biçimi Dart tarafında
/// tek bir istisna tipine indirger; uygulamalar HTTP durum koduna değil
/// [ApiErrorCode]'a bakar.
library;

/// Sözleşmedeki hata kodları.
enum ApiErrorCode {
  unauthenticated('UNAUTHENTICATED'),
  forbidden('FORBIDDEN'),
  notFound('NOT_FOUND'),
  validationFailed('VALIDATION_FAILED'),
  invalidTransition('INVALID_TRANSITION'),
  locationClosed('LOCATION_CLOSED'),
  itemUnavailable('ITEM_UNAVAILABLE'),
  deviceRevoked('DEVICE_REVOKED'),
  rateLimited('RATE_LIMITED'),
  serverError('SERVER_ERROR'),

  /// Sunucu sözleşmede olmayan bir kod gönderdi ya da yanıt hiç ayrıştırılamadı
  /// (ağ kesintisi, HTML hata sayfası, zaman aşımı).
  unknown('UNKNOWN');

  const ApiErrorCode(this.wireName);

  final String wireName;

  static ApiErrorCode parse(String? value) {
    if (value == null) return unknown;
    for (final code in ApiErrorCode.values) {
      if (code.wireName == value) return code;
    }
    return unknown;
  }
}

/// API'den dönen her hata bu tipe çevrilir.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
  });

  /// Ağ katmanı hiç yanıt üretemedi (bağlantı yok, zaman aşımı).
  const ApiException.network([String? message])
    : code = ApiErrorCode.unknown,
      message = message ?? 'Bağlantı kurulamadı. İnternetinizi kontrol edin.',
      statusCode = null,
      details = null;

  final ApiErrorCode code;

  /// Kullanıcıya doğrudan gösterilebilir Türkçe metin. Sunucu üretir.
  final String message;

  final int? statusCode;

  /// `VALIDATION_FAILED` için alan bazlı ayrıntı.
  final Map<String, dynamic>? details;

  /// Sözleşmedeki `{ "error": { ... } }` gövdesinden üretir.
  ///
  /// Gövde beklenen biçimde değilse [ApiErrorCode.unknown] ile döner — bir
  /// hata yanıtını ayrıştıramamak, ayrı bir çökme sebebi olmamalı.
  factory ApiException.fromResponse(Object? body, int? statusCode) {
    if (body is! Map) {
      return ApiException(
        code: ApiErrorCode.unknown,
        message: 'Beklenmeyen bir hata oluştu.',
        statusCode: statusCode,
      );
    }

    final error = body['error'];
    if (error is! Map) {
      return ApiException(
        code: ApiErrorCode.unknown,
        message: 'Beklenmeyen bir hata oluştu.',
        statusCode: statusCode,
      );
    }

    final rawDetails = error['details'];
    return ApiException(
      code: ApiErrorCode.parse(error['code'] as String?),
      message: (error['message'] as String?) ?? 'Beklenmeyen bir hata oluştu.',
      statusCode: statusCode,
      details: rawDetails is Map
          ? Map<String, dynamic>.from(rawDetails)
          : null,
    );
  }

  /// Cihaz token'ı iptal edilmiş — KDS eşleme ekranına dönmeli
  /// (`docs/05-mutfakapp.md` §7).
  bool get isDeviceRevoked => code == ApiErrorCode.deviceRevoked;

  /// Oturum düşmüş — istemci giriş ekranına dönmeli.
  bool get isUnauthenticated => code == ApiErrorCode.unauthenticated;

  /// Yeniden denemek anlamlı mı?
  ///
  /// Doğrulama ve yetki hataları tekrar denemekle düzelmez; ağ hatası ve
  /// `429`/`5xx` düzelir. KDS'in üstel geri çekilmesi bunu kullanır.
  bool get isRetryable =>
      code == ApiErrorCode.unknown ||
      code == ApiErrorCode.rateLimited ||
      code == ApiErrorCode.serverError;

  @override
  String toString() => 'ApiException(${code.wireName}: $message)';
}
