/// `K-06` / `K-20` — otomatik yazdırma tetikleri (`docs/05-mutfakapp.md` §5.5).
///
/// **SİPARİŞ BAŞINA TAM İKİ KÂĞIT ÇIKAR.**
///
/// | Olay | Fiş |
/// |---|---|
/// | Mutfak siparişi **onayladı** (`onaylandi`) | Mutfak fişi |
/// | Durum **`hazir`** yapıldı | Müşteri fişi (kurye bilgileri içinde) |
/// | **Revizyon numarası arttı** | Basılmış olanlar, güncel hâliyle, bir kez |
///
/// K-20'YE KADAR ÜÇ KÂĞIT ÇIKIYORDU ve düzenlenen sipariş her seferinde iki
/// kâğıt daha ekliyordu: iki kez düzenlenmiş adrese gönderim siparişi yedi
/// kâğıt demekti. Tezgâhta aynı siparişin birkaç kâğıdı birikiyor ve
/// hangisinin güncel olduğu kâğıda bakarak anlaşılmıyordu.
///
/// Kurye fişi (`ReceiptType.kurye`) **artık hiç tetiklenmiyor**. Kuryenin
/// ihtiyaç duyduğu her şey müşteri fişinde; o tip yalnızca personelin elle
/// yeniden bastırabildiği bir kaçış kapısı olarak duruyor.
///
/// Mutfak fişi `yeni` durumunda BASILMAZ: sipariş henüz kabul edilmemiştir
/// ve müşteri iptal edebilir (`docs/03` §4 — iptal `yeni` ve `onaylandi`
/// durumlarında serbest). `yeni`de basmak, iptal edilen her sipariş için
/// çöpe giden bir fiş demekti.
///
/// İnsan müdahalesi yoktur. Tetikler yalnızca **kuyruğa yazar**; basımı
/// `PrintService` yapar ve tekillik veritabanındaki
/// `UNIQUE(order_id, type, revision)` kısıtıyla garanti altındadır. Bu
/// yüzden tetiğin fazladan çalışması zararsızdır.
library;

import 'package:bld_api_client/bld_api_client.dart';

/// Sipariş listesindeki değişimleri yazdırma işlerine çeviren saf mantık.
///
/// Widget ve Riverpod bilmez: girdi sipariş listesi, çıktı kuyruğa eklenecek
/// işler. Testi bu yüzden ucuzdur.
class PrintTriggers {
  PrintTriggers({
    DateTime Function()? clock,
    this.revisionQuietWindow = defaultRevisionQuietWindow,
    this.revisionMaxHold = defaultRevisionMaxHold,
  }) : _now = clock ?? (() => DateTime.now().toUtc());

  /// Art arda düzenlemelerin tek kâğıtta birleşmesi için beklenen sessizlik.
  ///
  /// Personel müşteriyle telefonda konuşurken birkaç kez kaydediyor ve her
  /// kayıt ayrı bir kâğıt demekti. Pencere, yoklama aralığından (5 sn)
  /// belirgin biçimde uzun seçildi ki art arda gelen kayıtlar aynı
  /// pencerenin içine düşsün.
  ///
  /// VARSAYIM: 20 saniye. Ölçüyle değil kararla seçildi; sahada uzun
  /// gelirse tek satırda düşürülür.
  static const Duration defaultRevisionQuietWindow = Duration(seconds: 20);

  /// Bekletmenin üst sınırı.
  ///
  /// Beş dakika boyunca düzenlemeye devam eden bir personel yüzünden mutfak
  /// ASIL siparişi pişirmeye devam etmesin diye: sessizlik hiç gelmese bile
  /// bu süre dolunca güncel fiş çıkar.
  static const Duration defaultRevisionMaxHold = Duration(seconds: 60);

  final Duration revisionQuietWindow;
  final Duration revisionMaxHold;
  final DateTime Function() _now;

  /// Hangi işlerin kuyruğa gireceğine karar verir.
  ///
  /// Her iki eşik de "**o durum ya da ötesi**" diye okunur, "tam o durum"
  /// diye değil: sipariş `hazir` iken uygulama kapanıp `yolda` iken
  /// açılırsa fiş hiç basılmamış olabilir.
  List<PrintTriggerJob> jobsFor(List<KitchenOrder> orders) {
    final now = _now();
    final jobs = <PrintTriggerJob>[];

    for (final order in orders) {
      final revision = order.revisionNo;

      /*
       * İLK GÖRÜŞ REVİZYON DEĞİLDİR — `?? revision`.
       *
       * Uygulama yeniden başladığında hafıza boş; düzenlenmiş bir siparişi
       * ilk kez gören KDS, onu "az önce düzenlendi" sanıp bekletmeye
       * alırdı. Oysa elde bekletilecek bir kâğıt yok: bu cihaz o sipariş
       * için henüz hiçbir şey basmadı. Eşitlik sayesinde iş normal
       * eşiklerden geçip GECİKMEDEN basılıyor.
       */
      final known = _revisions[order.id] ?? revision;
      _revisions[order.id] = revision;
      _lastStatus[order.id] = order.status;

      if (order.status == OrderStatus.iptal) {
        // İptal edilen siparişin bekleyen revize fişi çöpe giden kâğıttır.
        _held.remove(order.id);
        continue;
      }

      if (revision > known) {
        _hold(order.id, revision, now);
      }

      if (_isAcceptedOrBeyond(order.status) && _acceptedOrders.add(order.id)) {
        jobs.add(PrintTriggerJob(order.id, ReceiptType.mutfak, revision));
      }
      if (_isReadyOrBeyond(order.status) && _readyOrders.add(order.id)) {
        jobs.add(PrintTriggerJob(order.id, ReceiptType.musteri, revision));
      }
    }

    // Sipariş döngüsünden SONRA: bekleyen iş, siparişin listeden düşmesinden
    // (teslim edildi / iptal) bağımsız olarak salınabilmeli.
    jobs.addAll(_flushDue(now));

    return jobs;
  }

