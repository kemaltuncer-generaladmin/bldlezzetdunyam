/// Geçmiş siparişi sepete geri koyma.
///
/// Ayrı dosyada ve arayüzden bağımsız: burada karar var, çizim yok. Bu
/// sayede menüde artık bulunmayan ürünlerin nasıl ele alındığı test
/// edilebiliyor — sepete ne girdiği, ekrandan bakarak anlaşılmıyor.
library;

import 'package:bld_api_client/bld_api_client.dart';

/// Tekrar sipariş girişiminin sonucu.
///
/// [missing] SESSİZCE YUTULMAZ. Menü her gün değişiyor; dünkü siparişin
/// yarısı bugün yoksa kullanıcı bunu bilmeli. Yalnızca "sepete eklendi"
/// deseydik müşteri eksik sipariş verir ve farkı ancak teslimatta görürdü.
class ReorderOutcome {
  const ReorderOutcome({required this.added, required this.missing});

  /// Sepete giren kalem sayısı.
  final int added;

  /// Menüde bulunamayan ya da satışta olmayan kalem sayısı.
  final int missing;

  bool get isEmpty => added == 0;

  bool get isPartial => added > 0 && missing > 0;
}

/// [order] kalemlerini [menu] içinde arar ve bulunanları [addToCart] ile ekler.
///
/// Fiyat ve seçenek farkları TAŞINMAZ: sepete bugünkü menü kalemi eklenir.
/// Dünkü fiyatı taşımak, sunucunun hesapladığı tutarla çelişen bir sepet
/// üretirdi (`docs/openapi.yaml` `createOrder` — tutarda sunucu haklıdır).
///
/// Seçenekler de taşınmıyor: sipariş kaydı seçenekleri yalnızca metin olarak
/// tutuyor (`OrderItem.options`), kimliklerini değil. Metinden kimliğe geri
/// eşleme, adı değişmiş bir seçeneği yanlış eşleştirip müşteriye istemediği
/// ürünü satardı. Kullanıcı seçeneklerini ürün ekranında yeniden seçer.
ReorderOutcome reorderInto({
  required OrderDetail order,
  required List<MenuCategory> menu,
  required void Function(MenuItem item, int quantity) addToCart,
}) {
  final available = <int, MenuItem>{
    for (final category in menu)
      for (final item in category.items)
        if (item.isAvailable) item.id: item,
  };

  var added = 0;
  var missing = 0;

  for (final line in order.items) {
    final item = available[line.menuId];
    if (item == null) {
      missing++;
      continue;
    }
    addToCart(item, line.quantity);
    added++;
  }

  return ReorderOutcome(added: added, missing: missing);
}
