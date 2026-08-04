/// KDS veri katmanı soyutlaması — `docs/05-mutfakapp.md` §4, ADR-05.
///
/// **Neden soyutlama zorunlu:** Faz 1'de 5 saniyelik artımlı polling var,
/// Faz 1.5'te Laravel Reverb WebSocket gelecek. İkisi de bu arayüzü uygular;
/// geçiş tek satırlık bağımlılık değişimi olur, ekran kodu hiç değişmez.
library;

import 'models/kitchen.dart';

/// Mutfak siparişlerinin kaynağı.
///
/// Uygulama bu arayüzden başka bir şey bilmez — `PollingOrderSource` mi
/// `WebSocketOrderSource` mi olduğunu KDS ekranı umursamaz.
abstract class OrderSource {
  /// Aktif sipariş listesinin akışı.
  ///
  /// Her yayın **tam listedir**, artış değil: ekran diff hesaplamaz, gelen
  /// listeyi çizer. Bağlantı koptuğunda akış hata vermez; son bilinen liste
  /// ekranda kalır ve [connection] "bağlantı yok"a döner
  /// (`docs/10-test-kabul.md` S4 adım 4).
  Stream<List<KitchenOrder>> watch();

  /// Elle tam yenileme.
  ///
  /// Bağlantı geri geldiğinde ve kullanıcı yenile dediğinde çağrılır; kaçırılan
  /// durum değişimlerini toparlar.
  Future<void> refresh();

  /// Bağlantı durumu — durum çubuğundaki gösterge bunu dinler.
  ///
  /// Sözleşme dokümanındaki iki metoda ek olarak eklendi: "Bağlantı yok"
  /// uyarısı zorunlu bir kabul ölçütü (S4 adım 4) ve bunu [watch] üzerinden
  /// bildirmenin tek yolu akışı hataya düşürmek olurdu — ki o da son bilinen
  /// listeyi ekrandan siler. Ayrı akış, ikisini birbirinden bağımsız tutar.
  Stream<OrderSourceConnection> get connection;

  /// Zamanlayıcıları ve soketleri kapatır.
  Future<void> dispose();
}

/// [OrderSource]'un sunucuyla bağlantı durumu.
enum OrderSourceConnection {
  /// Veri akıyor.
  connected,

  /// İlk bağlantı ya da yeniden bağlanma denemesi sürüyor.
  connecting,

  /// Ulaşılamıyor. Geri çekilerek yeniden denenir; ekrandaki liste korunur.
  disconnected,

  /// Cihaz token'ı iptal edilmiş — yeniden denemek anlamsız, eşleme ekranına
  /// dönülmeli (`docs/05-mutfakapp.md` §7 adım 5).
  revoked,
}
