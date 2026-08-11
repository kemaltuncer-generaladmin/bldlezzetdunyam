/// `K-06` — otomatik yazdırma tetikleri (`docs/05-mutfakapp.md` §5.5).
///
/// | Olay | Fiş |
/// |---|---|
/// | Mutfak siparişi **onayladı** (`onaylandi`) | Mutfak fişi |
/// | Durum **`hazir`** yapıldı | Müşteri fişi |
/// | Durum **`hazir`** + adrese gönderim | Kurye fişi (K-14) |
/// | **Revizyon numarası arttı** | Mutfak + kurye fişi yeniden |
///
/// Düzenlenmemiş bir gel-al siparişi başına **iki**, adrese gönderim
/// başına **üç** fiş çıkar. Kurye fişi gel-al'da basılmaz: kurye yok.
///
/// Mutfak fişi `yeni` durumunda BASILMAZ: sipariş henüz kabul edilmemiştir
/// ve müşteri iptal edebilir (`docs/03` §4 — iptal `yeni` ve `onaylandi`
/// durumlarında serbest). `yeni`de basmak, iptal edilen her sipariş için
/// çöpe giden bir fiş demekti.
///
/// İnsan müdahalesi yoktur. Tetikler yalnızca **kuyruğa yazar**; basımı
/// `PrintService` yapar ve tekillik veritabanındaki
/// `UNIQUE(order_id, type, revision)` kısıtıyla garanti altındadır. Bu yüzden tetiğin fazladan çalışması
/// zararsızdır — uygulama yeniden başlayıp tüm liste "yeni" gibi geldiğinde
/// bile ikinci fiş çıkmaz.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';

/// Sipariş listesindeki değişimleri yazdırma işlerine çeviren saf mantık.
///
/// Widget ve Riverpod bilmez: girdi sipariş listesi, çıktı kuyruğa eklenecek
/// işler. Testi bu yüzden ucuzdur.
class PrintTriggers {
  /// Hangi işlerin kuyruğa gireceğine karar verir.
  ///
  /// Her iki eşik de "**o durum ya da ötesi**" diye okunur, "tam o durum"
  /// diye değil: sipariş `hazir` iken uygulama kapanıp `yolda` iken
  /// açılırsa fiş hiç basılmamış olabilir. Fazladan çağrı, kuyruktaki
  /// `UNIQUE(order_id, type)` sayesinde bedava.
  List<PrintTriggerJob> jobsFor(List<KitchenOrder> orders) {
    final jobs = <PrintTriggerJob>[];

    for (final order in orders) {
      final revision = order.revisionNo;

      // REVİZYON ARTTIYSA hafıza sıfırlanır ve fişler yeniden tetiklenir
      // (K-14). Sıfırlanmasaydı, düzenlenen siparişin fişi hiç
      // basılmazdı: `_acceptedOrders` onu zaten "basıldı" sayıyordu ve
      // mutfak eski adedi hazırlamaya devam ederdi.
      //
      // MÜŞTERİ FİŞİ YENİDEN BASILMAZ: o fiş müşterinin eline geçiyor ve
      // ikinci bir kopya yalnız kafa karıştırır. Mutfağın ve kuryenin
      // elindeki kâğıt ise güncel olmak zorunda.
      final known = _revisions[order.id];
      if (known != null && revision > known) {
        _acceptedOrders.remove(order.id);
        _courierOrders.remove(order.id);
      }
      _revisions[order.id] = revision;

      if (_isAcceptedOrBeyond(order.status) && _acceptedOrders.add(order.id)) {
        jobs.add(PrintTriggerJob(order.id, ReceiptType.mutfak, revision));
      }
      if (_isReadyOrBeyond(order.status) && _readyOrders.add(order.id)) {
        jobs.add(PrintTriggerJob(order.id, ReceiptType.musteri, revision));
      }
      // Kurye fişi YALNIZ adrese gönderimde: gel-al siparişini müşteri
      // kendisi alıyor, kurye fişi çöpe giden bir kâğıt olurdu.
      if (order.deliveryType == DeliveryType.delivery &&
          _isReadyOrBeyond(order.status) &&
          _courierOrders.add(order.id)) {
        jobs.add(PrintTriggerJob(order.id, ReceiptType.kurye, revision));
      }
    }

    return jobs;
  }

  /// Mutfak fişi tetiklenmiş siparişler (bu oturumda).
  final Set<int> _acceptedOrders = <int>{};

  /// Müşteri fişi tetiklenmiş siparişler.
  final Set<int> _readyOrders = <int>{};

  /// Kurye fişi tetiklenmiş siparişler.
  final Set<int> _courierOrders = <int>{};

  /// Sipariş başına son görülen revizyon numarası.
  final Map<int, int> _revisions = <int, int>{};

  /// Onaylandı ya da ötesi. `yeni` ve `iptal` dışarıda kalır.
  static bool _isAcceptedOrBeyond(OrderStatus status) => switch (status) {
    OrderStatus.onaylandi ||
    OrderStatus.hazirlaniyor ||
    OrderStatus.hazir ||
    OrderStatus.yolda ||
    OrderStatus.teslimEdildi => true,
    OrderStatus.yeni || OrderStatus.iptal => false,
  };

  /// Hazır ya da ötesi. `teslim_edildi` DAHİLDİR: gel-al siparişleri
  /// `hazir`'dan doğrudan oraya geçer ve arada bir yayın kaçarsa müşteri
  /// fişi hiç basılmazdı.
  static bool _isReadyOrBeyond(OrderStatus status) => switch (status) {
    OrderStatus.hazir || OrderStatus.yolda || OrderStatus.teslimEdildi => true,
    OrderStatus.yeni ||
    OrderStatus.onaylandi ||
    OrderStatus.hazirlaniyor ||
    OrderStatus.iptal => false,
  };
}

/// Kuyruğa girecek tek iş.
class PrintTriggerJob {
  const PrintTriggerJob(this.orderId, this.type, [this.revision = 0]);

  final int orderId;
  final ReceiptType type;

  /// Siparişin kaçıncı revizyonu için basılıyor. Kuyruk tekilliğinin
  /// üçüncü parçası.
  final int revision;

  @override
  bool operator ==(Object other) =>
      other is PrintTriggerJob &&
      other.orderId == orderId &&
      other.type == type &&
      other.revision == revision;

  @override
  int get hashCode => Object.hash(orderId, type, revision);

  @override
  String toString() =>
      'PrintTriggerJob($orderId, ${type.wireName}, rev $revision)';
}
