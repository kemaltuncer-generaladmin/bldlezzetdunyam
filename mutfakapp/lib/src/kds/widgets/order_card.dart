/// Tek sipariş kartı — `docs/05-mutfakapp.md` §3.
///
/// Boyut alt sınırları `KdsTextScale`'dendir: ürün adı en az 20, adet en az 28
/// ve kalın. Değerler burada sabit yazılmaz.
///
/// Kart üç soruyu bir metreden cevaplamak zorundadır: **kimin siparişi**,
/// **ne kadardır bekliyor**, **şimdi ne yapmalıyım**. Bu yüzden sol kenarda
/// aciliyet şeridi, başlıkta bekleme sayacı ve altta tek bir büyük eylem
/// düğmesi vardır.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/kds_theme.dart';
import '../board.dart';
import '../order_progress.dart';
import '../urgency.dart';

class OrderCard extends StatefulWidget {
  const OrderCard({
    required this.order,
    required this.age,
    required this.column,
    required this.thresholds,
    required this.highlighted,
    required this.selected,
    required this.busy,
    required this.progress,
    required this.onAdvance,
    required this.onToggleItem,
    required this.onReprint,
    this.touchMode = false,
    this.onDetails,
    this.onEdit,
    super.key,
  });

  final KitchenOrder order;

  /// Bekleme süresi ve aciliyet. Kartın rengini bu belirler.
  final OrderAge age;

  /// Kartın bulunduğu sütun — aciliyet yokken kimlik rengi buradan gelir.
  final KdsColumn column;

  /// Hazırlanma süresi hedefi buradan gelir (kırmızı eşiği).
  final UrgencyThresholds thresholds;

  /// Yeni düşen sipariş: 3 saniye yanıp söner (`docs/05` §3).
  final bool highlighted;

  /// Klavyeyle seçili kart.
  final bool selected;

  /// Sunucuya istek uçuyor: düğme kilitli, çift dokunma yutulur.
  final bool busy;

  final OrderItemProgress progress;

  final VoidCallback onAdvance;

  /// Kalemi hazır/beklemede yapar. İşaret yereldir, sunucuya gitmez.
  final void Function(int itemIndex) onToggleItem;

  /// Fişi elle yeniden bastırır. Kâğıt sıkıştığında personelin ayarlar
  /// ekranına gitmesi gerekmesin diye kartın üzerindedir.
  final void Function(ReceiptType type) onReprint;

  /// Dokunmatik kip: kaydırma jestleri ve açılır menü yerine alt sayfa.
  final bool touchMode;

  /// Uzun basma / sola kaydırma — kartın işlem sayfası.
  ///
  /// `null` ise jest hiç bağlanmaz: bağlanıp hiçbir şey yapmayan bir jest,
  /// personeli "dokundum ama olmadı" döngüsüne sokar.
  final VoidCallback? onDetails;

  /// Sipariş düzenleme ekranını açar (K-14).
  ///
  /// Terminal durumdaki siparişte `null` gelir ve düğme çizilmez —
  /// sunucu zaten reddediyor, çizilen düğme yalnız hayal kırıklığı.
  final VoidCallback? onEdit;

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  /// Kart neden yanıp sönüyor?
  ///
  /// İki sebep var ve renkleri farklı: yeni sipariş (marka rengi, 3 saniye)
  /// ve gecikme (kırmızı, düzelene kadar). Gecikme daha ağır bastığı için
  /// öndedir — geciken bir siparişi turuncu yakıp söndürmek yanlış bilgi
  /// olurdu.
  bool get _blinking => widget.highlighted || widget.age.isLate;

