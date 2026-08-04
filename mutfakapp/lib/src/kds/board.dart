/// KDS panosunun saf iş mantığı — `docs/05-mutfakapp.md` §3.
///
/// Widget içermez, bu yüzden testi ucuzdur: sütunlara dağıtma ve üretim
/// listesi toplamı burada, çizim `kds_screen.dart`'tadır.
library;

import 'package:bld_api_client/bld_api_client.dart';

/// Ekrandaki üç sütun.
enum KdsColumn {
  /// Mutfağın henüz onaylamadığı siparişler. Yanıp sönme ve sesli uyarı
  /// yalnızca bu sütunda olur.
  yeni,

  /// Onaylanmış ve pişirilmekte olanlar.
  hazirlaniyor,

  /// Pişmiş; teslimata ya da müşteriye verilmeyi bekleyenler.
  hazir,
}

/// Beş aktif durumun üç sütuna dağılımı.
///
/// VARSAYIM: doküman üç sütun adı verip beş aktif durum tanımlıyor ama
/// `onaylandi` ile `yolda`'nın hangi sütuna düştüğünü yazmıyor
/// (`docs/BILINMEYENLER.md`). Seçim şu gerekçeyle yapıldı: "YENİ" sütunu
/// **mutfağın henüz görmediği iş** anlamına gelmeli, çünkü 3 saniye kuralı ve
/// sesli uyarı bu sütuna bağlıdır. `ONAYLA` basıldığı anda kart sütun
/// değiştirir, personel neyi hallettiğini görür.
KdsColumn? columnOf(OrderStatus status) => switch (status) {
  OrderStatus.yeni => KdsColumn.yeni,
  OrderStatus.onaylandi || OrderStatus.hazirlaniyor => KdsColumn.hazirlaniyor,
  OrderStatus.hazir || OrderStatus.yolda => KdsColumn.hazir,
  OrderStatus.teslimEdildi || OrderStatus.iptal => null,
};

/// Siparişleri sütunlara dağıtır. Gelen sıra korunur (en eski üstte).
Map<KdsColumn, List<KitchenOrder>> groupIntoColumns(List<KitchenOrder> orders) {
  final board = <KdsColumn, List<KitchenOrder>>{
    for (final column in KdsColumn.values) column: <KitchenOrder>[],
  };

  for (final order in orders) {
    final column = columnOf(order.status);
    if (column != null) board[column]!.add(order);
  }

  return board;
}

/// Üretim şeridindeki tek satır.
class ProductionTotal {
  const ProductionTotal({required this.name, required this.quantity});

  final String name;
  final int quantity;
}

/// Üst şeridin içeriği: hazırlanacak ürünlerin adet toplamı, çoktan aza.
///
/// Sözleşmede `GET /kitchen/production-list` ucu var ama yerelde hesaplanır:
/// aynı veri zaten elde, ayrıca çekmek 5 saniyede bir ikinci istek demek
/// olurdu ve cihaz başına saatlik istek sınırını (`docs/openapi.yaml` §Oran
/// sınırları) ikiye katlardı. Kural sözleşmeyle aynıdır: `onaylandi` ve
/// `hazirlaniyor` durumundaki siparişler sayılır.
List<ProductionTotal> productionTotals(List<KitchenOrder> orders) {
  final totals = <String, int>{};

  for (final order in orders) {
    if (order.status != OrderStatus.onaylandi &&
        order.status != OrderStatus.hazirlaniyor) {
      continue;
    }
    for (final item in order.items) {
      totals[item.name] = (totals[item.name] ?? 0) + item.quantity;
    }
  }

  final rows =
      [
        for (final entry in totals.entries)
          ProductionTotal(name: entry.key, quantity: entry.value),
      ]..sort((a, b) {
        final byQuantity = b.quantity.compareTo(a.quantity);
        return byQuantity != 0 ? byQuantity : a.name.compareTo(b.name);
      });

  return List<ProductionTotal>.unmodifiable(rows);
}

/// [order] için istenen teslim saati geçmiş mi? Geçmişse kartta kırmızı yazar.
bool isRequestedTimeLate(KitchenOrder order, DateTime now) {
  final requested = order.requestedAt;
  return requested != null && requested.isBefore(now);
}
