/// `K-06` / `K-20` — otomatik yazdırma tetikleri (`docs/05-mutfakapp.md` §5.5).
///
/// **SİPARİŞ BAŞINA TAM İKİ KÂĞIT ÇIKAR — AMA ASLA AYNI TURDA.**
///
/// | Olay | Fiş |
/// |---|---|
/// | Mutfak siparişi **onayladı** (`onaylandi`) | Mutfak fişi |
/// | Durum **`hazir`** yapıldı | Müşteri fişi (kurye bilgileri içinde) |
/// | **Revizyon numarası arttı** | Basılmış olanlar, güncel hâliyle, bir kez |
///
/// **TURDA SİPARİŞ BAŞINA TEK KÂĞIT (14.08.2026).** Sahadan gelen şikâyet:
/// *"şu an arka arkaya fiş basılıyor"*. İki eşik tek yoklamada birden
/// aşılabiliyordu — sipariş iki yoklama arasında `yeni`den `hazir`a atlarsa
/// mutfak ve müşteri fişi 1,2 saniye arayla peş peşe çıkıyor, tezgâha aynı
/// siparişin iki kâğıdı birden düşüyordu. Aynısı revizyon salınımında da
/// oluyordu: bekletilen tiplerin hepsi tek turda dökülüyordu.
///
/// Artık `jobsFor` bir turda aynı sipariş için **en fazla bir** iş üretir.
/// Öncelik **mutfak > müşteri**: mutfak yemeğe başlamak için kâğıdı hemen
/// görmeli, müşteri fişi ancak teslimde lazım.
///
/// **ERTELEMEK KAYBETMEK DEĞİLDİR.** Ertelenen iş `_deferred` içinde,
/// sipariş listesinden **bağımsız** durur ve bir sonraki yoklamada sipariş
/// listede olmasa bile çıkar. `PollingOrderSource` `teslim_edildi` ve
/// `iptal` siparişleri listeden düşürüyor; gel-al siparişinde `hazir` ile
/// `teslim_edildi` arası tek bir yoklamadan kısa olabiliyor. İş yalnız
/// "eşik bir sonraki turda yeniden değerlendirilir" varsayımına
/// bırakılsaydı müşteri fişi bu senaryoda HİÇ çıkmazdı — oysa o kâğıt
/// kuryenin adres ve tahsilat bilgisini taşıyan tek kâğıt.
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
  ///
  /// Dönen listede **sipariş başına en çok bir iş** bulunur; ertelenenler
  /// bir sonraki çağrıda çıkar.
  List<PrintTriggerJob> jobsFor(List<KitchenOrder> orders) {
    final now = _now();
    final jobs = <PrintTriggerJob>[];

    // Bu turda kâğıdı çıkan siparişler — üç kaynağın (eşik, bekletme,
    // erteleme) ortak sayacı. "Turda sipariş başına tek kâğıt" kuralı tek
    // yerde burada tutuluyor; her kaynak kendi kontrolünü yapsaydı kuralın
    // doğruluğu kaynak sayısıyla çarpılan bir zamanlama muhakemesine kalırdı.
    final claimed = <int>{};

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
        // İptal edilen siparişin bekleyen kâğıdı çöpe giden kâğıttır —
        // bekletilen revize fiş de, ertelenen müşteri fişi de.
        _held.remove(order.id);
        _deferred.remove(order.id);
        continue;
      }

      if (revision > known) {
        _hold(order.id, revision, now);
      }

      /*
       * BEKLEYEN KÂĞIT TURUN SIRASINI KAPATIR.
       *
       * Bu tur döngü sonundaki salımlar bu sipariş için zaten bir kâğıt
       * çıkaracaksa eşikler hiç yoklanmaz: yoksa bekleyen revize mutfak
       * fişiyle hiç basılmamış müşteri fişi aynı turda çıkar ve şikâyet
       * edilen "arka arkaya" durumu geri gelirdi.
       *
       * Burada ertelenen eşik her zaman MÜŞTERİ fişidir: `_hold` yalnız
       * basılmış tipleri bekletir, yani bekletmesi olan siparişin mutfak
       * fişi çoktan basılmış ve o eşik zaten kapanmıştır. Dolayısıyla bu
       * erteleme de "mutfak > müşteri" önceliğinin bir parçası.
       */
      final held = _held[order.id];
      if (_deferred.containsKey(order.id) ||
          (held != null && _isDue(held, now))) {
        _deferIfEarned(order, revision);
        continue;
      }

      if (_isAcceptedOrBeyond(order.status) && _acceptedOrders.add(order.id)) {
        jobs.add(PrintTriggerJob(order.id, ReceiptType.mutfak, revision));
        claimed.add(order.id);

        // Müşteri fişi de bu turda hak edilmişse ertelemeye alınır.
        _deferIfEarned(order, revision);
        continue;
      }

      if (_isReadyOrBeyond(order.status) && _readyOrders.add(order.id)) {
        jobs.add(PrintTriggerJob(order.id, ReceiptType.musteri, revision));
        claimed.add(order.id);
      }
    }

    // Sipariş döngüsünden SONRA: hem bekletilen hem ertelenen iş, siparişin
    // listeden düşmesinden (teslim edildi / iptal) bağımsız salınabilmeli.
    //
    // BEKLETME ÖNCE: bekletmedeki kâğıt mutfak fişi, ertelenen ise müşteri
    // fişidir. Sıra ters olsaydı "mutfak > müşteri" önceliği tam da iki
    // kaynağın aynı tura düştüğü anda bozulurdu.
    jobs
      ..addAll(_flushDue(now, claimed))
      ..addAll(_flushDeferred(claimed));

    return jobs;
  }

  /// Bu turda basılmayan ama **hak edilmiş** müşteri fişini ertelemeye alır.
  ///
  /// `_readyOrders` KASTEN İŞARETLENMEZ. Küme "bu cihaz bunu bir kez bastı"
  /// demek; basılmadan işaretlenen fiş bir daha hiçbir turda eşiğe takılmaz.
  /// Fişin taşıyıcısı küme değil, `_deferred` kaydının kendisidir.
  void _deferIfEarned(KitchenOrder order, int revision) {
    if (!_isReadyOrBeyond(order.status)) return;
    if (_readyOrders.contains(order.id)) return;

    // HER ZAMAN EN YENİ REVİZYON — `_hold` ile aynı kural: bekleyen kâğıt
    // eski sürümü basmamalı, sipariş listede görüldükçe tazeleniyor.
    _deferred[order.id] = PrintTriggerJob(
      order.id,
      ReceiptType.musteri,
      revision,
    );
  }

  /// Ertelenen işleri salar — sipariş listede olsun ya da olmasın.
  List<PrintTriggerJob> _flushDeferred(Set<int> claimed) {
    final out = <PrintTriggerJob>[];

    for (final orderId in _deferred.keys.toList(growable: false)) {
      // Turun kâğıdı başka bir kaynağa gittiyse erteleme bir tur daha durur.
      if (!claimed.add(orderId)) continue;

      final job = _deferred.remove(orderId)!;
      assert(
        job.type == ReceiptType.musteri,
        'Yalnız müşteri fişi ertelenir — mutfak fişi turun önceliğidir.',
      );

      // Küme ANCAK BASARKEN işaretlenir; erteleme anında değil.
      _readyOrders.add(orderId);
      out.add(job);
    }

    return out;
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

  /// Süresi dolan bekletmeleri işe çevirir — **turda sipariş başına tek tip**.
  ///
  /// Eskiden bekletmedeki tiplerin hepsi tek turda dökülüyordu ve revizyon
  /// salınımı da tezgâha iki kâğıdı arka arkaya atıyordu. Artık salınacak
  /// birden çok tip varsa yalnız ilki çıkar, kalan bekletmede durur ve bir
  /// sonraki yoklamada salınır.
  List<PrintTriggerJob> _flushDue(DateTime now, Set<int> claimed) {
    final out = <PrintTriggerJob>[];

    // Anahtar kopyası: döngü içinde `_held` hem güncelleniyor hem siliniyor.
    for (final orderId in _held.keys.toList(growable: false)) {
      final held = _held[orderId]!;
      if (!_isDue(held, now)) continue;

      if (_lastStatus[orderId] == OrderStatus.iptal) {
        _held.remove(orderId);
        continue;
      }

      // Turun kâğıdı eşiğe gittiyse bekletme bir tur daha durur; zaman
      // alanları tazelenmediği için sıradaki turda salınır.
      if (!claimed.add(orderId)) continue;

      // SIRA SABİT — mutfak önce: yemek yeniden hazırlanacaksa saniyeler
      // önemli, müşteri fişi teslimde lazım. Küme hiçbir zaman boş değil:
      // `_hold` boş kümeyi hiç yazmıyor, son tip çıkınca girdi siliniyor.
      final type = held.types.contains(ReceiptType.mutfak)
          ? ReceiptType.mutfak
          : ReceiptType.musteri;
      out.add(PrintTriggerJob(orderId, type, held.revision));

      final rest = held.without(type);
      if (rest.types.isEmpty) {
        _held.remove(orderId);
      } else {
        _held[orderId] = rest;
      }
    }

    return out;
  }

  /// Bekletmenin salınma vakti geldi mi?
  ///
  /// Sessizlik penceresi ya da üst sınır — hangisi önce dolarsa. Eşiklerin
  /// erteleneceğine de bu karar veriyor, bu yüzden tek yerde durması şart:
  /// iki ayrı kopya, "salınacak" sanılan ama salınmayan bir turda fişi
  /// kaybettirirdi.
  bool _isDue(_HeldReprint held, DateTime now) =>
      now.difference(held.lastChangeAt) >= revisionQuietWindow ||
      now.difference(held.firstHeldAt) >= revisionMaxHold;

  /// Mutfak fişi **hiç** tetiklenmiş siparişler (bu oturumda).
  ///
  /// K-20'DEN BERİ REVİZYONDA TEMİZLENMİYOR. Eskiden temizlenip eşiğin
  /// yeniden ateşlenmesi bekleniyordu; bekletmeyle birlikte bu çalışmaz,
  /// çünkü temizlenen küme aynı geçişte eşiğe takılıp işi ANINDA çıkarırdı.
  /// Kümenin anlamı artık "bu cihaz bunu bir kez bastı".
  final Set<int> _acceptedOrders = <int>{};

  /// Müşteri fişi hiç tetiklenmiş siparişler.
  ///
  /// AYNI TURDA MUTFAK FİŞİ ÇIKTIYSA BURAYA YAZILMAZ. Küme "bu cihaz bunu
  /// bir kez bastı" demek; ertelenen fişi baştan işaretlemek onu bastırmak
  /// değil, kaybetmek olurdu.
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

  /// Turda tek kâğıt kuralı yüzünden bir sonraki tura bırakılan işler.
  ///
  /// SİPARİŞ LİSTESİNDEN BAĞIMSIZ — `_held` ile aynı sebeple ve aynı
  /// yöntemle. `PollingOrderSource._applyPage` `teslim_edildi` ve `iptal`
  /// siparişleri listeden düşürüyor; gel-al siparişi `hazir`dan doğrudan
  /// oraya geçiyor ve bu iki yoklama arasına sığabiliyor. İş yalnız eşiğin
  /// bir sonraki turda yeniden değerlendirilmesine bırakılsaydı, o turda
  /// sipariş listede olmadığı için müşteri fişi HİÇ çıkmazdı; kuryenin
  /// elindeki tek kâğıt sessizce kaybolurdu.
  ///
  /// `_held` gibi yalnız bellekte: çöken kasa açılışta boş kümelerle
  /// eşiklere takılıp hemen basar. Hata yönü yine "daha erken kâğıt".
  final Map<int, PrintTriggerJob> _deferred = <int, PrintTriggerJob>{};

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

  /// Bir tip salındıktan sonra kalanıyla aynı bekletmeyi sürdürür.
  ///
  /// ZAMAN ALANLARI TAŞINIR, TAZELENMEZ: pencere bir kez doldu, kalan tipin
  /// onu baştan beklemesi için sebep yok. Tazelenselerdi "turda tek kâğıt"
  /// kuralı sessizce 20 saniyelik bir gecikmeye dönüşürdü; oysa kalan fiş
  /// bir sonraki yoklamada çıkmalı.
  _HeldReprint without(ReceiptType type) => _HeldReprint(
    revision: revision,
    types: {...types}..remove(type),
    firstHeldAt: firstHeldAt,
    lastChangeAt: lastChangeAt,
  );
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
