/// Tek kullanımlık kod (OTP) alanı — SMS ile gelen altı hane.
///
/// **Neden ortak bir bileşen:** kod alanı üç ayrı ayrıntının hepsini birden
/// doğru yapmak zorunda ve her kopyada biri unutuluyor:
///  * `autofillHints: oneTimeCode` — iOS ve Android klavyesi SMS'teki kodu
///    üstte öneri olarak gösteriyor; bu öznitelik olmadan kullanıcı kodu elle
///    kopyalamak zorunda.
///  * Yalnız rakam kabul eden giriş biçimlendiricisi — kopyala/yapıştır ile
///    gelen boşluk ve tire, sunucuya giden gövdeyi bozuyor.
///  * Sayaç gizlenmiş, ortalanmış ve **tabular** rakamlar — hane genişliği
///    değiştikçe kutunun içindeki metin sağa sola kayıyordu.
///
/// Ekran, alanın kendisinden başka bir şey bilmez: doğrulama da burada
/// ([validateOtpCode]).
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/bld_theme.dart';

/// Sözleşmedeki kod uzunluğu (`docs/openapi.yaml`: `minLength/maxLength: 6`).
const int kOtpCodeLength = 6;

final RegExp _otpPattern = RegExp('^[0-9]{$kOtpCodeLength}\$');

/// Altı hanenin doğrulaması.
///
/// `core/validators.dart` YERİNE burada: o dosya sözleşmedeki **kayıt**
/// alanlarının (e-posta, parola, telefon) kopyasını taşıyor ve bu dalgada
/// başka bir kulvarın elinde. Kod uzunluğu alanın kendi bilgisi; alanla
/// birlikte duruyor.
String? validateOtpCode(String? value, AppLocalizations l10n) {
  final code = value?.trim() ?? '';
  if (code.isEmpty) return l10n.validationRequired;
  if (!_otpPattern.hasMatch(code)) return l10n.validationOtpCode;
  return null;
}

class OtpField extends StatelessWidget {
  const OtpField({
    super.key,
    required this.controller,
    this.label,
    this.enabled = true,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;

  /// Alan etiketi. Verilmezse `l10n.otpFieldLabel` kullanılır.
  final String? label;

  final bool enabled;
  final bool autofocus;

  /// Klavyedeki "bitti" tuşu. Gönderim sürüyorsa çağrı yeri `null` geçer.
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.oneTimeCode],
      maxLength: kOtpCodeLength,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(kOtpCodeLength),
      ],
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        // Kod bir SAYI DEĞİL, bir dizi hane: aralık açık ve rakam genişliği
        // sabit olmalı ki altı hane okunurken kaybolmasın.
        letterSpacing: BldSpacing.sm,
        fontFeatures: kBldTabularFigures,
      ),
      decoration: InputDecoration(
        labelText: label ?? l10n.otpFieldLabel,
        // Sayaç ("3/6") gizli: kullanıcı zaten kaç hane girdiğini görüyor ve
        // sayaç, hata metniyle aynı satırı paylaşıp onu kırpıyordu.
        counterText: '',
      ),
      validator: (value) => validateOtpCode(value, l10n),
      onFieldSubmitted: onSubmitted,
    );
  }
}
