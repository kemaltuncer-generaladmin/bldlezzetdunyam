/// Alt gezinme çubuğu: Ana Sayfa / Menü / Aboneliklerim / Siparişlerim / Hesabım.
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

    // Android geri tuşu: alt sekmelerdeyken uygulamadan çıkmak yerine önce
    // Ana Sayfa sekmesine döner; yalnızca Ana Sayfa kökündeyken çıkışa izin
    // verir (beklenen Android davranışı). Push edilen ekranlar zaten kendi
    // Navigator'ında normal pop olur, buraya hiç gelmez.
    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
        }
      },
      child: _buildScaffold(context, l10n, offline),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    AppLocalizations l10n,
    bool offline,
  ) {
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
                icon: const Icon(Icons.event_repeat_outlined),
                selectedIcon: const Icon(Icons.event_repeat),
                label: l10n.navSubscriptions,
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
