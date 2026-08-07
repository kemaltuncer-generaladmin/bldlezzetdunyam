/// "Bugün abonelik var" bildirim şeridi.
///
/// Abonelik siparişleri panoda normal kartlar olarak da görünür (her birinde
/// ABONE rozeti), ama mutfak günün başında "bugün kaç abonelik var, kimler"
/// sorusunun cevabını tek bakışta istiyor. Bu şerit onu üstte toplar;
/// dokununca bugünün abonelik siparişlerinin dökümü açılır.
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
    final subscriptions = ref
        .watch(activeOrdersProvider)
        .where((o) => o.isSubscription)
        .toList();

    if (subscriptions.isEmpty) return const SizedBox.shrink();

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
          onTap: () => _showDetail(context, subscriptions),
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
                    l10n.subscriptionBannerCount(subscriptions.length),
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
    List<KitchenOrder> orders,
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
          width: 560,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: orders.length,
            separatorBuilder: (_, _) => const Divider(
              height: BldSpacing.md,
              color: Color(KdsColors.surfaceRaised),
            ),
            itemBuilder: (context, index) => _DetailRow(order: orders[index]),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.order});

  final KitchenOrder order;

  @override
  Widget build(BuildContext context) {
    final items = order.items
        .map((i) => '${i.quantity}× ${i.name}')
        .join(', ');
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
            _Pill(
              text: order.deliveryBadge,
              color: Color(
                order.deliveryType == DeliveryType.delivery
                    ? KdsColors.badgeDelivery
                    : KdsColors.badgePickup,
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

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: BldSpacing.sm,
      vertical: BldSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(BldRadius.sm),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: KdsTextScale.statusBar,
        fontWeight: FontWeight.bold,
        color: KdsAccents.onAccent(color),
      ),
    ),
  );
}
