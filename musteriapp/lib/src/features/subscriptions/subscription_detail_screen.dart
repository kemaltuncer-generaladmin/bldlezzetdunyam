/// Abonelik detayı — kural özeti + gün atlama + duraklat/devam/iptal.
///
/// Aksiyonlar sunucuda durum makinesini yürütür; istemci yalnız çağırır ve
/// sağlayıcıları tazeler (sipariş iptalindeki kalıp). Fiyat/tutar asla
/// istemcide hesaplanmaz — `agreedUnitPrice` sunucudan gelir.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error_text.dart';
import '../../core/labels.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/infra_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../theme/bld_semantic_colors.dart';
import '../../theme/bld_theme.dart';
import '../../widgets/bld_card.dart';
import '../../widgets/pill.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_views.dart';
import 'subscriptions_screen.dart';

/// Gün atlama şeridinin gösterdiği gün sayısı.
///
/// Otuz gün: peşin ödemenin dönemi otuz günlük ve abone "bu dönemde
/// gelmeyeceğim günler" sorusunu o pencerede soruyor. Daha uzun bir şerit,
/// henüz ödenmemiş bir dönemin günlerini atlatırdı.
const int _skipStripDays = 30;

/// Şerit hücresinin genişliği ve araları — menü gün şeridiyle aynı ritim.
const double _skipChipWidth = 60;
const double _skipChipGap = BldSpacing.sm;

class SubscriptionDetailScreen extends ConsumerStatefulWidget {
  const SubscriptionDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<SubscriptionDetailScreen> createState() =>
      _SubscriptionDetailScreenState();
}

class _SubscriptionDetailScreenState
    extends ConsumerState<SubscriptionDetailScreen> {
  bool _busy = false;

  Future<void> _run(
    Future<Subscription> Function(SubscriptionService s) action,
    String successMessage,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await action(ref.read(apiProvider).subscriptions);
      ref.invalidate(subscriptionProvider(widget.id));
      ref.invalidate(subscriptionsProvider);
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } on ApiException catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(apiErrorDisplayMessage(error, l10n))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCancel() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.subscriptionCancelConfirmTitle),
        content: Text(l10n.subscriptionCancelConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.subscriptionCancel),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run((s) => s.cancel(widget.id), l10n.subscriptionCancelled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(subscriptionProvider(widget.id));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.subscriptionDetailTitle)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(subscriptionProvider(widget.id)),
        ),
        data: (subscription) => _Body(
          subscription: subscription,
          busy: _busy,
          onPause: () =>
              _run((s) => s.pause(widget.id), l10n.subscriptionPaused),
          onResume: () =>
              _run((s) => s.resume(widget.id), l10n.subscriptionResumed),
          onCancel: _confirmCancel,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.subscription,
    required this.busy,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  final Subscription subscription;
  final bool busy;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final (label, variant) = subscriptionStatusPresentation(
      subscription.status,
      l10n,
    );
    final price = subscription.agreedUnitPrice;

    return ListView(
      padding: const EdgeInsets.all(BldSpacing.md),
      children: [
        // Durum + fiyat başlığı.
        BldCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  BldPill(label: label, variant: variant),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      l10n.subscriptionQuantityLabel(
                        subscription.defaultQuantity,
                      ),
                      style: textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BldSpacing.md),
              Text(
                price != null ? Money.format(price) : l10n.subscriptionNoPrice,
                style: textTheme.headlineSmall,
              ),
              Text(
                l10n.subscriptionAgreedPrice,
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: BldSpacing.md),

        // Kural özeti.
        BldCard(
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.local_shipping_outlined,
                label: l10n.subscriptionDelivery,
                value: deliveryTypeLabel(subscription.deliveryType, l10n),
              ),
              if (subscription.deliveryTimeFrom != null)
                _InfoRow(
                  icon: Icons.schedule_outlined,
                  label: l10n.subscriptionDeliveryTime,
                  value: _timeWindow(subscription),
                ),
              _InfoRow(
                icon: Icons.date_range_outlined,
                label: l10n.subscriptionPeriod,
                value: _period(subscription, l10n),
              ),
            ],
          ),
        ),
        const SizedBox(height: BldSpacing.md),

        // Servis günleri.
        SectionHeader(
          title: l10n.subscriptionDays,
          padding: const EdgeInsets.only(
            left: BldSpacing.xs,
            bottom: BldSpacing.sm,
          ),
        ),
        Wrap(
          spacing: BldSpacing.sm,
          runSpacing: BldSpacing.sm,
          children: [
            for (final day in subscription.serviceDays)
              BldPill(
                label: subscriptionDayLabel(day, l10n),
                variant: BldPillVariant.brand,
              ),
          ],
        ),
        const SizedBox(height: BldSpacing.sm),

        // Gün atlama YALNIZ `active` abonelikte. Talep, sözleşme ve ödeme
        // bekleyen aboneliğin henüz atlanacak bir günü yok; iptal edilende de
        // sipariş üretilmiyor. Şeridi o durumlarda da çizmek, hiçbir işe
        // yaramayan bir takvim göstermek olurdu.
        if (subscription.isActive) ...[
          SectionHeader(
            title: l10n.subscriptionSkipTitle,
            padding: const EdgeInsets.only(
              left: BldSpacing.xs,
              top: BldSpacing.md,
              bottom: BldSpacing.xs,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: BldSpacing.xs,
              right: BldSpacing.xs,
              bottom: BldSpacing.sm,
            ),
            child: Text(
              l10n.subscriptionSkipHelp,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _SkipStrip(subscription: subscription),
        ],

        // İçerik (satırlar).
        SectionHeader(
          title: l10n.subscriptionProducts,
          padding: const EdgeInsets.only(
            left: BldSpacing.xs,
            top: BldSpacing.md,
            bottom: BldSpacing.sm,
          ),
        ),
        if (subscription.lines.isEmpty)
          BldCard(
            child: Text(
              l10n.subscriptionNoProducts,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          BldCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < subscription.lines.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _LineRow(line: subscription.lines[i]),
                ],
              ],
            ),
          ),
        const SizedBox(height: BldSpacing.xl),

        // Aksiyonlar.
        ..._actions(context, l10n),
      ],
    );
  }

  List<Widget> _actions(BuildContext context, AppLocalizations l10n) {
    if (subscription.isCancelled) return const [];

    final buttons = <Widget>[];
    if (subscription.isActive) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: busy ? null : onPause,
          icon: const Icon(Icons.pause_circle_outline),
          label: Text(l10n.subscriptionPause),
        ),
      );
    } else if (subscription.isPaused) {
      buttons.add(
        FilledButton.icon(
          onPressed: busy ? null : onResume,
          icon: const Icon(Icons.play_circle_outline),
          label: Text(l10n.subscriptionResume),
        ),
      );
    }
    buttons.add(
      TextButton.icon(
        onPressed: busy ? null : onCancel,
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        icon: const Icon(Icons.cancel_outlined),
        label: Text(l10n.subscriptionCancel),
      ),
    );

    return [
      for (final button in buttons) ...[
        SizedBox(width: double.infinity, child: button),
        const SizedBox(height: BldSpacing.sm),
      ],
    ];
  }

  String _timeWindow(Subscription s) {
    final from = s.deliveryTimeFrom ?? '';
    final to = s.deliveryTimeTo;
    return to != null && to.isNotEmpty ? '$from – $to' : from;
  }

  String _period(Subscription s, AppLocalizations l10n) {
    final start = _date(s.startDate);
    final end = s.endDate != null
        ? _date(s.endDate!)
        : l10n.subscriptionOpenEnded;
    return '$start → $end';
  }

  /// Tarih-yalnız alan; zaman dilimi çevirmeden alanlardan biçimlenir.
  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';
}

