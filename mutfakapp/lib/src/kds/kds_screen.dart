/// KDS ana ekranı — `docs/05-mutfakapp.md` §3.
///
/// Tek ekran, üç bölge: üretim şeridi (üst), üç sütunlu pano (orta),
/// durum çubuğu (alt).
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../l10n/app_localizations.dart';
import 'board.dart';
import 'new_order_highlights.dart';
import 'widgets/kds_status_bar.dart';
import 'widgets/order_column.dart';
import 'widgets/production_strip.dart';

class KdsScreen extends ConsumerWidget {
  const KdsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ProductionStrip(totals: ref.watch(productionTotalsProvider)),
            const Expanded(child: _Board()),
            const KdsStatusBar(),
          ],
        ),
      ),
    );
  }
}

class _Board extends ConsumerWidget {
  const _Board();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final board = ref.watch(boardProvider);
    final highlights = ref.watch(newOrderHighlightsProvider);

    final titles = <KdsColumn, String>{
      KdsColumn.yeni: l10n.columnNew,
      KdsColumn.hazirlaniyor: l10n.columnPreparing,
      KdsColumn.hazir: l10n.columnReady,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BldSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final column in KdsColumn.values) ...[
            if (column != KdsColumn.values.first)
              const VerticalDivider(
                width: BldSpacing.lg,
                color: Color(KdsColors.surfaceRaised),
              ),
            Expanded(
              child: OrderColumn(
                title: titles[column]!,
                orders: board[column]!,
                highlightedIds: highlights,
                onAdvance: (order) => _advance(context, ref, order),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Geri alma yoktur (`docs/05` §3): buton tek yön çalışır, hata görünür olur.
  Future<void> _advance(
    BuildContext context,
    WidgetRef ref,
    KitchenOrder order,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);

    try {
      await ref.read(orderStatusControllerProvider).advance(order);
    } on ApiException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(BldColors.danger),
          content: Text(
            l10n.statusChangeFailed(error.message),
            style: const TextStyle(fontSize: KdsTextScale.statusBar),
          ),
        ),
      );
    }
  }
}
