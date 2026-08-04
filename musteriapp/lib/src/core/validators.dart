/// Form doğrulayıcıları.
///
/// Buradaki kurallar sözleşmedeki alan kısıtlarının **kopyasıdır**
/// (`docs/openapi.yaml` `RegisterRequest`). Son söz sunucudadır; bunlar
/// yalnızca kullanıcıyı boşuna sunucuya göndermemek içindir.
library;

import '../l10n/app_localizations.dart';

/// Basit ve gevşek e-posta kontrolü: tek `@`, iki yanında karakter, noktalı
/// alan adı. Sıkı RFC 5322 kontrolü geçerli adresleri reddettiği için
/// bilinçli olarak yapılmaz.
final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// `docs/openapi.yaml`: `^[1-9][0-9]{9}$` — başında 0 veya +90 olmadan 10 hane.
final RegExp _telephonePattern = RegExp(r'^[1-9][0-9]{9}$');

String? validateRequired(String? value, AppLocalizations l10n) {
  if (value == null || value.trim().isEmpty) return l10n.validationRequired;
  return null;
}

String? validateEmail(String? value, AppLocalizations l10n) {
  final required = validateRequired(value, l10n);
  if (required != null) return required;
  if (!_emailPattern.hasMatch(value!.trim())) return l10n.validationEmail;
  return null;
}

String? validatePassword(String? value, AppLocalizations l10n) {
  final required = validateRequired(value, l10n);
  if (required != null) return required;
  if (value!.length < 8) return l10n.validationPasswordShort;
  return null;
}

String? validateTelephone(String? value, AppLocalizations l10n) {
  final required = validateRequired(value, l10n);
  if (required != null) return required;
  if (!_telephonePattern.hasMatch(value!.trim())) {
    return l10n.validationTelephone;
  }
  return null;
}