  /// Revizyon işini bekletmeye alır ya da bekleyeni tazeler.
  ///
  /// YALNIZ DAHA ÖNCE BASILMIŞ TİPLER BEKLETİLİR. Henüz basılmamış bir fiş
  /// için "yeniden bas" diye bir şey yok; o zaten kendi eşiğinde, güncel
  /// veriyle, bir kez çıkacak. `hazir` öncesi yapılan düzenlemelerin
  /// çoğunluğu bu yüzden hiç fazladan kâğıt üretmiyor.
  void _hold(int orderId, int revision, DateTime now) {
    final types = <ReceiptType>{
      if (_acceptedOrders.contains(orderId)) ReceiptType.mutfak,
      if (_readyOrders.contains(orderId)) ReceiptType.musteri,
    };
    if (types.isEmpty) return;

    final open = _held[orderId];
    _held[orderId] = _HeldReprint(
      // HER ZAMAN EN YENİ REVİZYON: bekletme süresince gelen ara sürümler
      // hiç basılmıyor, yalnız sonuncusu kâğıda çıkıyor.
      revision: revision,
      types: {...?open?.types, ...types},
      firstHeldAt: open?.firstHeldAt ?? now,
      lastChangeAt: now,
    );
  }

  /// Süresi dolan bekletmeleri işe çevirir.
  List<PrintTriggerJob> _flushDue(DateTime now) {
    final out = <PrintTriggerJob>[];

    _held.removeWhere((orderId, held) {
      final quiet = now.difference(held.lastChangeAt) >= revisionQuietWindow;
      final tooOld = now.difference(held.firstHeldAt) >= revisionMaxHold;
      if (!quiet && !tooOld) return false;

      if (_lastStatus[orderId] != OrderStatus.iptal) {
        // SIRA SABİT — mutfak önce: yemek yeniden hazırlanacaksa saniyeler
        // önemli, müşteri fişi teslimde lazım.
        if (held.types.contains(ReceiptType.mutfak)) {
          out.add(PrintTriggerJob(orderId, ReceiptType.mutfak, held.revision));
        }
        if (held.types.contains(ReceiptType.musteri)) {
          out.add(PrintTriggerJob(orderId, ReceiptType.musteri, held.revision));
        }
      }

      return true;
    });

    return out;
  }

  /// Mutfak fişi **hiç** tetiklenmiş siparişler (bu oturumda).
  ///
  /// K-20'DEN BERİ REVİZYONDA TEMİZLENMİYOR. Eskiden temizlenip eşiğin
  /// yeniden ateşlenmesi bekleniyordu; bekletmeyle birlikte bu çalışmaz,
  /// çünkü temizlenen küme aynı geçişte eşiğe takılıp işi ANINDA çıkarırdı.
  /// Kümenin anlamı artık "bu cihaz bunu bir kez bastı".
  final Set<int> _acceptedOrders = <int>{};

  /// Müşteri fişi hiç tetiklenmiş siparişler.
  final Set<int> _readyOrders = <int>{};

  /// Sipariş başına son görülen revizyon numarası.
  final Map<int, int> _revisions = <int, int>{};

  /// Sipariş başına son görülen durum — bekletme salınırken iptali görmek için.
  final Map<int, OrderStatus> _lastStatus = <int, OrderStatus>{};

  /// Bekleyen revize basımları.
  ///
  /// YALNIZ BELLEKTE, bilerek. Bekletme sırasında çöken bir kasa, yeniden
  /// açıldığında boş kümelerle eşiklere takılır ve fişi **hemen** basar.
  /// Hata yönü "daha erken kâğıt", asla "hiç kâğıt yok".
  final Map<int, _HeldReprint> _held = <int, _HeldReprint>{};

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

/// Bekletilen bir revize basımı.
class _HeldReprint {
  const _HeldReprint({
    required this.revision,
    required this.types,
    required this.firstHeldAt,
    required this.lastChangeAt,
  });

  final int revision;
  final Set<ReceiptType> types;

  /// İlk bekletme anı — üst sınır bundan sayılır.
  final DateTime firstHeldAt;

  /// Son revizyon anı — sessizlik penceresi bundan sayılır.
  final DateTime lastChangeAt;
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
