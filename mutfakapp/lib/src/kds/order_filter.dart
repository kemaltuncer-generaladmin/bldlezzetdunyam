/// Sipariş arama/filtreleme — yoğun günde 40 kart arasından birini bulmak.
///
/// Kurye kapıda "S-5012 hazır mı?" diye sorduğunda personelin üç sütunu
/// gözle taraması gerekmemeli. Filtre yalnızca **çizimi** daraltır; üretim
/// listesi ve geciken sayacı tüm siparişleri saymaya devam eder — mutfağın
/// toplam yükü bir arama kutusuyla değişmez.
library;

import 'package:bld_api_client/bld_api_client.dart';
// `TurkishCase` yalnızca `bld_core/escpos.dart` giriş noktasından dışa
// açılıyor ve `packages/` bu görevin kapsamı dışında. Kendi küçük kopyamızı
// yazmak yerine var olanı kullanıyoruz (AGENTS.md §4).
import 'package:bld_core/escpos.dart';

/// Aranabilir metin: sipariş no + müşteri + ürün adları + notlar.
///
/// Ürün adının da aranabilir olması bilinçli: "mercimek" yazıp mercimek
/// çorbası bekleyen tüm siparişleri görmek, tek bir tencerenin kime
/// gideceğini planlarken işe yarar.
String searchHaystack(KitchenOrder order) {
  final parts = <String>[
    order.orderNumber,
    if (order.customerLabel != null) order.customerLabel!,
    if (order.customerNote != null) order.customerNote!,
    for (final item in order.items) ...[
      item.name,
      ...item.options,
      if (item.note != null) item.note!,
    ],
  ];

  return TurkishCase.toLowerCase(parts.join(' '));
}

/// Sorgu metnini karşılaştırmaya hazır hâle getirir.
///
/// Personel "S-5012" yerine "5012" yazar; baştaki `S-` ve boşluklar elenmez,
/// alt dize araması ikisini de yakalar.
String normalizeQuery(String query) => TurkishCase.toLowerCase(query.trim());

/// [order], [query] ile eşleşiyor mu? Boş sorgu her siparişle eşleşir.
///
/// Sorgu boşlukla ayrılmış birden çok parça içeriyorsa **hepsi** eşleşmelidir
/// ("ayşe pilav" → hem Ayşe hem pilav geçen sipariş). Sıra önemsizdir.
bool orderMatchesQuery(KitchenOrder order, String query) {
  final terms = normalizeQuery(query).split(' ').where((t) => t.isNotEmpty);
  if (terms.isEmpty) return true;

  final haystack = searchHaystack(order);
  return terms.every(haystack.contains);
}

/// [orders] içinden [query] ile eşleşenler. Sıra korunur.
List<KitchenOrder> filterOrders(List<KitchenOrder> orders, String query) {
  if (normalizeQuery(query).isEmpty) return orders;
  return List<KitchenOrder>.unmodifiable(
    orders.where((order) => orderMatchesQuery(order, query)),
  );
}
