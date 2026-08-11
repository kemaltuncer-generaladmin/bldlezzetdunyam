/// Panonun tek sütunu: renkli başlık + kart listesi.
///
/// Başlığın renkli olması dekorasyon değil işlev: personel sütunu okuyarak
/// değil, renginden tanır. Kartların sol şeridi aynı rengi taşır, böylece
/// bir kartın hangi sütuna ait olduğu kaydırma sırasında da bellidir.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
// `ScrollCacheExtent` yalnızca buradan dışa açılıyor; `material.dart` onu
// yeniden aktarmıyor.
import 'package:flutter/rendering.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/kds_theme.dart';
import '../board.dart';
import '../order_progress.dart';
import '../urgency.dart';
import 'order_card.dart';

class OrderColumn extends StatefulWidget {
  const OrderColumn({
    required this.column,
    required this.title,
    required this.orders,
    required this.highlightedIds,
    required this.busyIds,
    required this.progress,
    required this.selectedIndex,
    required this.now,
    required this.thresholds,
    required this.onAdvance,
    required this.onToggleItem,
    required this.onReprint,
    this.touchMode = false,
    this.onDetails,
    this.onEdit,
    super.key,
  });

  /// Dokunmatik kip — karta jest ve alt sayfa davranışı ekler (K-10).
  final bool touchMode;

  /// Kartın işlem sayfası (uzun bas / sola kaydır).
  final void Function(KitchenOrder order)? onDetails;

  /// Sipariş düzenleme ekranı (K-14).
  final void Function(KitchenOrder order)? onEdit;

  final KdsColumn column;
  final String title;
  final List<KitchenOrder> orders;
  final Set<int> highlightedIds;

  /// Sunucuya isteği uçan siparişler — düğmeleri kilitli çizilir.
  final Set<int> busyIds;

  final OrderItemProgress progress;

  /// Klavyeyle seçili kartın sırası; bu sütunda seçim yoksa `null`.
  final int? selectedIndex;

  /// Pano saati. Tek bir kaynaktan gelir; her kart kendi saatini okusaydı
  /// aynı ekranda iki farklı "şimdi" olurdu.
  final DateTime now;

  final UrgencyThresholds thresholds;

  final void Function(KitchenOrder order) onAdvance;
  final void Function(KitchenOrder order, int itemIndex) onToggleItem;
  final void Function(KitchenOrder order, ReceiptType type) onReprint;

  @override
  State<OrderColumn> createState() => _OrderColumnState();
}

