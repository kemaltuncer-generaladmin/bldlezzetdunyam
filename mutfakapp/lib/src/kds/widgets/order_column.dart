/// Panonun tek sütunu: renkli başlık + kart listesi.
///
/// Başlığın renkli olması dekorasyon değil işlev: personel sütunu okuyarak
/// değil, renginden tanır. Kartların sol şeridi aynı rengi taşır, böylece
/// bir kartın hangi sütuna ait olduğu kaydırma sırasında da bellidir.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
// `ScrollCacheExtent` yalnızca buradan dışa açılıyor; `material.dart` onu
// yeniden aktarmıyor.
import 'package:flutter/rendering.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/kds_theme.dart';
import '../board.dart';
import '../order_progress.dart';
import '../urgency.dart';
import 'order_card.dart';

class OrderColumn extends StatefulWidget {
  const OrderColumn({
    required this.column,
    required this.title,
    required this.orders,
    required this.highlightedIds,
    required this.busyIds,
    required this.progress,
    required this.selectedIndex,
    required this.now,
    required this.thresholds,
    required this.onAdvance,
    required this.onToggleItem,
    required this.onReprint,
    super.key,
  });

  final KdsColumn column;
  final String title;
  final List<KitchenOrder> orders;
  final Set<int> highlightedIds;

  /// Sunucuya isteği uçan siparişler — düğmeleri kilitli çizilir.
  final Set<int> busyIds;

  final OrderItemProgress progress;

  /// Klavyeyle seçili kartın sırası; bu sütunda seçim yoksa `null`.
  final int? selectedIndex;

  /// Pano saati. Tek bir kaynaktan gelir; her kart kendi saatini okusaydı
  /// aynı ekranda iki farklı "şimdi" olurdu.
  final DateTime now;

  final UrgencyThresholds thresholds;

  final void Function(KitchenOrder order) onAdvance;
  final void Function(KitchenOrder order, int itemIndex) onToggleItem;
  final void Function(KitchenOrder order, ReceiptType type) onReprint;

  @override
  State<OrderColumn> createState() => _OrderColumnState();
}

class _OrderColumnState extends State<OrderColumn> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OrderColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _revealSelection();
    }
  }

  /// Klavyeyle seçilen kartı görünür alana getirir.
  ///
  /// Ekranın dışında kalan bir seçim, `Enter`'ın görünmeyen bir siparişi
  /// ilerletmesi demektir. Kart henüz çizilmemişse (uzağa atlanmışsa) hiçbir
  /// şey yapmayız; listenin önbellek payı komşuların çizili olmasını
  /// sağladığı için tek adımlık hareketler her zaman yakalanır.
  void _revealSelection() {
    final index = widget.selectedIndex;
    if (index == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _cardKey(index).currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.25,
        duration: const Duration(milliseconds: 150),
      ).ignore();
    });
  }

  GlobalObjectKey<State<StatefulWidget>> _cardKey(int index) =>
      GlobalObjectKey<State<StatefulWidget>>('${widget.column.name}-$index');

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final accent = KdsAccents.column(widget.column);
    final orders = widget.orders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ColumnHeader(
          accent: accent,
          label: l10n.columnHeader(widget.title, orders.length),
          lateCount: lateOrderCount(
            orders,
            now: widget.now,
            thresholds: widget.thresholds,
          ),
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
                  controller: _scroll,
                  // Komşu kartların çizili durması klavye seçimini görünür
                  // kılar; 40 kartlık bir listede yalnızca birkaç kart fazla
                  // çizmek, kaydırmayı takılmaya sokmayacak kadar ucuzdur.
                  scrollCacheExtent: const ScrollCacheExtent.pixels(1200),
                  padding: const EdgeInsets.only(bottom: BldSpacing.md),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: BldSpacing.md),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return KeyedSubtree(
                      key: _cardKey(index),
                      child: OrderCard(
                        key: ValueKey<int>(order.id),
                        order: order,
                        column: widget.column,
                        age: ageOf(
                          order,
                          now: widget.now,
                          thresholds: widget.thresholds,
                        ),
                        thresholds: widget.thresholds,
                        highlighted: widget.highlightedIds.contains(order.id),
                        selected: widget.selectedIndex == index,
                        busy: widget.busyIds.contains(order.id),
                        progress: widget.progress,
                        onAdvance: () => widget.onAdvance(order),
                        onToggleItem: (itemIndex) =>
                            widget.onToggleItem(order, itemIndex),
                        onReprint: (type) => widget.onReprint(order, type),
                      ),
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
