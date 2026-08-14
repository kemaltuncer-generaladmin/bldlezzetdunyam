/// Sepete ekleme geri bildirimi — menü ekranı ve kalem detayı ORTAK kullanır.
///
/// NEDEN AYRI DOSYA: sepetin başka bir güne bağlıyken boşaltıldığı uyarısı iki
/// yerden birden çıkıyor (paket kartı ve kalem detayı). İki yerde ayrı ayrı
/// yazıldığında biri uyarıyı gösteriyor, diğeri yalnızca "eklendi" diyordu —
/// aynı olayın iki farklı anlatımı, kullanıcının sepetini kaybettiğini
/// anlamasını tesadüfe bırakıyordu.
library;

import 'package:bld_core/bld_core.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../cart/cart_controller.dart';

/// [CartNotifier.add] sonucunu kullanıcıya anlatır.
///
/// Gün değişimi uyarısı daha UZUN duruyor: "eklendi" bilgisi kaçırılabilir,
/// "önceki sepetiniz silindi" kaçırılmamalı.
void showCartAddFeedback(
  BuildContext context,
  CartAddResult result, {
  required String itemName,
  required String date,
}) {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final (String message, Duration duration) = switch (result) {
    CartAddResult.added => (
      l10n.productAdded(itemName),
      const Duration(seconds: 2),
    ),
    CartAddResult.addedAfterDayChange => (
      l10n.cartDayChanged(BusinessDate.long(date)),
      const Duration(seconds: 6),
    ),
    CartAddResult.rejected => (
      l10n.menuItemUnavailable,
      const Duration(seconds: 3),
    ),
  };

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(content: Text(message), duration: duration),
  );
}
