/// Sepet ekranı — kalemler, adet düzenleme, tutar özeti
/// (`docs/07-musteriapp.md` §2).
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/eta_text.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/infra_providers.dart';
import '../../router/app_router.dart';
import '../../theme/bld_theme.dart';
import '../../widgets/eta_notice.dart';
import '../../widgets/status_views.dart';
import 'cart_controller.dart';
import 'cart_model.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cart = ref.watch(cartProvider);
    final offline = ref.watch(connectivityProvider);
    final location = ref.watch(locationProvider).valueOrNull?.location;

    final minOrderTotal = location?.minOrderTotal ?? 0;
    final missing = minOrderTotal - cart.subtotal;
    final belowMinimum = cart.isNotEmpty && missing > 0;
    final orderingClosed = location != null && !location.acceptsOrders;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cartTitle),
        actions: [
          if (cart.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(cartProvider.notifier).clear(),
              child: Text(
                l10n.cartClear,
                style: TextStyle(color: bldColor(BldColors.neutral0)),
              ),
            ),
        ],
      ),
      body: cart.isEmpty
          ? _EmptyCart()
          : Column(
              children: [
                if (offline) OfflineBanner(message: l10n.offlineOrderBlocked),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(BldSpacing.md),
                    itemCount: cart.lines.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: BldSpacing.sm),
                    itemBuilder: (context, index) =>
                        _CartLineTile(line: cart.lines[index]),
                  ),
                ),
                _CartSummary(
                  cart: cart,
                  // Teslimat tipi ödeme ekranında seçiliyor; sepette adrese
                  // gönderim tahmini gösterilir, orada seçime göre güncellenir.
                  eta: location?.etaFor(DeliveryType.delivery),
                  belowMinimumMessage: belowMinimum
                      ? l10n.cartMinOrderNotMet(
                          Money.format(minOrderTotal),
                          Money.format(missing),
                        )
                      : null,
                  closedMessage: orderingClosed
                      ? l10n.checkoutOrderingClosed
                      : null,
                  offlineMessage: offline ? l10n.offlineOrderBlocked : null,
                  onCheckout: (belowMinimum || orderingClosed || offline)
                      ? null
                      : () => context.push(Routes.checkout),
                ),
              ],
            ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BldSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_basket_outlined,
              size: 48,
              color: bldColor(BldColors.neutral400),
            ),
            const SizedBox(height: BldSpacing.md),
            Text(l10n.cartEmpty),
            const SizedBox(height: BldSpacing.lg),
            OutlinedButton(
              onPressed: () => context.go(Routes.menu),
              child: Text(l10n.cartGoToMenu),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartLineTile extends ConsumerWidget {
  const _CartLineTile({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(cartProvider.notifier);
    final options = line.optionLabels;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(BldSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    line.item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  Money.format(line.lineTotal),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: bldColor(BldColors.brand700),
                  ),
                ),
              ],
            ),
            if (options.isNotEmpty)
              Text(
                options.join(', '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (line.note != null)
              Text(
                line.note!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            const SizedBox(height: BldSpacing.sm),
            Row(
              children: [
                IconButton.outlined(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => notifier.decrement(line.signature),
                  icon: const Icon(Icons.remove, size: 18),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BldSpacing.md,
                  ),
                  child: Text('${line.quantity}'),
                ),
                IconButton.outlined(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => notifier.increment(line.signature),
                  icon: const Icon(Icons.add, size: 18),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => notifier.removeLine(line.signature),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(l10n.cartRemove),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  const _CartSummary({
    required this.cart,
    required this.onCheckout,
    this.eta,
    this.belowMinimumMessage,
    this.closedMessage,
    this.offlineMessage,
  });

  final Cart cart;
  final EtaWindow? eta;
  final VoidCallback? onCheckout;
  final String? belowMinimumMessage;
  final String? closedMessage;
  final String? offlineMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final eta = this.eta;
    final blockers = [?closedMessage, ?offlineMessage, ?belowMinimumMessage];

    return Material(
      elevation: 8,
      color: bldColor(BldColors.neutral0),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(BldSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tahmin, siparişi tamamlama düğmesinden **önce** gelir:
              // kullanıcı ne zaman geleceğini onaydan sonra değil, önce görmeli.
              if (eta != null) ...[
                EtaNotice(
                  eta: etaBeforeOrder(
                    eta,
                    DeliveryType.delivery,
                    l10n,
                    now: DateTime.now().toUtc(),
                  ),
                ),
                const SizedBox(height: BldSpacing.sm),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${l10n.cartSubtotal} · ${l10n.cartItemCount(cart.lineCount)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    Money.format(cart.subtotal),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: BldSpacing.xs),
              Text(
                l10n.cartServerCalculatesTotal,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              for (final blocker in blockers) ...[
                const SizedBox(height: BldSpacing.sm),
                FormErrorBox(message: blocker),
              ],
              const SizedBox(height: BldSpacing.md),
              FilledButton(
                onPressed: onCheckout,
                child: Text(l10n.cartCheckout),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
