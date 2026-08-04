/// Tek sipariş kartı — `docs/05-mutfakapp.md` §3.
///
/// Boyut alt sınırları `KdsTextScale`'dendir: ürün adı en az 20, adet en az 28
/// ve kalın. Değerler burada sabit yazılmaz.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board.dart';

class OrderCard extends StatefulWidget {
  const OrderCard({
    required this.order,
    required this.highlighted,
    required this.onAdvance,
    super.key,
  });

  final KitchenOrder order;

  /// Yeni düşen sipariş: 3 saniye yanıp söner (`docs/05` §3).
  final bool highlighted;

  final VoidCallback onAdvance;

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void initState() {
    super.initState();
    if (widget.highlighted) _blink.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant OrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlighted == oldWidget.highlighted) return;
    if (widget.highlighted) {
      _blink.repeat(reverse: true);
    } else {
      _blink
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final order = widget.order;

    return AnimatedBuilder(
      animation: _blink,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BldRadius.md),
          border: Border.all(
            color: Color.lerp(
              const Color(KdsColors.surfaceRaised),
              const Color(BldColors.brand400),
              _blink.value,
            )!,
            width: 3,
          ),
        ),
        child: child,
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(BldSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _CardHeader(order: order),
              if (order.requestedAt != null) ...[
                const SizedBox(height: BldSpacing.xs),
                _RequestedAt(order: order),
              ],
              if (order.customerLabel != null) ...[
                const SizedBox(height: BldSpacing.xs),
                Text(
                  order.customerLabel!,
                  style: const TextStyle(
                    fontSize: KdsTextScale.statusBar,
                    color: Color(KdsColors.onSurfaceMuted),
                  ),
                ),
              ],
              const SizedBox(height: BldSpacing.sm),
              for (final item in order.items) _ItemRow(item: item),
              if (order.customerNote != null &&
                  order.customerNote!.trim().isNotEmpty) ...[
                const SizedBox(height: BldSpacing.sm),
                _NoteBox(text: '${l10n.notePrefix}: ${order.customerNote}'),
              ],
              if (order.nextStatus != null) ...[
                const SizedBox(height: BldSpacing.md),
                FilledButton(
                  onPressed: widget.onAdvance,
                  child: Text(_actionLabel(l10n, order.nextStatus!)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.order});

  final KitchenOrder order;

  @override
  Widget build(BuildContext context) {
    final isDelivery = order.deliveryType == DeliveryType.delivery;

    return Row(
      children: [
        Expanded(
          child: Text(
            order.orderNumber,
            style: const TextStyle(
              fontSize: KdsTextScale.orderNumber,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BldSpacing.sm,
            vertical: BldSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: Color(
              isDelivery ? KdsColors.badgeDelivery : KdsColors.badgePickup,
            ),
            borderRadius: BorderRadius.circular(BldRadius.sm),
          ),
          child: Text(
            order.deliveryBadge,
            style: const TextStyle(
              fontSize: KdsTextScale.statusBar,
              fontWeight: FontWeight.bold,
              color: Color(BldColors.neutral900),
            ),
          ),
        ),
      ],
    );
  }
}

class _RequestedAt extends StatelessWidget {
  const _RequestedAt({required this.order});

  final KitchenOrder order;

  @override
  Widget build(BuildContext context) {
    final late = isRequestedTimeLate(order, DateTime.now().toUtc());

    return Text(
      '${AppL10n.of(context).requestedAtPrefix}: '
      '${TurkishTime.shortDateTime(order.requestedAt!)}',
      style: TextStyle(
        fontSize: KdsTextScale.statusBar,
        fontWeight: FontWeight.bold,
        color: Color(late ? BldColors.danger : KdsColors.onSurfaceMuted),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final KitchenOrderItem item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: BldSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${item.quantity}×',
              style: const TextStyle(
                fontSize: KdsTextScale.quantity,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: BldSpacing.sm),
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(fontSize: KdsTextScale.itemName),
              ),
            ),
          ],
        ),
        if (item.options.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: BldSpacing.xl),
            child: Text(
              item.options.join(', '),
              style: const TextStyle(
                fontSize: KdsTextScale.statusBar,
                color: Color(KdsColors.onSurfaceMuted),
              ),
            ),
          ),
        if (item.note != null && item.note!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(
              left: BldSpacing.xl,
              top: BldSpacing.xs,
            ),
            child: _NoteBox(text: item.note!),
          ),
      ],
    ),
  );
}

/// Sipariş notu asla gizlenmez, kırmızı zeminde büyük basılır (`docs/05` §3).
class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(BldSpacing.sm),
    decoration: BoxDecoration(
      color: const Color(KdsColors.noteBackground),
      borderRadius: BorderRadius.circular(BldRadius.sm),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: KdsTextScale.note,
        fontWeight: FontWeight.bold,
        color: Color(KdsColors.noteForeground),
      ),
    ),
  );
}

String _actionLabel(AppL10n l10n, OrderStatus next) => switch (next) {
  OrderStatus.onaylandi => l10n.actionConfirm,
  OrderStatus.hazirlaniyor => l10n.actionStart,
  OrderStatus.hazir => l10n.actionReady,
  OrderStatus.yolda => l10n.actionDispatch,
  OrderStatus.teslimEdildi => l10n.actionDeliver,
  // `nextForward` bu ikisini asla döndürmez; durum adı yine de anlamlıdır.
  OrderStatus.yeni || OrderStatus.iptal => orderStatusLabelsTr[next]!,
};
