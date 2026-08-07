/// Giriş ekranı — `docs/07-musteriapp.md` §2.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_error_text.dart';
import '../../core/validators.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/infra_providers.dart';
import '../../providers/session_provider.dart';
import '../../router/app_router.dart';
import '../../widgets/status_views.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.nextLocation});

  /// Girişten sonra dönülecek yol; yoksa menüye gidilir.
  final String? nextLocation;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _submitting = false;
  String? _failure;

  /// Oturum cihazda kalsın mı? Kullanıcının son tercihiyle açılır.
  late bool _remember = ref.read(tokenStoreProvider).remember;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _failure = null;
    });

    try {
      // Tercih girişten ÖNCE yazılıyor: token'ın diske mi belleğe mi
      // yazılacağına karar veren şey bu bayrak. Sonradan ayarlansaydı token
      // çoktan diske düşmüş olurdu.
      await ref.read(tokenStoreProvider).setRemember(value: _remember);
      await ref
          .read(sessionProvider.notifier)
          .login(email: _email.text.trim(), password: _password.text);
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
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BldSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.loginSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: BldSpacing.lg),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(labelText: l10n.loginEmail),
                  validator: (value) => validateEmail(value, l10n),
                ),
                const SizedBox(height: BldSpacing.md),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(labelText: l10n.loginPassword),
                  validator: (value) => validatePassword(value, l10n),
                  onFieldSubmitted: (_) => _submitting ? null : _submit(),
                ),
                const SizedBox(height: BldSpacing.xs),
                CheckboxListTile(
                  value: _remember,
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _remember = value ?? false),
                  title: Text(l10n.loginRemember),
                  subtitle: Text(l10n.loginRememberHelp),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_failure != null) ...[
                  const SizedBox(height: BldSpacing.md),
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
                      : Text(l10n.loginSubmit),
                ),
                const SizedBox(height: BldSpacing.sm),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => context.push(
                          '${Routes.register}'
                          '${widget.nextLocation == null ? '' : '?next=${Uri.encodeComponent(widget.nextLocation!)}'}',
                        ),
                  child: Text(l10n.loginToRegister),
                ),
                TextButton(
                  onPressed: _submitting ? null : () => context.go(Routes.menu),
                  child: Text(l10n.loginBrowseMenu),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
