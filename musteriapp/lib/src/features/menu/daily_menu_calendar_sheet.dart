/// Takvim sayfası — gün şeridinin göremediği uzağı gösterir.
///
/// NEDEN ŞERİDİN YANINDA BİR DE TAKVİM: ileri görüş penceresi 30 gün ve şerit
/// yatay. Müşteri "önümüzdeki salı" ya da "ayın 20'si" diye düşünüyor, "on
/// yedi gün sonra" diye değil; şeritte on yedi kutu kaydırmak o soruya cevap
/// vermiyor. Takvim ayrıca KAPALI GÜNLERİ ve nedenlerini bir arada gösteriyor —
/// şeritte bunlar tek tek kaydırılarak keşfediliyordu.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/catalog_providers.dart';
import '../../theme/bld_semantic_colors.dart';
import '../../theme/bld_theme.dart';
import '../../widgets/skeletons.dart';

/// Takvimi alttan açar. Seçim yapılırsa sayfa kendini kapatır.
Future<void> showDailyMenuCalendarSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // `lg` (20) yarıçap: sheet/dialog ölçüsü.
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(BldRadius.lg)),
    ),
    builder: (context) => const DailyMenuCalendarSheet(),
  );
}

class DailyMenuCalendarSheet extends ConsumerWidget {
  const DailyMenuCalendarSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final range = ref.watch(menuCalendarRangeProvider);

    if (range == null) {
      return const Padding(
        padding: EdgeInsets.all(BldSpacing.lg),
        child: ListRowSkeleton(count: 3),
      );
    }

