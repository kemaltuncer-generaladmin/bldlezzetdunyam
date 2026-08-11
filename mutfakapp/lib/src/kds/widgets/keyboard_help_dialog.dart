/// `F1` — kısayol listesi.
///
/// Kısayolları ezberlemek beklenmiyor. Mutfakta çalışan kişi değişir, yeni
/// gelen kimseye sormadan öğrenebilmeli; bu yüzden liste ekranın kendisinde
/// durur, bir belgede değil.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

Future<void> showKeyboardHelpDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => const _KeyboardHelpDialog(),
);

class _KeyboardHelpDialog extends StatelessWidget {
  const _KeyboardHelpDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final rows = <(String, String)>[
      ('↑ ↓ ← →', l10n.shortcutSelect),
      ('Enter', l10n.shortcutAdvance),
      ('F1', l10n.shortcutHelp),
      ('F2', l10n.shortcutSearch),
      ('F3', l10n.shortcutSummary),
      ('F4', l10n.shortcutSilence),
      ('F5', l10n.shortcutRefresh),
      ('F6', l10n.shortcutHealth),
      ('F7', l10n.shortcutSales),
      ('F8', l10n.planOpen),
      ('Esc', l10n.shortcutClear),
    ];

    return AlertDialog(
      backgroundColor: const Color(KdsColors.surface),
      title: Text(
        l10n.shortcutsTitle,
        style: const TextStyle(
          fontSize: KdsTextScale.columnHeader,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final row in rows) _ShortcutRow(row.$1, row.$2)],
        ),
      ),
      actions: [
        FilledButton(
          // Tema tüm dolu butonlara sonsuz genişlik veriyor; pencere eyleminde
          // bu düzeni çökertir (`docs/05` §6 notu).
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            l10n.close,
            style: const TextStyle(fontSize: KdsTextScale.statusBar),
          ),
        ),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow(this.keys, this.label);

  final String keys;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: BldSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: BldSpacing.sm,
              vertical: BldSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: const Color(KdsColors.surfaceRaised),
              borderRadius: BorderRadius.circular(BldRadius.sm),
            ),
            child: Text(
              keys,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: KdsTextScale.statusBar,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: BldSpacing.md),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: KdsTextScale.statusBar),
          ),
        ),
      ],
    ),
  );
}
