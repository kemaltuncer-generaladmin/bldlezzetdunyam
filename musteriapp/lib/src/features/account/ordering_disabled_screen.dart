/// Sipariş kapalı bilgi ekranı.
///
/// B2B geçişi: yalnız kurumsal onaylı hesaplar sipariş verir. Sipariş
/// yüzeylerine (sepet/ödeme) girmeye çalışan `can_order = false` bir kullanıcı
/// buraya yönlendirilir. Menü/keşif serbest kaldığından bu bir çıkmaz değil,
/// bir açıklamadır.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/empty_view.dart';

class OrderingDisabledScreen extends StatelessWidget {
  const OrderingDisabledScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.orderingDisabledTitle)),
      body: EmptyView(
        icon: Icons.lock_outline,
        title: l10n.orderingDisabledTitle,
        message: l10n.orderingDisabledBody,
        actionLabel: l10n.navMenu,
        onAction: () => context.go('/menu'),
      ),
    );
  }
}
