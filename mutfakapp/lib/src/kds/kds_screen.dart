/// KDS ana ekranı — `docs/05-mutfakapp.md` §3.
///
/// Beş bölge, yukarıdan aşağı: üretim şeridi, alarm/arama çubuğu, kesinti
/// şeridi (yalnızca gerekince), üç sütunlu pano, durum çubuğu. Pano her
/// zaman kalan tüm yeri alır — çevresindeki şeritler bilgi taşır ama panonun
/// yerini çalmaz.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../l10n/app_localizations.dart';
import 'board.dart';
import 'new_order_highlights.dart';
import 'widgets/kds_alert_banner.dart';
import 'widgets/kds_header_bar.dart';
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
            const KdsHeaderBar(),
            const KdsAlertBanner(),
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
    final now = ref.watch(clockProvider).value ?? DateTime.now().toUtc();
    final thresholds = ref.watch(urgencyThresholdsProvider);

    if (ref.watch(visibleOrderCountProvider) == 0) return const _EmptyBoard();

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
              const SizedBox(width: BldSpacing.md),
            Expanded(
              child: OrderColumn(
                column: column,
                title: titles[column]!,
                orders: board[column]!,
                highlightedIds: highlights,
                now: now,
                thresholds: thresholds,
                onAdvance: (order) => _advance(context, ref, order),
                onReprint: (order, type) => _reprint(context, ref, order, type),
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

  /// Fişi kuyruğa geri koyar. Basımın kendisi kuyruk işçisinin işidir; bu
  /// yüzden onay mesajı "basıldı" değil "kuyruğa alındı" der — yazıcı
  /// kapalıysa kâğıt hemen çıkmaz ve yalan söylememeliyiz.
  void _reprint(
    BuildContext context,
    WidgetRef ref,
    KitchenOrder order,
    ReceiptType type,
  ) {
    ref.read(printServiceProvider).reprint(order.id, type);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppL10n.of(context).reprintQueued(order.orderNumber),
          style: const TextStyle(fontSize: KdsTextScale.statusBar),
        ),
      ),
    );
  }
}

/// Pano boşken ne yazdığı önemlidir: "hata mı var, yoksa gerçekten sipariş mi
/// yok" sorusu mutfakta her sabah sorulur. Arama açıkken sebep de çıkış yolu
/// da farklıdır — bu yüzden iki ayrı metin.
class _EmptyBoard extends ConsumerWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final filtering = ref.watch(searchQueryProvider).trim().isNotEmpty;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filtering ? Icons.search_off : Icons.ramen_dining_outlined,
            size: 96,
            color: const Color(KdsColors.surfaceRaised),
          ),
          const SizedBox(height: BldSpacing.md),
          Text(
            filtering ? l10n.searchNoResult : l10n.boardEmpty,
            style: const TextStyle(
              fontSize: KdsTextScale.columnHeader,
              fontWeight: FontWeight.bold,
              color: Color(KdsColors.onSurfaceMuted),
            ),
          ),
          const SizedBox(height: BldSpacing.sm),
          if (filtering)
            TextButton.icon(
              onPressed: ref.read(searchQueryProvider.notifier).clear,
              icon: const Icon(Icons.close),
              label: Text(
                l10n.searchClear,
                style: const TextStyle(fontSize: KdsTextScale.statusBar),
              ),
            )
          else
            Text(
              l10n.boardEmptyHint,
              style: const TextStyle(
                fontSize: KdsTextScale.statusBar,
                color: Color(KdsColors.onSurfaceMuted),
              ),
            ),
        ],
      ),
    );
  }
}