  @override
  void initState() {
    super.initState();
    if (_blinking) _blink.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant OrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasBlinking = oldWidget.highlighted || oldWidget.age.isLate;
    if (_blinking == wasBlinking) return;
    if (_blinking) {
      _blink.repeat(reverse: true);
    } else {
      _blink
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final order = widget.order;
    final accent = KdsAccents.urgency(widget.age.urgency, widget.column);
    final doneCount = widget.progress.doneCount(order.id);

    // Gecikmede kırmızı, yeni siparişte marka rengi. Yanıp sönme kapalıysa
    // `_blink.value` hep 0 kalır ve kenar sabit durur.
    final blinkTarget = widget.age.isLate
        ? const Color(BldColors.danger)
        : const Color(BldColors.brand400);
    final restingBorder = widget.selected
        ? const Color(BldColors.neutral0)
        : widget.age.urgency == OrderUrgency.normal
        ? const Color(KdsColors.surfaceRaised)
        : accent;

    final card = AnimatedBuilder(
      animation: _blink,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BldRadius.md),
          border: Border.all(
            color: Color.lerp(restingBorder, blinkTarget, _blink.value)!,
            // Seçili kartın kenarı kalınlaşır: renk körü personel için de,
            // bir metre uzaktan da ayırt edilebilir olmalı.
            width: widget.selected ? 5 : 3,
          ),
        ),
        child: child,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BldRadius.md),
        child: ColoredBox(
          color: const Color(KdsColors.surface),
          child: Stack(
            children: [
              // Sol şerit: kartın sütun/aciliyet kimliği. Metin okumadan,
              // yalnızca renk taramasıyla ayırt edilir.
              //
              // `Row` + `CrossAxisAlignment.stretch` DEĞİL: kart kaydırılabilir
              // bir listede duruyor, yani yüksekliği sınırsız geliyor ve
              // stretch şeride sonsuz yükseklik dayatıp düzeni patlatıyor.
              // `Positioned` içeriğin ölçtüğü yüksekliğe uyar.
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                width: _accentStripeWidth,
                child: ColoredBox(color: accent),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _accentStripeWidth + BldSpacing.md,
                  BldSpacing.md,
                  BldSpacing.md,
                  BldSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CardHeader(order: order, age: widget.age),
                    if (order.revisionNo > 0) ...[
                      const SizedBox(height: BldSpacing.xs),
                      _RevisionBadge(revisionNo: order.revisionNo),
                    ],
                    const SizedBox(height: BldSpacing.xs),
                    _PrepBar(
                      order: order,
                      age: widget.age,
                      thresholds: widget.thresholds,
                    ),
                    if (order.requestedAt != null) ...[
                      const SizedBox(height: BldSpacing.xs),
                      _RequestedAt(order: order, age: widget.age),
                    ],
                    if (order.customerName != null ||
                        order.customerLabel != null) ...[
                      const SizedBox(height: BldSpacing.xs),
                      Text(
                        // Tam ad varsa o gösterilir: personel müşteriyi
                        // arayacaksa "Ayşe Y." yerine tam adı bilmeli.
                        order.customerName ?? order.customerLabel!,
                        style: const TextStyle(
                          fontSize: KdsTextScale.statusBar,
                          color: Color(KdsColors.onSurfaceMuted),
                        ),
                      ),
                    ],
                    // ── TELEFON (K-14) ──────────────────────────────────
                    //
                    // `docs/03` §5 eskiden "mutfak listesinde telefon
                    // GÖRÜNMEZ" diyordu ve sipariş düzenleme gelene kadar
                    // doğruydu. Artık personel müşteriyi ARAYIP anlaşmak
                    // zorunda; numara için fiş basmak saçma.
                    //
                    // SEÇİLEBİLİR METİN: kasada telefon uygulaması yok,
                    // personel numarayı cep telefonuna yazıyor. Seçip
                    // kopyalayabilmesi tek kolaylık.
                    if (order.customerPhone != null) ...[
                      const SizedBox(height: BldSpacing.xs),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 20,
                            color: Color(KdsColors.onSurfaceMuted),
                          ),
                          const SizedBox(width: BldSpacing.xs),
                          Expanded(
                            child: SelectableText(
                              order.customerPhone!,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: KdsTextScale.orderNumber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: BldSpacing.sm),
                      child: Divider(
                        height: 1,
                        color: Color(KdsColors.surfaceRaised),
                      ),
                    ),
                    if (order.items.length > 1 && doneCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: BldSpacing.sm),
                        child: Text(
                          l10n.itemsDone(doneCount, order.items.length),
                          style: const TextStyle(
                            fontSize: KdsTextScale.statusBar,
                            fontWeight: FontWeight.bold,
                            color: Color(BldColors.success),
                          ),
                        ),
                      ),
                    for (var index = 0; index < order.items.length; index++)
                      _ItemRow(
                        item: order.items[index],
                        done: widget.progress.isDone(order.id, index),
                        onToggle: () => widget.onToggleItem(index),
                      ),
                    if (order.customerNote != null &&
                        order.customerNote!.trim().isNotEmpty) ...[
                      const SizedBox(height: BldSpacing.sm),
                      _NoteBox(
                        text: '${l10n.notePrefix}: ${order.customerNote}',
                      ),
                    ],
                    const SizedBox(height: BldSpacing.md),
                    _CardActions(
                      touchMode: widget.touchMode,
                      order: order,
                      accent: accent,
                      busy: widget.busy,
                      onAdvance: widget.onAdvance,
                      onReprint: widget.onReprint,
                      onEdit: widget.onEdit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!widget.touchMode) return card;

    // ── Dokunmatik jestler (K-10) ────────────────────────────────────────
    //
    // YALNIZCA dokunmatik kipte bağlanıyor: fareyle kullanılan kasada
    // yatay sürükleme, listeyi kaydırmaya çalışan kullanıcıyı yanlışlıkla
    // siparişi ilerletmeye götürebilir.
    //
    // Sağa kaydır = ilerlet (okuma yönünde "ileri"), sola kaydır ve uzun
    // bas = işlem sayfası. Eşik `_swipeThreshold`: kısa tutulursa liste
    // kaydırırken tetikleniyor, uzun tutulursa jest hiç çalışmıyor hissi
    // veriyor.
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onLongPress: widget.onDetails,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < _swipeVelocityThreshold) return;

        if (velocity > 0) {
          if (!widget.busy && order.nextStatus != null) widget.onAdvance();
        } else {
          widget.onDetails?.call();
        }
      },
      child: card,
    );
  }
}

