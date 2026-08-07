/// Sepete gitme çubuğu — sepet doluyken alt gezinmenin üstünde durur.
///
/// NEDEN KABUKTA, TEK BİR EKRANDA DEĞİL: bu çubuk önceden yalnızca menü
/// ekranındaydı. Ürün ekleyip ana sayfaya, siparişlerine ya da hesabına
/// geçen kullanıcının sepete dönmek için önce menüye geri gelmesi
/// gerekiyordu — sepetin nerede olduğu görünmüyordu. Artık hangi sekmede
/// olursa olsun elinin altında.
///
/// Sepet boşken hiç çizilmiyor: boş bir "sepetiniz boş" şeridi her ekranda
/// yer kaplar ve hiçbir şey söylemez.
library;

import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/cart/cart_controller.dart';
import '../l10n/app_localizations.dart';
import '../router/app_router.dart';

class CartBar extends ConsumerWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cart = ref.watch(cartProvider);
    if (cart.isEmpty) return const SizedBox.shrink();

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BldSpacing.md,
          BldSpacing.sm,
          BldSpacing.md,
          BldSpacing.sm,
        ),
        child: FilledButton(
          onPressed: () => context.push(Routes.cart),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ürün ADEDİ rozette: "Sepet · 370,00 ₺" tek başına kaç ürün
              // olduğunu söylemiyordu ve kullanıcı yanlışlıkla iki kez
              // eklediğini ancak sepeti açınca görüyordu.
              Badge(
                label: Text('${cart.itemCount}'),
                child: const Icon(Icons.shopping_basket_outlined, size: 20),
              ),
              const SizedBox(width: BldSpacing.md),
              Text(l10n.menuCartButton(Money.format(cart.subtotal))),
            ],
          ),
        ),
      ),
    );
  }
}
