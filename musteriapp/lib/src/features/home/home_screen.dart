/// Ana sayfa — keşif ekranı.
///
/// NEDEN VAR: uygulama doğrudan düz bir ürün listesiyle açılıyordu. Liste
/// doğruydu ama uygulamayı ilk açan kullanıcıya ne yapabileceğini
/// anlatmıyordu: teslimat ne kadar sürüyor, bugün ne pişti, dün ne sipariş
/// ettim. Bu ekran o soruları kaydırmadan cevaplıyor.
///
/// **KATEGORİ VE ÖNE ÇIKANLAR ŞERİTLERİ KALDIRILDI (B-19).** İkisi de genel
/// ürün kataloğundan besleniyordu; katalog artık müşteri yüzeyinde yok. Yerini
/// BUGÜNÜN MENÜSÜ aldı — satılan tek şey o. Menü sekmesi duruyor: burası
/// vitrin, gün seçimi ve sipariş orada.
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
import '../../providers/announcement_providers.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/infra_providers.dart';
import '../../providers/order_providers.dart';
import '../../providers/session_provider.dart';
import '../../providers/subscription_providers.dart';
import '../../router/app_router.dart';
import '../../theme/bld_semantic_colors.dart';
import '../../theme/bld_theme.dart';
import '../../widgets/announcement_banner.dart';
import '../../widgets/bld_card.dart';
import '../../widgets/menu_photo_grid.dart';
import '../../widgets/money_text.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/status_views.dart';
import '../../widgets/stock_pill.dart';
import '../cart/cart_controller.dart';
import '../menu/daily_menu_cart.dart';
import 'reorder.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locationAsync = ref.watch(locationProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      // Bant listenin İÇİNDE değil ÜSTÜNDE: bakım ve kapanış duyuruları
      // vitrin yüklenemediğinde de görünmeli — hata ekranıyla karşılaşan
      // müşteriye sebebi söyleyen tek yüzey bu. Listenin ilk elemanı olsaydı
      // hem vitrin hatasında kaybolur hem de aşağı kaydırınca ekrandan
      // çıkardı.
      body: Column(
        children: [
          const AnnouncementBanner(),
          Expanded(
            child: locationAsync.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(locationProvider),
              ),
              data: (snapshot) => _Body(location: snapshot.location),
            ),
          ),
        ],
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
    final today = ref.watch(businessTodayProvider);
    final menuAsync = ref.watch(dailyMenuProvider(today));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dailyMenuProvider(today));
        ref.invalidate(ordersProvider);
        // Duyurunun tazelenmesinin tek yolu bu: push yok, duyuru ancak
        // sorulunca geliyor ve aşağı çekme kullanıcının "yenile" dediği an.
        ref.invalidate(announcementsProvider(AnnouncementPlacement.home));
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: BldSpacing.xl),
        children: [
          const SizedBox(height: BldSpacing.md),
          _Hero(location: location),
          const _SubscriptionShortcut(),
          const _LastOrderCard(),
          SectionHeader(
            title: l10n.homeTodaysMenu,
            actionLabel: l10n.homeSeeAll,
            onAction: () => context.go(Routes.menu),
          ),
          menuAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(horizontal: BldSpacing.md),
              child: MenuCardSkeleton(),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(BldSpacing.md),
              child: ErrorView(
                error: error,
                onRetry: () => ref.invalidate(dailyMenuProvider(today)),
              ),
            ),
            data: (snapshot) =>
                _TodaysMenuCard(menu: snapshot.menu, location: location),
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
          // KARŞILAMA ŞERİDİ TEMADAN BAĞIMSIZ MARKA YÜZEYİDİR — bilerek.
          //
          // Gradyan iki temada da brand600→brand500 kalır ve üstündeki her şey
          // beyaz çizilir. Buradaki `neutral0`, "tema beyazı" değil "marka
          // turuncusunun üstündeki beyaz"tır: zemin temayla değişmediği için
          // kontrast da değişmiyor (brand500 üstünde 4,58). Rolleri
          // (`onPrimary`) kullanmak burayı BOZARDI — koyu temada o rol koyu
          // metne dönüyor ve turuncu zeminde okunmaz oluyor.
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
                Icons.restaurant_outlined,
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
                    icon: Icons.schedule_outlined,
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

