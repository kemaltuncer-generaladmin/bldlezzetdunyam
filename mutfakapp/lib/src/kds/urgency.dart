/// Aciliyet hesabı — mutfağın en çok ihtiyaç duyduğu sinyal.
///
/// Bir KDS'nin asıl işi "hangi siparişler var" değil, **"hangisi yanıyor"**
/// sorusunu bir metre uzaktan cevaplamaktır. Bu dosya o kararı verir: kart
/// kenarının rengi, sayaç rozeti ve üst şeritteki "GECİKEN n" hepsi buradan
/// beslenir.
///
/// Widget içermez; testi bu yüzden ucuzdur.
library;

import 'package:bld_api_client/bld_api_client.dart';

/// Bir siparişin aciliyet derecesi. Sıra anlamlıdır: [late] en yüksektir.
enum OrderUrgency {
  /// Beklenen sürede.
  normal,

  /// Eşiğe yaklaşıyor — sarı.
  warning,

  /// Eşik aşıldı — kırmızı ve yanıp söner.
  late;

  /// İki sinyalden ağır basanı.
  OrderUrgency atLeast(OrderUrgency other) =>
      index >= other.index ? this : other;
}

/// Aciliyet eşikleri. Ayarlar ekranından değiştirilir.
///
/// Tek bir "dakika" bilgisi iki soruyu birden cevaplar:
/// * sipariş kaç dakikadır bekliyor,
/// * istenen teslim saatine kaç dakika kaldı.
///
/// Aynı sayının iki yerde kullanılması bilinçlidir — mutfak şefine iki ayrı
/// kavram öğretmek yerine tek bir "tolerans" kavramı veriyoruz.
class UrgencyThresholds {
  const UrgencyThresholds({
    required this.warningAfter,
    required this.lateAfter,
  });

  /// Varsayılanlar: 10 dakika sarı, 20 dakika kırmızı.
  ///
  /// VARSAYIM: doküman eşik vermiyor (`docs/05` §3 yalnızca "geçmişse
  /// kırmızıya döner" diyor). Catering hazırlık süresi için 10/20 dakika
  /// makul bir başlangıçtır ve ayarlar ekranından değiştirilebilir olduğu
  /// için geri alınabilir bir varsayımdır.
  static const UrgencyThresholds standard = UrgencyThresholds(
    warningAfter: Duration(minutes: 10),
    lateAfter: Duration(minutes: 20),
  );

  final Duration warningAfter;
  final Duration lateAfter;
}

/// Tek siparişin zaman durumu.
class OrderAge {
  const OrderAge({
    required this.waiting,
    required this.urgency,
    this.untilRequested,
  });

  /// Sipariş oluştuğundan beri geçen süre.
  ///
  /// `updatedAt` DEĞİL `createdAt` kullanılır: müşteriyi bekleten şey
  /// siparişin toplam yaşıdır, mutfaktaki son dokunuşun üzerinden geçen süre
  /// değil. Aksi hâlde "BAŞLA"ya basmak sayacı sıfırlar ve gecikme görünmez
  /// olurdu.
  final Duration waiting;

  /// İstenen teslim saatine kalan süre; negatifse geçilmiştir. Saat
  /// istenmemişse `null`.
  final Duration? untilRequested;

  final OrderUrgency urgency;

  bool get isLate => urgency == OrderUrgency.late;

  /// İstenen teslim saati geçti mi?
  bool get requestedTimePassed =>
      untilRequested != null && untilRequested!.isNegative;
}

/// [order] için aciliyet durumunu hesaplar.
///
/// İki sinyal vardır ve **ağır basan** kazanır:
/// 1. Bekleme süresi (`createdAt`'ten beri).
/// 2. İstenen teslim saatine kalan süre — varsa.
///
/// İkincisi birincisini ezmez, yalnızca yükseltebilir: 09:30'a teslim
/// istenen bir sipariş 07:00'de girildiyse iki saat beklemiş olması onu acil
/// yapmaz, ama 09:25 olduğunda yapar.
OrderAge ageOf(
  KitchenOrder order, {
  required DateTime now,
  UrgencyThresholds thresholds = UrgencyThresholds.standard,
}) {
  final waiting = now.toUtc().difference(order.createdAt.toUtc());
  var urgency = _fromWaiting(waiting, thresholds);

  Duration? untilRequested;
  final requested = order.requestedAt;
  if (requested != null) {
    untilRequested = requested.toUtc().difference(now.toUtc());
    urgency = urgency.atLeast(_fromRequested(untilRequested, thresholds));
  }

  return OrderAge(
    waiting: waiting,
    untilRequested: untilRequested,
    urgency: urgency,
  );
}

OrderUrgency _fromWaiting(Duration waiting, UrgencyThresholds thresholds) {
  if (waiting >= thresholds.lateAfter) return OrderUrgency.late;
  if (waiting >= thresholds.warningAfter) return OrderUrgency.warning;
  return OrderUrgency.normal;
}

OrderUrgency _fromRequested(Duration remaining, UrgencyThresholds thresholds) {
  // Saat geçtiyse tartışma yok: sipariş geç kalmıştır.
  if (remaining.isNegative) return OrderUrgency.late;
  // Aynı tolerans penceresi: "kaç dakika beklediyse dikkat" ile "kaç dakika
  // kaldıysa dikkat" tek sayıyla yönetilir.
  if (remaining <= thresholds.warningAfter) return OrderUrgency.warning;
  return OrderUrgency.normal;
}

/// Ekrandaki geciken sipariş sayısı — üst şeritteki alarm rozetinin değeri.
int lateOrderCount(
  List<KitchenOrder> orders, {
  required DateTime now,
  UrgencyThresholds thresholds = UrgencyThresholds.standard,
}) => orders
    .where((order) => ageOf(order, now: now, thresholds: thresholds).isLate)
    .length;

/// Sütun içinde çizim sırası: en acil olan en üstte.
///
/// Mutfak listenin başından çalışır; en acil kartın en üstte olması,
/// personelin doğru işi seçmek için ekranı taramasını gereksiz kılar.
/// Eşit aciliyette **en eski** öne geçer (FIFO adaleti korunur).
List<KitchenOrder> sortByUrgency(
  List<KitchenOrder> orders, {
  required DateTime now,
  UrgencyThresholds thresholds = UrgencyThresholds.standard,
}) {
  final ages = <int, OrderAge>{
    for (final order in orders)
      order.id: ageOf(order, now: now, thresholds: thresholds),
  };

  final sorted = [...orders]
    ..sort((a, b) {
      final byUrgency = ages[b.id]!.urgency.index.compareTo(
        ages[a.id]!.urgency.index,
      );
      if (byUrgency != 0) return byUrgency;

      // Eşit aciliyette artan `createdAt`: eski sipariş önce çıkar.
      final byAge = a.createdAt.compareTo(b.createdAt);
      return byAge != 0 ? byAge : a.id.compareTo(b.id);
    });

  return List<KitchenOrder>.unmodifiable(sorted);
}