/// Sipariş düzenlendi rozeti (K-12).
///
/// NEDEN GÖRÜNÜR OLMAK ZORUNDA: revize edilmiş bir siparişin kâğıdı
/// mutfakta iki kez basılıyor (eski + revize). Kart üzerinde işaret
/// yoksa personel hangi kâğıdın geçerli olduğunu bilemez.
class _RevisionBadge extends StatelessWidget {
  const _RevisionBadge({required this.revisionNo});

  final int revisionNo;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BldSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: const Color(BldColors.warning),
        borderRadius: BorderRadius.circular(BldRadius.sm),
      ),
      child: Text(
        AppL10n.of(context).orderRevised(revisionNo),
        style: const TextStyle(
          fontSize: KdsTextScale.statusBar,
          fontWeight: FontWeight.bold,
          color: Color(BldColors.neutral900),
        ),
      ),
    ),
  );
}

/// Sol aciliyet şeridinin genişliği. Bir metreden görünmesi gerekir.
const double _accentStripeWidth = 12;

/// Kaydırma jestinin tetikleme hızı (px/sn).
///
/// Sahada ölçülmedi, Material'ın `kMinFlingVelocity` (50) değerinin
/// katı olarak seçildi: liste kaydırırken oluşan yanlışlıkla yatay
/// bileşen bu hıza ulaşmıyor, kasıtlı bir kaydırma rahatça aşıyor.
const double _swipeVelocityThreshold = 300;

/// Karttaki eylem satırı: tek ileri adım + fiş yeniden basma.
///
/// Geri alma yoktur (`docs/05` §3); yeniden basma bir geri alma değildir,
/// yalnızca kâğıt üretir.
class _CardActions extends StatelessWidget {
  const _CardActions({
    required this.order,
    required this.accent,
    required this.busy,
    required this.onAdvance,
    required this.onReprint,
    this.touchMode = false,
    this.onEdit,
  });

  final KitchenOrder order;
  final Color accent;
  final bool busy;
  final VoidCallback onAdvance;
  final void Function(ReceiptType type) onReprint;
  final bool touchMode;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final next = order.nextStatus;

