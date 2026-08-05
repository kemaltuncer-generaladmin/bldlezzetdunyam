/// `F3` — vardiya özeti.
///
/// Şefin akşam üstü sorduğu üç soru: kaç sipariş geçti, ortalama ne kadar
/// sürdü, hangisi bizi yaktı. Sayaçlar **uygulama açıldığından beri** sayar;
/// bunu pencerede açıkça yazıyoruz. Yanlış bir "bugün 0 sipariş" iddiası, hiç
/// iddia etmemekten kötüdür.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../shift_stats.dart';

Future<void> showShiftSummaryDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => const _ShiftSummaryDialog(),
);

class _ShiftSummaryDialog extends ConsumerWidget {
  const _ShiftSummaryDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final stats = ref.watch(shiftStatsProvider);

    return AlertDialog(
      backgroundColor: const Color(KdsColors.surface),
      title: Text(
        l10n.shiftSummaryTitle,
        style: const TextStyle(
          fontSize: KdsTextScale.columnHeader,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatRow(label: l10n.shiftSeen, value: '${stats.seenCount}'),
            _StatRow(label: l10n.shiftReady, value: '${stats.readyCount}'),
            _StatRow(
              label: l10n.shiftAverage,
              value: _duration(l10n, stats.averagePrep),
            ),
            _StatRow(
              label: l10n.shiftSlowest,
              value: _slowest(l10n, stats),
            ),
            const SizedBox(height: BldSpacing.md),
            Text(
              l10n.shiftSummaryHint,
              style: const TextStyle(
                fontSize: KdsTextScale.statusBar,
                color: Color(KdsColors.onSurfaceMuted),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
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

  static String _duration(AppL10n l10n, Duration? value) {
    if (value == null) return l10n.shiftNone;
    return value.inHours > 0
        ? l10n.elapsedHours(value.inHours, value.inMinutes.remainder(60))
        : l10n.elapsedMinutes(value.inMinutes);
  }

  static String _slowest(AppL10n l10n, ShiftStats stats) {
    final number = stats.slowestOrderNumber;
    if (number == null) return l10n.shiftNone;
    return '$number · ${_duration(l10n, stats.slowestPrep)}';
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: BldSpacing.sm),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: KdsTextScale.orderNumber,
              color: Color(KdsColors.onSurfaceMuted),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: KdsTextScale.orderNumber,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
