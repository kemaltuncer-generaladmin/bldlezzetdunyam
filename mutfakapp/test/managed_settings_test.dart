/// Sunucudan yönetilen ayarlar ve komutlar — `docs/05-mutfakapp.md` §8.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/data/command_runner.dart';
import 'package:mutfakapp/src/data/kitchen_health.dart';
import 'package:mutfakapp/src/data/managed_settings.dart';
import 'package:mutfakapp/src/settings/kds_settings.dart';

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
  });

  group('Komut çalıştırma', () {
    late List<String> cagrilar;

    CommandRunner build({
      Future<String?> Function()? test,
      Future<String?> Function(int, String)? reprint,
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
