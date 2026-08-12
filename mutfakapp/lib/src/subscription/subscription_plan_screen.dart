/// Abonelik üretim planı ekranı — `docs/05-mutfakapp.md` §15 (K-15).
///
/// ÖNCEKİ HÂLİ tek bir banner ve salt-okunur bir pencereydi: kaç sipariş
/// olduğunu söylüyor, **ne pişeceğini** söylemiyordu. Mutfak sabah "40
/// abonelik var" bilgisiyle hiçbir şey yapamıyor; ihtiyacı olan "120
/// mercimek, 85 tavuk".
///
/// EKRAN ÜÇ SORUYA CEVAP VERİYOR, sırayla:
///   1. **Ne EKSİK?** — uyarılar en üstte. Üretim koşmamışsa mutfak
///      "bugün abonelik yok" sanıp hazırlık yapmıyor; bu bilgi listeden
///      önce gelmeli.
///   2. **Ne pişecek?** — ürün bazında toplam, büyük punto.
///   3. **Nereye, kaçta?** — teslimat çizelgesi ve durum ilerletme.
///
/// FİŞ BASILABİLİR: mutfak akşam kapatırken yarının listesini kâğıda
/// basıp tezgâha asıyor. Ekrana bakmak için elini yıkayıp kasaya gitmek
/// gerekir; kâğıt tezgâhın üstünde durur.
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_core/escpos.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../data/subscription_plan.dart';
import '../kds/kds_screen.dart';
import '../l10n/app_localizations.dart';

class SubscriptionPlanScreen extends ConsumerStatefulWidget {
  const SubscriptionPlanScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const SubscriptionPlanScreen());

  @override
  ConsumerState<SubscriptionPlanScreen> createState() =>
      _SubscriptionPlanScreenState();
}

