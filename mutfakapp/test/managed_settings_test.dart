/// Sunucudan yönetilen ayarlar ve komutlar — `docs/05-mutfakapp.md` §8.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/data/command_runner.dart';
import 'package:mutfakapp/src/data/kitchen_health.dart';
import 'package:mutfakapp/src/data/managed_settings.dart';
import 'package:mutfakapp/src/settings/kds_settings.dart';
import 'package:mutfakapp/src/sound/kds_sound_event.dart';

const yerel = KdsSettings(
  soundEnabled: true,
  pollSeconds: 5,
  printerDevicePath: '/dev/thermal0',
  warningAfterMinutes: 10,
  lateAfterMinutes: 20,
);

void main() {
  group('Yönetilen ayarlar', () {
    test('boş ayar yereli hiç değiştirmez', () {
      expect(applyManagedSettings(yerel, KitchenManagedSettings.empty), yerel);
    });

    test('DOKUNULMAMIŞ alan yereli EZMEZ', () {
      // `null` "yönetici dokunmadı" demek. "Kapat" ya da "varsayılana dön"
      // diye yorumlansaydı, yönetici tek bir ayarı değiştirdiğinde
      // diğer sekizi sıfırlanırdı.
      final sonuc = applyManagedSettings(
        yerel,
        const KitchenManagedSettings(pollSeconds: 8),
      );

      expect(sonuc.pollSeconds, 8);
      expect(sonuc.soundEnabled, yerel.soundEnabled);
      expect(sonuc.printerDevicePath, yerel.printerDevicePath);
      expect(sonuc.warningAfterMinutes, yerel.warningAfterMinutes);
      expect(sonuc.lateAfterMinutes, yerel.lateAfterMinutes);
    });

    test('sesi kapatmak uygulanır', () {
      // `false` da geçerli bir değer; `null` ile karıştırılmamalı.
      final sonuc = applyManagedSettings(
        yerel,
        const KitchenManagedSettings(soundEnabled: false),
      );

      expect(sonuc.soundEnabled, isFalse);
    });

    test('sınır dışı sunucu değeri yine kırpılır', () {
      // Sunucu da kırpıyor ama ona güvenip atlamak, elle veritabanı
      // düzenlemesinin ya da eski bir sunucu sürümünün kasayı bozmasına
      // izin vermek olurdu.
      final sonuc = applyManagedSettings(
        yerel,
        const KitchenManagedSettings(pollSeconds: 9999),
      );

      expect(sonuc.pollSeconds, KdsSettings.maxPollSeconds);
    });

    // ── K-09: eskiden ayrıştırılıp KULLANILMAYAN alanlar ────────────────
    //
    // Bu dört alan sözleşmede ve istemci modelinde vardı ama hiçbir yere
    // bağlanmamıştı: yönetici panelden değiştiriyor, kasada hiçbir şey
    // olmuyordu. Testleri, bir daha sessizce kopmasınlar diye.

    test('ses seviyesi uygulanır ve 0-100 aralığına kırpılır', () {
      expect(
        applyManagedSettings(
          yerel,
          const KitchenManagedSettings(volumePercent: 35),
        ).volumePercent,
        35,
      );
      expect(
        applyManagedSettings(
          yerel,
          const KitchenManagedSettings(volumePercent: 900),
        ).volumePercent,
        100,
      );
    });

    test('çıkış cihazı uygulanır; BOŞ DİZE varsayılana döndürür', () {
      // `null` "dokunmadı" anlamına ayrılmış olduğu için, yöneticinin
      // seçimini geri alabilmesinin tek yolu boş dize.
      final secili = applyManagedSettings(
        yerel,
        const KitchenManagedSettings(audioSink: 'hoparlor-1'),
      );
      expect(secili.audioSinkName, 'hoparlor-1');

      final sifirlanmis = applyManagedSettings(
        secili,
        const KitchenManagedSettings(audioSink: ''),
      );
      expect(sifirlanmis.audioSinkName, isNull);
    });

    test('çıkış cihazı SUNUCU JSON\'ından da sıfırlanabilir', () {
      // Üstteki test nesneyi DOĞRUDAN kuruyor ve bu yüzden gerçek bir
      // açığı yıllarca kaçırdı: `fromJson` boş dizeyi `null`'a çeviriyor,
      // `null` da "dokunmadı" demek olduğu için "varsayılana dön" emri
      // tele hiç çıkmıyordu. Panelin sıfırlama düğmesi sessizce hiçbir
      // şey yapmıyordu. Doğru yol TELDEN geçen yoldur.
      final secili = applyManagedSettings(
        yerel,
        KitchenManagedSettings.fromJson(const {'audio_sink': 'hoparlor-1'}),
      );
      expect(secili.audioSinkName, 'hoparlor-1');

      final sifirlanmis = applyManagedSettings(
        secili,
        KitchenManagedSettings.fromJson(const {'audio_sink': ''}),
      );
      expect(sifirlanmis.audioSinkName, isNull);
    });

    test('çıkış cihazı anahtarı YOKSA yerel korunur', () {
      final secili = applyManagedSettings(
        yerel,
        KitchenManagedSettings.fromJson(const {'audio_sink': 'hoparlor-1'}),
      );

      final sonuc = applyManagedSettings(
        secili,
        KitchenManagedSettings.fromJson(const {'poll_seconds': 7}),
      );

      expect(sonuc.audioSinkName, 'hoparlor-1');
      expect(sonuc.pollSeconds, 7);
    });

    test('çıkış cihazı `null` gelince yerel korunur', () {
      // JSON'da açıkça `null` yazması da "dokunmadı"dır; boş dizeden
      // ayrılan tam olarak bu durum.
      final secili = applyManagedSettings(
        yerel,
        KitchenManagedSettings.fromJson(const {'audio_sink': 'hoparlor-1'}),
      );

      final sonuc = applyManagedSettings(
        secili,
        KitchenManagedSettings.fromJson(const {'audio_sink': null}),
      );

      expect(sonuc.audioSinkName, 'hoparlor-1');
    });

    test('kod sayfası uygulanır — yanlış değer Türkçe karakteri bozar', () {
      final sonuc = applyManagedSettings(
        yerel,
        const KitchenManagedSettings(printerCodePage: 13),
      );

      expect(sonuc.printerCodePage, 13);
    });

    test('sağlık ve bağlantı uyarısı aralıkları sınırlarına kırpılır', () {
      final sonuc = applyManagedSettings(
        yerel,
        const KitchenManagedSettings(
          healthSeconds: 5,
          connectionAlarmSeconds: 9999,
        ),
      );

      expect(sonuc.healthSeconds, KdsSettings.minHealthSeconds);
      expect(
        sonuc.connectionAlarmSeconds,
        KdsSettings.maxConnectionAlarmSeconds,
      );
    });

    test('susturma yetkisi kapatılabilir', () {
      final sonuc = applyManagedSettings(
        yerel,
        const KitchenManagedSettings(alarmSilenceable: false),
      );

      expect(sonuc.alarmSilenceable, isFalse);
    });

    test('anons ve dokunmatik kip sunucudan açılabilir', () {
      final sonuc = applyManagedSettings(
        yerel,
        const KitchenManagedSettings(ttsEnabled: true, touchMode: true),
      );

      expect(sonuc.ttsEnabled, isTrue);
      expect(sonuc.touchMode, isTrue);
    });

    test('yeni alanlara dokunmayan sunucu yereli bozmaz', () {
      // Eski sunucu sürümü yeni alanları hiç göndermiyor; kasa kendi
      // ayarlarını korumalı.
      final ozel = yerel.copyWith(
        volumePercent: 45,
        ttsEnabled: true,
        touchMode: true,
      );

      final sonuc = applyManagedSettings(
        ozel,
        const KitchenManagedSettings(pollSeconds: 7),
      );

      expect(sonuc.volumePercent, 45);
      expect(sonuc.ttsEnabled, isTrue);
      expect(sonuc.touchMode, isTrue);
    });
  });

  // ── K-21: kilit politikası ────────────────────────────────────────────
  //
  // Yönetim Kontrol Merkezi'ne geçiyor. Bu yedi alan aynı `null` kuralına
  // uyar; uymazsa alanın eklenmesi sahadaki her kasayı kilitler.

  group('Kilit politikası', () {
    test('yerel varsayılan SERBESTtir', () {
      // En tehlikeli hata bu olurdu: sürüm yükselten mutfak sabaha
      // kilitli uyanır ve kimse ayarlara giremez.
      expect(yerel.allowSettings, isTrue);
      expect(yerel.allowServerChange, isTrue);
      expect(yerel.allowWindowControls, isTrue);
      expect(yerel.allowOrderEdit, isTrue);
      expect(yerel.allowManualReprint, isTrue);
      expect(yerel.allowSalesControl, isTrue);
      expect(yerel.lockMessage, isEmpty);
      expect(yerel.hasLock, isFalse);
    });

    test('DOKUNULMAMIŞ kilit alanı yereli KORUR', () {
      // Yönetici yalnız "ayarlar"ı kilitledi; kalan beşi kendi hâlinde
      // kalmalı, `null` "aç" diye yorumlanmamalı.
      final kilitli = yerel.copyWith(
        allowOrderEdit: false,
        allowSalesControl: false,
      );

      final sonuc = applyManagedSettings(
        kilitli,
        const KitchenManagedSettings(allowSettings: false),
      );

      expect(sonuc.allowSettings, isFalse);
      expect(sonuc.allowOrderEdit, isFalse);
      expect(sonuc.allowSalesControl, isFalse);
      expect(sonuc.allowServerChange, isTrue);
      expect(sonuc.allowWindowControls, isTrue);
      expect(sonuc.allowManualReprint, isTrue);
    });

    test('`false` gerçek bir değerdir ve kilitler', () {
      final sonuc = applyManagedSettings(
        yerel,
        const KitchenManagedSettings(
          allowSettings: false,
          allowServerChange: false,
          allowWindowControls: false,
          allowOrderEdit: false,
          allowManualReprint: false,
          allowSalesControl: false,
        ),
      );

      expect(sonuc.allowSettings, isFalse);
      expect(sonuc.allowServerChange, isFalse);
      expect(sonuc.allowWindowControls, isFalse);
      expect(sonuc.allowOrderEdit, isFalse);
      expect(sonuc.allowManualReprint, isFalse);
      expect(sonuc.allowSalesControl, isFalse);
      expect(sonuc.hasLock, isTrue);
    });

    test('kilit yönetici `true` yazınca geri açılır', () {
      final kilitli = applyManagedSettings(
        yerel,
        const KitchenManagedSettings(allowSettings: false),
      );

      final acilmis = applyManagedSettings(
        kilitli,
        const KitchenManagedSettings(allowSettings: true),
      );

      expect(acilmis.allowSettings, isTrue);
    });

    test('kilit metni uygulanır; BOŞ DİZE genel metne döndürür', () {
      // `audio_sink` ile aynı istisna: `null` "dokunmadı"ya ayrılmış
      // olduğu için, yöneticinin yazdığı cümleyi geri almasının tek yolu
      // boş dize.
      final yazili = applyManagedSettings(
        yerel,
        const KitchenManagedSettings(lockMessage: 'Müdüre haber verin.'),
      );
      expect(yazili.lockMessage, 'Müdüre haber verin.');

      final dokunulmamis = applyManagedSettings(
        yazili,
        const KitchenManagedSettings(allowSettings: false),
      );
      expect(dokunulmamis.lockMessage, 'Müdüre haber verin.');

      final silinmis = applyManagedSettings(
        yazili,
        const KitchenManagedSettings(lockMessage: ''),
      );
      expect(silinmis.lockMessage, isEmpty);
    });

    test('kilit metni 160 karaktere kırpılır', () {
      final sonuc = applyManagedSettings(
        yerel,
        KitchenManagedSettings(lockMessage: 'a' * 400),
      );

      expect(sonuc.lockMessage, hasLength(KdsSettings.maxLockMessageLength));
    });

    test('kilit alanlarına dokunmayan sunucu kilidi çözmez', () {
      // Eski bir sunucu sürümü bu anahtarları hiç göndermiyor. Kilidin
      // sessizce açılması, kilit hiç olmamasıyla aynı sonucu verirdi.
      final kilitli = yerel.copyWith(
        allowSettings: false,
        lockMessage: 'Kontrol Merkezi yönetiyor.',
      );

      final sonuc = applyManagedSettings(
        kilitli,
        const KitchenManagedSettings(pollSeconds: 7),
      );

      expect(sonuc.allowSettings, isFalse);
      expect(sonuc.lockMessage, 'Kontrol Merkezi yönetiyor.');
    });
  });

  // ── K-22 §1 — olay bazlı sesler ──────────────────────────────────────
  //
  // Tel üzerindeki biçim virgülle ayrılmış `KdsSoundEvent` adları. Üç hâl
  // var ve üçü de farklı: `null` (dokunmadı), boş dize (hepsini aç), dolu
  // liste (tam olarak bunlar kapalı).
  group('Olay bazlı sesler', () {
    KitchenManagedSettings gelen(Object? value) =>
        KitchenManagedSettings.fromJson(<String, Object?>{
          'disabled_sound_events': value,
        });

    final ikisiKapali = yerel.copyWith(
      disabledSoundEvents: {
        KdsSoundEvent.printerError,
        KdsSoundEvent.lateOrder,
      },
    );

    test('ANAHTAR YOKKEN yerel liste korunur', () {
      // Eski bir sunucu sürümü bu anahtarı hiç göndermiyor. Listenin
      // sessizce boşalması, personelin kapattığı yazıcı uyarısının geri
      // gelip yeni sipariş sesini bastırması demekti.
      final sonuc = applyManagedSettings(
        ikisiKapali,
        KitchenManagedSettings.fromJson(const <String, Object?>{}),
      );

      expect(sonuc.disabledSoundEvents, ikisiKapali.disabledSoundEvents);
    });

    test('null gelirse yerel liste korunur', () {
      // `null` = "yönetici dokunmadı". "Hepsini aç" DEĞİL.
      final sonuc = applyManagedSettings(ikisiKapali, gelen(null));

      expect(sonuc.disabledSoundEvents, ikisiKapali.disabledSoundEvents);
    });

    test('BOŞ DİZE hepsini açar', () {
      // `audio_sink` ile aynı istisna: `null` "dokunmadı"ya ayrılmış
      // olduğu için yöneticinin kapattığı uyarıyı geri açmasının başka
      // yolu yok.
      final sonuc = applyManagedSettings(ikisiKapali, gelen(''));

      expect(sonuc.disabledSoundEvents, isEmpty);
      expect(sonuc.soundEnabledFor(KdsSoundEvent.printerError), isTrue);
    });

    test('liste uygulanır ve yerel listenin YERİNE geçer', () {
      final sonuc = applyManagedSettings(
        ikisiKapali,
        gelen('newOrder,bbdOrder'),
      );

      expect(sonuc.disabledSoundEvents, {
        KdsSoundEvent.newOrder,
        KdsSoundEvent.bbdOrder,
      });
      expect(sonuc.soundEnabledFor(KdsSoundEvent.printerError), isTrue);
      expect(sonuc.soundEnabledFor(KdsSoundEvent.newOrder), isFalse);
    });

    test('connectionLost ELENİR ama DİĞERLERİ uygulanır', () {
      // Yöneticinin yazım hatası mutfağı sessiz bırakmamalı: isteği
      // tamamen reddetmek, gerçekten kapatılmak istenen uyarıların da
      // açık kalması demek olurdu.
      final sonuc = applyManagedSettings(
        yerel,
        gelen('connectionLost,printerError'),
      );

      expect(sonuc.disabledSoundEvents, {KdsSoundEvent.printerError});
      expect(sonuc.soundEnabledFor(KdsSoundEvent.connectionLost), isTrue);
    });

    test('connectionLost TEK BAŞINA gelirse liste boşalır, hata olmaz', () {
      final sonuc = applyManagedSettings(ikisiKapali, gelen('connectionLost'));

      expect(sonuc.disabledSoundEvents, isEmpty);
    });

    test('BİLİNMEYEN olay adı yok sayılır', () {
      // Sözleşme eklemeli: sunucu kasadan yeni bir sürümde olabilir ve
      // henüz tanımadığımız bir olay gönderebilir. Ayrıştırmayı
      // patlatmak, o turdaki diğer ayarların da uygulanmaması demekti.
      final sonuc = applyManagedSettings(
        yerel,
        gelen('newOrder,fisBitti,lateOrder'),
      );

      expect(sonuc.disabledSoundEvents, {
        KdsSoundEvent.newOrder,
        KdsSoundEvent.lateOrder,
      });
    });

    test('boşluklu ve tekrarlı liste temizlenir', () {
      final sonuc = applyManagedSettings(
        yerel,
        gelen(' newOrder , newOrder ,lateOrder '),
      );

      expect(sonuc.disabledSoundEvents, {
        KdsSoundEvent.newOrder,
        KdsSoundEvent.lateOrder,
      });
    });

    test('ses listesi tek başına gelince DİĞER ayarlar korunur', () {
      final sonuc = applyManagedSettings(yerel, gelen('newOrder'));

      expect(sonuc.pollSeconds, yerel.pollSeconds);
      expect(sonuc.printerDevicePath, yerel.printerDevicePath);
      expect(sonuc.soundEnabled, yerel.soundEnabled);
    });

    test('boş küme ile null AYNI ŞEY DEĞİLDİR', () {
      // Model düzeyindeki ayrım: eşitlik ve özet bunları karıştırırsa
      // "hepsini aç" emri "dokunmadım" sanılıp yutulurdu.
      expect(gelen(''), isNot(gelen(null)));
      expect(gelen('').isEmpty, isFalse, reason: 'Boş dize bir emirdir.');
      expect(gelen(null).isEmpty, isTrue, reason: '`null` dokunmamaktır.');
    });
  });

  group('Komut çalıştırma', () {
    late List<String> cagrilar;

    CommandRunner build({
      Future<String?> Function()? test,
      Future<String?> Function(int, String)? reprint,
      Future<String?> Function()? update,
    }) => CommandRunner(
      CommandActions(
        printTestReceipt:
            test ??
            () async {
              cagrilar.add('test');
              return null;
            },
        reprint:
            reprint ??
            (id, tip) async {
              cagrilar.add('reprint:$id:$tip');
              return null;
            },
        clearFailed: () async {
          cagrilar.add('clear');
          return null;
        },
        silenceAlarm: () async {
          cagrilar.add('silence');
          return null;
        },
        restart: () async {
          cagrilar.add('restart');
          return null;
        },
        update:
            update ??
            () async {
              cagrilar.add('update');
              return null;
            },
        unpair: () async {
          cagrilar.add('unpair');
          return null;
        },
        clearQueue: () async {
          cagrilar.add('clear_queue');
          return null;
        },
      ),
    );

    setUp(() => cagrilar = []);

    test('her komut kendi eylemini tetikler', () async {
      final sonuc = await build().run(const [
        KitchenCommand(id: 1, command: KitchenCommand.testReceipt),
        KitchenCommand(id: 2, command: KitchenCommand.clearFailed),
        KitchenCommand(id: 3, command: KitchenCommand.silenceAlarm),
        KitchenCommand(id: 4, command: KitchenCommand.restart),
      ]);

      expect(cagrilar, ['test', 'clear', 'silence', 'restart']);
      expect(sonuc.map((r) => r.ok), everyElement(isTrue));
    });

    test('K-22 KOMUTLARI kendi eylemlerine bağlanır', () async {
      final sonuc = await build().run(const [
        KitchenCommand(id: 5, command: KitchenCommand.update),
        KitchenCommand(id: 6, command: KitchenCommand.unpair),
        KitchenCommand(id: 7, command: KitchenCommand.clearQueue),
      ]);

      expect(cagrilar, ['update', 'unpair', 'clear_queue']);
      expect(sonuc.map((r) => r.id), [5, 6, 7]);
      expect(sonuc.map((r) => r.ok), everyElement(isTrue));
    });

    test('KUYRUĞU BOŞALT ile BAŞARISIZLARI TEMİZLE ayrı eylemlerdir', () async {
      // İkisi tek eyleme bağlansaydı, yalnız hatalıları düşürmek isteyen
      // yönetici bekleyen sağlam fişleri de çöpe atmış olurdu.
      await build().run(const [
        KitchenCommand(id: 1, command: KitchenCommand.clearFailed),
        KitchenCommand(id: 2, command: KitchenCommand.clearQueue),
      ]);

      expect(cagrilar, ['clear', 'clear_queue']);
    });

    test('KURULUM BAŞARISIZSA komut gerekçesiyle başarısız döner', () async {
      // Kasa eski sürümde kalır ve yönetici NEDEN kalındığını panelde
      // görür; sessiz bir "çalıştı" yanıtı, güncellenmediğini ancak
      // sürüm sütununa bakan birinin fark etmesi demek olurdu.
      final sonuc = await build(
        update: () async => 'Paket açılamadı: bozuk arşiv',
      ).run(const [KitchenCommand(id: 9, command: KitchenCommand.update)]);

      expect(sonuc.single.ok, isFalse);
      expect(sonuc.single.message, 'Paket açılamadı: bozuk arşiv');
    });

    test('komutlar SIRAYLA çalışır', () async {
      // "Başarısız kuyruğu temizle" ile "fişi yeniden bas" aynı anda
      // koşarsa hangisinin kazandığı belirsiz olur.
      await build().run(const [
        KitchenCommand(id: 1, command: KitchenCommand.clearFailed),
        KitchenCommand(id: 2, command: KitchenCommand.testReceipt),
      ]);

      expect(cagrilar, ['clear', 'test']);
    });

    test('yeniden basma sipariş numarasını ve tipi geçirir', () async {
      await build().run(const [
        KitchenCommand(
          id: 1,
          command: KitchenCommand.reprint,
          payload: {'order_id': 42, 'type': 'musteri'},
        ),
      ]);

      expect(cagrilar, ['reprint:42:musteri']);
    });

    test('tip verilmezse mutfak fişi varsayılır', () async {
      await build().run(const [
        KitchenCommand(
          id: 1,
          command: KitchenCommand.reprint,
          payload: {'order_id': 7},
        ),
      ]);

      expect(cagrilar, ['reprint:7:mutfak']);
    });

    test('sipariş numarası eksikse gerekçeyle başarısız olur', () async {
      final sonuc = await build().run(const [
        KitchenCommand(id: 1, command: KitchenCommand.reprint),
      ]);

      expect(sonuc.single.ok, isFalse);
      expect(sonuc.single.message, contains('Sipariş numarası'));
      expect(cagrilar, isEmpty);
    });

    test('bir komut patlarsa diğerleri yine çalışır', () async {
      // Biri hatalı diye kalanların çalışmaması, yöneticinin gönderdiği
      // "yeniden başlat"ın kaybolması demek olurdu.
      final sonuc =
          await build(
            test: () async => throw StateError('yazıcı yok'),
          ).run(const [
            KitchenCommand(id: 1, command: KitchenCommand.testReceipt),
            KitchenCommand(id: 2, command: KitchenCommand.clearFailed),
          ]);

      expect(sonuc.first.ok, isFalse);
      expect(sonuc.first.message, contains('yazıcı yok'));
      expect(sonuc.last.ok, isTrue);
      expect(cagrilar, ['clear']);
    });

    test('eylem gerekçe döndürürse başarısız sayılır', () async {
      final sonuc = await build(
        test: () async => 'Kâğıt bitti',
      ).run(const [KitchenCommand(id: 9, command: KitchenCommand.testReceipt)]);

      expect(sonuc.single.ok, isFalse);
      expect(sonuc.single.message, 'Kâğıt bitti');
    });

    test('bilinmeyen komut sessizce yutulmaz', () async {
      // Yönetici bunu panelde görmeli, yoksa "gönderdim ama olmadı" diye
      // tekrar tekrar dener.
      final sonuc = await build().run(const [
        KitchenCommand(id: 1, command: 'ucus_moduna_gec'),
      ]);

      expect(sonuc.single.ok, isFalse);
      expect(sonuc.single.message, contains('tanımıyor'));
    });
  });
}
