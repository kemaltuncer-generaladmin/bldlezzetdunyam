/// Ana sayfa — keşif ekranı.
///
/// NEDEN VAR: uygulama doğrudan düz bir ürün listesiyle açılıyordu. Liste
/// doğruydu ama uygulamayı ilk açan kullanıcıya ne yapabileceğini
/// anlatmıyordu: teslimat ne kadar sürüyor, hangi kategoriler var, dün ne
/// sipariş ettim. Bu ekran o soruları kaydırmadan cevaplıyor.
///
/// Menü ekranı KALDIRILMADI: burası vitrin, sipariş hâlâ menüde veriliyor.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_error_text.dart';
import '../../core/eta_text.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/account_providers.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/infra_providers.dart';
import '../../providers/order_providers.dart';
import '../../providers/session_provider.dart';
import '../../providers/subscription_providers.dart';
import '../../router/app_router.dart';
import '../../theme/bld_theme.dart';
import '../../widgets/bld_card.dart';
import '../../widgets/network_food_image.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/status_views.dart';
import '../cart/cart_controller.dart';
import 'reorder.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locationAsync = ref.watch(locationProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: locationAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(locationProvider),
        ),
        data: (snapshot) => _Body(location: snapshot.location),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.location});

  final Location location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final menuAsync = ref.watch(menuProvider(location.id));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(menuProvider(location.id));
        ref.invalidate(ordersProvider);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: BldSpacing.xl),
        children: [
          const SizedBox(height: BldSpacing.md),
          _Hero(location: location),
          const _CorporateShortcuts(),
          const _LastOrderCard(),
          menuAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: BldSpacing.lg),
              child: _FeaturedSkeleton(),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(BldSpacing.md),
              child: ErrorView(
                error: error,
                onRetry: () => ref.invalidate(menuProvider(location.id)),
              ),
            ),
            data: (snapshot) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: l10n.homeCategories,
                  actionLabel: l10n.homeSeeAll,
                  onAction: () => context.go(Routes.menu),
                ),
                _CategoryStrip(categories: snapshot.categories),
                SectionHeader(title: l10n.homeFeatured),
                _FeaturedStrip(categories: snapshot.categories),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Marka bandı — yuvarlatılmış gradyan kart.
///
/// Teslim süresi ve karşılama burada; iki bilgi de sipariş kararını etkiler
/// ve menüye inmeden görünmeli. Tam ekran yerine kenar boşluklu, gölgeli bir
/// kart daha premium durur.
class _Hero extends StatelessWidget {
  const _Hero({required this.location});