/// Hücrenin ne anlattığı. Sıra ÖNCELİKTİR: dıştaki sebep içtekini yener.
enum SubscriptionSkipDayState {
  /// Abonelik penceresinin dışında (başlangıçtan önce ya da bitişten sonra).
  outside,

  /// Aboneliğin servis günü değil.
  notServiceDay,

  /// Mutfak o gün kapalı; sipariş zaten üretilmiyor.
  closed,

  /// Kesim geçti — o günün siparişi kilitlendi.
  locked,

  /// Atlanmış gün.
  skipped,

  /// Teslimat var ve atlanabilir.
  scheduled,
}

/// Şeritteki bir günün **ne anlattığı** ve **değiştirilebilir mi** olduğu.
///
/// İkisi ayrı çünkü çakışıyorlar: kesimi geçmiş ama atlanmış bir gün ekranda
/// hâlâ "Atlandı" der (yoksa abone o günü atladığını göremezdi) ama artık
/// geri alınamaz. Tek bir değer, bu iki cümleden birini yutardı.
typedef SubscriptionSkipDay = ({SubscriptionSkipDayState state, bool editable});

/// Şeritteki bir günün durumu.
///
/// Widget'tan AYRI bir işlev: kesim, servis günü ve dönem penceresi kuralları
/// burada birleşiyor ve arayüz çizmeden sınanabiliyor. Aynı üç kuralın hücre
/// çiziminin içine gömülmesi, hangi sebebin hangisini yendiğini kimsenin
/// okuyamayacağı bir koşul yığını yapardı.
///
/// [day] o günün takvim kaydıdır; takvim penceresinin dışındaki gün için
/// `null` gelir. [now] UTC an — kesim karşılaştırması **mutlak anlar
/// arasındadır**, cihazın duvar saatiyle değil.
SubscriptionSkipDay subscriptionSkipDay({
  required String date,
  required Subscription subscription,
  required MenuCalendarDay? day,
  required DateTime now,
}) {
  final start = BusinessDate.of(
    subscription.startDate.year,
    subscription.startDate.month,
    subscription.startDate.day,
  );
  if (BusinessDate.isBefore(date, start)) {
    return (state: SubscriptionSkipDayState.outside, editable: false);
  }

  final endDate = subscription.endDate;
  if (endDate != null) {
    final end = BusinessDate.of(endDate.year, endDate.month, endDate.day);
    if (BusinessDate.isAfter(date, end)) {
      return (state: SubscriptionSkipDayState.outside, editable: false);
    }
  }

  final weekday = BusinessDate.tryParse(date)?.weekday;
  if (weekday == null || !subscription.serviceDays.contains(weekday)) {
    return (state: SubscriptionSkipDayState.notServiceDay, editable: false);
  }

  // Kapalı gün: sipariş zaten üretilmiyor, atlanacak bir şey yok.
  if (day?.closed ?? false) {
    return (state: SubscriptionSkipDayState.closed, editable: false);
  }

  // `cutoffAt` boşsa kesim BİLİNMİYOR demektir (kesim tanımsız ya da gün
  // takvim penceresinin dışında), geçmiş değil. Boşu "geçti" saymak, otuz
  // günlük şeridin ileri görüş penceresi dışında kalan bütün günlerini
  // kilitlerdi — atlanabilecek günlerin çoğu tam olarak onlar.
  final cutoffAt = day?.cutoffAt;
  final passed = cutoffAt != null && !now.isBefore(cutoffAt);
  final skipped = subscription.exceptionFor(date)?.skip ?? false;

  if (skipped) {
    return (state: SubscriptionSkipDayState.skipped, editable: !passed);
  }
  return passed
      ? (state: SubscriptionSkipDayState.locked, editable: false)
      : (state: SubscriptionSkipDayState.scheduled, editable: true);
}

