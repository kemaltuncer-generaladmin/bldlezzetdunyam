/// Panonun tek sütunu: renkli başlık + kart listesi.
///
/// Başlığın renkli olması dekorasyon değil işlev: personel sütunu okuyarak
/// değil, renginden tanır. Kartların sol şeridi aynı rengi taşır, böylece
/// bir kartın hangi sütuna ait olduğu kaydırma sırasında da bellidir.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/kds_theme.dart';
import '../board.dart';
import '../urgency.dart';
import 'order_card.dart';

class OrderColumn extends StatelessWidget {
  const OrderColumn({
    required this.column,
    required this.title,
    required this.orders,
    required this.highlightedIds,
    required this.now,
    required this.thresholds,
    required this.onAdvance,
    required this.onReprint,
    super.key,
  });

  final KdsColumn column;
  final String title;
  final List<KitchenOrder> orders;
  final Set<int> highlightedIds;

  /// Pano saati. Tek bir kaynaktan gelir; her kart kendi saatini okusaydı
  /// aynı ekranda iki farklı "şimdi" olurdu.
  final DateTime now;

  final UrgencyThresholds thresholds;

  final void Function(KitchenOrder order) onAdvance;
  final void Function(KitchenOrder order, ReceiptType type) onReprint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final accent = KdsAccents.column(column);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ColumnHeader(
          accent: accent,
          label: l10n.columnHeader(title, orders.length),
          lateCount: lateOrderCount(orders, now: now, thresholds: thresholds),
        ),
        const SizedBox(height: BldSpacing.sm),
        Expanded(
          child: orders.isEmpty
              ? Center(
                  child: Text(
                    l10n.columnEmpty,
                    style: const TextStyle(
                      fontSize: KdsTextScale.statusBar,
                      color: Color(KdsColors.onSurfaceMuted),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: BldSpacing.md),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: BldSpacing.md),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return OrderCard(
                      key: ValueKey<int>(order.id),
                      order: order,
                      column: column,
                      age: ageOf(order, now: now, thresholds: thresholds),
                      highlighted: highlightedIds.contains(order.id),
                      onAdvance: () => onAdvance(order),
                      onReprint: (type) => onReprint(order, type),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Sütun başlığı: renkli zemin, ad, kart sayısı ve geciken sayacı.
class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    required this.accent,
    required this.label,
    required this.lateCount,
  });

  final Color accent;
  final String label;
  final int lateCount;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: BldSpacing.md,
      vertical: BldSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: accent,
      borderRadius: BorderRadius.circular(BldRadius.sm),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: KdsTextScale.columnHeader,
              fontWeight: FontWeight.bold,
              color: KdsAccents.onAccent(accent),
            ),
          ),
        ),
        // Sütun başına gecikme sayısı: "HAZIR" sütununda birikmiş üç geciken
        // sipariş, mutfağın değil kuryenin sorunudur. Sayıyı sütun bazında
        // göstermek, sorunun nerede olduğunu tek bakışta söyler.
        if (lateCount > 0) _LateCountBadge(count: lateCount),
      ],
    ),
  );
}

class _LateCountBadge extends StatelessWidget {
  const _LateCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: BldSpacing.sm, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(BldColors.neutral900),
      borderRadius: BorderRadius.circular(BldRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          size: 18,
          color: Color(BldColors.danger),
        ),
        const SizedBox(width: BldSpacing.xs),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: KdsTextScale.statusBar,
            fontWeight: FontWeight.bold,
            color: Color(BldColors.danger),
          ),
        ),
      ],
    ),
  );
}
