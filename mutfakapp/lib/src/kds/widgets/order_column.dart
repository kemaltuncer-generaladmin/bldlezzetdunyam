/// Panonun tek sütunu: başlık + kart listesi.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'order_card.dart';

class OrderColumn extends StatelessWidget {
  const OrderColumn({
    required this.title,
    required this.orders,
    required this.highlightedIds,
    required this.onAdvance,
    super.key,
  });

  final String title;
  final List<KitchenOrder> orders;
  final Set<int> highlightedIds;
  final void Function(KitchenOrder order) onAdvance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: BldSpacing.sm),
          child: Text(
            l10n.columnHeader(title, orders.length),
            style: const TextStyle(
              fontSize: KdsTextScale.columnHeader,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: orders.isEmpty
              ? Center(
                  child: Text(
                    l10n.columnEmpty,
                    style: const TextStyle(
                      fontSize: KdsTextScale.statusBar,
                      color: Color(KdsColors.onSurfaceMuted),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: BldSpacing.md),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: BldSpacing.md),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return OrderCard(
                      key: ValueKey<int>(order.id),
                      order: order,
                      highlighted: highlightedIds.contains(order.id),
                      onAdvance: () => onAdvance(order),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