/// Gün atlama şeridi — `POST /subscriptions/{id}/exceptions`.
///
/// **KESİME SAYGI:** bir gün ancak `cutoff_at` geçmemişken atlanabilir. Kesim
/// anı aboneliğin kendi yanıtında YOK; menü takviminde var
/// (`MenuCalendarDay.cutoffAt`) ve şerit onu aynı aralık için okuyor. Kesimi
/// istemcide "sabah 08:00" diye varsaymak, kesim saati değiştiği gün
/// abonenin kapanmış bir siparişi kapattığını sanmasına yol açardı.
///
/// **Atlanan porsiyonun serbest satışa dönmesi SUNUCUNUN işidir.** İstemcinin
/// tek görevi o tarihin günlük menü sağlayıcısını tazelemek; boşalan kontenjan
/// ancak öyle görünür.
class _SkipStrip extends ConsumerStatefulWidget {
  const _SkipStrip({required this.subscription});

  final Subscription subscription;

  @override
  ConsumerState<_SkipStrip> createState() => _SkipStripState();
}

class _SkipStripState extends ConsumerState<_SkipStrip> {
  /// İşlem gören gün; aynı anda tek hücre çalışır.
  ///
  /// Tek bir `bool` yerine GÜN tutuluyor: dokunulan hücrenin kendisi
  /// beklediğini göstermeli, şeridin tamamı değil.
  String? _pending;

  Future<void> _toggle(String date, {required bool skipped}) async {
    if (_pending != null) return;
    setState(() => _pending = date);

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(apiProvider)
          .subscriptions
          .addException(
            widget.subscription.id,
            SubscriptionExceptionRequest(serviceDate: date, skip: !skipped),
          );

      ref.invalidate(subscriptionProvider(widget.subscription.id));
      ref.invalidate(subscriptionsProvider);
      // Boşalan (ya da geri alınan) kontenjan o günün menüsünde görünsün.
      ref.invalidate(dailyMenuProvider(date));

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            skipped
                ? l10n.subscriptionSkipUndone(BusinessDate.long(date))
                : l10n.subscriptionSkipDone(BusinessDate.long(date)),
          ),
        ),
      );
    } on ApiException catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(apiErrorDisplayMessage(error, l10n))),
      );
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscription = widget.subscription;
    final today = ref.watch(businessTodayProvider);
    final range = (
      from: today,
      to: BusinessDate.addDays(today, _skipStripDays - 1),
    );

    // Takvim YÜKLENMEDEN dokunma açılmıyor: kesim anı bilinmeden atlanan bir
    // gün sunucudan `422` yer ve abone hatanın nereden geldiğini anlayamaz.
    // Sağlayıcı ağ hatasında da değer döndürüyor (önbellek ya da boş liste),
    // yani bu bekleme kilitlenmiyor.
    final calendarAsync = ref.watch(menuCalendarProvider(range));
    final calendarLoaded = calendarAsync.hasValue;
    final byDate = <String, MenuCalendarDay>{
      for (final day in calendarAsync.valueOrNull ?? const <MenuCalendarDay>[])
        day.date: day,
    };

    final now = DateTime.now().toUtc();

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: BldSpacing.sm),
        itemCount: _skipStripDays,
        separatorBuilder: (_, _) => const SizedBox(width: _skipChipGap),
        itemBuilder: (context, index) {
          final date = BusinessDate.addDays(today, index);
          final day = subscriptionSkipDay(
            date: date,
            subscription: subscription,
            day: byDate[date],
            now: now,
          );

          return _SkipChip(
            date: date,
            offsetFromToday: index,
            state: day.state,
            busy: _pending == date,
            onTap: calendarLoaded && day.editable
                ? () => _toggle(
                    date,
                    skipped: day.state == SubscriptionSkipDayState.skipped,
                  )
                : null,
          );
        },
      ),
    );
  }
}

