/// Sunucudan gelen komutları çalıştırır.
///
/// Yöneticinin isteği: *"gerekirse uygulamaya komut göndersin, uygulama
/// onu uygulasın."* Komutlar sağlık yanıtıyla iniyor; burası onları
/// eyleme çeviren ve sonucu geri bildiren yer.
///
/// SAF DEĞİL AMA DAR: her komut tek bir geri çağrıya bağlanıyor ve bu
/// sınıf Riverpod'u, widget'ı, HTTP'yi bilmiyor. Testte geri çağrılar
/// sahtelenir ve "hangi komut neyi tetikledi" kesin ölçülür.
library;

import 'kitchen_health.dart';

/// Bir komutun çalıştırılmasını sağlayan eylemler.
///
/// Hepsi `Future<String?>` döner: `null` başarı, metin ise başarısızlık
/// gerekçesi. Yöneticinin panelde göreceği mesaj bu.
class CommandActions {
  const CommandActions({
    required this.printTestReceipt,
    required this.reprint,
    required this.clearFailed,
    required this.silenceAlarm,
    required this.restart,
    required this.update,
    required this.unpair,
    required this.clearQueue,
  });

  final Future<String?> Function() printTestReceipt;
  final Future<String?> Function(int orderId, String type) reprint;
  final Future<String?> Function() clearFailed;
  final Future<String?> Function() silenceAlarm;
  final Future<String?> Function() restart;

  // ── K-22 ile gelen üç eylem ───────────────────────────────────────────

  /// Yeni sürümü indirir ve kurar.
  ///
  /// BAŞARISIZLIK GÜVENLİ TARAFTA: kurulumun herhangi bir adımı düşerse
  /// kasa ESKİ SÜRÜMDE çalışmaya devam eder ve gerekçe geri döner.
  /// "Yarısı kurulmuş" bir kasa hiç güncellenmemiş olandan çok daha
  /// kötüdür — mutfak sabaha açılmayan bir ekranla uyanır.
  final Future<String?> Function() update;

  /// Cihaz token'ını siler; kasa eşleme ekranına döner.
  final Future<String?> Function() unpair;

  /// Kuyruktaki BEKLEYEN işleri de düşürür ([clearFailed] yalnız hatalıları).
  final Future<String?> Function() clearQueue;
}

/// Komutları çalıştırıp sonuçlarını toplar.
class CommandRunner {
  const CommandRunner(this._actions);

  final CommandActions _actions;

  /// Verilen komutları sırayla çalıştırır.
  ///
  /// SIRAYLA, paralel değil: "başarısız kuyruğu temizle" ile "fişi
  /// yeniden bas" aynı anda koşarsa hangisinin kazandığı belirsiz olur.
  ///
  /// Bir komutun patlaması diğerlerini DURDURMAZ ve hata yukarı
  /// ATILMAZ — biri hatalı diye kalanların çalışmaması, yöneticinin
  /// gönderdiği "yeniden başlat"ın kaybolması demek olurdu.
  Future<List<KitchenCommandResult>> run(List<KitchenCommand> commands) async {
    final results = <KitchenCommandResult>[];

    for (final command in commands) {
      results.add(await _runOne(command));
    }

    return results;
  }

  Future<KitchenCommandResult> _runOne(KitchenCommand command) async {
    try {
      final hata = await _dispatch(command);

      return KitchenCommandResult(
        id: command.id,
        ok: hata == null,
        message: hata,
      );
    } on Object catch (error) {
      return KitchenCommandResult(
        id: command.id,
        ok: false,
        message: _kisalt('$error'),
      );
    }
  }

  Future<String?> _dispatch(KitchenCommand command) =>
      switch (command.command) {
        KitchenCommand.testReceipt => _actions.printTestReceipt(),
        KitchenCommand.reprint => _reprint(command),
        KitchenCommand.clearFailed => _actions.clearFailed(),
        KitchenCommand.silenceAlarm => _actions.silenceAlarm(),
        KitchenCommand.restart => _actions.restart(),
        KitchenCommand.update => _actions.update(),
        KitchenCommand.unpair => _actions.unpair(),
        KitchenCommand.clearQueue => _actions.clearQueue(),
        // Bilinmeyen komut SESSİZCE YUTULMAZ: sunucu bu sürümün tanımadığı
        // bir komut gönderdiyse yönetici bunu panelde görmeli, yoksa
        // "gönderdim ama olmadı" diye tekrar tekrar dener.
        _ => Future<String?>.value(
          'Bu sürüm "${command.command}" komutunu tanımıyor',
        ),
      };

  Future<String?> _reprint(KitchenCommand command) async {
    final orderId = command.payload['order_id'];
    final type = command.payload['type'];

    final id = orderId is int ? orderId : int.tryParse('$orderId');
    if (id == null) return 'Sipariş numarası eksik';

    final tip = type is String && type.isNotEmpty ? type : 'mutfak';

    return _actions.reprint(id, tip);
  }

  static String _kisalt(String value) =>
      value.length <= 255 ? value : value.substring(0, 255);
}