    return Row(
      children: [
        if (next != null)
          Expanded(
            child: FilledButton(
              // İSTEK UÇARKEN KİLİTLİ. Yağlı elle basılan bir düğme kolayca
              // iki kez tetiklenir; ikinci istek ya sebepsiz bir hata uyarısı
              // üretir ya da siparişi bir adım fazla ilerletir.
              onPressed: busy ? null : onAdvance,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: KdsAccents.onAccent(accent),
                // Yağlı elle, aceleyle basılır: 64 piksel, tema
                // varsayılanının üstünde bilinçli bir yükseltme.
                minimumSize: const Size.fromHeight(64),
              ),
              child: busy
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : Text(_actionLabel(l10n, next)),
            ),
          )
        else
          const Spacer(),
        // DÜZENLE — mutfak müşteriyle konuşup adedi değiştiriyor (K-14).
        //
        // İlerlet düğmesinin YANINDA ama ondan küçük: düzenleme nadir,
        // ilerletme her siparişte. Aynı boyutta olsalardı acele eden
        // personel yanlışına basardı.
        if (onEdit != null) ...[
          const SizedBox(width: BldSpacing.sm),
          IconButton.filledTonal(
            tooltip: l10n.editAction,
            iconSize: touchMode ? 30 : 26,
            onPressed: busy ? null : onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
        const SizedBox(width: BldSpacing.sm),
        // DOKUNMATİKTE AÇILIR MENÜ YOK. `PopupMenuButton` küçük satırlar
        // çiziyor ve menü parmağın altında kalıyor: personel neye
        // bastığını göremiyor. Alt sayfa tam genişlik, büyük satır ve
        // parmağın üstünde açılıyor.
        if (touchMode)
          IconButton.filledTonal(
            tooltip: l10n.reprintTooltip,
            iconSize: 30,
            onPressed: () => showReprintSheet(context, onReprint),
            icon: const Icon(Icons.print_outlined),
          )
        else
          PopupMenuButton<ReceiptType>(
            onSelected: onReprint,
            tooltip: l10n.reprintTooltip,
            iconSize: 28,
            padding: const EdgeInsets.all(BldSpacing.md),
            icon: const Icon(Icons.print_outlined),
            itemBuilder: (context) => [
              PopupMenuItem<ReceiptType>(
                value: ReceiptType.mutfak,
                child: Text(l10n.reprintKitchen),
              ),
              PopupMenuItem<ReceiptType>(
                value: ReceiptType.musteri,
                child: Text(l10n.reprintCustomer),
              ),
            ],
          ),
      ],
    );
  }
}

