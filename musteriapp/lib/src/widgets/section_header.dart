/// Bölüm başlığı — başlık + isteğe bağlı "tümü" eylemi.
///
/// Ana sayfadaki özel `_SectionHeader`'ın yerini alır; artık birçok ekran
/// (hesabım, abonelikler, ekstre) aynı ritmi paylaşır.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(
      BldSpacing.md,
      BldSpacing.lg,
      BldSpacing.sm,
      BldSpacing.sm,
    ),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            // `titleLarge` = h3 (21/28), serif, marka kahvesi. Bölüm başlığı
            // bir İSİMDİR; işlevsel metin değil.
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (actionLabel != null)
            // Dokunma hedefi kırpılmıyor: eskiden `minimumSize: Size.zero` +
            // `shrinkWrap` ile "tümü" bağlantısı ~20 px yüksekliğinde bir
            // hedefe iniyordu. Asgari 44×44 tema düzeyinde veriliyor, burada
            // yalnız yatay dolgu daraltılıyor.
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: BldSpacing.sm),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
