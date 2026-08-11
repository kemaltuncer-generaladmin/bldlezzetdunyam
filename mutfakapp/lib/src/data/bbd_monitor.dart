/// BBD fiş kuyruğunu işleyen döngü (K-16).
///
/// BBD Store bir **kitap e-ticaret sitesi**; köprünün tek varlık sebebi
/// mutfaktaki termal yazıcıyı paylaşmak. Çıkan kâğıt bir mutfak fişi
/// değil, bir **paketleme fişi**.
///
/// AKIŞ: sunucudan basılmayı bekleyen fişleri çeker → **ses çalar** →
/// **fiş basar** → başarılıysa sunucuya bildirir (ack).
///
/// SUNUCU KUYRUK GÖREVİ GÖRÜYOR, yerel SQLite kuyruğu DEĞİL. İki sebep:
///
///   1. Yerel kuyruğun tekilliği `(order_id, type, revision)` üçlüsüne
///      dayanıyor ve BBD fişinin BLD sipariş kimliği yok. Zorlamak için
///      dördüncü bir `ReceiptType` değeri eklemek gerekirdi; o enum ise
///      veritabanı kısıtında, tetikleyicilerde, ayarlar ekranında ve
///      sözleşmede geçiyor — küçük bir iş için geniş bir yüzey.
///   2. Sunucu zaten `printed_at IS NULL` ile kuyruk tutuyor. Basım
///      başarısızsa **ack gönderilmiyor** ve fiş bir sonraki turda geri
///      geliyor. Yazıcı kapalıyken kasa yeniden başlasa bile fiş
///      kaybolmuyor — yerel kuyruğun verdiği garantinin aynısı, fazladan
///      şema olmadan.
library;

import 'dart:async';

import 'package:bld_core/escpos.dart';

import 'bbd_source.dart';

/// Döngünün dışarıdan görünen durumu.
class BbdMonitorState {
  const BbdMonitorState({
    this.pending = 0,
    this.printedToday = 0,
    this.lastError,
  });

  /// Basılmayı bekleyen fiş sayısı — durum çubuğundaki çip.
  final int pending;

  /// Bu oturumda basılan fiş sayısı.
  final int printedToday;

  /// Son hata; yoksa `null`.
  final String? lastError;

  BbdMonitorState copyWith({
    int? pending,
    int? printedToday,
    String? lastError,
    bool clearError = false,
  }) => BbdMonitorState(
    pending: pending ?? this.pending,
    printedToday: printedToday ?? this.printedToday,
    lastError: clearError ? null : (lastError ?? this.lastError),
  );

  @override
  bool operator ==(Object other) =>
      other is BbdMonitorState &&
      other.pending == pending &&
      other.printedToday == printedToday &&
      other.lastError == lastError;

  @override
  int get hashCode => Object.hash(pending, printedToday, lastError);

  @override
  String toString() =>
      'BbdMonitorState(pending: $pending, printed: $printedToday, '
      'error: $lastError)';
}

/// BBD fişlerini çeken, bastıran ve onaylayan döngü.
///
/// Widget ve Riverpod bilmez: bağımlılıklar geri çağrı olarak geliyor ve
/// testi ucuz.
class BbdMonitor {
  BbdMonitor({
    required BbdApi api,
    required Future<void> Function(List<int> bytes) print,
    required Future<void> Function() playSound,
    ReceiptStyle style = ReceiptStyle.standard,
    DateTime Function()? clock,
  }) : _api = api,
       _print = print,
       _playSound = playSound,
       _style = style,
       _clock = clock ?? DateTime.now;

  final BbdApi _api;
  final Future<void> Function(List<int> bytes) _print;
  final Future<void> Function() _playSound;
  final ReceiptStyle _style;
  final DateTime Function() _clock;

  BbdMonitorState _state = const BbdMonitorState();

  BbdMonitorState get state => _state;

  /// Bir tur: çek, çal, bas, onayla.
  ///
  /// SES BİR KEZ ÇALAR, fiş başına değil: beş fiş birden geldiğinde beş
  /// kez üst üste ses çalmak, mutfağı sesi kapatmaya iter.
  Future<BbdMonitorState> poll() async {
    final List<BbdOrder> orders;

    try {
      orders = await _api.pending();
    } on Object catch (error) {
      _state = _state.copyWith(lastError: '$error');
      return _state;
    }

    if (orders.isEmpty) {
      _state = _state.copyWith(pending: 0, clearError: true);
      return _state;
    }

    _state = _state.copyWith(pending: orders.length, clearError: true);

    // Ses ÖNCE: fiş basımı saniyeler sürebiliyor ve personelin kâğıdı
    // almak için yazıcıya gitmesi o sesle başlıyor.
    await _playQuietly();

    var printed = _state.printedToday;

    for (final order in orders) {
      try {
        await _print(buildBbdReceipt(_toData(order), style: _style));

        // ACK YALNIZ BASIM BAŞARILIYSA. Başarısızsa fiş sunucuda
        // bekliyor kalıyor ve bir sonraki turda geri geliyor — yazıcı
        // kapalıyken kasa yeniden başlasa bile fiş kaybolmuyor.
        await _api.ack(order.id);
        printed++;
      } on Object catch (error) {
        _state = _state.copyWith(printedToday: printed, lastError: '$error');
        return _state;
      }
    }

    _state = BbdMonitorState(pending: 0, printedToday: printed);
    return _state;
  }

  Future<void> _playQuietly() async {
    try {
      await _playSound();
    } on Object {
      // Ses çalınamaması fişin basılmasını engellemez: kâğıt asıl iştir.
    }
  }

  BbdReceiptData _toData(BbdOrder order) => BbdReceiptData(
    orderNumber: order.orderNumber,
    printedAt: _clock().toUtc(),
    createdAt: order.createdAt,
    customerLabel: order.customerLabel,
    customerPhone: order.customerPhone,
    address: order.address,
    note: order.note,
    deliveryType: order.deliveryType,
    amount: order.amountKurus,
    cargoCompany: order.cargoCompany,
    trackingNumber: order.trackingNumber,
    paymentLabel: order.paymentLabel,
    lines: order.items
        .map(
          (item) => BbdReceiptLine(
            quantity: item.quantity,
            name: item.name,
            sku: item.sku,
            attributes: item.attributes,
            note: item.note,
          ),
        )
        .toList(growable: false),
  );
}
