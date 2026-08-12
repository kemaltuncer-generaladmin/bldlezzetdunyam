/// Dokunmatik kipte harici klavye gerektirmeyen metin alanı.
///
/// KURAL (12.08.2026): **dokunmatik kip açıkken kasada klavye ve fare
/// takılı olmayacak.** Ekrandaki her metin alanının kendi klavyesini
/// getirmesi gerekiyor; getirmeyen tek bir alan, personeli kasanın
/// arkasına klavye aramaya gönderir ve vardiya durur.
///
/// NEDEN SATIR ARASI DEĞİL PENCERE: klavyeyi alanın altına gömmek,
/// listelerin (ürün arama, ayarlar) düzenini bozuyor ve klavye ekranın
/// yarısını kaplayınca aranan sonuç görünmüyor. Pencere ise tam ekran
/// açılıyor: üstte yazılan metin, altta büyük tuşlar.
///
/// KLASİK KİPTE HİÇBİR ŞEY DEĞİŞMİYOR. Dokunmatik kapalıyken alan normal
/// bir `TextField`; klavyesi olan bir kasada pencere açmak yavaşlatırdı.
library;

import 'dart:async';

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'onscreen_keyboard.dart';

/// Dokunmatik kipte dokununca ekran klavyesi açan metin alanı.
class KeyboardTextField extends StatelessWidget {
  const KeyboardTextField({
    super.key,
    required this.controller,
    required this.touchMode,
    this.label,
    this.hint,
    this.prefixIcon,
    this.layout = OnscreenKeyboardLayout.turkish,
    this.maxLength,
    this.maxLines = 1,
    this.obscureText = false,
    this.autofocus = false,
    this.isDense = false,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;

  /// Dokunmatik kip açık mı? Çağıran taraf ayarı okuyup geçiriyor —
  /// widget'ın kendisi `Ref` bilmiyor, testte kurulumu ucuz kalıyor.
  final bool touchMode;

  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final OnscreenKeyboardLayout layout;
  final int? maxLength;
  final int maxLines;
  final bool obscureText;
  final bool autofocus;
  final bool isDense;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    // DOKUNMATİKTE SALT OKUNUR: sistem klavyesi yok, imleç yanıp sönüp
    // hiçbir şey yazılamayan bir alan personeli "bozuk" sanmaya iter.
    readOnly: touchMode,
    showCursor: !touchMode,
    autofocus: autofocus && !touchMode,
    obscureText: obscureText,
    maxLength: maxLength,
    maxLines: obscureText ? 1 : maxLines,
    style: const TextStyle(fontSize: KdsTextScale.statusBar),
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    onTap: touchMode ? () => unawaited(_openKeyboard(context)) : null,
    decoration: InputDecoration(
      isDense: isDense,
      labelText: label,
      hintText: hint,
      errorText: errorText,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      border: const OutlineInputBorder(),
    ),
  );

  Future<void> _openKeyboard(BuildContext context) async {
    final entered = await showDialog<String>(
      context: context,
      builder: (context) => OnscreenKeyboardDialog(
        title: label ?? hint ?? AppL10n.of(context).keyboardTitle,
        initial: controller.text,
        layout: layout,
        maxLength: maxLength,
        obscureText: obscureText,
      ),
    );

    if (entered == null) return;

    controller.text = entered;
    // `onChanged` KENDİLİĞİNDEN ÇALIŞMIYOR: denetleyiciye programla
    // yazmak alanın geri çağrısını tetiklemiyor. Arama alanları buna
    // bağlı — çağırmazsak yazılan metin listeyi süzmez.
    onChanged?.call(entered);
    onSubmitted?.call(entered);
  }
}

/// Tam ekran klavye penceresi.
class OnscreenKeyboardDialog extends StatefulWidget {
  const OnscreenKeyboardDialog({
    super.key,
    required this.title,
    required this.initial,
    this.layout = OnscreenKeyboardLayout.turkish,
    this.maxLength,
    this.obscureText = false,
  });

  final String title;
  final String initial;
  final OnscreenKeyboardLayout layout;
  final int? maxLength;
  final bool obscureText;

  @override
  State<OnscreenKeyboardDialog> createState() => _OnscreenKeyboardDialogState();
}

class _OnscreenKeyboardDialogState extends State<OnscreenKeyboardDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AlertDialog(
      backgroundColor: const Color(KdsColors.surface),
      title: Text(widget.title),
      content: SizedBox(
        width: 1100,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                // Pencerenin İÇİNDE de salt okunur: dokunmatik kipte
                // yazının tek kaynağı alttaki tuşlar olmalı, yoksa
                // imleç konumu iki yerden değişip karışıyor.
                readOnly: true,
                showCursor: true,
                obscureText: widget.obscureText,
                maxLength: widget.maxLength,
                style: const TextStyle(fontSize: KdsTextScale.orderNumber),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: BldSpacing.md),
              OnscreenKeyboard(
                controller: _controller,
                layout: widget.layout,
                onSubmit: _submit,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
          onPressed: _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
