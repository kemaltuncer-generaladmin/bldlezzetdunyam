/// Sözleşme DTO'ları → ESC/POS şablon girdisi dönüşümü.
///
/// `bld_core` zaten `bld_api_client`'ın bağımlılığı olduğu için yazdırma motoru
/// DTO'ları doğrudan göremez (döngü olurdu). Bu dosya iki dünyayı birleştiren
/// tek yerdir; başka hiçbir yerde `KitchenReceipt` → `KitchenReceiptData`
/// dönüşümü yapılmaz.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/escpos.dart';

/// Mutfak fişi DTO'sunu şablon girdisine çevirir.
///
/// [printedAt] fişin basıldığı andır; sözleşmede sipariş oluşturma zamanı
/// bulunmadığı için fiş başlığındaki tarih budur.
KitchenReceiptData toKitchenReceiptData(
  KitchenReceipt receipt, {
  required DateTime printedAt,
}) => KitchenReceiptData(
  orderNumber: receipt.orderNumber,
  deliveryType: receipt.deliveryType,
  printedAt: printedAt,
  requestedAt: receipt.requestedAt,
  // Telefon taşınmazsa kurye kapıda kaldığında arayacak numarayı fişte
  // bulamaz.
  customerPhone: receipt.customerPhone,
  customerNote: receipt.customerNote,
  lines: [
    for (final line in receipt.lines)
      KitchenReceiptLine(
        quantity: line.quantity,
        name: line.name,
        options: line.options,
        note: line.note,
      ),
  ],
);

/// Müşteri fişi DTO'sunu şablon girdisine çevirir.
CustomerReceiptData toCustomerReceiptData(
  CustomerReceipt receipt, {
  required DateTime printedAt,
}) => CustomerReceiptData(
  orderNumber: receipt.orderNumber,
  deliveryType: receipt.deliveryType,
  printedAt: printedAt,
  requestedAt: receipt.requestedAt,
  subtotal: receipt.subtotal,
  deliveryFee: receipt.deliveryFee,
  total: receipt.total,
  paymentMethod: _paymentMethod(receipt.payment.method),
  paymentStatus: _paymentStatus(receipt.payment.status),
  address: receipt.address == null ? null : _address(receipt.address!),
  lines: [
    for (final item in receipt.items)
      CustomerReceiptLine(
        quantity: item.quantity,
        name: item.name,
        lineTotal: item.lineTotal,
        options: item.options,
      ),
  ],
);

ReceiptAddress _address(Address address) => ReceiptAddress(
  line1: address.line1,
  district: address.district,
  city: address.city,
  note: address.note,
  // Koordinat taşınmazsa fişe QR basılmaz ve müşterinin haritada
  // işaretlediği kapı kuryeye hiç ulaşmaz.
  latitude: address.latitude,
  longitude: address.longitude,
);

ReceiptPaymentMethod _paymentMethod(PaymentMethod method) => switch (method) {
  PaymentMethod.online => ReceiptPaymentMethod.online,
  PaymentMethod.cash => ReceiptPaymentMethod.cash,
  PaymentMethod.account => ReceiptPaymentMethod.account,
  PaymentMethod.unknown => ReceiptPaymentMethod.unknown,
};

ReceiptPaymentStatus _paymentStatus(PaymentStatus status) => switch (status) {
  PaymentStatus.pending => ReceiptPaymentStatus.pending,
  PaymentStatus.paid => ReceiptPaymentStatus.paid,
  PaymentStatus.unknown => ReceiptPaymentStatus.unknown,
};
