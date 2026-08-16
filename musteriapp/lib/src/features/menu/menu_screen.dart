/// Günün menüsü ekranı — gün şeridi, takvim, paket kartı ve tek tek kalemler
/// (B-19).
///
/// **BU EKRAN ARTIK BİR KATALOG DEĞİL.** Eskiden kategori sekmeleri ve arama
/// kutusuyla bütün ürünleri listeliyordu; satış artık yalnızca o günün
/// menüsünden yapılıyor. Kategori de arama da kaldırıldı: aranacak bir
/// katalog yok, bir günde satılan şey bir avuç kalem.
///
/// Kararı yine **sunucu** veriyor ve bu ekran onu yansıtıyor: hangi gün
/// satılabilir (`DailyMenu.is_orderable`), neden satılamıyor
/// (`unavailable_reason`), paket satılıyor mu (`package`), kalem tükendi mi
/// (`MenuItem.is_available`). İstemci kesim saati ya da geçmiş gün hesabı
/// YAPMAZ — cihaz saati yanlış olabilir ve bağlayıcı denetim `POST /orders`
/// anındadır.
///
/// Ekrandaki geri sayım bu cümleyi bozmuyor, doğruluyor: sunucunun gönderdiği
/// mutlak anı (`DailyMenu.cutoffAt`) okunur hâle getiren bir SUNUMDUR, kapı
/// değil. Sıfırlandığında ekran kilitlenmez, menü yeniden çekilir ve karar
/// yine `is_orderable`'a bırakılır. Stok da aynı biçimde: rozet ve tavan
/// sunucunun bildirdiği kalan porsiyonu yansıtır, rezervasyonu sunucu yapar.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/catalog_providers.dart';
import '../../router/app_router.dart';
import '../../theme/bld_semantic_colors.dart';
import '../../theme/bld_theme.dart';
import '../../widgets/bld_card.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/menu_photo_grid.dart';
import '../../widgets/money_text.dart';
import '../../widgets/network_food_image.dart';
import '../../widgets/order_cutoff_countdown.dart';
import '../../widgets/pill.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/status_views.dart';
import '../../widgets/stock_pill.dart';
import '../cart/cart_controller.dart';
import '../cart/cart_model.dart';
import 'daily_menu_calendar_sheet.dart';
import 'daily_menu_cart.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Uygulama öne geldiğinde işletme gününü tazeler.
  ///
  /// NEDEN: telefon gece cebinde açık kalıyor. Sabah uygulamaya dönen
  /// müşteri, şeridin başında hâlâ dünü "Bugün" diye görüyor ve dünün
  /// menüsünü sepete atıyordu; hata ancak `POST /orders` `past` dediğinde
  /// ortaya çıkıyordu. Tazeleme tek yerde ([BusinessTodayNotifier.refresh]),
  /// gün gerçekten dönmediyse hiçbir şey yeniden çizilmiyor.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(businessTodayProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locationAsync = ref.watch(locationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dailyMenuTitle),
        actions: [
          IconButton(
            // İkon-yalnız düğme etiketsiz olmaz (marka kılavuzu).
            tooltip: l10n.dailyMenuCalendarOpen,
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: locationAsync.hasValue
                ? () => showDailyMenuCalendarSheet(context)
                : null,
          ),
        ],
      ),
      body: locationAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(locationProvider),
        ),
        data: (snapshot) => _DailyMenuBody(location: snapshot.location),
      ),
    );
  }
}

class _DailyMenuBody extends ConsumerWidget {
  const _DailyMenuBody({required this.location});

  final Location location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(selectedServiceDateProvider);
    final menuAsync = ref.watch(dailyMenuProvider(selected));

