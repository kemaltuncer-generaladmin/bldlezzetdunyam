/// Menü ekranı — kategori sekmeleri, ürün listesi, arama
/// (`docs/07-musteriapp.md` §2).
///
/// Hangi menünün gösterileceğine ve sipariş alınıp alınmadığına **sunucu**
/// karar verir (§3); bu ekran `is_open`, `ordering_enabled` ve `is_available`
/// alanlarını yalnızca yansıtır.
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
import '../../router/app_router.dart';
import '../../theme/bld_theme.dart';
import '../../widgets/eta_notice.dart';
import '../../widgets/status_views.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locationAsync = ref.watch(locationProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.menuTitle)),
      body: locationAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(locationProvider),
        ),
        data: (snapshot) => _MenuBody(
          location: snapshot.location,
          searchController: _search,
          query: _query,
          onQueryChanged: (value) => setState(() => _query = value),
        ),
      ),
    );
  }
}

class _MenuBody extends ConsumerWidget {
  const _MenuBody({
    required this.location,
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
  });

  final Location location;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final menuAsync = ref.watch(menuProvider(location.id));

    return Column(
      children: [
        _LocationHeader(location: location),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BldSpacing.md,
            BldSpacing.sm,
            BldSpacing.md,
            BldSpacing.sm,
          ),
          child: TextField(
            controller: searchController,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.menuSearchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        onQueryChanged('');
                      },
                    ),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: menuAsync.when(
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              error: error,
              onRetry: () => ref.invalidate(menuProvider(location.id)),
            ),
            data: (snapshot) => query.trim().isEmpty
                ? _CategoryTabs(location: location, snapshot: snapshot)
                : _SearchResults(
                    location: location,
                    snapshot: snapshot,
                    query: query,
                  ),
          ),
        ),
      ],
    );
  }
}

/// Vitrin bilgisi: sipariş alınıyor mu, teslim süresi, kesim saati, en az tutar.
class _LocationHeader extends StatelessWidget {
  const _LocationHeader({required this.location});

  final Location location;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Menüde teslimat tipi henüz seçilmedi; yaygın olan adrese gönderim
    // gösterilir. Yalnızca gel-al tahmini varsa ona düşülür — başlık da
    // onunla değişir, yoksa yol süresi içermeyen bir süreyi "teslim" diye
    // sunmuş olurduk.
    final deliveryType = location.etaFor(DeliveryType.delivery) != null
        ? DeliveryType.delivery
        : DeliveryType.pickup;
    final eta = location.etaFor(deliveryType);

    final notes = <String>[
      if (location.orderCutoff != null) l10n.menuCutoff(location.orderCutoff!),
      if (location.minOrderTotal > 0)
        l10n.menuMinOrderTotal(Money.format(location.minOrderTotal)),
    ];

    return Column(
      children: [
        if (!location.acceptsOrders)
          Container(
            width: double.infinity,
            color: bldColor(BldColors.brand100),
            padding: const EdgeInsets.all(BldSpacing.md),
            child: Text(
              l10n.menuOrderingClosed,
              style: TextStyle(
                color: bldColor(BldColors.brand900),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (eta != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BldSpacing.md,
              BldSpacing.md,
              BldSpacing.md,
              0,
            ),
            child: EtaNotice(
              compact: true,
              eta: etaBeforeOrder(
                eta,
                deliveryType,
                l10n,
                now: DateTime.now().toUtc(),
              ),
            ),
          ),
        if (notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BldSpacing.md,
              BldSpacing.sm,
              BldSpacing.md,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    notes.join('  ·  '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.location, required this.snapshot});

  final Location location;
  final MenuSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = snapshot.categories;

    if (categories.isEmpty) {
      return Center(child: Text(l10n.menuEmpty));
    }

    return DefaultTabController(
      length: categories.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: bldColor(BldColors.brand700),
            unselectedLabelColor: bldColor(BldColors.neutral600),
            indicatorColor: bldColor(BldColors.brand500),
            tabs: [for (final c in categories) Tab(text: c.name)],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final category in categories)
                  _ItemList(location: location, items: category.items),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.location,
    required this.snapshot,
    required this.query,
  });

  final Location location;
  final MenuSnapshot snapshot;
  final String query;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final needle = query.trim().toLowerCase();
    final matches = snapshot.allItems
        .where((item) {
          final haystack = '${item.name} ${item.description ?? ''}'
              .toLowerCase();
          return haystack.contains(needle);
        })
        .toList(growable: false);

    if (matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(BldSpacing.lg),
          child: Text(l10n.menuSearchEmpty, textAlign: TextAlign.center),
        ),
      );
    }
    return _ItemList(location: location, items: matches);
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({required this.location, required this.items});

  final Location location;
  final List<MenuItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (items.isEmpty) {
      return Center(child: Text(l10n.menuEmpty));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(BldSpacing.md),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: BldSpacing.sm),
      itemBuilder: (context, index) =>
          MenuItemTile(item: items[index], location: location),
    );
  }
}

/// Ürün satırı. Satışta olmayan ürün listede **kalır**, soluk gösterilir
/// (`docs/openapi.yaml` `MenuItem.is_available`).
class MenuItemTile extends StatelessWidget {
  const MenuItemTile({super.key, required this.item, required this.location});

  final MenuItem item;
  final Location location;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final available = item.isAvailable;

    return Opacity(
      opacity: available ? 1 : 0.45,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(BldRadius.md),
          onTap: available
              ? () => context.push(Routes.productDetail(item.id))
              : null,
          child: Padding(
            padding: const EdgeInsets.all(BldSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Görsel API'den geliyor (`MenuItem.image_url`), panelden
                // yönetiliyor. Ürünün görseli yoksa satır görselsiz çizilir —
                // yer tutucu kutu, listeyi hiçbir şey anlatmayan gri
                // dikdörtgenlerle doldururdu.
                if (item.imageUrl != null) ...[
                  _MenuItemThumb(url: item.imageUrl!),
                  const SizedBox(width: BldSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (item.description != null &&
                          item.description!.isNotEmpty) ...[
                        const SizedBox(height: BldSpacing.xs),
                        Text(
                          item.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: BldSpacing.sm),
                      Row(
                        children: [
                          Text(
                            Money.format(item.price),
                            style: TextStyle(
                              color: bldColor(BldColors.brand700),
                              fontWeight: FontWeight.w700,
                              fontSize: BldTextScale.body,
                            ),
                          ),
                          if (!available) ...[
                            const SizedBox(width: BldSpacing.sm),
                            BldBadge(
                              label: l10n.menuItemUnavailable,
                              background: BldColors.neutral600,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (available)
                  Icon(
                    Icons.chevron_right,
                    color: bldColor(BldColors.neutral400),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Liste satırındaki küçük ürün görseli.
///
/// Kare: satırın yüksekliğini metin belirliyor ve 16:9 bir görsel satırı
/// gereksiz uzatıyordu. Yüklenemezse hiç yer kaplamaz.
class _MenuItemThumb extends StatelessWidget {
  const _MenuItemThumb({required this.url});

  final String url;

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(BldRadius.sm),
      child: Image.network(
        url,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Sepet dolu olduğunda menünün altında duran çubuk.