class _OrderColumnState extends State<OrderColumn> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OrderColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _revealSelection();
    }
  }

  /// Klavyeyle seçilen kartı görünür alana getirir.
  ///
  /// Ekranın dışında kalan bir seçim, `Enter`'ın görünmeyen bir siparişi
  /// ilerletmesi demektir. Kart henüz çizilmemişse (uzağa atlanmışsa) hiçbir
  /// şey yapmayız; listenin önbellek payı komşuların çizili olmasını
  /// sağladığı için tek adımlık hareketler her zaman yakalanır.
  void _revealSelection() {
    final index = widget.selectedIndex;
    if (index == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _cardKey(index).currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.25,
        duration: const Duration(milliseconds: 150),
      ).ignore();
    });
  }

  GlobalObjectKey<State<StatefulWidget>> _cardKey(int index) =>
      GlobalObjectKey<State<StatefulWidget>>('${widget.column.name}-$index');

  /// Bir kartın alacağı en dar genişlik.
  ///
  /// Bunun altında ürün adı ("30× Mercimek Çorbası") ve eylem düğmesi aynı
  /// satıra sığmıyor, kart iki kata çıkıp kazanılan yeri geri veriyor.
  ///
  /// 1920 px'lik ekranda komşusu boşalmış bir sütun ~795 px'e çıkıyor; eşik
  /// 400 olsaydı 1,98 çıkıp aşağı yuvarlanır ve iki kart hiç yan yana
  /// gelmezdi. 360, o sınırın altında pay bırakıyor.
  static const double _minCardWidth = 360;

  /// Bir satırdaki en fazla kart.
  ///
  /// Üçten fazlası 1920 px'de kartları okunmayacak kadar daraltıyor; mutfakta
  /// ekrana bir metreden bakılıyor.
  static const int _maxPerRow = 2;

  Widget _buildCard(List<KitchenOrder> orders, int index) {
    final order = orders[index];
    return KeyedSubtree(
      key: _cardKey(index),
      child: OrderCard(
        key: ValueKey<int>(order.id),
        order: order,
        column: widget.column,
        age: ageOf(order, now: widget.now, thresholds: widget.thresholds),
        thresholds: widget.thresholds,
        highlighted: widget.highlightedIds.contains(order.id),
        selected: widget.selectedIndex == index,
        busy: widget.busyIds.contains(order.id),
        progress: widget.progress,
        onAdvance: () => widget.onAdvance(order),
        onToggleItem: (itemIndex) => widget.onToggleItem(order, itemIndex),
        onReprint: (type) => widget.onReprint(order, type),
        touchMode: widget.touchMode,
        onDetails: widget.onDetails == null
            ? null
            : () => widget.onDetails!(order),
        // Terminal durumdaki siparişte düzenleme yok: sunucu reddediyor
        // ve çizilen düğme yalnız hayal kırıklığı üretir.
        onEdit: widget.onEdit == null || order.status.isTerminal
            ? null
            : () => widget.onEdit!(order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final accent = KdsAccents.column(widget.column);
    final orders = widget.orders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ColumnHeader(
          accent: accent,
          label: l10n.columnHeader(widget.title, orders.length),
          lateCount: lateOrderCount(
            orders,
            now: widget.now,
            thresholds: widget.thresholds,
          ),
        ),
        const SizedBox(height: BldSpacing.sm),
        Expanded(
          child: orders.isEmpty
              ? Center(
                  child: Text(
                    l10n.columnEmpty,
                    style: const TextStyle(
                      fontSize: KdsTextScale.statusBar,
                      color: Color(KdsColors.onSurfaceMuted),
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    /*
                     * SÜTUN GENİŞSE KARTLAR YAN YANA.
                     *
                     * Yoğun saatte gerçek tablo şu: YENİ'de sekiz sipariş
                     * birikiyor, diğer sütunlar boşalıyor. Tek sütunlu
                     * yerleşimde aşçı bunların yalnızca üçünü görüyordu ve
                     * kalanı görmek için kaydırması gerekiyordu — oysa
                     * ekranın üçte ikisi boştu.
                     *
                     * Ölçü sipariş sayısına değil GENİŞLİĞE bakıyor: sütun
                     * ancak komşuları boşaldığı için genişler, yani sıra
                     * yalnızca panonun dengesi değiştiğinde değişir. Sayıya
                     * bağlasaydık her yeni siparişte kartlar yer değiştirir
                     * ve göz her seferinde yeniden arardı.
                     */
                    final perRow =
                        (constraints.maxWidth / _minCardWidth)
                            .floor()
                            .clamp(1, _maxPerRow)
                            // Sütunda kart sayısından fazla sıra açmıyoruz:
                            // tek kalan sipariş yarım genişlikte durup yanında
                            // boşluk bırakmasın, tam genişliğe yayılıp daha
                            // görünür olsun.
                            .clamp(1, orders.length);
                    final rowCount = (orders.length + perRow - 1) ~/ perRow;

                    return ListView.separated(
                      controller: _scroll,
                      // Komşu kartların çizili durması klavye seçimini görünür
                      // kılar; 40 kartlık bir listede yalnızca birkaç kart
                      // fazla çizmek, kaydırmayı takılmaya sokmayacak kadar
                      // ucuzdur.
                      scrollCacheExtent: const ScrollCacheExtent.pixels(1200),
                      padding: const EdgeInsets.only(bottom: BldSpacing.md),
                      itemCount: rowCount,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: BldSpacing.md),
                      itemBuilder: (context, rowIndex) {
                        final first = rowIndex * perRow;
                        final last = (first + perRow).clamp(0, orders.length);

                        return Row(
                          // Kartlar farklı yükseklikte (kalem sayısı ve not
                          // değişiyor); üstten hizalanmazlarsa kısa kart
                          // uzayıp boş yer kaplıyor.
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var index = first; index < last; index++) ...[
                              if (index != first)
                                const SizedBox(width: BldSpacing.md),
                              Expanded(child: _buildCard(orders, index)),
                            ],
                            // Son satır eksik kalırsa kartlar genişleyip
                            // üsttekilerle hizasını kaybediyor; boş paylar
                            // hizayı koruyor.
                            for (var bos = last - first; bos < perRow; bos++)
                              ...[
                                const SizedBox(width: BldSpacing.md),
                                const Expanded(child: SizedBox.shrink()),
                              ],
                          ],
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Sütun başlığı: renkli zemin, ad, kart sayısı ve geciken sayacı.
class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    required this.accent,
    required this.label,
    required this.lateCount,
  });

  final Color accent;
  final String label;
  final int lateCount;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: BldSpacing.md,
      vertical: BldSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: accent,
      borderRadius: BorderRadius.circular(BldRadius.sm),
    ),
    child: Row(
      children: [
        Expanded(
          /*
           * KIRPMA YERİNE KÜÇÜLTME.
           *
           * Boş sütun daraldığında "HAZIRLANIYOR (0)" başlığı "HAZIRLANIYOR ..."
           * diye kesiliyordu. Sütunu renginden tanıyan personel için başlık
           * ikincil ama kesik bir kelime ekranda arıza gibi duruyor. `scaleDown`
           * yalnızca sığmadığında küçültür; geniş sütunda punto değişmez.
           */
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: KdsTextScale.columnHeader,
                fontWeight: FontWeight.bold,
                color: KdsAccents.onAccent(accent),
              ),
            ),
          ),
        ),
        // Sütun başına gecikme sayısı: "HAZIR" sütununda birikmiş üç geciken
        // sipariş, mutfağın değil kuryenin sorunudur. Sayıyı sütun bazında
        // göstermek, sorunun nerede olduğunu tek bakışta söyler.
        if (lateCount > 0) _LateCountBadge(count: lateCount),
      ],
    ),
  );
}

class _LateCountBadge extends StatelessWidget {
  const _LateCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: BldSpacing.sm, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(BldColors.neutral900),
      borderRadius: BorderRadius.circular(BldRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          size: 18,
          color: Color(BldColors.danger),
        ),
        const SizedBox(width: BldSpacing.xs),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: KdsTextScale.statusBar,
            fontWeight: FontWeight.bold,
            color: Color(BldColors.danger),
          ),
        ),
      ],
    ),
  );
}