    return Column(
      children: [
        if (!location.acceptsOrders)
          _OrderingPausedBanner(
            // SEBEP SUNUCUDAN GELİYORSA ONU GÖSTER (K-11). "Şu anda sipariş
            // alamıyoruz" tek başına müşteriyi tekrar tekrar denemeye itiyor;
            // "fırın arızalandı" beklemeyi bilinçli kılıyor.
            message: location.orderingPauseReason ?? l10n.menuOrderingClosed,
          ),
        const DayStrip(),
        Expanded(
          child: menuAsync.when(
            loading: () => const _DayContentSkeleton(),
            error: (error, _) => ErrorView(
              error: error,
              onRetry: () => ref.invalidate(dailyMenuProvider(selected)),
            ),
            data: (snapshot) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(dailyMenuProvider(selected));
                final range = ref.read(menuCalendarRangeProvider);
                if (range != null) ref.invalidate(menuCalendarProvider(range));
              },
              child: _DayContent(
                snapshot: snapshot,
                location: location,
                minOrderTotal: location.minOrderTotal,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderingPausedBanner extends StatelessWidget {
  const _OrderingPausedBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final bld = context.bld;

    return Container(
      width: double.infinity,
      color: bld.warningBg,
      padding: const EdgeInsets.all(BldSpacing.md),
      child: Row(
        children: [
          Icon(Icons.pause_circle_outline, size: 18, color: bld.warningFg),
          const SizedBox(width: BldSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: bld.warningFg, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gün şeridi ──────────────────────────────────────────────────────────────

/// Yatay gün seçici.
///
/// **Hangi gün dokunulabilir:** menüsü OLAN her gün. Sipariş kapısı ayrı ve
/// aşağıda — `is_orderable` yanlış olan güne de bakılabilmeli. Aksi hâlde
/// kesim saatinden sonra BUGÜN de kapanır ve uygulama akşam saatlerinde
/// müşteriye bomboş açılırdı; oysa "bugün ne pişti" sorusu akşam da soruluyor.
class DayStrip extends ConsumerStatefulWidget {
  const DayStrip({super.key});

  /// Bir gün kutusunun genişliği + araları. Kaydırma konumu buradan
  /// hesaplanıyor, ölçülerek değil: kutular sabit genişlikte.
  static const double _chipWidth = 68;
  static const double _chipGap = BldSpacing.sm;

  @override
  ConsumerState<DayStrip> createState() => _DayStripState();
}

class _DayStripState extends ConsumerState<DayStrip> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Seçili günü görünür alana getirir.
  ///
  /// Takvimden 40 gün sonrası seçildiğinde şerit başta kalıyordu ve müşteri
  /// hangi günü seçtiğini şeritte GÖREMİYORDU — seçim yapılmamış gibi
  /// duruyordu.
  void _revealSelected(int index) {
    if (!_controller.hasClients) return;
    final target = index * (DayStrip._chipWidth + DayStrip._chipGap);
    final max = _controller.position.maxScrollExtent;
    _controller.animateTo(
      target.clamp(0, max).toDouble(),
      duration: bldDuration(BldMotion.baseMs),
      curve: bldCurve(BldEase.emphasized),
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(menuCalendarRangeProvider);
    if (range == null) return const SizedBox(height: 92);

    final today = ref.watch(businessTodayProvider);
    final selected = ref.watch(selectedServiceDateProvider);
    final calendar = ref.watch(menuCalendarProvider(range)).valueOrNull;
    final byDate = <String, MenuCalendarDay>{
      for (final day in calendar ?? const <MenuCalendarDay>[]) day.date: day,
    };

    final span = BusinessDate.daysBetween(range.from, range.to) ?? 0;
    final dates = [
      for (var offset = 0; offset <= span; offset++)
        BusinessDate.addDays(today, offset),
    ];

    final selectedIndex = dates.indexOf(selected);
    if (selectedIndex >= 0) {
      // Çizimden sonra: kaydırma konumu ancak liste yerleştikten sonra
      // hesaplanabiliyor.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _revealSelected(selectedIndex);
      });
    }

    return SizedBox(
      height: 92,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: BldSpacing.md,
          vertical: BldSpacing.sm,
        ),
        itemCount: dates.length,
        separatorBuilder: (_, _) => const SizedBox(width: DayStrip._chipGap),
        itemBuilder: (context, index) {
          final date = dates[index];
          return _DayChip(
            date: date,
            offsetFromToday: index,
            day: byDate[date],
            // Takvim henüz gelmediyse hiçbir gün kilitlenmez: bilinmeyen bir
            // durumu "kapalı" diye çizmek, var olan menüyü gizlemek olurdu.
            calendarLoaded: calendar != null,
            selected: date == selected,
            onTap: () =>
                ref.read(selectedServiceDateProvider.notifier).select(date),
          );
        },
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.offsetFromToday,
    required this.day,
    required this.calendarLoaded,
    required this.selected,
    required this.onTap,
  });

  final String date;
  final int offsetFromToday;
  final MenuCalendarDay? day;
  final bool calendarLoaded;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bld = context.bld;

    final closed = day?.closed ?? false;
    final browsable = !calendarLoaded || (day?.isBrowsable ?? false) || closed;

    final (Color background, Color foreground, BorderSide? border) = selected
        ? (theme.colorScheme.primary, theme.colorScheme.onPrimary, null)
        : browsable
        ? (
            theme.colorScheme.surface,
            theme.colorScheme.onSurface,
            BorderSide(color: bld.decorativeBorder),
          )
        : (
            bld.canvas,
            bld.placeholder,
            BorderSide(color: bld.decorativeBorder),
          );

    final parsed = BusinessDate.tryParse(date);
    final title = switch (offsetFromToday) {
      0 => l10n.dayToday,
      1 => l10n.dayTomorrow,
      _ => parsed == null ? '' : _weekdayShort(parsed.weekday, l10n),
    };

    // Durum ekran okuyucuya YAZIYLA da gidiyor: kutunun altındaki 6 px işaret
    // yalnız renkle konuşuyor ve renk tek başına bilgi taşımaz.
    final soldOut = day?.soldOut ?? false;
    final state = closed
        ? l10n.dailyMenuLegendClosed
        : soldOut
        ? l10n.stockSoldOut
        : null;

    return Semantics(
      button: true,
      selected: selected,
      enabled: browsable,
      label: [
        BusinessDate.long(date),
        BusinessDate.weekday(date),
        ?state,
      ].join(' '),
      child: SizedBox(
        width: DayStrip._chipWidth,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(BldRadius.md),
          child: InkWell(
            onTap: browsable ? onTap : null,
            borderRadius: BorderRadius.circular(BldRadius.md),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(BldRadius.md),
                border: border == null ? null : Border.fromBorderSide(border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExcludeSemantics(
                    child: Text(
                      title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  ExcludeSemantics(
                    child: Text(
                      '${parsed?.day ?? ''}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: foreground,
                        fontFeatures: kBldTabularFigures,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _DayMark(
                    closed: closed,
                    soldOut: soldOut,
                    hasMenu: day?.hasMenu ?? false,
                    selected: selected,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gün kutusunun altındaki 6 px işaret.
///
/// Renk TEK BAŞINA bilgi taşımıyor: kapalı gün ayrıca takvim sayfasında adıyla
/// ve nedeniyle yazılı, menüsüz gün ise soluk çiziliyor ve dokunulamıyor,
/// tükenmiş gün ise hem ekran okuyucuya yazıyla bildiriliyor
/// ([_DayChip]) hem de açıldığında sebebiyle birlikte anlatılıyor.
class _DayMark extends StatelessWidget {
  const _DayMark({
    required this.closed,
    required this.soldOut,
    required this.hasMenu,
    required this.selected,
  });

  final bool closed;

  /// O günün stoku bitti (`MenuCalendarDay.soldOut`). Gün yine GEZİLEBİLİR;
  /// müşteri menüyü okuyabilmeli, yalnız sipariş verememeli.
  final bool soldOut;

  final bool hasMenu;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bld = context.bld;

    // Sıra ÖNEMLİ: kapalı gün tükenmişi yener — kapalıysa zaten pişmiyor ve
    // "tükendi" demek yarın gelmeyi vaat ederdi.
    final Color? color = closed
        ? bld.warningFg
        : soldOut
        // Menü var ama satış kapandı: marka rengi "buradan alınır" diyor,
        // tükenmiş günde ise alınmıyor. Nötr yer tutucu tonu, hem "menü yok"
        // boşluğundan hem de açık günün marka renginden ayrılıyor.
        ? bld.placeholder
        : hasMenu
        ? (selected ? theme.colorScheme.onPrimary : theme.colorScheme.primary)
        : null;

    return SizedBox(
      height: 6,
      width: 6,
      child: color == null
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
    );
  }
}

String _weekdayShort(int weekday, AppLocalizations l10n) => switch (weekday) {
  DateTime.monday => l10n.dayMon,
  DateTime.tuesday => l10n.dayTue,
  DateTime.wednesday => l10n.dayWed,
  DateTime.thursday => l10n.dayThu,
  DateTime.friday => l10n.dayFri,
  DateTime.saturday => l10n.daySat,
  _ => l10n.daySun,
};

// ── Seçili günün içeriği ────────────────────────────────────────────────────

class _DayContent extends ConsumerWidget {
  const _DayContent({
    required this.snapshot,
    required this.location,
    required this.minOrderTotal,
  });

  final DailyMenuSnapshot snapshot;
  final Location location;
  final int minOrderTotal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final menu = snapshot.menu;

    // `AlwaysScrollableScrollPhysics`: aşağı çekip yenileme, içerik ekranı
    // doldurmadığında da çalışmalı — menüsüz bir gün tam olarak o durum.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: BldSpacing.xl),
      children: [
        if (snapshot.fromCache)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BldSpacing.md,
              BldSpacing.sm,
              BldSpacing.md,
              0,
            ),
            child: OfflineBanner(message: l10n.dailyMenuOffline),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BldSpacing.md,
            BldSpacing.md,
            BldSpacing.md,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${BusinessDate.long(menu.date)} · ${BusinessDate.weekday(menu.date)}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              // GÜN toplamının kalanı; kalem rozetleri ayrıca her satırda.
              // Tavan konmamışsa rozet hiç çizilmiyor.
              StockPill(remaining: menu.remainingPortions),
            ],
          ),
        ),
        // Geri sayım YALNIZ hâlâ sipariş alınan günde: kapanmış bir günün
        // altında "son 0 dakika" yazmak, kapanmayı bir kez daha ve yanlış
        // sözcüklerle anlatmak olurdu — sebep zaten aşağıdaki kutuda.
        if (menu.isOrderable && menu.cutoffAt != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BldSpacing.md,
              BldSpacing.xs,
              BldSpacing.md,
              0,
            ),
            child: OrderCutoffCountdown(
              cutoffAt: menu.cutoffAt!,
              // Süre dolduğunda KARAR istemcide verilmiyor: menü ve takvim
              // yeniden çekiliyor, `is_orderable` ne derse o oluyor.
              onExpired: () {
                ref.invalidate(dailyMenuProvider(menu.date));
                final range = ref.read(menuCalendarRangeProvider);
                if (range != null) ref.invalidate(menuCalendarProvider(range));
              },
            ),
          ),
        if (menu.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: BldSpacing.xl),
            child: EmptyView(
              icon: menu.closed
                  ? Icons.event_busy_outlined
                  : Icons.restaurant_menu_outlined,
              title: menu.closed
                  ? l10n.dailyMenuClosedTitle
                  : l10n.dailyMenuMissingTitle,
              message: menu.closed
                  ? l10n.dailyMenuClosedBody
                  : l10n.dailyMenuMissingBody,
            ),
          )
        else ...[
          if (menu.title != null && menu.title!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BldSpacing.md,
                BldSpacing.xs,
                BldSpacing.md,
                0,
              ),
              child: Text(menu.title!, style: theme.textTheme.headlineSmall),
            ),
          if (!menu.isOrderable)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BldSpacing.md,
                BldSpacing.md,
                BldSpacing.md,
                0,
              ),
              child: _NoticeBox(
                icon: Icons.info_outline,
                message: _unavailableMessage(menu, l10n),
              ),
            ),
          if (menu.sellsPackage)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BldSpacing.md,
                BldSpacing.md,
                BldSpacing.md,
                0,
              ),
              child: _PackageCard(menu: menu, location: location),
            ),
          if (menu.items.isNotEmpty) ...[
            SectionHeader(title: l10n.dailyMenuItemsSection),
            for (final item in menu.items)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  BldSpacing.md,
                  0,
                  BldSpacing.md,
                  BldSpacing.sm,
                ),
                child: DailyMenuItemTile(
                  item: item,
                  date: menu.date,
                  enabled: menu.isOrderable,
                  dayRemaining: menu.remainingPortions,
                ),
              ),
          ],
          if (minOrderTotal > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BldSpacing.md,
                BldSpacing.md,
                BldSpacing.md,
                0,
              ),
              child: Text(
                l10n.menuMinOrderTotal(Money.format(minOrderTotal)),
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }
}

/// Sipariş edilemeyen günün gerekçesi.
///
/// Metin `bld_api_client`'taki `dailyMenuUnavailableLabelsTr` haritasından
/// geliyor, ekranda kurulmuyor: aynı durumu üç yüzeyin (menü, sepet, ödeme)
/// üç ayrı cümleyle anlatmasını engellemek için sözleşme modeliyle birlikte
/// tanımlandı ve `contract_test` her sebebin karşılığının yazıldığını
/// doğruluyor. Kapalı günde takvimin notu (`MenuCalendarDay.note`) daha iyi
/// bir cümle kurabilir; o zaman ekran bunu kullanmak zorunda değil.
String _unavailableMessage(DailyMenu menu, AppLocalizations l10n) =>
    dailyMenuUnavailableLabelsTr[menu.unavailableReason] ??
    l10n.dailyMenuNotOrderable;

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final bld = context.bld;

    return Container(
      padding: const EdgeInsets.all(BldSpacing.md - 4),
      decoration: BoxDecoration(
        color: bld.warningBg,
        borderRadius: BorderRadius.circular(BldRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: bld.warningFg),
          const SizedBox(width: BldSpacing.sm),
          Expanded(
            child: Text(message, style: TextStyle(color: bld.warningFg)),
          ),
        ],
      ),
    );
  }
}

// ── Paket kartı ─────────────────────────────────────────────────────────────

class _PackageCard extends ConsumerWidget {
  const _PackageCard({required this.menu, required this.location});

  final DailyMenu menu;
  final Location location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final package = menu.package!;
    final saving = menu.packageSavingKurus;
    final itemsTotal = menu.itemsTotal;

    // Paketin bağlı olduğu kalan: gün toplamı ile paketin kendi tavanından
    // hangisi darsa o. Rozet bunu gösteriyor, sepete kaç tane girebileceği
    // ise ayrı bir soru ([room]) — biri stok, öbürü sepet durumu.
    final remaining = effectiveRemaining(
      dayRemaining: menu.remainingPortions,
      itemRemaining: package.remainingPortions,
    );
    final soldOut =
        stockLevel(remaining: remaining, lowThreshold: 0) == StockLevel.soldOut;

    final cart = ref.watch(cartProvider);
    final room = maxAddable(
      dayRemaining: menu.remainingPortions,
      itemRemaining: package.remainingPortions,
      alreadyInCartForDay: cart.quantityOn(menu.date),
      alreadyInCartForItem: cart.quantityOfItemOn(menu.date, package.menuId),
      hardMax: kMaxCartLineQuantity,
    );

    // Devre dışı düğme HER ZAMAN bir sebep metniyle birlikte (marka kılavuzu).
    //
    // Sıra ÖNEMLİ ve en dıştaki engel önce söyleniyor: o güne hiç sipariş
    // alınmıyorken "tükendi" demek, müşteriyi yarın tekrar denemeye
    // gönderirdi. Stok iki ayrı cümleyle anlatılıyor — yemek gerçekten bitti
    // mi, yoksa kalanın tamamı zaten müşterinin sepetinde mi? İkisini aynı
    // metne sıkıştırmak, sepetini boşaltıp yeniden deneyen bir müşteri
    // üretirdi.
    final String? blocker = !menu.isOrderable
        ? _unavailableMessage(menu, l10n)
        : !package.isAvailable
        ? (package.soldOutReason ?? l10n.dailyMenuPackageSoldOut)
        : soldOut
        ? l10n.dailyMenuPackageSoldOut
        : room <= 0
        ? l10n.cartStockAllInCart
        : !location.acceptsOrders
        ? (location.orderingPauseReason ?? l10n.menuOrderingClosed)
        : null;

    return BldCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(BldRadius.md),
            ),
            // Kapak varsa tek hücre, yoksa ilk dört kalemin 2×2 ızgarası —
            // seçimi `cardImageUrls` yapıyor (sözleşmenin cümlesi orada).
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
                Wrap(
                  spacing: BldSpacing.sm,
                  runSpacing: BldSpacing.xs,
                  children: [
                    BldPill(
                      label: l10n.dailyMenuPackageBadge,
                      variant: BldPillVariant.brand,
                      icon: Icons.restaurant_outlined,
                    ),
                    // `Wrap` şart: dar telefonda iki rozet yan yana sığmıyor
                    // ve `Row` taşma hatası atardı.
                    StockPill(remaining: remaining),
                  ],
                ),
                const SizedBox(height: BldSpacing.sm),
                Text(package.name, style: theme.textTheme.titleLarge),
                if (menu.description != null &&
                    menu.description!.isNotEmpty) ...[
                  const SizedBox(height: BldSpacing.xs),
                  Text(menu.description!, style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: BldSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MoneyText(package.price, scale: MoneyScale.lg),
                    if (saving != null && itemsTotal != null) ...[
                      const SizedBox(width: BldSpacing.sm),
                      // Üstü çizili ESKİ tutar önce, güncel fiyat ondan
                      // sonra — marka kuralı bunun tersini yasaklıyor;
                      // burada güncel fiyat solda olduğu için üstü çizili
                      // tutar onun SAĞINDA.
                      MoneyText.previous(itemsTotal),
                    ],
                  ],
                ),
                if (saving != null) ...[
                  const SizedBox(height: BldSpacing.sm),
                  BldPill(
                    label: l10n.dailyMenuSaving(Money.format(saving)),
                    variant: BldPillVariant.success,
                  ),
                ],
                if (package.components.isNotEmpty) ...[
                  const SizedBox(height: BldSpacing.md),
                  Text(
                    l10n.dailyMenuPackageIncludes,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: BldSpacing.sm),
                  for (final component in package.components)
                    _ComponentRow(component: component),
                ],
                const SizedBox(height: BldSpacing.md),
                FilledButton.icon(
                  onPressed: blocker == null
                      ? () => _addPackage(context, ref, l10n)
                      : null,
                  icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
                  label: Text(l10n.dailyMenuPackageAdd),
                ),
                if (blocker != null) ...[
                  const SizedBox(height: BldSpacing.sm),
                  Text(
                    blocker,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addPackage(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final item = menu.packageAsMenuItem;
    if (item == null) return;

    final result = ref
        .read(cartProvider.notifier)
        .add(
          item: item,
          locationId: location.id,
          serviceDate: menu.date,
          // Gün toplamı ayrıca veriliyor: `packageAsMenuItem` yalnız paketin
          // kendi tavanını taşıyor ve gün dolmuşken paket sınırsız görünürdü.
          dayRemaining: menu.remainingPortions,
          packageComponents: menu.package!.components,
        );

    showCartAddFeedback(context, result, itemName: item.name, date: menu.date);
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.component});

  final DailyMenuPackageComponent component;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: BldSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(
              Icons.circle_outlined,
              size: 8,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: BldSpacing.sm),
          Expanded(
            child: Text(
              // Bileşenin FİYATI YOK ve gösterilmiyor: paketin parası üst
              // satırda. "0,00 ₺" yazan bir liste, bedavaya çorba verdiğimiz
              // izlenimi bırakıyordu.
              component.quantity > 1
                  ? '${component.quantity} × ${component.name}'
                  : component.name,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tek tek satılan kalemler ────────────────────────────────────────────────

/// Günün menüsündeki tek bir kalem.
///
/// Tükenmiş kalem listeden DÜŞMEZ, soluk gösterilir
/// (`docs/openapi.yaml` `MenuItem.is_available`): müşteri "bugün mercimek
/// çorbası var mıydı" sorusunun cevabını görmeli, kalem sessizce yok
/// olmamalı.
class DailyMenuItemTile extends StatelessWidget {
  const DailyMenuItemTile({
    super.key,
    required this.item,
    required this.date,
    required this.enabled,
    this.dayRemaining,
  });

  final MenuItem item;
  final String date;

  /// Günün kendisi sipariş edilebilir mi? Kalemin durumundan AYRI: kesim
  /// saati geçmiş bir günün kalemleri satışta görünse de sepete girmemeli.
  final bool enabled;

  /// O günün TOPLAM kalan porsiyonu (`DailyMenu.remainingPortions`).
  ///
  /// Rozette kalemin kendi tavanıyla birlikte değerlendiriliyor: gün
  /// toplamından 2 kalmışken bu yemekten 40 olduğunu duyurmak, müşteriye
  /// alamayacağı bir adedi vaat etmek olurdu. **`null` sınırsız.**
  final int? dayRemaining;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bld = context.bld;
    final available = item.isAvailable && enabled;

    return Opacity(
      opacity: available ? 1 : 0.5,
      child: BldCard(
        padding: const EdgeInsets.all(BldSpacing.sm + 2),
        onTap: available
            ? () => context.push(Routes.dailyMenuItem(date, item.id))
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NetworkFoodImage(
              url: item.imageUrl,
              width: 56,
              height: 56,
              radius: BldRadius.md,
            ),
            const SizedBox(width: BldSpacing.md - 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: theme.textTheme.titleMedium),
                  if (item.description != null &&
                      item.description!.isNotEmpty) ...[
                    const SizedBox(height: BldSpacing.xs),
                    Text(
                      item.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: BldSpacing.sm),
                  Wrap(
                    spacing: BldSpacing.sm,
                    runSpacing: BldSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      MoneyText(item.price, scale: MoneyScale.sm),
                      // Satışta olmayan kalemde stok rozeti YOK: "satışta
                      // değil" ile "son 2 porsiyon" aynı satırda birbirini
                      // yalanlar. Satıştaysa kalan konuşur.
                      if (!item.isAvailable)
                        BldPill(
                          label: item.soldOutToday
                              ? l10n.productSoldOutToday
                              : l10n.menuItemUnavailable,
                        )
                      else
                        StockPill(
                          remaining: effectiveRemaining(
                            dayRemaining: dayRemaining,
                            itemRemaining: item.remainingPortions,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (available)
              Padding(
                padding: const EdgeInsets.only(top: BldSpacing.xs),
                child: Icon(
                  Icons.chevron_right_outlined,
                  color: bld.decorativeBorder,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Günün içeriğinin iskeleti — gerçek düzenin kutu sayısını yansıtır:
/// 16:9 paket görseli + başlık + fiyat, ardından üç kalem satırı.
///
/// **`SingleChildScrollView` ZORUNLU, süs değil.** İskelet gerçek düzeni
/// yansıttığı için gerçek düzen kadar uzun: telefon yüksekliğinde (844 px)
/// gün şeridi ve sepet çubuğu düştükten sonra kalan alana 31 px sığmıyor ve
/// düz bir `Column` "RenderFlex overflowed" atıyordu. Hata yalnızca gün
/// değiştirilirken, yani yükleme anında görünüyor — kaçırılması çok kolay bir
/// kırmızı şerit. Kaydırılabilir kap, taşan kısmı hatasız kırpar; içerik
/// zaten 150 ms sonra yerini alıyor.
class _DayContentSkeleton extends StatelessWidget {
  const _DayContentSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // Kullanıcı iskeleti KAYDIRMAZ: kaydırılacak bir bilgi yok ve kayan
      // bir iskelet, içerik gelince yanlış konumdan başlardı.
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(BldSpacing.md),
      child: Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 140, height: BldTextScale.bodyLineHeight),
            const SizedBox(height: BldSpacing.md),
            const AspectRatio(
              aspectRatio: 16 / 9,
              child: SkeletonBox(
                width: double.infinity,
                height: double.infinity,
                radius: BldRadius.md,
              ),
            ),
            const SizedBox(height: BldSpacing.md),
            const SkeletonBox(width: 200, height: BldTextScale.h3LineHeight),
            const SizedBox(height: BldSpacing.sm),
            const SkeletonBox(width: 96, height: BldTextScale.moneyLgLineHeight),
            const SizedBox(height: BldSpacing.lg),
            const ListRowSkeleton(count: 3),
          ],
        ),
      ),
    );
  }
}
