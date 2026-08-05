/// Kalem bazlı "hazır" işaretleri.
///
/// Beş kalemlik bir siparişte aşçı üçünü tencereye koyup ikisini beklemeye
/// aldığında, bunu aklında tutmak zorunda kalmamalı — özellikle vardiya
/// değişiminde devralan kişi hiçbir şey bilmez. İşaretler **yerel**dir ve
/// sunucuya gitmez: sözleşmede kalem durumu yok (`docs/openapi.yaml`) ve
/// uydurmak yasak (AGENTS.md §6).
///
/// Sonuç olarak işaretler uygulama yeniden başlarsa kaybolur. Bu bilinçli bir
/// takas: yarım kalmış bir işaret listesini diskte tutup yanlış siparişe
/// eşlemek, hiç tutmamaktan tehlikelidir.
library;

/// Değişmez işaret kümesi: sipariş kimliği → hazır kalem indeksleri.
class OrderItemProgress {
  const OrderItemProgress._(this._byOrder);

  /// Hiçbir kalemin işaretlenmediği başlangıç durumu.
  static const OrderItemProgress empty = OrderItemProgress._(<int, Set<int>>{});

  final Map<int, Set<int>> _byOrder;

  /// [orderId] siparişinin [itemIndex] numaralı kalemi hazır mı?
  bool isDone(int orderId, int itemIndex) =>
      _byOrder[orderId]?.contains(itemIndex) ?? false;

  /// [orderId] siparişinde kaç kalem hazır işaretli?
  int doneCount(int orderId) => _byOrder[orderId]?.length ?? 0;

  /// [itemCount] kalemin hepsi işaretli mi? Kalemsiz sipariş "bitmiş" sayılmaz.
  bool allDone(int orderId, int itemCount) =>
      itemCount > 0 && doneCount(orderId) >= itemCount;

  /// Bir kalemin işaretini ters çevirir.
  OrderItemProgress toggle(int orderId, int itemIndex) {
    final next = <int, Set<int>>{
      for (final entry in _byOrder.entries) entry.key: Set<int>.of(entry.value),
    };
    final marks = next.putIfAbsent(orderId, () => <int>{});

    if (!marks.remove(itemIndex)) marks.add(itemIndex);
    if (marks.isEmpty) next.remove(orderId);

    return OrderItemProgress._(next);
  }

  /// Bir siparişin tüm işaretlerini siler — kart ekrandan düştüğünde.
  OrderItemProgress clearOrder(int orderId) {
    if (!_byOrder.containsKey(orderId)) return this;
    final next = <int, Set<int>>{
      for (final entry in _byOrder.entries)
        if (entry.key != orderId) entry.key: Set<int>.of(entry.value),
    };
    return OrderItemProgress._(next);
  }

  /// Yalnızca ekranda duran siparişlerin işaretlerini korur.
  ///
  /// Bu olmadan harita vardiya boyunca büyür ve — daha kötüsü — sunucu bir
  /// sipariş kimliğini yeniden kullanırsa eski işaretler yeni siparişe yapışır.
  OrderItemProgress retaining(Set<int> liveOrderIds) {
    if (_byOrder.keys.every(liveOrderIds.contains)) return this;
    return OrderItemProgress._(<int, Set<int>>{
      for (final entry in _byOrder.entries)
        if (liveOrderIds.contains(entry.key))
          entry.key: Set<int>.of(entry.value),
    });
  }

  /// İşaret taşıyan sipariş sayısı — yalnızca test ve teşhis için.
  int get trackedOrderCount => _byOrder.length;
}
