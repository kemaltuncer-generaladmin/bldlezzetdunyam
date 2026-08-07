/// Alt gezinme çubuğu: Menü / Siparişlerim / Hesabım.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/infra_providers.dart';
import '../../widgets/cart_bar.dart';
import '../../widgets/status_views.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final offline = ref.watch(connectivityProvider);

    return Scaffold(
      body: Column(
        children: [
          if (offline) OfflineBanner(message: l10n.offlineMenuNotice),
          Expanded(child: navigationShell),
        ],
      ),
      // Sepet çubuğu gezinmenin ÜSTÜNDE: sekme değiştirmek onu
      // kaybettirmemeli, çünkü sorun tam olarak "sepeti bulamıyorum"du.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CartBar(),
          NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Aynı sekmeye tekrar basmak o sekmenin köküne döner.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.restaurant_menu_outlined),
            selectedIcon: const Icon(Icons.restaurant_menu),
            label: l10n.navMenu,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: l10n.navOrders,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.navAccount,
          ),
            ],
          ),
        ],
      ),
    );
  }
}
