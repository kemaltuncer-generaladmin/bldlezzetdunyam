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
import '../../theme/bld_semantic_colors.dart';
import '../../widgets/bld_card.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/eta_notice.dart';
import '../../widgets/network_food_image.dart';
import '../../widgets/status_views.dart';
import '../../widgets/stock_pill.dart';
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

    // O günün GÜNCEL menüsü. Sepetteki satırlar kalan porsiyonun eklendiği
    // andaki kopyasını taşıyor; tavan o zamandan beri inmiş olabilir
    // (yönetici düşürdü, abonelikler rezerve etti). Menü henüz gelmediyse ya
    // da çevrimdışıysak `null` ve hiçbir engel konmuyor — bilinmeyen bir
    // durumu "tükendi" saymak, satılabilir bir sepeti kilitlemek olurdu.
    final serviceDate = cart.serviceDate;
    final menu = serviceDate == null
        ? null
        : ref.watch(dailyMenuProvider(serviceDate)).valueOrNull?.menu;
    final stockMessage = (menu != null && cartExceedsStock(cart, menu))
        ? l10n.cartStockExceeded
        : null;

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
                    itemBuilder: (context, index) {
                      final line = cart.lines[index];
                      return _CartLineTile(
                        line: line,
                        dayRemaining: menu?.remainingPortions,
                        itemRemaining: menu == null
                            ? line.item.remainingPortions
                            : dailyMenuSellableFor(
                                menu,
                                line.item.id,
                              )?.remainingPortions,
                      );
                    },
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
                  stockMessage: stockMessage,
                  onCheckout:
                      (belowMinimum ||
                          orderingClosed ||
                          offline ||
                          stockMessage != null ||
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
  const _CartLineTile({
    required this.line,
    required this.dayRemaining,
    required this.itemRemaining,
  });

  final CartLine line;

  /// Günün toplam kalanı; menü bilinmiyorsa `null` (= sınırsız).
  final int? dayRemaining;

  /// Bu ürünün GÜNCEL kalanı; menü bilinmiyorsa satırın kendi kopyası.
  final int? itemRemaining;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final notifier = ref.read(cartProvider.notifier);
    final cart = ref.watch(cartProvider);
    final options = line.optionLabels;

    // Artı düğmesinin açık olması, sepetin o adedi KABUL EDECEĞİ anlamına
    // gelmeli. Sepet satırı kendi kopyasındaki tavana bakıyor, ekran ise
    // menüden gelen güncel tavana; ikisinin DARI alınmazsa tavan yükselmiş
    // bir üründe düğme açık görünür ama dokunuş hiçbir şey yapmaz.
    final room = maxAddable(
      dayRemaining: dayRemaining,
      itemRemaining: effectiveRemaining(
        dayRemaining: itemRemaining,
        itemRemaining: line.item.remainingPortions,
      ),
      alreadyInCartForDay: cart.itemCount,
      alreadyInCartForItem: cart.quantityOfItem(line.item.id),
      hardMax: kMaxCartLineQuantity,
    );

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
                  color: Theme.of(context).colorScheme.secondary,
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
                onIncrement: room > 0
                    ? () => notifier.increment(
                        line.signature,
                        dayRemaining: dayRemaining,
                      )
                    : null,
              ),
              const SizedBox(width: BldSpacing.sm),
              // Kalan porsiyon SATIRIN yanında: sepette adedi artıran
              // müşterinin sınırı öğrenmek için menüye geri dönmesi gerekmiyor.
              Flexible(
                child: StockPill(
                  remaining: effectiveRemaining(
                    dayRemaining: dayRemaining,
                    itemRemaining: itemRemaining,
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => notifier.removeLine(line.signature),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
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

  /// `null` = stok tavanı doldu; artı düğmesi kapanır.
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        // Sessiz yüzey + dekoratif kenarlık: adet seçici kartın üstünde
        // durur, kartla aynı tonda olursa sınırı kaybolur.
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(BldRadius.pill),
        border: Border.all(color: context.bld.decorativeBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(theme, Icons.remove_outlined, onDecrement),
          SizedBox(
            width: 32,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          _btn(theme, Icons.add_outlined, onIncrement),
        ],
      ),
    );
  }

  Widget _btn(ThemeData theme, IconData icon, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(BldSpacing.sm),
          child: Icon(
            icon,
            size: 18,
            // Marka rengi METİN/ikon rolünden (`secondary`) geliyor, dolgu
            // rolünden değil: dolgu koyu temada açılıp kart zemininde
            // kayboluyor.
            color: onTap == null
                ? theme.disabledColor
                : theme.colorScheme.secondary,
          ),
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
    this.stockMessage,
  });

  final Cart cart;
  final EtaWindow? eta;
  final VoidCallback? onCheckout;
  final String? belowMinimumMessage;
  final String? closedMessage;
  final String? offlineMessage;

  /// Sepetin günüyle ilgili engel (`cartDayProblem`).
  final String? dayMessage;

  /// Sepetin kalan porsiyonu aştığı uyarısı (`cartExceedsStock`).
  final String? stockMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final eta = this.eta;
    // Sıra ÖNEMLİ: günü geçmiş bir sepette "en az tutar" uyarısı yazmak,
    // müşteriyi hiçbir işe yaramayacak bir kalem eklemeye yönlendirirdi.
    final blockers = [
      ?dayMessage,
      // Stok günden SONRA, kapalılıktan ÖNCE: günü geçmiş bir sepette kalan
      // porsiyondan söz etmek anlamsız, ama vitrin kapalıyken bile müşteri
      // adedini düzeltebilir ve düzeltmesi gerektiğini bilmelidir.
      ?stockMessage,
      ?closedMessage,
      ?offlineMessage,
      ?belowMinimumMessage,
    ];

    return Container(
      decoration: BoxDecoration(
        // Sabit alt çubuk YÜKSELTİLMİŞ yüzeydir: koyu temada yükseltmeyi
        // gölge değil açıklık adımı taşır (bkz. `BldSemanticColors`).
        color: context.bld.surfaceRaised,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.08),
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