class _SkipChip extends StatelessWidget {
  const _SkipChip({
    required this.date,
    required this.offsetFromToday,
    required this.state,
    required this.busy,
    required this.onTap,
  });

  final String date;
  final int offsetFromToday;
  final SubscriptionSkipDayState state;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bld = context.bld;

    // Durum METİNLE de söyleniyor: hücrenin rengi tek başına bilgi taşımaz ve
    // "atlandı" ile "kesim geçti" aynı soluklukta görünürdü.
    final (
      String status,
      Color background,
      Color foreground,
      IconData? mark,
    ) = switch (state) {
      SubscriptionSkipDayState.outside => (
        l10n.subscriptionSkipStateOutside,
        bld.canvas,
        bld.placeholder,
        null,
      ),
      SubscriptionSkipDayState.notServiceDay => (
        l10n.subscriptionSkipStateOffDay,
        bld.canvas,
        bld.placeholder,
        null,
      ),
      SubscriptionSkipDayState.closed => (
        l10n.dailyMenuLegendClosed,
        bld.warningBg,
        bld.warningFg,
        Icons.event_busy_outlined,
      ),
      SubscriptionSkipDayState.locked => (
        l10n.subscriptionSkipStateLocked,
        theme.colorScheme.surfaceContainer,
        bld.placeholder,
        Icons.lock_outline,
      ),
      SubscriptionSkipDayState.skipped => (
        l10n.subscriptionSkipStateSkipped,
        bld.warningBg,
        bld.warningFg,
        Icons.remove_circle_outline,
      ),
      SubscriptionSkipDayState.scheduled => (
        l10n.subscriptionSkipStateScheduled,
        theme.colorScheme.surface,
        theme.colorScheme.onSurface,
        Icons.check_circle_outline,
      ),
    };

    final parsed = BusinessDate.tryParse(date);
    final title = switch (offsetFromToday) {
      0 => l10n.dayToday,
      1 => l10n.dayTomorrow,
      _ => parsed == null ? '' : subscriptionDayLabel(parsed.weekday, l10n),
    };

    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: [
        BusinessDate.long(date),
        BusinessDate.weekday(date),
        status,
      ].join(' '),
      child: SizedBox(
        width: _skipChipWidth,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(BldRadius.md),
          child: InkWell(
            onTap: busy ? null : onTap,
            borderRadius: BorderRadius.circular(BldRadius.md),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(BldRadius.md),
                border: Border.all(color: bld.decorativeBorder),
              ),
              child: ExcludeSemantics(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${parsed?.day ?? ''}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: foreground,
                        fontFeatures: kBldTabularFigures,
                        // Atlanan gün ÜSTÜ ÇİZİLİ: rozet rengiyle birlikte
                        // ikinci bir işaret veriyor ve renk körü kullanıcı
                        // için de okunuyor.
                        decoration: state == SubscriptionSkipDayState.skipped
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 16,
                      width: 16,
                      child: busy
                          ? Padding(
                              padding: const EdgeInsets.all(2),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: foreground,
                              ),
                            )
                          : mark == null
                          ? null
                          : Icon(mark, size: 16, color: foreground),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BldSpacing.sm - 2),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: BldSpacing.md),
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});

  final SubscriptionLine line;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final price = line.agreedUnitPrice;
    return Padding(
      padding: const EdgeInsets.all(BldSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: BldSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(BldRadius.sm),
            ),
            child: Text('×${line.quantity}', style: textTheme.labelLarge),
          ),
          const SizedBox(width: BldSpacing.md),
          Expanded(
            child: Text(
              line.label ?? l10n.subscriptionProducts,
              style: textTheme.bodyLarge,
            ),
          ),
          if (price != null)
            Text(Money.format(price), style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
