/// Üst şerit: hazırlanacak ürünlerin adet toplamı — `docs/05-mutfakapp.md` §3.
///
/// Aşçının "bugün kaç tavuk sote" sorusuna cevap veren tek yer burasıdır;
/// kartları tek tek saymak yerine tencere planı buradan yapılır. Bu yüzden
/// rakam ürün adından daha iri ve daha parlaktır.
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
      decoration: const BoxDecoration(
        color: Color(KdsColors.surface),
        border: Border(
          top: BorderSide(color: Color(BldColors.brand500), width: 3),
        ),
      ),
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
                              right: BldSpacing.sm,
                            ),
                            child: _TotalChip(total: total),
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

/// Tek ürün toplamı. Rakam solda ve iri: göz önce sayıyı, sonra adı okur.
class _TotalChip extends StatelessWidget {
  const _TotalChip({required this.total});

  final ProductionTotal total;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: BldSpacing.sm,
      vertical: BldSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: const Color(KdsColors.surfaceRaised),
      borderRadius: BorderRadius.circular(BldRadius.sm),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '${total.quantity}',
          style: const TextStyle(
            fontSize: KdsTextScale.itemName,
            fontWeight: FontWeight.bold,
            color: Color(BldColors.brand400),
          ),
        ),
        const SizedBox(width: BldSpacing.xs),
        Text(
          total.name,
          style: const TextStyle(fontSize: KdsTextScale.statusBar),
        ),
      ],
    ),
  );
}
