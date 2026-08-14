/// Teslim süresi tahmini kutusu — menü, sepet, ödeme ve sipariş takibinde
/// aynı görünür.
///
/// **Yoğunluk uyarısı neden burada:** `Location.busy` uygulamada başka hiçbir
/// yerde gösterilmiyor, `eta.busy` ise aynı kaynağı okuyor
/// (`docs/openapi.yaml` `EtaWindow.busy`). Uyarıyı tahminin yanında vermek
/// hem tek yerde tutar hem de bağlamı doğru kurar: kullanıcı uzamış süreyi
/// görürken nedenini de okur. Ayrı bir yoğunluk şeridi eklenirse bu satır
/// kaldırılmalıdır — aynı şey iki kez söylenmez.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../core/eta_text.dart';
import '../theme/bld_semantic_colors.dart';

class EtaNotice extends StatelessWidget {
  const EtaNotice({super.key, required this.eta, this.compact = false});

  final EtaPresentation eta;

  /// Dar yerlerde (menü başlığı) tek satıra iner ve kaynak açıklamasını
  /// gizler. Yoğunluk uyarısı burada da gösterilir.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busyNote = eta.busyNote;

    // Marka tintli "accent" yüzeyi: açık temada brand50 + brand800 yazı,
    // koyu temada #462314 + brand300. İkisi de rol tablosundan geliyor;
    // burada ham renk yok, yoksa koyu temada krem kutu üstünde krem yazı
    // kalırdı.
    final surface = scheme.secondaryContainer;
    final onSurface = scheme.onSecondaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BldSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(BldRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule_outlined, size: 18, color: onSurface),
          const SizedBox(width: BldSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${eta.title}: ${eta.value}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: BldSpacing.xs),
                  Text(
                    eta.sourceNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (busyNote != null) ...[
                  const SizedBox(height: BldSpacing.xs),
                  Text(
                    busyNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.bld.warningFg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
