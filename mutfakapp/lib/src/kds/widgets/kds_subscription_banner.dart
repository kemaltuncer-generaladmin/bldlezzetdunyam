/// "Bugün abonelik var" bildirim şeridi + bugün/yarın dökümü.
///
/// Ana pano yalnız bugünü gösterir; abonelik yemekleri önceden hazırlandığı
/// için mutfak yarını da görmek ister (`/kitchen/subscription-orders`). Şerit
/// bugün+yarının abonelik sipariş sayısını üstte toplar; dokununca gün gün
/// döküm açılır: hazırlanacak TOPLAM adetler (yemek kuyruğunu buna göre kurar)
/// ve tek tek siparişler.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/kds_theme.dart';

class KdsSubscriptionBanner extends ConsumerWidget {
  const KdsSubscriptionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final data = ref.watch(subscriptionOrdersProvider).value;
    if (data == null) return const SizedBox.shrink();

    final today = data.today;
    final tomorrow = data.tomorrow;
    if (today.isEmpty && tomorrow.isEmpty) return const SizedBox.shrink();

    const background = Color(BldColors.brand500);
    final foreground = KdsAccents.onAccent(background);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BldSpacing.md,
        0,
        BldSpacing.md,
        BldSpacing.sm,
      ),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(BldRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(BldRadius.sm),
          onTap: () => _showDetail(context, today, tomorrow),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BldSpacing.md,
              vertical: BldSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(Icons.event_repeat, size: 32, color: foreground),
                const SizedBox(width: BldSpacing.md),
                Text(
                  l10n.subscriptionBannerTitle,
                  style: TextStyle(
                    fontSize: KdsTextScale.columnHeader,
                    fontWeight: FontWeight.bold,
                    color: foreground,
                  ),
                ),
                const SizedBox(width: BldSpacing.md),
                Expanded(
                  child: Text(
                    l10n.subscriptionBannerBreakdown(
                      today.length,
                      tomorrow.length,
                    ),
                    style: TextStyle(
                      fontSize: KdsTextScale.statusBar,
                      color: foreground,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 28, color: foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDetail(
    BuildContext context,
    List<KitchenOrder> today,
    List<KitchenOrder> tomorrow,
  ) {
    final l10n = AppL10n.of(context);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(KdsColors.surface),
        title: Text(
          l10n.subscriptionDialogTitle,
          style: const TextStyle(
            fontSize: KdsTextScale.columnHeader,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _DaySection(title: l10n.subscriptionDayToday, orders: today),
                const SizedBox(height: BldSpacing.lg),
                _DaySection(
                  title: l10n.subscriptionDayTomorrow,
                  orders: tomorrow,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              l10n.subscriptionDialogClose,
              style: const TextStyle(fontSize: KdsTextScale.statusBar),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek gün: başlık + hazırlanacak toplamlar + tek tek siparişler.
class _DaySection extends StatelessWidget {
  const _DaySection({required this.title, required this.orders});

  final String title;
  final List<KitchenOrder> orders;

  /// Ürün adı → toplam adet (yemek kuyruğu buna göre kurulur).
  Map<String, int> get _totals {
    final totals = <String, int>{};
    for (final order in orders) {
      for (final item in order.items) {
        totals[item.name] = (totals[item.name] ?? 0) + item.quantity;
      }
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: KdsTextScale.columnHeader,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: BldSpacing.sm),
            Text(
              l10n.subscriptionOrderCount(orders.length),
              style: const TextStyle(
                fontSize: KdsTextScale.statusBar,
                color: Color(KdsColors.onSurfaceMuted),
              ),
            ),
          ],
        ),
        if (orders.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: BldSpacing.xs),
            child: Text(
              '—',
              style: TextStyle(
                fontSize: KdsTextScale.statusBar,
                color: Color(KdsColors.onSurfaceMuted),
              ),
            ),
          )
        else ...[
          const SizedBox(height: BldSpacing.sm),
          // Hazırlanacak toplamlar — asıl işe yarayan bilgi.
          Text(
            l10n.subscriptionTotalsLabel,
            style: const TextStyle(
              fontSize: KdsTextScale.statusBar,
              fontWeight: FontWeight.bold,
              color: Color(BldColors.brand400),
            ),
          ),
          const SizedBox(height: BldSpacing.xs),
          Wrap(
            spacing: BldSpacing.sm,
            runSpacing: BldSpacing.sm,
            children: [
              for (final entry in _totals.entries)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BldSpacing.sm,
                    vertical: BldSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(KdsColors.surfaceRaised),
                    borderRadius: BorderRadius.circular(BldRadius.sm),
                  ),
                  child: Text(
                    '${entry.value}× ${entry.key}',
                    style: const TextStyle(
                      fontSize: KdsTextScale.statusBar,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: BldSpacing.sm),
            child: Divider(height: 1, color: Color(KdsColors.surfaceRaised)),
          ),
          // Tek tek siparişler.
          for (final order in orders)
            Padding(
              padding: const EdgeInsets.only(bottom: BldSpacing.sm),
              child: _OrderRow(order: order),
            ),
        ],
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final KitchenOrder order;

  @override
  Widget build(BuildContext context) {
    final items = order.items.map((i) => '${i.quantity}× ${i.name}').join(', ');
    final badgeColor = Color(
      order.deliveryType == DeliveryType.delivery
          ? KdsColors.badgeDelivery
          : KdsColors.badgePickup,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                order.orderNumber,
                style: const TextStyle(
                  fontSize: KdsTextScale.statusBar,
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
                color: badgeColor,
                borderRadius: BorderRadius.circular(BldRadius.sm),
              ),
              child: Text(
                order.deliveryBadge,
                style: TextStyle(
                  fontSize: KdsTextScale.statusBar,
                  fontWeight: FontWeight.bold,
                  color: KdsAccents.onAccent(badgeColor),
                ),
              ),
            ),
          ],
        ),
        if (order.customerLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: BldSpacing.xs),
            child: Text(
              order.customerLabel!,
              style: const TextStyle(
                fontSize: KdsTextScale.statusBar,
                color: Color(KdsColors.onSurfaceMuted),
              ),
            ),
          ),
        const SizedBox(height: BldSpacing.xs),
        Text(items, style: const TextStyle(fontSize: KdsTextScale.statusBar)),
      ],
    );
  }
}
