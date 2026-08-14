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
import '../../widgets/bld_card.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/eta_notice.dart';
import '../../widgets/network_food_image.dart';
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
    final today = ref.watch(businessTodayProvider);

    final minOrderTotal = location?.minOrderTotal ?? 0;
    final missing = minOrderTotal - cart.subtotal;
    final belowMinimum = cart.isNotEmpty && missing > 0;
    final orderingClosed = location != null && !location.acceptsOrders;

    final dayProblem = cartDayProblem(cart, today: today);
    final dayMessage = switch (dayProblem) {
      null => null,
      CartDayProblem.missing => l10n.cartDayMissing,
      CartDayProblem.past => l10n.cartDayPast(
        BusinessDate.long(cart.serviceDate ?? ''),
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cartTitle),
        actions: [
          if (cart.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(cartProvider.notifier).clear(),
              child: Text(l10n.cartClear),
            ),
        ],
      ),
      body: cart.isEmpty
          ? EmptyView(
              icon: Icons.shopping_basket_outlined,
              title: l10n.cartEmpty,
              actionLabel: l10n.cartGoToMenu,
              onAction: () => context.go(Routes.menu),
            )
          : Column(
              children: [
                if (offline) OfflineBanner(message: l10n.offlineOrderBlocked),
                if (cart.serviceDate != null && dayProblem == null)
                  _ServiceDayHeader(serviceDate: cart.serviceDate!),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(BldSpacing.md),
                    itemCount: cart.lines.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: BldSpacing.md - 4),
                    itemBuilder: (context, index) =>
                        _CartLineTile(line: cart.lines[index]),
                  ),
                ),
                _CartSummary(
                  cart: cart,
                  // Teslimat tipi ödeme ekranında seçiliyor; sepette adrese
                  // gönderim tahmini gösterilir, orada seçime göre güncellenir.
                  // İLERİ TARİHLİ sepette hiç gösterilmiyor: "yaklaşık 75
                  // dakika" cuma menüsü için anlamsız.
                  eta: cart.serviceDate == today
                      ? location?.etaFor(DeliveryType.delivery)
                      : null,
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
                  dayMessage: dayMessage,
                  onCheckout:
                      (belowMinimum ||
                          orderingClosed ||
                          offline ||
                          dayProblem != null)
                      ? null
                      : () => context.push(Routes.checkout),
                ),
              ],
            ),
    );
  }
}

/// Sepetin bağlı olduğu servis günü.
///
/// Sepet listesinin ÜSTÜNDE, kalemlerin dışında: gün kalemlerin bir özelliği
/// değil, sepetin tamamının özelliği. Satır başına yazsaydık dört kalemde
/// dört kez aynı tarihi okutur ve yine de "hepsi aynı gün mü" sorusunu
/// cevaplamazdık.
class _ServiceDayHeader extends StatelessWidget {
  const _ServiceDayHeader({required this.serviceDate});

  final String serviceDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: BldSpacing.md,
        vertical: BldSpacing.sm + 2,
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_outlined,
            size: 18,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: BldSpacing.sm),
          Expanded(
            child: Text(
              l10n.cartServiceDate(BusinessDate.long(serviceDate)),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
    final textTheme = Theme.of(context).textTheme;
    final notifier = ref.read(cartProvider.notifier);
    final options = line.optionLabels;

    return BldCard(
      padding: const EdgeInsets.all(BldSpacing.sm + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (line.item.imageUrl != null) ...[
                NetworkFoodImage(
                  url: line.item.imageUrl,
                  width: 56,
                  height: 56,
                  radius: BldRadius.md,
                ),
                const SizedBox(width: BldSpacing.md - 4),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.item.name, style: textTheme.titleMedium),
                    if (options.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(options.join(', '), style: textTheme.bodySmall),
                    ],
                    if (line.note != null && line.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        line.note!,
                        style: textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    // Paketin İÇİ, paket satırının altında ve FİYATSIZ.
                    // Fiyatı paket satırı taşıyor; bileşenlere "0,00 ₺"
                    // yazmak bedavaya yemek verdiğimiz izlenimi bırakıyor.
                    if (line.isPackage) ...[
                      const SizedBox(height: BldSpacing.xs),
                      for (final component in line.packageComponents)
                        Text(
                          component.quantity > 1
                              ? '· ${component.quantity} × ${component.name}'
                              : '· ${component.name}',
                          style: textTheme.bodySmall,
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: BldSpacing.sm),
              Text(
                Money.format(line.lineTotal),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: bldColor(BldColors.brand700),
                  fontSize: BldTextScale.body,
                ),
              ),
            ],
          ),
          const SizedBox(height: BldSpacing.sm),
          Row(
            children: [
              _MiniStepper(
                quantity: line.quantity,
                onDecrement: () => notifier.decrement(line.signature),
                onIncrement: () => notifier.increment(line.signature),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => notifier.removeLine(line.signature),
                style: TextButton.styleFrom(
                  foregroundColor: bldColor(BldColors.neutral600),
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(l10n.cartRemove),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kompakt adet seçici — sepet satırında.
class _MiniStepper extends StatelessWidget {
  const _MiniStepper({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bldColor(BldColors.neutral50),
        borderRadius: BorderRadius.circular(BldRadius.pill),
        border: Border.all(color: bldColor(BldColors.neutral200)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove_outlined, onDecrement),
          SizedBox(
            width: 32,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          _btn(Icons.add_outlined, onIncrement),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(BldSpacing.sm),
          child: Icon(icon, size: 18, color: bldColor(BldColors.brand700)),
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
    this.dayMessage,
  });

  final Cart cart;
  final EtaWindow? eta;
  final VoidCallback? onCheckout;
  final String? belowMinimumMessage;
  final String? closedMessage;
  final String? offlineMessage;

  /// Sepetin günüyle ilgili engel (`cartDayProblem`).
  final String? dayMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final eta = this.eta;
    // Sıra ÖNEMLİ: günü geçmiş bir sepette "en az tutar" uyarısı yazmak,
    // müşteriyi hiçbir işe yaramayacak bir kalem eklemeye yönlendirirdi.
    final blockers = [
      ?dayMessage,
      ?closedMessage,
      ?offlineMessage,
      ?belowMinimumMessage,
    ];

    return Container(
      decoration: BoxDecoration(
        color: bldColor(BldColors.neutral0),
        boxShadow: [
          BoxShadow(
            color: bldColor(BldColors.neutral900).withValues(alpha: 0.08),
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
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
                const SizedBox(height: BldSpacing.md),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${l10n.cartSubtotal} · ${l10n.cartItemCount(cart.lineCount)}',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    Money.format(cart.subtotal),
                    style: textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: BldSpacing.xs),
              Text(l10n.cartServerCalculatesTotal, style: textTheme.bodySmall),
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
