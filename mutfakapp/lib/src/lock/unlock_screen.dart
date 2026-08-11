/// Açılış kilidi ekranı — `docs/05-mutfakapp.md` §8.
///
/// Uygulama açıldığında **bir kez** sorulur. Doğru parola girilince KDS
/// açılır ve bir daha sorulmaz: ayarlar, fiş yeniden basma, eşleme sıfırlama
/// hiçbiri parola istemez. Mutfakta elleri dolu bir personelin her işlemde
/// parola girmesi, parolanın duvara yazılmasıyla sonuçlanır.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../input/onscreen_keyboard.dart';
import '../l10n/app_localizations.dart';
import 'unlock_password.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({
    required this.onUnlocked,
    this.showOnscreenKeyboard = false,
    super.key,
  });

  final VoidCallback onUnlocked;

  /// Dokunmatik kipte ekran klavyesi açılır (K-10).
  ///
  /// KİLİT EKRANI ÖZELLİKLE ÖNEMLİ: kasa açıldığında ilk karşılaşılan
  /// ekran burası. Harici klavye takılı değilse ve ekran klavyesi de
  /// yoksa mutfak uygulamayı hiç açamaz — kurtarılamaz bir kilitlenme.
  final bool showOnscreenKeyboard;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _wrong = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    if (unlockPasswordMatches(_controller.text)) {
      widget.onUnlocked();
      return;
    }

    setState(() => _wrong = true);
    _controller.clear();
    // Odak alanda kalsın: personel yanlış yazdığında fareye uzanmak
    // zorunda kalmamalı.
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          // Ekran klavyesi açıkken içerik 460 px'e sığmıyor; klavye
          // satırlarının okunur kalması için genişlik iki katına çıkıyor.
          constraints: BoxConstraints(
            maxWidth: widget.showOnscreenKeyboard ? 900 : 460,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(BldSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.appTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: KdsTextScale.columnHeader,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: BldSpacing.xl),
                TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  obscureText: true,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _submit(),
                  // Parola alanına yapıştırma/otomatik düzeltme kapalı:
                  // dokunmatik klavyede büyük harf düzeltmesi "Bld" yazımını
                  // bozuyordu.
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [LengthLimitingTextInputFormatter(64)],
                  style: const TextStyle(fontSize: KdsTextScale.statusBar),
                  decoration: InputDecoration(
                    labelText: l10n.unlockPrompt,
                    border: const OutlineInputBorder(),
                    errorText: _wrong ? l10n.unlockWrong : null,
                  ),
                ),
                const SizedBox(height: BldSpacing.lg),
                FilledButton(
                  onPressed: _submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: BldSpacing.sm,
                    ),
                    child: Text(
                      l10n.unlockAction,
                      style: const TextStyle(fontSize: KdsTextScale.statusBar),
                    ),
                  ),
                ),
                if (widget.showOnscreenKeyboard) ...[
                  const SizedBox(height: BldSpacing.lg),
                  OnscreenKeyboard(
                    controller: _controller,
                    onSubmit: _submit,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
