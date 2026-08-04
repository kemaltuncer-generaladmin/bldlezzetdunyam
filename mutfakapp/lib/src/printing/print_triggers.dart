/// `K-06` — otomatik yazdırma tetikleri (`docs/05-mutfakapp.md` §5.5).
///
/// | Olay | Fiş |
/// |---|---|
/// | Yeni sipariş listeye geldi | Mutfak fişi |
/// | Durum `hazir` yapıldı | Müşteri fişi |
///
/// İnsan müdahalesi yoktur. Tetikler yalnızca **kuyruğa yazar**; basımı
/// `PrintService` yapar ve tekillik veritabanındaki `UNIQUE(order_id, type)`
/// kısıtıyla garanti altındadır. Bu yüzden tetiğin fazladan çalışması
/// zararsızdır — uygulama yeniden başlayıp tüm liste "yeni" gibi geldiğinde
/// bile ikinci fiş çıkmaz.
library;

import 'package:bld_api_client/bld_api_client.dart';

/// Sipariş listesindeki değişimleri yazdırma işlerine çeviren saf mantık.
///
/// Widget ve Riverpod bilmez: girdi sipariş listesi, çıktı kuyruğa eklenecek
/// işler. Testi bu yüzden ucuzdur.
class PrintTriggers {
  /// Hangi işlerin kuyruğa gireceğine karar verir.
  ///
  /// `hazir`'ı geçmiş siparişler de müşteri fişi üretir: sipariş `hazir`
  /// iken uygulama kapanır ve `yolda` iken açılırsa fiş hiç basılmamış
  /// olabilir. Fazladan çağrı idempotentlik sayesinde bedava.
  List<PrintTriggerJob> jobsFor(List<KitchenOrder> orders) {
    final jobs = <PrintTriggerJob>[];

    for (final order in orders) {
      if (_seenOrders.add(order.id)) {
        jobs.add(PrintTriggerJob(order.id, ReceiptType.mutfak));
      }
      if (_isReadyOrBeyond(order.status) && _readyOrders.add(order.id)) {
        jobs.add(PrintTriggerJob(order.id, ReceiptType.musteri));
      }
    }

    return jobs;
  }

  /// Mutfak fişi basılmış siparişler (bu oturumda görülenler).
  final Set<int> _seenOrders = <int>{};

  /// Müşteri fişi tetiklenmiş siparişler.
  final Set<int> _readyOrders = <int>{};

  static bool _isReadyOrBeyond(OrderStatus status) =>
      status == OrderStatus.hazir || status == OrderStatus.yolda;
}

/// Kuyruğa girecek tek iş.
class PrintTriggerJob {
  const PrintTriggerJob(this.orderId, this.type);

  final int orderId;
  final ReceiptType type;

  @override
  bool operator ==(Object other) =>
      other is PrintTriggerJob &&
      other.orderId == orderId &&
      other.type == type;

  @override
  int get hashCode => Object.hash(orderId, type);

  @override
  String toString() => 'PrintTriggerJob($orderId, ${type.wireName})';
}
