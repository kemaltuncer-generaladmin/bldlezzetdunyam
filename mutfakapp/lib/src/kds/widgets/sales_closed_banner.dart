/// Satış kapalıyken panonun en üstünde duran kırmızı şerit (K-11).
///
/// NEDEN KALICI VE BÜYÜK: satışı kapatmanın en olası hatası "kapattım,
/// açmayı unuttum". Şerit sürekli görünür ve kalan süreyi sayar; süresiz
/// kapatıldıysa bunu açıkça söyler. Kaybolan ya da küçülen bir uyarı,
/// vardiya ortasında görünmez olur.
///
/// AÇIKKEN HİÇ ÇİZİLMEZ: normal günde panodan tek piksel çalmamalı.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/sales_control.dart';
import '../../l10n/app_localizations.dart';
import '../../sales/sales_control_screen.dart';

class SalesClosedBanner extends ConsumerWidget {
  const SalesClosedBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordering = ref.watch(orderingStateProvider).value;

    // Durum henüz bilinmiyorsa şerit ÇİZİLMEZ. "Bilinmiyorsa kapalı say"
    // demek, her açılışta birkaç saniye yanlış kırmızı şerit göstermekti.
    if (ordering == null || ordering.enabled) return const SizedBox.shrink();

    final l10n = AppL10n.of(context);
    final now = ref.watch(clockProvider).value ?? DateTime.now().toUtc();

    return Material(
      color: const Color(BldColors.danger),
      child: InkWell(
        onTap: () => Navigator.of(context).push(SalesControlScreen.route()),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BldSpacing.md,
            vertical: BldSpacing.sm,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.do_not_disturb_on,
                size: 30,
                color: Color(BldColors.neutral900),
              ),
              const SizedBox(width: BldSpacing.sm),
              Expanded(
                child: Text(
                  l10n.salesBannerClosed(_detail(l10n, ordering, now)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: KdsTextScale.orderNumber,
                    fontWeight: FontWeight.bold,
                    color: Color(BldColors.neutral900),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 30,
                color: Color(BldColors.neutral900),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _detail(AppL10n l10n, OrderingState ordering, DateTime now) {
    final parts = <String>[];

    if (ordering.reason != null) parts.add(ordering.reason!);

    final left = ordering.remaining(now);
    if (left == null) {
      parts.add(l10n.salesClosedIndefinite);
    } else {
      parts.add(
        left.inHours > 0
            ? l10n.salesRemainingHours(left.inHours, left.inMinutes % 60)
            : l10n.salesRemainingMinutes(left.inMinutes),
      );
    }

    return parts.join(' · ');
  }
}
