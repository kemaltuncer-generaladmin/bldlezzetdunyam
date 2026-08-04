/// Üst şerit: hazırlanacak ürünlerin adet toplamı — `docs/05-mutfakapp.md` §3.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board.dart';

class ProductionStrip extends StatelessWidget {
  const ProductionStrip({required this.totals, super.key});

  final List<ProductionTotal> totals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Container(
      width: double.infinity,
      color: const Color(KdsColors.surface),
      padding: const EdgeInsets.symmetric(
        horizontal: BldSpacing.md,
        vertical: BldSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            l10n.productionStripTitle,
            style: const TextStyle(
              fontSize: KdsTextScale.statusBar,
              fontWeight: FontWeight.bold,
              color: Color(BldColors.brand400),
            ),
          ),
          const SizedBox(width: BldSpacing.lg),
          Expanded(
            child: totals.isEmpty
                ? Text(
                    l10n.productionStripEmpty,
                    style: const TextStyle(
                      fontSize: KdsTextScale.statusBar,
                      color: Color(KdsColors.onSurfaceMuted),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final total in totals)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: BldSpacing.lg,
                            ),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: '${total.name} '),
                                  TextSpan(
                                    text: '${total.quantity}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(BldColors.brand400),
                                    ),
                                  ),
                                ],
                              ),
                              style: const TextStyle(
                                fontSize: KdsTextScale.orderNumber,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
