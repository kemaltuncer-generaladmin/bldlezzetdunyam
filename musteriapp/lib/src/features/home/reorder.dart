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

  /// Sepete GİREMEYEN kalem sayısı.
  ///
  /// İki sebepten olur ve ikisi de aynı kovaya düşer: kalem o gün menüde
  /// yok/satışta değil, ya da kalan porsiyon yetmiyor. Müşteri açısından fark
  /// yok — o ürün bu sipariş için alınamıyor; sayının işi eksik bir sepetin
  /// sessizce gönderilmesini engellemek.
  final int missing;

  bool get isEmpty => added == 0;

  bool get isPartial => added > 0 && missing > 0;
}

/// [order] kalemlerini [menuItems] içinde arar ve bulunanları [addToCart] ile
/// ekler.
///
/// **Kaynak artık GÜNÜN MENÜSÜ, genel katalog değil** (B-19): satılabilir olan
/// tek şey o. Dünkü siparişin bugün menüde olmayan yarısı [ReorderOutcome.missing]
/// olarak sayılır ve çağıran bunu kullanıcıya söyler.
///
/// Fiyat ve seçenek farkları TAŞINMAZ: sepete bugünkü kalem eklenir. Dünkü
/// fiyatı taşımak, sunucunun hesapladığı tutarla çelişen bir sepet üretirdi
/// (`docs/openapi.yaml` `createOrder` — tutarda sunucu haklıdır).
///
/// Seçenekler de taşınmıyor: sipariş kaydı seçenekleri yalnızca metin olarak
/// tutuyor (`OrderItem.options`), kimliklerini değil. Metinden kimliğe geri
/// eşleme, adı değişmiş bir seçeneği yanlış eşleştirip müşteriye istemediği
/// ürünü satardı. Kullanıcı seçeneklerini kalem ekranında yeniden seçer.
///
/// **Paketin BİLEŞEN satırları atlanır.** Onlar siparişte paketin altında
/// duran sıfır fiyatlı satırlar; ayrıca eklenselerdi menü hem paket olarak
/// hem de içindekiler tek tek olarak iki kez sepete girer, müşteri iki kat
/// öderdi. Paketin ÜST satırı ise sıradan bir kalem gibi ele alınıyor: o da
/// bir `menu_id` ve bugün menüde varsa yeniden alınabilir.
/// [addToCart] **sepetin kabul edip etmediğini döndürür.** `void` olduğu
/// sürece stok tavanına takılan bir kalem "eklendi" diye sayılıyordu: müşteri
/// "3 ürün sepete eklendi" okuyup sepette 2 buluyordu. Karar sepetindir,
/// sayım buranın.
ReorderOutcome reorderInto({
  required OrderDetail order,
  required List<MenuItem> menuItems,
  required bool Function(MenuItem item, int quantity) addToCart,
}) {
  final available = <int, MenuItem>{
    for (final item in menuItems)
      if (item.isAvailable) item.id: item,
  };

  var added = 0;
  var missing = 0;

  for (final line in order.items) {
    if (line.isPackageComponent) continue;

    final item = available[line.menuId];
    if (item == null) {
      missing++;
      continue;
    }
    if (addToCart(item, line.quantity)) {
      added++;
    } else {
      missing++;
    }
  }

  return ReorderOutcome(added: added, missing: missing);
}
