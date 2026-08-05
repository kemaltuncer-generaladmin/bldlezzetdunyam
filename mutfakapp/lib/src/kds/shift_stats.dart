/// Vardiya özeti — "bugün nasıl gitti" sorusunun cevabı.
///
/// Bir KDS yalnızca şu anı göstermekle yetinemez: şef akşam üstü "kaç sipariş
/// çıktı, ortalama ne kadar sürdü, hangisi bizi yaktı" diye sorar. Sunucuda
/// böyle bir uç yok (`docs/openapi.yaml`) ve uydurmak yasak (AGENTS.md §6),
/// bu yüzden sayaçlar **ekranın gördüğünden** türetilir.
///
/// Sınırı açıkça söylüyoruz: uygulama yeniden başlarsa sayaçlar sıfırlanır ve
/// arayüz bunu yazar. Yanlış bir "bugün 0 sipariş" iddiası, hiç iddia
/// etmemekten kötüdür.
library;

import 'package:bld_api_client/bld_api_client.dart';

/// Bir vardiyanın (uygulama oturumunun) sayaçları.
class ShiftStats {
  const ShiftStats({
    required this.seenCount,
    required this.readyCount,
    required this.totalPrep,
    this.slowestOrderNumber,
    this.slowestPrep,
  });

  static const ShiftStats empty = ShiftStats(
    seenCount: 0,
    readyCount: 0,
    totalPrep: Duration.zero,
  );

  /// Ekranda görülmüş farklı sipariş sayısı.
  final int seenCount;

  /// `hazir` ya da ötesine geçtiği görülen sipariş sayısı.
  final int readyCount;

  /// Ölçülen hazırlanma sürelerinin toplamı.
  final Duration totalPrep;

  /// En uzun süren siparişin numarası.
  final String? slowestOrderNumber;

  /// O siparişin hazırlanma süresi.
  final Duration? slowestPrep;

  /// Ortalama hazırlanma süresi; ölçüm yoksa `null`.
  Duration? get averagePrep => readyCount == 0
      ? null
      : Duration(microseconds: totalPrep.inMicroseconds ~/ readyCount);

  @override
  bool operator ==(Object other) =>
      other is ShiftStats &&
      other.seenCount == seenCount &&
      other.readyCount == readyCount &&
      other.totalPrep == totalPrep &&
      other.slowestOrderNumber == slowestOrderNumber &&
      other.slowestPrep == slowestPrep;

  @override
  int get hashCode => Object.hash(
    seenCount,
    readyCount,
    totalPrep,
    slowestOrderNumber,
    slowestPrep,
  );

  @override
  String toString() =>
      'ShiftStats(seen: $seenCount, ready: $readyCount, '
      'avg: $averagePrep, slowest: $slowestOrderNumber $slowestPrep)';
}

/// Sipariş yayınlarını [ShiftStats]'e çeviren biriktirici.
///
/// Saf: zamanlayıcı kurmaz, ağa gitmez, widget bilmez.
class ShiftStatsTracker {
  final Set<int> _seen = <int>{};
  final Set<int> _measured = <int>{};

  ShiftStats _stats = ShiftStats.empty;

  ShiftStats get stats => _stats;

  /// Yeni bir sipariş listesi geldi.
  ///
  /// Hazırlanma süresi `updatedAt - createdAt` ile ölçülür: sipariş `hazir`
  /// olduğu anda sunucu `updated_at`'i o ana çeker, yani ikisinin farkı
  /// siparişin girişten pişmeye kadar geçen toplam süresidir. Ölçüm sipariş
  /// başına **bir kez** yapılır; `yolda`/`teslim_edildi` geçişleri
  /// `updated_at`'i ileri taşır ve tekrar ölçmek süreyi şişirirdi.
  ShiftStats apply(List<KitchenOrder> orders) {
    var seen = _stats.seenCount;
    var ready = _stats.readyCount;
    var total = _stats.totalPrep;
    var slowestNumber = _stats.slowestOrderNumber;
    var slowest = _stats.slowestPrep;

    for (final order in orders) {
      if (_seen.add(order.id)) seen++;

      if (!_isReadyOrBeyond(order.status)) continue;
      if (!_measured.add(order.id)) continue;

      // Sunucu ve kasa saatleri birbirini tutmayabilir; negatif süre ölçüm
      // değil hatadır ve ortalamayı bozar.
      final prep = order.updatedAt.toUtc().difference(order.createdAt.toUtc());
      if (prep.isNegative) continue;

      ready++;
      total += prep;
      if (slowest == null || prep > slowest) {
        slowest = prep;
        slowestNumber = order.orderNumber;
      }
    }

    _stats = ShiftStats(
      seenCount: seen,
      readyCount: ready,
      totalPrep: total,
      slowestOrderNumber: slowestNumber,
      slowestPrep: slowest,
    );
    return _stats;
  }

  static bool _isReadyOrBeyond(OrderStatus status) => switch (status) {
    OrderStatus.hazir ||
    OrderStatus.yolda ||
    OrderStatus.teslimEdildi => true,
    OrderStatus.yeni ||
    OrderStatus.onaylandi ||
    OrderStatus.hazirlaniyor ||
    OrderStatus.iptal => false,
  };
}
