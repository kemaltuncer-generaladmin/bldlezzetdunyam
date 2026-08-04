/// `K-07` — cihaz eşleme ekranı (`docs/05-mutfakapp.md` §7).
///
/// İlk açılışta ve token iptal edildiğinde gösterilir. Eşleme başarılı olunca
/// [deviceSessionProvider] durumu değişir ve kök bileşen KDS ekranına geçer;
/// bu ekranın yönlendirme sorumluluğu yoktur.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/device_session.dart';
import '../data/providers.dart';
import '../l10n/app_localizations.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({this.revoked = false, super.key});

  /// Eşleme, token iptal edildiği için mi gösteriliyor?
  final bool revoked;

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _server = TextEditingController(
    text: ref.read(deviceSessionProvider).baseUrl,
  );
  late final TextEditingController _code = TextEditingController();
  late final TextEditingController _deviceName = TextEditingController(
    text: 'Mutfak Kasası',
  );

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _server.dispose();
    _code.dispose();
    _deviceName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(deviceSessionProvider.notifier)
          .pair(
            baseUrl: normalizeBaseUrl(_server.text),
            pairingCode: _code.text.trim().toUpperCase(),
            deviceName: _deviceName.text.trim(),
          );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(BldSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.pairingTitle,
                    style: const TextStyle(
                      fontSize: KdsTextScale.columnHeader,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: BldSpacing.md),
                  if (widget.revoked)
                    _Banner(
                      text: l10n.pairingRevokedNotice,
                      color: const Color(KdsColors.noteBackground),
                    ),
                  if (_error != null)
                    _Banner(
                      text: _error!,
                      color: const Color(BldColors.danger),
                    ),
                  const SizedBox(height: BldSpacing.md),
                  _Field(
                    controller: _server,
                    label: l10n.pairingServerLabel,
                    keyboardType: TextInputType.url,
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? l10n.pairingServerRequired
                        : null,
                  ),
                  const SizedBox(height: BldSpacing.md),
                  _Field(
                    controller: _code,
                    label: l10n.pairingCodeLabel,
                    hint: l10n.pairingCodeHint,
                    // Sözleşmedeki desen: ^[A-Z0-9]{4}-[A-Z0-9]{4}$
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp('[A-Za-z0-9-]'),
                      ),
                      LengthLimitingTextInputFormatter(9),
                      TextInputFormatter.withFunction(
                        (_, next) => next.copyWith(
                          text: next.text.toUpperCase(),
                        ),
                      ),
                    ],
                    validator: (value) =>
                        RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}$')
                            .hasMatch((value ?? '').trim().toUpperCase())
                        ? null
                        : l10n.pairingCodeRequired,
                  ),
                  const SizedBox(height: BldSpacing.md),
                  _Field(
                    controller: _deviceName,
                    label: l10n.pairingDeviceNameLabel,
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? l10n.pairingDeviceNameRequired
                        : null,
                  ),
                  const SizedBox(height: BldSpacing.xl),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : Text(l10n.pairingSubmit),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.validator,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    validator: validator,
    style: const TextStyle(fontSize: KdsTextScale.itemName),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: BldSpacing.sm),
    padding: const EdgeInsets.all(BldSpacing.md),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(BldRadius.sm),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: KdsTextScale.statusBar,
        color: Color(KdsColors.noteForeground),
      ),
    ),
  );
}