/// Fiş yeniden basma alt sayfası — dokunmatik kipin açılır menü karşılığı.
Future<void> showReprintSheet(
  BuildContext context,
  void Function(ReceiptType type) onReprint,
) async {
  final l10n = AppL10n.of(context);

  final selected = await showModalBottomSheet<ReceiptType>(
    context: context,
    backgroundColor: const Color(KdsColors.surface),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: BldSpacing.sm),
          Text(
            l10n.reprintTooltip,
            style: const TextStyle(
              fontSize: KdsTextScale.columnHeader,
              fontWeight: FontWeight.bold,
            ),
          ),
          for (final type in const [ReceiptType.mutfak, ReceiptType.musteri])
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: BldSpacing.lg,
                vertical: BldSpacing.sm,
              ),
              leading: const Icon(Icons.print_outlined, size: 30),
              title: Text(
                type == ReceiptType.mutfak
                    ? l10n.reprintKitchen
                    : l10n.reprintCustomer,
                style: const TextStyle(fontSize: KdsTextScale.orderNumber),
              ),
              onTap: () => Navigator.of(context).pop(type),
            ),
          const SizedBox(height: BldSpacing.md),
        ],
      ),
    ),
  );

  if (selected != null) onReprint(selected);
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.order, required this.age});

  final KitchenOrder order;
  final OrderAge age;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final isDelivery = order.deliveryType == DeliveryType.delivery;
    final badgeColor = Color(
      isDelivery ? KdsColors.badgeDelivery : KdsColors.badgePickup,
    );

    return Row(
      children: [
        Expanded(
          child: Text(
            order.orderNumber,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: KdsTextScale.columnHeader,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Uzun bir kartta not aşağıda kalır ve kaydırmadan görünmez. Başlıktaki
        // rozet, "bu siparişte okunacak bir şey var" bilgisini yukarı taşır.
        if (order.hasHighlightedNote) ...[
          _Pill(
            color: const Color(KdsColors.noteBackground),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.priority_high,
                  size: 18,
                  color: Color(KdsColors.noteForeground),
                ),
                Text(
                  l10n.cardNoteBadge,
                  style: const TextStyle(
                    fontSize: KdsTextScale.statusBar,
                    fontWeight: FontWeight.bold,
                    color: Color(KdsColors.noteForeground),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: BldSpacing.sm),
        ],
        // Abonelik kuralından üretilmiş sipariş — mutfak bunu bir bakışta
        // ayırt etsin (yinelenen kurumsal öğle yemeği).
        if (order.isSubscription) ...[
          _Pill(
            color: const Color(BldColors.brand500),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.event_repeat,
                  size: 18,
                  color: KdsAccents.onAccent(const Color(BldColors.brand500)),
                ),
                const SizedBox(width: BldSpacing.xs),
                Text(
                  l10n.cardSubscriptionBadge,
                  style: TextStyle(
                    fontSize: KdsTextScale.statusBar,
                    fontWeight: FontWeight.bold,
                    color: KdsAccents.onAccent(const Color(BldColors.brand500)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: BldSpacing.sm),
        ],
        _ElapsedBadge(age: age),
        const SizedBox(width: BldSpacing.sm),
        _Pill(
          color: badgeColor,
          child: Text(
            order.deliveryBadge,
            style: TextStyle(
              fontSize: KdsTextScale.statusBar,
              fontWeight: FontWeight.bold,
              color: KdsAccents.onAccent(badgeColor),
            ),
          ),
        ),
      ],
    );
  }
}

/// Hazırlanma süresi hedefi ve gerçekleşeni.
///
/// Sayaç "kaç dakika oldu" der ama "ne kadar kaldı" demez; ikisi farklı
/// sorulardır. Çubuk hedefe ne kadar yaklaşıldığını bir bakışta gösterir ve
/// sipariş hazır olduğunda yerini **gerçekleşen** süreye bırakır — mutfak
/// kendi hızını ancak ölçebildiği zaman iyileştirebilir.
class _PrepBar extends StatelessWidget {
  const _PrepBar({
    required this.order,
    required this.age,
    required this.thresholds,
  });

  final KitchenOrder order;
  final OrderAge age;
  final UrgencyThresholds thresholds;

  /// Sipariş hazır ya da ötesindeyse hazırlanma bitmiştir.
  bool get _finished =>
      order.status == OrderStatus.hazir ||
      order.status == OrderStatus.yolda ||
      order.status == OrderStatus.teslimEdildi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    if (_finished) {
      // `updatedAt` siparişin `hazir` olduğu an; farkı gerçekleşen süredir.
      final actual = order.updatedAt.toUtc().difference(
        order.createdAt.toUtc(),
      );
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          l10n.prepActualLabel(actual.isNegative ? 0 : actual.inMinutes),
          style: const TextStyle(
            fontSize: KdsTextScale.statusBar,
            color: Color(BldColors.success),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final target = thresholds.lateAfter.inMicroseconds;
    final elapsed = age.waiting.inMicroseconds.clamp(0, target);
    final ratio = target == 0 ? 1.0 : elapsed / target;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BldRadius.pill),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: const Color(KdsColors.surfaceRaised),
              valueColor: AlwaysStoppedAnimation<Color>(
                KdsAccents.urgency(age.urgency, KdsColumn.yeni),
              ),
            ),
          ),
        ),
        const SizedBox(width: BldSpacing.sm),
        Text(
          l10n.prepTargetLabel(thresholds.lateAfter.inMinutes),
          style: const TextStyle(
            fontSize: KdsTextScale.statusBar,
            color: Color(KdsColors.onSurfaceMuted),
          ),
        ),
      ],
    );
  }
}

/// Siparişin kaç dakikadır beklediğini gösteren sayaç.
///
/// Mutfağın en çok baktığı sayıdır; bu yüzden rozet aciliyetle birlikte renk
/// değiştirir ve normalken bile görünür kalır — sessiz bir sayaç, gecikmeyi
/// olmadan önce sezmeyi sağlar.
class _ElapsedBadge extends StatelessWidget {
  const _ElapsedBadge({required this.age});

  final OrderAge age;

  @override
  Widget build(BuildContext context) {
    final normal = age.urgency == OrderUrgency.normal;
    final color = normal
        ? const Color(KdsColors.surfaceRaised)
        : KdsAccents.urgency(age.urgency, KdsColumn.yeni);
    final foreground = normal
        ? const Color(KdsColors.onSurfaceMuted)
        : KdsAccents.onAccent(color);

    return _Pill(
      color: color,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 18, color: foreground),
          const SizedBox(width: BldSpacing.xs),
          Text(
            formatElapsed(AppL10n.of(context), age.waiting),
            style: TextStyle(
              fontSize: KdsTextScale.statusBar,
              fontWeight: FontWeight.bold,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// `"12 dk"` / `"1 sa 5 dk"`. Negatif süre (saati ileri kasa) sıfır sayılır.
String formatElapsed(AppL10n l10n, Duration elapsed) {
  final total = elapsed.isNegative ? Duration.zero : elapsed;
  return total.inHours > 0
      ? l10n.elapsedHours(total.inHours, total.inMinutes.remainder(60))
      : l10n.elapsedMinutes(total.inMinutes);
}

/// Ortak rozet kabı: yuvarlak köşe, dolgu, renk.
class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: BldSpacing.sm,
      vertical: BldSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(BldRadius.sm),
    ),
    child: child,
  );
}

class _RequestedAt extends StatelessWidget {
  const _RequestedAt({required this.order, required this.age});

