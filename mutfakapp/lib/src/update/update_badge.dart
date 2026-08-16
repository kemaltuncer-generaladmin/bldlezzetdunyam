/// Durum çubuğundaki güncelleme rozeti — `docs/05-mutfakapp.md` §9.
///
/// Saatlik denetim yeni bir sürüm bulduğunda çıkan tek görsel iz budur.
/// Kurulumu BAŞLATMAZ; dokunulduğunda ne yapılacağını söyler. Gerekçesi
/// `update_checker.dart` başlığında: kurulum uygulamayı yeniden başlatıyor
/// ve bunun ne zaman olacağına mutfağın müsaitliğini bilen insan karar
/// vermeli.
///
/// GÜNCELLEME YOKSA ÇİZİLMEZ: normal kasada durum çubuğundan yer çalmaz —
/// `LockBadge` ile aynı davranış.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../l10n/app_localizations.dart';

class UpdateBadge extends ConsumerWidget {
  const UpdateBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(updateCheckProvider);
    if (!status.updateAvailable) return const SizedBox.shrink();

    final l10n = AppL10n.of(context);
    final latest = status.latest ?? '';

    return Padding(
      padding: const EdgeInsets.only(right: BldSpacing.lg),
      child: Tooltip(
        message: l10n.updateBadgeTooltip(latest),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Rozete dokunmak yalnızca ipucunu gösterir; kurulum ayarlar
          // ekranından. Buraya bir kurulum kısayolu koymak, mutfakta yanlışlıkla
          // dokunulan bir yerin ekranı yeniden başlatması demek olurdu.
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.updateBadgeTooltip(latest))),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.system_update_alt,
                size: 20,
                color: Color(BldColors.info),
              ),
              const SizedBox(width: BldSpacing.xs),
              Text(
                l10n.updateBadge,
                style: const TextStyle(
                  fontSize: KdsTextScale.statusBar,
                  fontWeight: FontWeight.bold,
                  color: Color(BldColors.info),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
