/// Boş durum — ikon + başlık + açıklama + isteğe bağlı eylem.
///
/// "Burada bir şey yok" demek yerine boşluğu bir davete çevirir: ne
/// yapılacağını söyler ve varsa eylemi sunar. Sepet, siparişler, abonelikler
/// ve ekstre gibi liste ekranlarının boş hâli buradan gelir.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../theme/bld_theme.dart';

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BldSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: bldColor(BldColors.brand50),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: bldColor(BldColors.brand500)),
            ),
            const SizedBox(height: BldSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge,
            ),
            if (message != null) ...[
              const SizedBox(height: BldSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: bldColor(BldColors.neutral600),
                ),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: BldSpacing.lg),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