  final KitchenOrder order;
  final OrderAge age;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final remaining = age.untilRequested ?? Duration.zero;
    final clock = TurkishTime.shortDateTime(order.requestedAt!);
    final overdue = age.requestedTimePassed;

    // Geçmişse kaç dakika geçtiğini yazmak "geçti" demekten daha işe yarar:
    // 2 dakikalık gecikme ile 40 dakikalık gecikme aynı şey değildir.
    final text = overdue
        ? l10n.requestedOverdue(clock, remaining.abs().inMinutes)
        : l10n.requestedRemaining(clock, remaining.inMinutes);
    final color = Color(overdue ? BldColors.danger : KdsColors.onSurfaceMuted);

    return Row(
      children: [
        Icon(Icons.event_outlined, size: 18, color: color),
        const SizedBox(width: BldSpacing.xs),
        Expanded(
          child: Text(
            '${l10n.requestedAtPrefix}: $text',
            style: TextStyle(
              fontSize: KdsTextScale.statusBar,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tek kalem. Dokunulunca "hazır" işaretlenir.
///
/// Beş kalemlik bir siparişte aşçının hangisini tencereye koyduğunu aklında
/// tutması gerekmemeli — özellikle vardiya değişiminde devralan kişi hiçbir
/// şey bilmez. İşaret yereldir; sözleşmede kalem durumu yok.
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.done,
    required this.onToggle,
  });

  final KitchenOrderItem item;
  final bool done;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final muted = Color(done ? KdsColors.onSurfaceMuted : BldColors.brand400);

    return Padding(
      padding: const EdgeInsets.only(bottom: BldSpacing.sm),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(BldRadius.sm),
        child: Semantics(
          label: l10n.itemToggleTooltip,
          checked: done,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    done
                        ? Icons.check_box_outlined
                        : Icons.check_box_outline_blank,
                    size: 28,
                    color: Color(
                      done ? BldColors.success : KdsColors.surfaceRaised,
                    ),
                  ),
                  const SizedBox(width: BldSpacing.sm),
                  Text(
                    '${item.quantity}×',
                    style: TextStyle(
                      fontSize: KdsTextScale.quantity,
                      fontWeight: FontWeight.bold,
                      color: muted,
                    ),
                  ),
                  const SizedBox(width: BldSpacing.sm),
                  Expanded(
                    child: Text(
                      item.name,
                      style: TextStyle(
                        fontSize: KdsTextScale.itemName,
                        fontWeight: FontWeight.w600,
                        color: done
                            ? const Color(KdsColors.onSurfaceMuted)
                            : null,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ],
              ),
              if (item.options.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: BldSpacing.xl),
                  child: Text(
                    item.options.join(', '),
                    style: const TextStyle(
                      fontSize: KdsTextScale.statusBar,
                      color: Color(KdsColors.onSurfaceMuted),
                    ),
                  ),
                ),
              if (item.note != null && item.note!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    left: BldSpacing.xl,
                    top: BldSpacing.xs,
                  ),
                  child: _NoteBox(text: item.note!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sipariş notu asla gizlenmez, kırmızı zeminde büyük basılır (`docs/05` §3).
class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(BldSpacing.sm),
    decoration: BoxDecoration(
      color: const Color(KdsColors.noteBackground),
      borderRadius: BorderRadius.circular(BldRadius.sm),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: KdsTextScale.note,
        fontWeight: FontWeight.bold,
        color: Color(KdsColors.noteForeground),
      ),
    ),
  );
}

String _actionLabel(AppL10n l10n, OrderStatus next) => switch (next) {
  OrderStatus.onaylandi => l10n.actionConfirm,
  OrderStatus.hazirlaniyor => l10n.actionStart,
  OrderStatus.hazir => l10n.actionReady,
  OrderStatus.yolda => l10n.actionDispatch,
  OrderStatus.teslimEdildi => l10n.actionDeliver,
  // `nextForward` bu ikisini asla döndürmez; durum adı yine de anlamlıdır.
  OrderStatus.yeni || OrderStatus.iptal => orderStatusLabelsTr[next]!,
};