    final calendarAsync = ref.watch(menuCalendarProvider(range));
    final selected = ref.watch(selectedServiceDateProvider);

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BldSpacing.lg,
                0,
                BldSpacing.lg,
                BldSpacing.sm,
              ),
              child: Text(
                l10n.dailyMenuCalendarTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const _Legend(),
            Expanded(
              child: calendarAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(BldSpacing.lg),
                  child: ListRowSkeleton(count: 4),
                ),
                // Takvim ucu hata verdiğinde sağlayıcı zaten önbelleğe düşüyor
                // ve boş liste dönüyor; buraya yalnızca vitrin çözülemezse
                // gelinir. O durumda gün seçtirmenin anlamı yok.
                error: (_, _) => Padding(
                  padding: const EdgeInsets.all(BldSpacing.lg),
                  child: Text(l10n.errorUnknown),
                ),
                data: (days) => _CalendarList(
                  range: range,
                  days: days,
                  selected: selected,
                  onSelect: (date) {
                    ref
                        .read(selectedServiceDateProvider.notifier)
                        .select(date);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bld = context.bld;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BldSpacing.lg,
        0,
        BldSpacing.lg,
        BldSpacing.md,
      ),
      child: Row(
        children: [
          _LegendDot(color: theme.colorScheme.primary),
          const SizedBox(width: BldSpacing.xs),
          Text(l10n.dailyMenuLegendHasMenu, style: theme.textTheme.bodySmall),
          const SizedBox(width: BldSpacing.md),
          _LegendDot(color: bld.warningFg),
          const SizedBox(width: BldSpacing.xs),
          Text(l10n.dailyMenuLegendClosed, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 8,
    height: 8,
    child: DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

class _CalendarList extends StatelessWidget {
  const _CalendarList({
    required this.range,
    required this.days,
    required this.selected,
    required this.onSelect,
  });

  final MenuCalendarRange range;
  final List<MenuCalendarDay> days;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final byDate = <String, MenuCalendarDay>{
      for (final day in days) day.date: day,
    };
    final months = _monthsIn(range.from, range.to);
    final closed = days.where((day) => day.closed).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        BldSpacing.md,
        0,
        BldSpacing.md,
        BldSpacing.xl,
      ),
      children: [
        for (final month in months)
          _MonthGrid(
            month: month,
            range: range,
            byDate: byDate,
            selected: selected,
            onSelect: onSelect,
          ),
        if (closed.isNotEmpty) ...[
          const SizedBox(height: BldSpacing.lg),
          Text(l10n.dailyMenuClosedDays, style: theme.textTheme.titleMedium),
          const SizedBox(height: BldSpacing.sm),
          for (final day in closed)
            Padding(
              padding: const EdgeInsets.only(bottom: BldSpacing.xs),
              child: Text(
                // Kapalı günün NEDENİ yazılı. Yalnız işaretlemek, müşteriyi
                // "acaba dolu mu, acaba hata mı" diye telefona sarılmaya
                // itiyordu.
                day.note == null || day.note!.isEmpty
                    ? BusinessDate.long(day.date)
                    : '${BusinessDate.long(day.date)} — ${day.note}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
        ],
      ],
    );
  }
}

/// Aralığa değen ayların ilk günleri (UTC gece yarısı — yalnız aritmetik).
List<DateTime> _monthsIn(String from, String to) {
  final start = BusinessDate.tryParse(from);
  final end = BusinessDate.tryParse(to);
  if (start == null || end == null) return const <DateTime>[];

  final months = <DateTime>[];
  var cursor = DateTime.utc(start.year, start.month);
  final last = DateTime.utc(end.year, end.month);
  while (!cursor.isAfter(last)) {
    months.add(cursor);
    cursor = DateTime.utc(cursor.year, cursor.month + 1);
  }
  return months;
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.range,
    required this.byDate,
    required this.selected,
    required this.onSelect,
  });

  final DateTime month;
  final MenuCalendarRange range;
  final Map<String, MenuCalendarDay> byDate;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final firstIso = BusinessDate.of(month.year, month.month, 1);
    // Sonraki ayın 0. günü = bu ayın son günü. Artık yıl hesabı bize kalmıyor.
    final dayCount = DateTime.utc(month.year, month.month + 1, 0).day;
    // Pazartesi = 1 … Pazar = 7; ızgara pazartesiden başlıyor.
    final leading = month.weekday - 1;

    final weekdayLabels = [
      l10n.dayMon,
      l10n.dayTue,
      l10n.dayWed,
      l10n.dayThu,
      l10n.dayFri,
      l10n.daySat,
      l10n.daySun,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BldSpacing.xs,
            BldSpacing.md,
            BldSpacing.xs,
            BldSpacing.sm,
          ),
          child: Text(
            BusinessDate.month(firstIso),
            style: theme.textTheme.titleMedium,
          ),
        ),
        Row(
          children: [
            for (final label in weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: BldSpacing.xs),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.86,
          ),
          itemCount: leading + dayCount,
          itemBuilder: (context, index) {
            if (index < leading) return const SizedBox.shrink();

            final date = BusinessDate.of(
              month.year,
              month.month,
              index - leading + 1,
            );
            final inRange =
                !BusinessDate.isBefore(date, range.from) &&
                !BusinessDate.isAfter(date, range.to);

            return _CalendarCell(
              date: date,
              day: byDate[date],
              inRange: inRange,
              selected: date == selected,
              onSelect: onSelect,
            );
          },
        ),
      ],
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.date,
    required this.day,
    required this.inRange,
    required this.selected,
    required this.onSelect,
  });

  final String date;
  final MenuCalendarDay? day;
  final bool inRange;
  final bool selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bld = context.bld;

    final closed = day?.closed ?? false;
    // Şeritle AYNI kural: menüsü olan güne bakılabilir, sipariş kapısı ayrı.
    final browsable = inRange && ((day?.isBrowsable ?? false) || closed);
    final number = BusinessDate.tryParse(date)?.day ?? 0;

    final Color foreground = selected
        ? theme.colorScheme.onPrimary
        : browsable
        ? theme.colorScheme.onSurface
        : bld.placeholder;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: selected ? theme.colorScheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(BldRadius.sm),
        child: InkWell(
          onTap: browsable ? () => onSelect(date) : null,
          borderRadius: BorderRadius.circular(BldRadius.sm),
          child: Semantics(
            button: browsable,
            selected: selected,
            label: BusinessDate.long(date),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExcludeSemantics(
                  child: Text(
                    '$number',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontFeatures: kBldTabularFigures,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 6,
                  width: 6,
                  child: _cellMark(context, closed: closed),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _cellMark(BuildContext context, {required bool closed}) {
    final theme = Theme.of(context);
    final bld = context.bld;

    final Color? color = closed
        ? bld.warningFg
        : (day?.hasMenu ?? false)
        ? (selected ? theme.colorScheme.onPrimary : theme.colorScheme.primary)
        : null;
    if (color == null) return null;

    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