/// Abonelik kısayolu — yalnız giriş yapmış kullanıcıya çıkar (B2B).
///
/// Eskiden yanında CARİ BAKİYE kartı vardı ve ikisi eşit genişlikte bir
/// şeritti. Cari hesap müşteri arayüzünden kaldırıldığında (B-19) yarım kalan
/// şerit yerine tek ve tam genişlikte bir kart bırakıldı: yanında boşluk
/// duran bir kart, silinmiş bir şeyin izini taşır.
class _SubscriptionShortcut extends ConsumerWidget {
  const _SubscriptionShortcut();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final signedIn = ref.watch(
      sessionProvider.select((s) => s.valueOrNull?.isSignedIn ?? false),
    );
    if (!signedIn) return const SizedBox.shrink();

    final subs = ref.watch(subscriptionsProvider).valueOrNull;
    final active = subs == null
        ? null
        : subs.where((s) => s.isActive).firstOrNull ?? subs.firstOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BldSpacing.md,
        BldSpacing.md,
        BldSpacing.md,
        0,
      ),
      child: BldCard(
        onTap: () => context.go(
          active != null
              ? Routes.subscriptionDetail(active.id)
              : Routes.subscriptions,
        ),
        child: Row(
          children: [
            Icon(Icons.event_repeat_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: BldSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.navSubscriptions, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    active != null
                        ? l10n.subscriptionQuantityLabel(active.defaultQuantity)
                        : l10n.subscriptionsNew,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_outlined,
              color: context.bld.decorativeBorder,
            ),
          ],
        ),
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
  ///
  /// Hedef gün her zaman **BUGÜN**: eski siparişin kendi servis günü geçmiş
  /// ve o günün menüsü bir daha satılmıyor. Kalemler bugünün menüsünde
  /// aranıyor, bulunmayanlar sayılıp kullanıcıya söyleniyor.
  Future<void> _reorder(
    BuildContext context,
    WidgetRef ref,
    OrderSummary summary,
    int locationId,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final cart = ref.read(cartProvider.notifier);
    final today = ref.read(businessTodayProvider);

    final OrderDetail order;
    final DailyMenuSnapshot menu;
    try {
      order = await ref.read(apiProvider).orders.get(summary.id);
      menu = await ref.read(dailyMenuProvider(today).future);
    } on ApiException catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(apiErrorDisplayMessage(error, l10n))),
      );
      return;
    }

    // Paket de aday: `packageAsMenuItem` onu ürün karşılığına çeviriyor, ki
    // "geçen hafta menüyü almıştım, aynısını ver" isteği çalışsın.
    final candidates = <MenuItem>[
      ...menu.menu.items,
      if (menu.menu.packageAsMenuItem != null) menu.menu.packageAsMenuItem!,
    ];

    final outcome = reorderInto(
      order: order,
      menuItems: menu.menu.isOrderable ? candidates : const <MenuItem>[],
      addToCart: (item, quantity) {
        final result = cart.add(
          item: item,
          locationId: locationId,
          serviceDate: today,
          quantity: quantity,
          // Gün toplamı olmadan tekrar sipariş, tavanı dolmuş bir güne dünkü
          // siparişin tamamını doldurmayı denerdi.
          dayRemaining: menu.menu.remainingPortions,
          packageComponents: item.id == menu.menu.package?.menuId
              ? menu.menu.package!.components
              : const <DailyMenuPackageComponent>[],
        );
        return result == CartAddResult.added ||
            result == CartAddResult.addedAfterDayChange;
      },
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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
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
                    // Tonal yüzey + etiketi: ikisi tek rol çiftinden gelir,
                    // yoksa koyu temada açık zeminde açık ikon kalırdı.
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(BldRadius.md),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    size: 22,
                    color: colorScheme.onPrimaryContainer,
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
                    icon: const Icon(Icons.replay_outlined, size: 18),
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

/// Bugünün menüsü — ana sayfadaki tek satış yüzeyi.
///
/// Menü ekranının küçültülmüş hâli DEĞİL, ona giden kapı: paket varsa fiyatı
/// ve "sepete ekle" düğmesiyle bir kart, yoksa günün kalemlerinden bir özet.
/// Gün seçimi, takvim ve tek tek kalemler menü sekmesinde — burada tek bir
/// karar var: "bugünkünü alayım mı?"
class _TodaysMenuCard extends ConsumerWidget {
  const _TodaysMenuCard({required this.menu, required this.location});

  final DailyMenu menu;
  final Location location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (menu.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: BldSpacing.md),
        child: BldCard(
          onTap: () => context.go(Routes.menu),
          child: Row(
            children: [
              Icon(
                menu.closed
                    ? Icons.event_busy_outlined
                    : Icons.restaurant_menu_outlined,
                color: context.bld.placeholder,
              ),
              const SizedBox(width: BldSpacing.md),
              Expanded(
                child: Text(
                  menu.closed
                      ? l10n.dailyMenuClosedTitle
                      : l10n.dailyMenuMissingTitle,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final package = menu.package;
    final saving = menu.packageSavingKurus;

    // Gün toplamı ile paketin kendi tavanından dar olanı bağlar; `null`
    // sınırsızdır. Ana sayfadaki düğme de menü ekranındakiyle aynı stoku
    // görmeli, yoksa buradan eklenen sepet orada reddediliyormuş gibi olurdu.
    final remaining = effectiveRemaining(
      dayRemaining: menu.remainingPortions,
      itemRemaining: package?.remainingPortions,
    );
    final band = stockLevel(
      remaining: remaining,
      lowThreshold: kStockLowThreshold,
    );
    final soldOut = band == StockLevel.soldOut;
    // Rozetin çizileceği durumlar; bolluk ve sınırsızlık sessiz olduğu için
    // üstündeki boşluk da onlarla birlikte düşer.
    final showStock = band == StockLevel.low || soldOut;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BldSpacing.md),
      child: BldCard(
        padding: EdgeInsets.zero,
        onTap: () => context.go(Routes.menu),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(BldRadius.md),
              ),
              // Menü sekmesindeki kartla AYNI kural: kapak varsa o, yoksa ilk
              // dört kalemin ızgarası. İki yüzey aynı günü farklı çizerse
              // müşteri iki ayrı menü olduğunu sanıyor.
              child: MenuPhotoGrid(
                imageUrls: menu.cardImageUrls,
                aspectRatio: 16 / 9,
                radius: 0,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(BldSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    menu.title ?? package?.name ?? l10n.dailyMenuTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: BldSpacing.xs),
                  Text(
                    // Kalem ADLARI, sayısı değil: "4 kalem" iştah açmıyor,
                    // "Mercimek çorbası · Etli nohut · Pilav" açıyor.
                    menu.items.map((item) => item.name).join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  if (package != null) ...[
                    const SizedBox(height: BldSpacing.md),
                    Row(
                      children: [
                        MoneyText(package.price, scale: MoneyScale.md),
                        if (saving != null) ...[
                          const SizedBox(width: BldSpacing.sm),
                          Expanded(
                            child: Text(
                              l10n.dailyMenuSaving(Money.format(saving)),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: context.bld.successFg,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (showStock) ...[
                      const SizedBox(height: BldSpacing.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: StockPill(remaining: remaining),
                      ),
                    ],
                    const SizedBox(height: BldSpacing.md),
                    FilledButton.icon(
                      onPressed:
                          menu.isOrderable &&
                              package.isAvailable &&
                              !soldOut &&
                              location.acceptsOrders
                          ? () => _addPackage(context, ref)
                          : null,
                      icon: const Icon(
                        Icons.add_shopping_cart_outlined,
                        size: 18,
                      ),
                      label: Text(l10n.dailyMenuPackageAdd),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addPackage(BuildContext context, WidgetRef ref) {
    final item = menu.packageAsMenuItem;
    if (item == null) return;

    final result = ref
        .read(cartProvider.notifier)
        .add(
          item: item,
          locationId: location.id,
          serviceDate: menu.date,
          dayRemaining: menu.remainingPortions,
          packageComponents: menu.package!.components,
        );

    showCartAddFeedback(context, result, itemName: item.name, date: menu.date);
  }
}
