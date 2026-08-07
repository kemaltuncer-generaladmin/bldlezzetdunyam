/// Kayıt ekranı — `docs/07-musteriapp.md` §2 (KVKK onay kutusu zorunlu).
///
/// `kvkk_accepted` sözleşmede `const: true`'dur; işaretlenmeden istek
/// gönderilmez, sunucu zaten `422 VALIDATION_FAILED` dönerdi.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_error_text.dart';
import '../../core/validators.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/session_provider.dart';
import '../../router/app_router.dart';
import '../../widgets/status_views.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.nextLocation});

  final String? nextLocation;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  // Firma bilgileri (B2B — yalnız kurumsal hesaplar sipariş verir).
  final _companyName = TextEditingController();
  final _contactPerson = TextEditingController();
  final _taxOffice = TextEditingController();
  final _taxNumber = TextEditingController();
  final _companyPhone = TextEditingController();
  // Giriş bilgileri.
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _telephone = TextEditingController();
  final _password = TextEditingController();

  bool _kvkkAccepted = false;
  bool _submitting = false;
  String? _failure;

  @override
  void dispose() {
    _companyName.dispose();
    _contactPerson.dispose();
    _taxOffice.dispose();
    _taxNumber.dispose();
    _companyPhone.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _telephone.dispose();
    _password.dispose();
    super.dispose();
  }

  static String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    if (!_kvkkAccepted) {
      setState(() => _failure = l10n.registerKvkkRequired);
      return;
    }

    setState(() {
      _submitting = true;
      _failure = null;
    });

    try {
      await ref
          .read(sessionProvider.notifier)
          .register(
            RegisterRequest(
              firstName: _firstName.text.trim(),
              lastName: _lastName.text.trim(),
              email: _email.text.trim(),
              telephone: _telephone.text.trim(),
              password: _password.text,
              kvkkAccepted: true,
              companyName: _companyName.text.trim(),
              contactPerson: _contactPerson.text.trim(),
              taxOffice: _emptyToNull(_taxOffice.text),
              taxNumber: _emptyToNull(_taxNumber.text),
              companyPhone: _emptyToNull(_companyPhone.text),
            ),
          );
      if (!mounted) return;
      context.go(widget.nextLocation ?? Routes.menu);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _failure = apiErrorDisplayMessage(error, l10n));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.registerTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BldSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Firma bilgileri — B2B: yalnız kurumsal hesaplar sipariş verir.
                _SectionLabel(text: l10n.registerCompanySection),
                Padding(
                  padding: const EdgeInsets.only(bottom: BldSpacing.md),
                  child: Text(
                    l10n.registerCorporateNote,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextFormField(
                  controller: _companyName,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.registerCompanyName,
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.registerCompanyRequired
                      : null,
                ),
                const SizedBox(height: BldSpacing.md),
                TextFormField(
                  controller: _contactPerson,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.registerContactPerson,
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.registerContactRequired
                      : null,
                ),
                const SizedBox(height: BldSpacing.md),
                TextFormField(
                  controller: _taxOffice,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.registerTaxOffice,
                  ),
                ),
                const SizedBox(height: BldSpacing.md),
                TextFormField(
                  controller: _taxNumber,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.registerTaxNumber,
                  ),
                ),
                const SizedBox(height: BldSpacing.md),
                TextFormField(
                  controller: _companyPhone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.registerCompanyPhone,
                  ),
                ),
                const SizedBox(height: BldSpacing.lg),

                _SectionLabel(text: l10n.registerAccountSection),
                TextFormField(
                  controller: _firstName,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.registerFirstName,
                  ),
                  validator: (value) => validateRequired(value, l10n),
                ),
                const SizedBox(height: BldSpacing.md),
                TextFormField(
                  controller: _lastName,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: l10n.registerLastName),
                  validator: (value) => validateRequired(value, l10n),
                ),
                const SizedBox(height: BldSpacing.md),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.loginEmail),
                  validator: (value) => validateEmail(value, l10n),
                ),
                const SizedBox(height: BldSpacing.md),
                TextFormField(
                  controller: _telephone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.registerTelephone,
                    helperText: l10n.registerTelephoneHelp,
                  ),
                  validator: (value) => validateTelephone(value, l10n),
                ),
                const SizedBox(height: BldSpacing.md),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.loginPassword,
                    helperText: l10n.registerPasswordHelp,
                  ),
                  validator: (value) => validatePassword(value, l10n),
                ),
                const SizedBox(height: BldSpacing.md),
                CheckboxListTile(
                  value: _kvkkAccepted,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: _submitting
                      ? null
                      : (value) =>
                            setState(() => _kvkkAccepted = value ?? false),
                  title: Text(
                    l10n.registerKvkk,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (_failure != null) ...[
                  const SizedBox(height: BldSpacing.sm),
                  FormErrorBox(message: _failure!),
                ],
                const SizedBox(height: BldSpacing.lg),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.registerSubmit),
                ),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => context.canPop()
                            ? context.pop()
                            : context.go(Routes.login),
                  child: Text(l10n.registerToLogin),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Form içi bölüm başlığı — "Firma bilgileri" / "Giriş bilgileri".
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BldSpacing.sm),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