class _SubscriptionPlanScreenState
    extends ConsumerState<SubscriptionPlanScreen> {
  PlanRange _range = PlanRange.today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final plan = ref.watch(subscriptionPlanProvider(_range));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(KdsColors.surface),
        title: Text(
          l10n.planTitle,
          style: const TextStyle(
            fontSize: KdsTextScale.columnHeader,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          tooltip: l10n.settingsBack,
          iconSize: 32,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: l10n.settingsQueueRefresh,
            iconSize: 30,
            onPressed: () =>
                ref.invalidate(subscriptionPlanProvider(_range)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _RangeTabs(
              selected: _range,
              onChanged: (range) => setState(() => _range = range),
            ),
            Expanded(
              child: plan.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(BldSpacing.xl),
                    child: Text(
                      l10n.planFailed(
                        error is ApiException ? error.message : '$error',
                      ),
                      style: const TextStyle(
                        fontSize: KdsTextScale.orderNumber,
                        color: Color(BldColors.danger),
                      ),
                    ),
                  ),
                ),
                data: (days) => ListView(
                  padding: const EdgeInsets.all(BldSpacing.lg),
                  children: [
                    for (final day in days) _DaySection(day: day),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeTabs extends StatelessWidget {
  const _RangeTabs({required this.selected, required this.onChanged});

  final PlanRange selected;
  final void Function(PlanRange range) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final labels = <PlanRange, String>{
      PlanRange.today: l10n.planToday,
      PlanRange.tomorrow: l10n.planTomorrow,
      PlanRange.week: l10n.planWeek,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BldSpacing.lg,
        vertical: BldSpacing.sm,
      ),
      child: Row(
        children: [
          for (final range in PlanRange.values) ...[
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: selected == range
                      ? const Color(BldColors.brand500)
                      : const Color(KdsColors.surface),
                  foregroundColor: selected == range
                      ? const Color(BldColors.neutral0)
                      : const Color(KdsColors.onSurfaceMuted),
                  minimumSize: const Size.fromHeight(60),
                ),
                onPressed: () => onChanged(range),
                child: Text(labels[range]!),
              ),
            ),
            if (range != PlanRange.values.last)
              const SizedBox(width: BldSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// Tek günün bloğu: uyarılar → toplamlar → teslimat çizelgesi.
class _DaySection extends ConsumerWidget {
  const _DaySection({required this.day});

  final PlanDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: BldSpacing.xl),
      child: Material(
        color: const Color(KdsColors.surface),
        borderRadius: BorderRadius.circular(BldRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(BldSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      TurkishTime.date(day.date.toUtc()),
                      style: const TextStyle(
                        fontSize: KdsTextScale.columnHeader,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (day.totalQuantity > 0)
                    Text(
                      l10n.planPortions(day.totalQuantity),
                      style: const TextStyle(
                        fontSize: KdsTextScale.orderNumber,
                        color: Color(KdsColors.onSurfaceMuted),
                      ),
                    ),
                ],
              ),

              // ── 1. NE EKSİK? Uyarılar EN ÜSTTE ────────────────────
              //
              // Alta konsaydı, listeyi okuyup işine dönen personel oraya
              // hiç bakmazdı. "Üretim koşmamış" bilgisi listenin
              // kendisinden önce gelir.
              if (day.warnings.isNotEmpty) ...[
                const SizedBox(height: BldSpacing.md),
                // BAŞLIK ŞART: başlıksız bir sarı satır dizisi, listenin
                // bir parçası gibi okunuyor ve "bunlar uyarı" olduğu
                // anlaşılmıyor.
                Text(
                  l10n.planWarnings,
                  style: const TextStyle(
                    fontSize: KdsTextScale.columnHeader,
                    fontWeight: FontWeight.bold,
                    color: Color(BldColors.warning),
                  ),
                ),
                const SizedBox(height: BldSpacing.xs),
                for (final warning in day.warnings)
                  _WarningRow(warning: warning),
              ],

              if (day.isEmpty) ...[
                const SizedBox(height: BldSpacing.md),
                Text(
                  l10n.planEmpty,
                  style: const TextStyle(
                    fontSize: KdsTextScale.orderNumber,
                    color: Color(KdsColors.onSurfaceMuted),
                  ),
                ),
              ] else ...[
                // ── 2. NE PİŞECEK? ─────────────────────────────────
                const SizedBox(height: BldSpacing.lg),
                _SectionLabel(text: l10n.planTotals),
                Wrap(
                  spacing: BldSpacing.sm,
                  runSpacing: BldSpacing.sm,
                  children: [
                    for (final total in day.totals) _TotalChip(total: total),
                  ],
                ),

                // ── 3. NEREYE, KAÇTA? ──────────────────────────────
                const SizedBox(height: BldSpacing.lg),
                _SectionLabel(text: l10n.planDeliveries),
                for (final order in day.orders) _OrderRow(order: order),
              ],

              const SizedBox(height: BldSpacing.lg),
              _PrintPlanButton(day: day),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarningRow extends StatelessWidget {
  const _WarningRow({required this.warning});

  final PlanWarning warning;

  @override
  Widget build(BuildContext context) {
    // KRİTİK UYARI KIRMIZI, diğerleri sarı. "Üretim koşmamış" eylem
    // gerektiriyor; "bir abonelik atlandı" yalnız bilgi. İkisini aynı
    // renkte göstermek, kırmızının anlamını yok eder.
    final color = Color(
      warning.isCritical ? BldColors.danger : BldColors.warning,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: BldSpacing.xs),
      padding: const EdgeInsets.all(BldSpacing.md),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(BldRadius.sm),
      ),
      child: Row(
        children: [
          Icon(
            warning.isCritical ? Icons.error : Icons.info_outline,
            size: 26,
            color: const Color(BldColors.neutral900),
          ),
          const SizedBox(width: BldSpacing.sm),
          Expanded(
            child: Text(
              warning.message,
              style: const TextStyle(
                fontSize: KdsTextScale.statusBar,
                fontWeight: FontWeight.bold,
                color: Color(BldColors.neutral900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ürün toplamı — mutfağın bir metreden okuduğu sayı.
class _TotalChip extends StatelessWidget {
  const _TotalChip({required this.total});

  final PlanTotal total;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: BldSpacing.md,
      vertical: BldSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: const Color(KdsColors.surfaceRaised),
      borderRadius: BorderRadius.circular(BldRadius.sm),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${total.quantity}',
          style: const TextStyle(
            fontSize: KdsTextScale.quantity,
            fontWeight: FontWeight.bold,
            color: Color(BldColors.brand400),
          ),
        ),
        const SizedBox(width: BldSpacing.sm),
        Text(
          total.name,
          style: const TextStyle(fontSize: KdsTextScale.itemName),
        ),
      ],
    ),
  );
}

/// Teslimat satırı — saat, kurum ve **durum ilerletme**.
///
/// İLERLETME BURADA DA VAR: abonelik siparişleri panoda da duruyor ama
/// mutfak sabah bu ekranda çalışıyor. Panoya dönüp aynı siparişi orada
/// bulmak zorunda kalmak, ekranı yalnız "bakılan" bir yer yapardı.
class _OrderRow extends ConsumerWidget {
  const _OrderRow({required this.order});

  final PlanOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final busy = ref.watch(orderActionProvider).contains(order.id);
    final next = OrderStatusMachine.nextForward(
      order.status,
      DeliveryType.delivery,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BldSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              order.deliveryTime ?? l10n.planNoTime,
              style: const TextStyle(
                fontSize: KdsTextScale.orderNumber,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.label ?? order.orderNumber,
                  style: const TextStyle(fontSize: KdsTextScale.orderNumber),
                ),
                Text(
                  order.items
                      .map((item) => '${item.quantity}× ${item.name}')
                      .join(', '),
                  style: const TextStyle(
                    fontSize: KdsTextScale.statusBar,
                    color: Color(KdsColors.onSurfaceMuted),
                  ),
                ),
                if (order.note != null)
                  Text(
                    order.note!,
                    style: const TextStyle(
                      fontSize: KdsTextScale.statusBar,
                      color: Color(KdsColors.noteForeground),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: BldSpacing.md),
          if (next != null)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(150, 56)),
              onPressed: busy
                  ? null
                  : () => unawaited(advanceOrder(context, ref, order.id)),
              child: Text(
                orderStatusLabelsTr[next] ?? next.wireName,
                style: const TextStyle(fontSize: KdsTextScale.statusBar),
              ),
            )
          else
            Text(
              orderStatusLabelsTr[order.status] ?? order.status.wireName,
              style: const TextStyle(
                fontSize: KdsTextScale.statusBar,
                color: Color(KdsColors.onSurfaceMuted),
              ),
            ),
        ],
      ),
    );
  }
}

/// Üretim planı fişini bastırır.
///
/// KUYRUĞA GİRMEZ: bu bir sipariş fişi değil, personelin istediği anda
/// bastığı bir rapor. Kuyruğa girseydi `UNIQUE(order_id, type)` kısıtına
/// takılırdı (sipariş kimliği yok) ve ikinci kez basılamazdı. Açılış test
/// fişiyle aynı yol: `printDiagnostic`.
class _PrintPlanButton extends ConsumerStatefulWidget {
  const _PrintPlanButton({required this.day});

  final PlanDay day;

  @override
  ConsumerState<_PrintPlanButton> createState() => _PrintPlanButtonState();
}

class _PrintPlanButtonState extends ConsumerState<_PrintPlanButton> {
  bool _printing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return FilledButton.tonalIcon(
      onPressed: _printing ? null : () => unawaited(_print()),
      icon: const Icon(Icons.receipt_long_outlined),
      label: Text(l10n.planPrint),
    );
  }

  Future<void> _print() async {
    setState(() => _printing = true);

    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final day = widget.day;

    try {
      await ref
          .read(printServiceProvider)
          .printDiagnostic(
            buildProductionPlanReceipt(
              ProductionPlanData(
                date: day.date.toUtc(),
                printedAt: DateTime.now().toUtc(),
                totals: day.totals
                    .map(
                      (total) => ProductionPlanTotal(
                        name: total.name,
                        quantity: total.quantity,
                      ),
                    )
                    .toList(growable: false),
                deliveries: day.orders
                    .map(
                      (order) => ProductionPlanDelivery(
                        label: order.label ?? order.orderNumber,
                        time: order.deliveryTime,
                        itemCount: order.items.fold(
                          0,
                          (sum, item) => sum + item.quantity,
                        ),
                      ),
                    )
                    .toList(growable: false),
                // Uyarılar FİŞE DE BASILIR: ekranda görünüp kâğıtta
                // görünmezse, tezgâhtaki kâğıda bakan kişi eksik
                // bilgiyle çalışır.
                warnings: day.warnings
                    .map((warning) => warning.message)
                    .toList(growable: false),
              ),
              style: ref.read(receiptStyleProvider),
            ),
          );

      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(BldColors.success),
          content: Text(
            l10n.planPrinted,
            style: const TextStyle(
              fontSize: KdsTextScale.statusBar,
              color: Color(BldColors.neutral900),
            ),
          ),
        ),
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(BldColors.danger),
          content: Text(
            l10n.planPrintFailed('$error'),
            style: const TextStyle(fontSize: KdsTextScale.statusBar),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: BldSpacing.sm),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: KdsTextScale.statusBar,
        fontWeight: FontWeight.bold,
        color: Color(KdsColors.onSurfaceMuted),
      ),
    ),
  );
}
