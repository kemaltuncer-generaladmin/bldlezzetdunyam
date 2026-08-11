/// "Bugün abonelik var" bildirim şeridi + bugün/yarın dökümü.
///
/// Ana pano yalnız bugünü gösterir; abonelik yemekleri önceden hazırlandığı
/// için mutfak yarını da görmek ister (`/kitchen/subscription-orders`). Şerit
/// bugün+yarının abonelik sipariş sayısını üstte toplar; dokununca gün gün
/// döküm açılır: hazırlanacak TOPLAM adetler (yemek kuyruğunu buna göre kurar)
/// ve tek tek siparişler.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../subscription/subscription_plan_screen.dart';
import '../../theme/kds_theme.dart';

class KdsSubscriptionBanner extends ConsumerWidget {
  const KdsSubscriptionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final data = ref.watch(subscriptionOrdersProvider).value;
    if (data == null) return const SizedBox.shrink();

    final today = data.today;
    final tomorrow = data.tomorrow;
    if (today.isEmpty && tomorrow.isEmpty) return const SizedBox.shrink();

    const background = Color(BldColors.brand500);
    final foreground = KdsAccents.onAccent(background);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BldSpacing.md,
        0,
        BldSpacing.md,
        BldSpacing.sm,
      ),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(BldRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(BldRadius.sm),
          // BANNER ARTIK TAM EKRANA GÖTÜRÜYOR (K-15).
          //
          // Eskiden salt-okunur bir pencere açıyordu: kaç sipariş
          // olduğunu söylüyor, NE PİŞECEĞİNİ söylemiyordu. Mutfak "40
          // abonelik var" bilgisiyle hiçbir şey yapamıyor.
          onTap: () =>
              Navigator.of(context).push(SubscriptionPlanScreen.route()),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BldSpacing.md,
              vertical: BldSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(Icons.event_repeat, size: 32, color: foreground),
                const SizedBox(width: BldSpacing.md),
                Text(
                  l10n.subscriptionBannerTitle,
                  style: TextStyle(
                    fontSize: KdsTextScale.columnHeader,
                    fontWeight: FontWeight.bold,
                    color: foreground,
                  ),
                ),
                const SizedBox(width: BldSpacing.md),
                Expanded(
                  child: Text(
                    l10n.subscriptionBannerBreakdown(
                      today.length,
                      tomorrow.length,
                    ),
                    style: TextStyle(
                      fontSize: KdsTextScale.statusBar,
                      color: foreground,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 28, color: foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

/// Tek gün: başlık + hazırlanacak toplamlar + tek tek siparişler.
