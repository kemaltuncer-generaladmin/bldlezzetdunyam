/// Ana sayfa — keşif ekranı.
///
/// NEDEN VAR: uygulama doğrudan düz bir ürün listesiyle açılıyordu. Liste
/// doğruydu ama uygulamayı ilk açan kullanıcıya ne yapabileceğini
/// anlatmıyordu: teslimat ne kadar sürüyor, hangi kategoriler var, dün ne
/// sipariş ettim. Bu ekran o üç soruyu kaydırmadan cevaplıyor.
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
import '../../providers/catalog_providers.dart';
import '../../providers/infra_providers.dart';
import '../../providers/order_providers.dart';
import '../../router/app_router.dart';
import '../../theme/bld_theme.dart';
import '../../widgets/eta_notice.dart';
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
        padding: const EdgeInsets.only(bottom: BldSpacing.lg),
        children: [
          _Hero(location: location),

          // Son sipariş kartı yalnızca sipariş VARSA görünür. Boş bir
          // "henüz sipariş yok" kutusu, ilk kez açan kullanıcıya ekranı
          // daha da boş gösterirdi.
          const _LastOrderCard(),

          menuAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(BldSpacing.lg),
              child: LoadingView(),
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
                _SectionHeader(
                  title: l10n.homeCategories,
                  actionLabel: l10n.homeSeeAll,
                  onAction: () => context.go(Routes.menu),
                ),
                _CategoryStrip(categories: snapshot.categories),
                _SectionHeader(title: l10n.homeFeatured),
                _FeaturedStrip(categories: snapshot.categories),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Marka bandı: teslim süresi ve asgari tutar burada.
///
/// Bu iki sayı sipariş kararını doğrudan etkiliyor ve menüye inmeden
/// görünmeli.
class _Hero extends StatelessWidget {
  const _Hero({required this.location});

  final Location location;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deliveryType = location.etaFor(DeliveryType.delivery) != null
        ? DeliveryType.delivery
        : DeliveryType.pickup;
    final eta = location.etaFor(deliveryType);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        BldSpacing.md,
        BldSpacing.lg,
        BldSpacing.md,
        BldSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bldColor(BldColors.brand600),
            bldColor(BldColors.brand500),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homeGreeting,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: bldColor(BldColors.neutral0),
            ),
          ),
          const SizedBox(height: BldSpacing.sm),
          // Teslim süresi yalnızca sunucu güvenilir bir tahmin verdiğinde
          // gösteriliyor; uydurma bir süre yazmaktansa hiç yazmamak doğru.
          if (eta != null)
            EtaNotice(
              compact: true,
              eta: etaBeforeOrder(
                eta,
                deliveryType,
                l10n,
                now: DateTime.now().toUtc(),
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
  /// olduğunu bilmek şart, o yüzden dokunulduğunda detay isteniyor. Listeyi
  /// baştan detayla doldurmak, hiç tekrar sipariş vermeyecek kullanıcılar
  /// için de her açılışta N istek demekti.
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
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(BldSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.homeLastOrder,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: BldSpacing.xs),
              // Özet kalem ADLARINI taşımıyor; sipariş numarası ve tutar
              // kullanıcının siparişi tanıması için yeterli.
              Text(
                '${order.orderNumber} · ${Money.format(order.total)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: BldSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _reorder(context, ref, order, locationId),
                      icon: const Icon(Icons.replay, size: 18),
                      label: Text(l10n.homeReorder),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BldSpacing.md,
        BldSpacing.lg,
        BldSpacing.sm,
        BldSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
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
      height: 44,
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

/// Görseli olan ve satışta olan ürünler.
///
/// Görselsiz ürün ALINMAZ: fotoğraf şeridinde gri kutu, ürünü öne çıkarmak
/// bir yana, menüyü eksik gösterir. Görselsiz ürünler menü ekranında zaten
/// listeleniyor.
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
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BldSpacing.md),
        itemCount: shown.length,
        separatorBuilder: (_, _) => const SizedBox(width: BldSpacing.sm),
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
    return SizedBox(
      width: 156,
      child: InkWell(
        borderRadius: BorderRadius.circular(BldRadius.md),
        onTap: () => context.push(Routes.productDetail(item.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(BldRadius.md),
              child: Image.network(
                item.imageUrl!,
                width: 156,
                height: 116,
                fit: BoxFit.cover,
                // Görsel gelmezse kart çökmemeli: ürünün adı ve fiyatı
                // hâlâ işe yarıyor.
                errorBuilder: (_, _, _) => Container(
                  width: 156,
                  height: 116,
                  color: bldColor(BldColors.neutral100),
                  child: Icon(
                    Icons.restaurant,
                    color: bldColor(BldColors.neutral400),
                  ),
                ),
              ),
            ),
            const SizedBox(height: BldSpacing.xs),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              Money.format(item.price),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: bldColor(BldColors.brand700),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
