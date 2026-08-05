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
import '../urgency.dart';

class OrderCard extends StatefulWidget {
  const OrderCard({
    required this.order,
    required this.age,
    required this.column,
    required this.highlighted,
    required this.onAdvance,
    required this.onReprint,
    super.key,
  });

  final KitchenOrder order;

  /// Bekleme süresi ve aciliyet. Kartın rengini bu belirler.
  final OrderAge age;

  /// Kartın bulunduğu sütun — aciliyet yokken kimlik rengi buradan gelir.
  final KdsColumn column;

  /// Yeni düşen sipariş: 3 saniye yanıp söner (`docs/05` §3).
  final bool highlighted;

  final VoidCallback onAdvance;

  /// Fişi elle yeniden bastırır. Kâğıt sıkıştığında personelin ayarlar
  /// ekranına gitmesi gerekmesin diye kartın üzerindedir.
  final void Function(ReceiptType type) onReprint;

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

    // Gecikmede kırmızı, yeni siparişte marka rengi. Yanıp sönme kapalıysa
    // `_blink.value` hep 0 kalır ve kenar sabit durur.
    final blinkTarget = widget.age.isLate
        ? const Color(BldColors.danger)
        : const Color(BldColors.brand400);
    final restingBorder = widget.age.urgency == OrderUrgency.normal
        ? const Color(KdsColors.surfaceRaised)
        : accent;

    return AnimatedBuilder(
      animation: _blink,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BldRadius.md),
          border: Border.all(
            color: Color.lerp(restingBorder, blinkTarget, _blink.value)!,
            width: 3,
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
                    if (order.requestedAt != null) ...[
                      const SizedBox(height: BldSpacing.xs),
                      _RequestedAt(order: order, age: widget.age),
                    ],
                    if (order.customerLabel != null) ...[
                      const SizedBox(height: BldSpacing.xs),
                      Text(
                        order.customerLabel!,
                        style: const TextStyle(
                          fontSize: KdsTextScale.statusBar,
                          color: Color(KdsColors.onSurfaceMuted),
                        ),
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: BldSpacing.sm),
                      child: Divider(
                        height: 1,
                        color: Color(KdsColors.surfaceRaised),
                      ),
                    ),
                    for (final item in order.items) _ItemRow(item: item),
                    if (order.customerNote != null &&
                        order.customerNote!.trim().isNotEmpty) ...[
                      const SizedBox(height: BldSpacing.sm),
                      _NoteBox(
                        text: '${l10n.notePrefix}: ${order.customerNote}',
                      ),
                    ],
                    const SizedBox(height: BldSpacing.md),
                    _CardActions(
                      order: order,
                      accent: accent,
                      onAdvance: widget.onAdvance,
                      onReprint: widget.onReprint,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sol aciliyet şeridinin genişliği. Bir metreden görünmesi gerekir.
const double _accentStripeWidth = 12;

/// Karttaki eylem satırı: tek ileri adım + fiş yeniden basma.
///
/// Geri alma yoktur (`docs/05` §3); yeniden basma bir geri alma değildir,
/// yalnızca kâğıt üretir.
class _CardActions extends StatelessWidget {
  const _CardActions({
    required this.order,
    required this.accent,
    required this.onAdvance,
    required this.onReprint,
  });

  final KitchenOrder order;
  final Color accent;
  final VoidCallback onAdvance;
  final void Function(ReceiptType type) onReprint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final next = order.nextStatus;

    return Row(
      children: [
        if (next != null)
          Expanded(
            child: FilledButton(
              onPressed: onAdvance,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: KdsAccents.onAccent(accent),
                // Yağlı elle, aceleyle basılır: 64 piksel, tema
                // varsayılanının üstünde bilinçli bir yükseltme.
                minimumSize: const Size.fromHeight(64),
              ),
              child: Text(_actionLabel(l10n, next)),
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: BldSpacing.sm),
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

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.order, required this.age});

  final KitchenOrder order;
  final OrderAge age;

  @override
  Widget build(BuildContext context) {
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

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final KitchenOrderItem item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: BldSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${item.quantity}×',
              style: const TextStyle(
                fontSize: KdsTextScale.quantity,
                fontWeight: FontWeight.bold,
                color: Color(BldColors.brand400),
              ),
            ),
            const SizedBox(width: BldSpacing.sm),
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(
                  fontSize: KdsTextScale.itemName,
                  fontWeight: FontWeight.w600,
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
  );
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
