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
import '../theme/bld_theme.dart';

class EtaNotice extends StatelessWidget {
  const EtaNotice({super.key, required this.eta, this.compact = false});

  final EtaPresentation eta;

  /// Dar yerlerde (menü başlığı) tek satıra iner ve kaynak açıklamasını
  /// gizler. Yoğunluk uyarısı burada da gösterilir.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final busyNote = eta.busyNote;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BldSpacing.md),
      decoration: BoxDecoration(
        color: bldColor(BldColors.brand50),
        borderRadius: BorderRadius.circular(BldRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule, size: 18, color: bldColor(BldColors.brand700)),
          const SizedBox(width: BldSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${eta.title}: ${eta.value}',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: bldColor(BldColors.brand900),
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: BldSpacing.xs),
                  Text(
                    eta.sourceNote,
                    style: textTheme.bodySmall?.copyWith(
                      color: bldColor(BldColors.neutral600),
                    ),
                  ),
                ],
                if (busyNote != null) ...[
                  const SizedBox(height: BldSpacing.xs),
                  Text(
                    busyNote,
                    style: textTheme.bodySmall?.copyWith(
                      color: bldColor(BldColors.warning),
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
