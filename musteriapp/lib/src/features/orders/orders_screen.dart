/// Siparişlerim — geçmiş liste (`docs/07-musteriapp.md` §2).
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/labels.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/order_providers.dart';
import '../../router/app_router.dart';
import '../../theme/bld_theme.dart';
import '../../widgets/bld_card.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/pill.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/status_views.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ordersTitle)),
      body: ordersAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(BldSpacing.md),
          child: ListRowSkeleton(),
        ),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(ordersProvider),
        ),
        data: (page) {
          if (page.data.isEmpty) {
            return EmptyView(
              icon: Icons.receipt_long_outlined,
              title: l10n.ordersEmpty,
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(ordersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(BldSpacing.md),
              itemCount: page.data.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: BldSpacing.md - 4),
              itemBuilder: (context, index) =>
                  _OrderTile(order: page.data[index]),
            ),
          );
        },
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return BldCard(
      onTap: () => context.push(Routes.orderTracking(order.id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.orderNumberLabel(order.orderNumber),
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: BldSpacing.xs),
                Text(
                  '${TurkishTime.longDateTime(order.createdAt)}'
                  '  ·  ${l10n.cartItemCount(order.itemCount)}',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: BldSpacing.sm),
                OrderStatusBadge(status: order.status),
              ],
            ),
          ),
          const SizedBox(width: BldSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Money.format(order.total),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: BldTextScale.body,
                  color: bldColor(BldColors.brand700),
                ),
              ),
              const SizedBox(height: BldSpacing.lg),
              Icon(
                Icons.chevron_right,
                color: bldColor(BldColors.neutral400),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Durum rozeti. Renk/varyant eşlemesi tek yerdedir; takip ekranı da kullanır.
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});

  final OrderStatus status;

  /// Katı zemin rengi (adım çubuğu gibi düz dolgu gereken yerler için korunur).
  static int backgroundFor(OrderStatus status) => switch (status) {
    OrderStatus.yeni => BldColors.info,
    OrderStatus.onaylandi => BldColors.info,
    OrderStatus.hazirlaniyor => BldColors.warning,
    OrderStatus.hazir => BldColors.success,
    OrderStatus.yolda => BldColors.brand500,
    OrderStatus.teslimEdildi => BldColors.neutral600,
    OrderStatus.iptal => BldColors.danger,
  };

  static BldPillVariant variantFor(OrderStatus status) => switch (status) {
    OrderStatus.yeni => BldPillVariant.info,
    OrderStatus.onaylandi => BldPillVariant.info,
    OrderStatus.hazirlaniyor => BldPillVariant.warning,
    OrderStatus.hazir => BldPillVariant.success,
    OrderStatus.yolda => BldPillVariant.brand,
    OrderStatus.teslimEdildi => BldPillVariant.neutral,
    OrderStatus.iptal => BldPillVariant.danger,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BldPill(
      label: orderStatusLabel(status, l10n),
      variant: variantFor(status),
    );
  }
}
