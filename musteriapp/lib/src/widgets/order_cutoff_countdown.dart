/// Kesim saati geri sayımı — `DailyMenu.cutoffAt` / `MenuCalendarDay.cutoffAt`.
///
/// **BU BİR KAPI DEĞİL, BİR SUNUMDUR.** Geri sayım sıfırlandığında hiçbir ekran
/// kilitlenmez: menü yeniden çekilir ve karar yine `is_orderable`'a bırakılır
/// ([onExpired] tam olarak bunun için var). Cihaz saati beş dakika ileriyken
/// açık bir günü kapalı göstermek satış kaybıdır; beş dakika geriyken açık
/// göstermek ise sunucunun zaten reddedeceği bir istektir. İkisinin arasındaki
/// fark, istemcinin kesim saatini HESAPLAMAMASININ sebebidir: sunucu tek bir
/// mutlak an gönderir, burası onu okunur hâle getirir.
///
/// **Neden dakikada bir:** kesim saati sabah 08:00 gibi bir gün sınırı ve
/// müşteri saniye saymıyor. Saniyede bir tıkan bir sayaç, menü ekranı açıkken
/// telefonu ısıtmaktan başka bir şey yapmazdı.
library;

import 'dart:async';

import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/bld_semantic_colors.dart';

/// Bir günün sipariş kabulünün bitmesine kalan süre.
class OrderCutoffCountdown extends StatefulWidget {
  const OrderCutoffCountdown({
    super.key,
    required this.cutoffAt,
    this.onExpired,
  });

  /// Sipariş kabulünün bittiği **mutlak an** (UTC).
  final DateTime cutoffAt;

  /// Süre dolduğunda bir kez çağrılır — çağıran menüyü tazeler.
  ///
  /// İsteğe bağlı: geri sayımı yalnız göstermek isteyen bir ekran (ör. takvim
  /// satırı) tazeleyecek bir şeye sahip olmayabilir.
  final VoidCallback? onExpired;

  /// Geri sayımın yerini mutlak tarihe bıraktığı sınır.
  ///
  /// Yedi gün ilerisi seçilebiliyor ve "6 gün 3 saat kaldı" bir aciliyet
  /// kurmuyor, yalnız gürültü yapıyor. Bir günden uzak kesimler
  /// "Son sipariş: 21 Ağustos 2026, 08:00" diye yazılır.
  static const Duration countdownWindow = Duration(days: 1);

  @override
  State<OrderCutoffCountdown> createState() => _OrderCutoffCountdownState();
}

class _OrderCutoffCountdownState extends State<OrderCutoffCountdown> {
  static const Duration _tick = Duration(minutes: 1);

  Timer? _timer;
  late Duration _left;

  @override
  void initState() {
    super.initState();
    _left = _remaining();
    _startTimer();
  }

  @override
  void didUpdateWidget(OrderCutoffCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Gün şeridinde başka bir güne geçildiğinde aynı State yeniden kullanılır;
    // sayaç sıfırlanmazsa dünün kalan süresi yeni günün altında yazardı.
    if (oldWidget.cutoffAt != widget.cutoffAt) {
      _timer?.cancel();
      _left = _remaining();
      _startTimer();
    }
  }

  @override
  void dispose() {
    // Zamanlayıcı `dispose`'ta MUTLAKA iptal edilir: iptal edilmeyen bir
    // `Timer.periodic` ekran kapandıktan sonra da tıklar ve ölü bir State
    // üzerinde `setState` çağırır.
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_left <= Duration.zero) return;
    _timer = Timer.periodic(_tick, (_) => _onTick());
  }

  Duration _remaining() => widget.cutoffAt.difference(DateTime.now().toUtc());

  void _onTick() {
    if (!mounted) return;
    final left = _remaining();
    setState(() => _left = left);

    if (left <= Duration.zero) {
      _timer?.cancel();
      _timer = null;
      widget.onExpired?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bld = context.bld;

    // Süre dolduysa bu satırın söyleyecek bir şeyi kalmadı: gerekçeyi artık
    // sunucunun `unavailable_reason`'ı taşıyor ve o ayrı bir kutuda yazılı.
    if (_left <= Duration.zero) return const SizedBox.shrink();

    // Yukarı yuvarlanır: 30 saniye kalmışken "0 dakika" yazan bir sayaç,
    // süre dolmadan dolmuş görünür.
    final totalMinutes = (_left.inSeconds + 59) ~/ 60;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    final String message;
    if (_left >= OrderCutoffCountdown.countdownWindow) {
      message = l10n.dailyMenuCutoffAt(TurkishTime.longDateTime(widget.cutoffAt));
    } else if (hours > 0) {
      message = l10n.dailyMenuCutoffInHours(hours, minutes);
    } else {
      message = l10n.dailyMenuCutoffInMinutes(minutes);
    }

    // Son bir saat UYARI tonunda: o eşikten sonra "yarın veririm" demek
    // siparişi kaçırmak demek.
    final urgent = _left < const Duration(hours: 1);
    final color = urgent ? bld.warningFg : theme.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(Icons.schedule_outlined, size: 16, color: color),
        const SizedBox(width: BldSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: urgent ? FontWeight.w600 : null,
            ),
          ),
        ),
      ],
    );
  }
}
