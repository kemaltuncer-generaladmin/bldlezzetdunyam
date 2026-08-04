/// Sözleşme enum'larının arayüz metinleri.
///
/// `packages/core` ve `packages/api_client` içindeki `*LabelsTr` haritaları
/// l10n kurulana kadar geçerliydi; uygulama artık metni `l10n`'den alır
/// (`AGENTS.md` §4).
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';

import '../l10n/app_localizations.dart';

String orderStatusLabel(OrderStatus status, AppLocalizations l10n) {
  return switch (status) {
    OrderStatus.yeni => l10n.orderStatusYeni,
    OrderStatus.onaylandi => l10n.orderStatusOnaylandi,
    OrderStatus.hazirlaniyor => l10n.orderStatusHazirlaniyor,
    OrderStatus.hazir => l10n.orderStatusHazir,
    OrderStatus.yolda => l10n.orderStatusYolda,
    OrderStatus.teslimEdildi => l10n.orderStatusTeslimEdildi,
    OrderStatus.iptal => l10n.orderStatusIptal,
  };
}

String deliveryTypeLabel(DeliveryType type, AppLocalizations l10n) {
  return switch (type) {
    DeliveryType.delivery => l10n.deliveryTypeDelivery,
    DeliveryType.pickup => l10n.deliveryTypePickup,
  };
}

String paymentMethodLabel(PaymentMethod method, AppLocalizations l10n) {
  return switch (method) {
    PaymentMethod.online => l10n.paymentMethodOnline,
    PaymentMethod.cash => l10n.paymentMethodCash,
    PaymentMethod.account => l10n.paymentMethodAccount,
    PaymentMethod.unknown => l10n.paymentMethodUnknown,
  };
}

String paymentStatusLabel(PaymentStatus status, AppLocalizations l10n) {
  return switch (status) {
    PaymentStatus.pending => l10n.paymentStatusPending,
    PaymentStatus.paid => l10n.paymentStatusPaid,
    PaymentStatus.unknown => l10n.paymentStatusUnknown,
  };
}