  final Location location;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final deliveryType = location.etaFor(DeliveryType.delivery) != null
        ? DeliveryType.delivery
        : DeliveryType.pickup;
    final eta = location.etaFor(deliveryType);
    final etaText = eta == null
        ? null
        : etaBeforeOrder(eta, deliveryType, l10n, now: DateTime.now().toUtc());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BldSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(BldSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BldRadius.lg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              bldColor(BldColors.brand600),
              bldColor(BldColors.brand500),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: bldColor(BldColors.brand500).withValues(alpha: 0.28),
              offset: const Offset(0, 8),
              blurRadius: 20,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -8,
              bottom: -18,
              child: Icon(
                Icons.restaurant,
                size: 104,
                color: bldColor(BldColors.neutral0).withValues(alpha: 0.14),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeGreeting,
                  style: textTheme.headlineSmall?.copyWith(
                    color: bldColor(BldColors.neutral0),
                  ),
                ),
                if (etaText != null) ...[
                  const SizedBox(height: BldSpacing.md),
                  _HeroChip(
                    icon: Icons.schedule,
                    label: '${etaText.title}: ${etaText.value}',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BldSpacing.md - 4,
        vertical: BldSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bldColor(BldColors.neutral0).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(BldRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: bldColor(BldColors.neutral0)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: bldColor(BldColors.neutral0),
              fontSize: BldTextScale.caption + 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kurumsal kısayollar — aktif abonelik + cari bakiye.
///
/// Yalnız giriş yapmış kullanıcıya çıkar (B2B). İki kartlık şerit: soldan
/// aboneliğe, sağdan cari ekstreye gider. Bakiye/adet sunucudan gelir;
/// istemci hesaplamaz.
class _CorporateShortcuts extends ConsumerWidget {
  const _CorporateShortcuts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(
      sessionProvider.select((s) => s.valueOrNull?.isSignedIn ?? false),
    );
    if (!signedIn) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BldSpacing.md,
        BldSpacing.md,
        BldSpacing.md,
        0,
      ),
      // IntrinsicHeight: iki kart eşit yükseklikte olur ve dikey ListView'in
      // sınırsız yüksekliği `stretch`'e sonsuz kısıt vermez.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            Expanded(child: _SubscriptionShortcut()),
            SizedBox(width: BldSpacing.md),
            Expanded(child: _BalanceShortcut()),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionShortcut extends ConsumerWidget {
  const _SubscriptionShortcut();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final subs = ref.watch(subscriptionsProvider).valueOrNull;

    final active = subs == null
        ? null
        : subs.where((s) => s.isActive).firstOrNull ?? subs.firstOrNull;

    return BldCard(
      onTap: () => context.go(
        active != null
            ? Routes.subscriptionDetail(active.id)
            : Routes.subscriptions,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_repeat, color: bldColor(BldColors.brand700)),
          const SizedBox(height: BldSpacing.sm),
          Text(l10n.navSubscriptions, style: textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            active != null
                ? l10n.subscriptionQuantityLabel(active.defaultQuantity)
                : l10n.subscriptionsNew,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _BalanceShortcut extends ConsumerWidget {
  const _BalanceShortcut();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final summary = ref.watch(accountSummaryProvider).valueOrNull;

    return BldCard(
      onTap: () => context.push(Routes.accountStatement),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            color: bldColor(BldColors.brand700),
          ),
          const SizedBox(height: BldSpacing.sm),
          Text(l10n.accountBalanceLabel, style: textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            summary != null ? Money.format(summary.balance.abs()) : '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              color: bldColor(
                summary != null && summary.hasDebt
                    ? BldColors.danger
                    : BldColors.neutral900,
              ),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LastOrderCard extends ConsumerWidget {
  const _LastOrderCard();

  /// Sipariş DETAYI ayrıca çekiliyor.
  ///
  /// Liste ucu yalnızca özet döndürüyor (`OrderSummary`) ve özette kalemler
  /// yok — yalnızca kaç kalem olduğu var. Tekrar sipariş için hangi ürünler
  /// olduğunu bilmek şart, o yüzden dokunulduğunda detay isteniyor.
  Future<void> _reorder(
    BuildContext context,
    WidgetRef ref,
    OrderSummary summary,
    int locationId,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final cart = ref.read(cartProvider.notifier);

    final OrderDetail order;
    final MenuSnapshot menu;
    try {
      order = await ref.read(apiProvider).orders.get(summary.id);
      menu = await ref.read(menuProvider(locationId).future);
    } on ApiException catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(apiErrorDisplayMessage(error, l10n))),
      );
      return;
    }

    final outcome = reorderInto(
      order: order,
      menu: menu.categories,
      addToCart: (item, quantity) =>
          cart.add(item: item, locationId: locationId, quantity: quantity),
    );

    if (!context.mounted) return;

    // Üç ayrı sonuç, üç ayrı mesaj. Hepsini "eklendi" diye özetlemek
    // müşterinin eksik sipariş vermesine yol açardı.
    final message = outcome.isEmpty
        ? l10n.homeReorderEmpty
        : outcome.isPartial
        ? l10n.homeReorderPartial(outcome.added, outcome.missing)
        : l10n.homeReorderDone(outcome.added);

    messenger.showSnackBar(SnackBar(content: Text(message)));
    if (!outcome.isEmpty && context.mounted) context.push(Routes.cart);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final ordersAsync = ref.watch(ordersProvider);
    final locationId = ref.watch(locationProvider).valueOrNull?.location.id;

    final order = ordersAsync.valueOrNull?.data.firstOrNull;
    if (order == null || locationId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BldSpacing.md,
        BldSpacing.md,
        BldSpacing.md,
        0,
      ),
      child: BldCard(
        onTap: () => context.push(Routes.orderTracking(order.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: bldColor(BldColors.brand50),
                    borderRadius: BorderRadius.circular(BldRadius.md),
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    size: 22,
                    color: bldColor(BldColors.brand700),
                  ),
                ),
                const SizedBox(width: BldSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.homeLastOrder, style: textTheme.bodySmall),
                      const SizedBox(height: 2),
                      Text(
                        '${order.orderNumber} · ${Money.format(order.total)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: BldSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reorder(context, ref, order, locationId),
                    icon: const Icon(Icons.replay, size: 18),
                    label: Text(l10n.homeReorder),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.categories});

  final List<MenuCategory> categories;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BldSpacing.md),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: BldSpacing.sm),
        itemBuilder: (context, index) => ActionChip(
          label: Text(categories[index].name),
          onPressed: () => context.go(Routes.menu),
        ),
      ),
    );
  }
}

/// Görseli olan ve satışta olan ürünler — premium yatay şerit.
///
/// Görselsiz ürün ALINMAZ: fotoğraf şeridinde gri kutu menüyü eksik gösterir.
/// Görselsiz ürünler menü ekranında zaten listeleniyor.
class _FeaturedStrip extends StatelessWidget {
  const _FeaturedStrip({required this.categories});

  final List<MenuCategory> categories;

  static const int _max = 8;

  @override
  Widget build(BuildContext context) {
    final items = <MenuItem>[
      for (final category in categories)
        for (final item in category.items)
          if (item.isAvailable && item.imageUrl != null) item,
    ];

    if (items.isEmpty) return const SizedBox.shrink();
    final shown = items.take(_max).toList();

    return SizedBox(
      height: 232,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BldSpacing.md),
        itemCount: shown.length,
        separatorBuilder: (_, _) => const SizedBox(width: BldSpacing.md),
        itemBuilder: (context, index) => _FeaturedCard(item: shown[index]),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: 168,
      child: BldCard(
        padding: const EdgeInsets.all(BldSpacing.sm),
        onTap: () => context.push(Routes.productDetail(item.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NetworkFoodImage(
              url: item.imageUrl,
              height: 120,
              width: double.infinity,
              radius: BldRadius.md,
            ),
            const SizedBox(height: BldSpacing.sm),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall,
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  Money.format(item.price),
                  style: textTheme.titleMedium?.copyWith(
                    color: bldColor(BldColors.brand700),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: bldColor(BldColors.brand500),
                    borderRadius: BorderRadius.circular(BldRadius.sm),
                  ),
                  child: Icon(
                    Icons.add,
                    size: 18,
                    color: bldColor(BldColors.neutral0),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedSkeleton extends StatelessWidget {
  const _FeaturedSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 232,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BldSpacing.md),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: BldSpacing.md),
        itemBuilder: (_, _) =>
            const SizedBox(width: 168, child: MenuCardSkeleton()),
      ),
    );
  }
}
