/// Satış kontrolü — durdurma akışı, koruma ve "bugün tükendi" (K-11).
///
/// EN KRİTİK TEST: şifre olmadan satış durdurulamaz. Bu şalter ciroyu
/// kesiyor; korumanın kazara kalkması, mutfakta yanlışlıkla dokunulan bir
/// düğmenin dükkânı kapatması demek.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/data/providers.dart';
import 'package:mutfakapp/src/data/sales_control.dart';
import 'package:mutfakapp/src/l10n/app_localizations.dart';
import 'package:mutfakapp/src/sales/sales_control_screen.dart';

import 'fake_system_audio.dart';

/// Şifre penceresindeki alan.
///
/// `find.byType(TextField).first` KULLANILMAZ: ekranda ürün arama kutusu
/// da var ve ağaçta önce geliyor. Bir önceki sürüm şifreyi arama kutusuna
/// yazıyor, pencere boş şifreyle reddediyor ve "yanlış şifre" testi
/// DOĞRU SEBEPLE DEĞİL yanlış sebeple geçiyordu.
final Finder passwordField = find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(TextField),
);

Future<void> pumpSales(WidgetTester tester, FakeSalesControlApi api) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [salesControlApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: ThemeData.dark(),
        home: const SalesControlScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Durum kartı', () {
    testWidgets('açıkken yeşil "Sipariş alınıyor" gösterir', (tester) async {
      await pumpSales(tester, FakeSalesControlApi());

      expect(find.text('Sipariş alınıyor'), findsOneWidget);
      expect(find.text('SATIŞI DURDUR'), findsOneWidget);
    });

    testWidgets('kapalıyken sebep ve kalan süre görünür', (tester) async {
      final api = FakeSalesControlApi(enabled: false)
        ..reason = 'Yoğunluk'
        ..resumesAt = DateTime.now().toUtc().add(const Duration(minutes: 25));

      await pumpSales(tester, api);

      expect(find.text('SİPARİŞ ALINMIYOR'), findsOneWidget);
      expect(find.text('Yoğunluk'), findsOneWidget);
      expect(find.text('SATIŞI AÇ'), findsOneWidget);
    });

    testWidgets('süresiz kapalıysa bunu açıkça söyler', (tester) async {
      // "Kapattım, açmayı unuttum" en olası hata; süresiz kapatıldığını
      // gizlemek onu görünmez kılardı.
      await pumpSales(tester, FakeSalesControlApi(enabled: false));

      expect(find.textContaining('Elle açılana kadar'), findsOneWidget);
    });
  });

  group('Durdurma akışı', () {
    testWidgets('ŞİFRE OLMADAN SATIŞ DURDURULAMAZ', (tester) async {
      final api = FakeSalesControlApi();
      await pumpSales(tester, api);

      await tester.tap(find.text('SATIŞI DURDUR'));
      await tester.pumpAndSettle();

      // 1. adım: süre
      await tester.tap(find.text('30 dakika'));
      await tester.pumpAndSettle();

      // 2. adım: sebep
      await tester.tap(find.text('Yoğunluk'));
      await tester.pumpAndSettle();

      // 3. adım: şifre — burada VAZGEÇİYORUZ.
      expect(find.text('Açılış şifresi'), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      expect(
        api.lastOrderingCall,
        isNull,
        reason: 'Şifre girilmeden sunucuya istek gitmemeli.',
      );
      expect(api.enabled, isTrue);
    });

    testWidgets('yanlış şifre kabul edilmez', (tester) async {
      final api = FakeSalesControlApi();
      await pumpSales(tester, api);

      await tester.tap(find.text('SATIŞI DURDUR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 dakika'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yoğunluk'));
      await tester.pumpAndSettle();

      await tester.enterText(passwordField, 'yanlis');
      await tester.tap(find.widgetWithText(FilledButton, 'Aç'));
      await tester.pumpAndSettle();

      expect(find.text('Şifre yanlış.'), findsOneWidget);
      expect(api.lastOrderingCall, isNull);
    });

    testWidgets('süre ve sebep sunucuya geçirilir', (tester) async {
      final api = FakeSalesControlApi();
      await pumpSales(tester, api);

      await tester.tap(find.text('SATIŞI DURDUR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bugünün sonuna kadar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Malzeme bitti'));
      await tester.pumpAndSettle();

      await tester.enterText(passwordField, 'Bld2026.');
      await tester.tap(find.widgetWithText(FilledButton, 'Aç'));
      await tester.pumpAndSettle();

      expect(api.lastOrderingCall, isNotNull);
      expect(api.lastOrderingCall!.enabled, isFalse);
      expect(api.lastOrderingCall!.reason, 'Malzeme bitti');
      // Gün sonu = 0 dakika; süresiz `null` ile karıştırılmamalı.
      expect(api.lastOrderingCall!.minutes, 0);
    });

    testWidgets('süresiz seçenek dakika GÖNDERMEZ', (tester) async {
      final api = FakeSalesControlApi();
      await pumpSales(tester, api);

      await tester.tap(find.text('SATIŞI DURDUR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ben açana kadar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yoğunluk'));
      await tester.pumpAndSettle();

      await tester.enterText(passwordField, 'Bld2026.');
      await tester.tap(find.widgetWithText(FilledButton, 'Aç'));
      await tester.pumpAndSettle();

      expect(api.lastOrderingCall!.minutes, isNull);
    });

    testWidgets('AÇMAK DA şifre ister', (tester) async {
      // Yanlışlıkla açılan bir dükkân, yanlışlıkla kapanan kadar zararlı:
      // mutfak hazır değilken sipariş akmaya başlar.
      final api = FakeSalesControlApi(enabled: false);
      await pumpSales(tester, api);

      await tester.tap(find.text('SATIŞI AÇ'));
      await tester.pumpAndSettle();

      expect(find.text('Açılış şifresi'), findsOneWidget);
      expect(api.lastOrderingCall, isNull);
    });
  });

  group('Ürün listesi', () {
    final items = const [
      KitchenMenuItem(menuId: 1, name: 'Mercimek Çorbası', listed: true, soldOut: false),
      KitchenMenuItem(menuId: 2, name: 'Pilav', listed: true, soldOut: true),
      KitchenMenuItem(menuId: 3, name: 'Kapalı Ürün', listed: false, soldOut: false),
    ];

    testWidgets('TÜKENENLER ÜSTTE listelenir', (tester) async {
      // Mutfağın bakmak istediği liste "neyi kapattım"dır, tüm menü değil.
      await pumpSales(tester, FakeSalesControlApi(items: items));

      final tiles = tester.widgetList<SwitchListTile>(
        find.byType(SwitchListTile),
      ).toList();

      expect(tiles.first.value, isTrue, reason: 'İlk satır tükenen olmalı.');
    });

    testWidgets('yöneticinin kapattığı ürün DEĞİŞTİRİLEMEZ', (tester) async {
      // Mutfak "açtım ama görünmüyor" durumuna düşmemeli: o karar
      // yöneticinin ve buradan geri alınamaz.
      await pumpSales(tester, FakeSalesControlApi(items: items));

      final tile = tester.widget<SwitchListTile>(
        find.ancestor(
          of: find.text('Kapalı Ürün'),
          matching: find.byType(SwitchListTile),
        ),
      );

      expect(tile.onChanged, isNull);
      expect(find.text('Menüde değil (yönetici kapattı)'), findsOneWidget);
    });

    testWidgets('anahtar sunucuya tükendi bilgisini yazar', (tester) async {
      final api = FakeSalesControlApi(items: items);
      await pumpSales(tester, api);

      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Mercimek Çorbası'),
            matching: find.byType(SwitchListTile),
          ),
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        api.items.firstWhere((item) => item.menuId == 1).soldOut,
        isTrue,
      );
    });

    testWidgets('arama listeyi daraltır', (tester) async {
      await pumpSales(tester, FakeSalesControlApi(items: items));

      await tester.enterText(
        find.descendant(
          of: find.byType(SalesControlScreen),
          matching: find.byType(TextField),
        ),
        'pilav',
      );
      await tester.pumpAndSettle();

      expect(find.text('Pilav'), findsOneWidget);
      expect(find.text('Mercimek Çorbası'), findsNothing);
    });
  });

  group('OrderingState', () {
    test('kalan süre negatife düşmez', () {
      final state = OrderingState(
        enabled: false,
        serverTime: DateTime.utc(2026, 8, 11, 12),
        resumesAt: DateTime.utc(2026, 8, 11, 11),
      );

      expect(state.remaining(DateTime.utc(2026, 8, 11, 12)), Duration.zero);
    });

    test('açıkken kalan süre yoktur', () {
      final state = OrderingState(
        enabled: true,
        serverTime: DateTime.utc(2026, 8, 11, 12),
        resumesAt: DateTime.utc(2026, 8, 11, 13),
      );

      expect(state.remaining(DateTime.utc(2026, 8, 11, 12)), isNull);
    });

    test('süresiz durdurmada kalan süre yoktur', () {
      final state = OrderingState(
        enabled: false,
        serverTime: DateTime.utc(2026, 8, 11, 12),
      );

      expect(state.remaining(DateTime.utc(2026, 8, 11, 12)), isNull);
    });
  });

  group('KitchenMenuItem', () {
    test('sipariş edilebilirlik iki koşulun BİRLİKTE sağlanmasıdır', () {
      const listedAvailable = KitchenMenuItem(
        menuId: 1, name: 'a', listed: true, soldOut: false,
      );
      const soldOut = KitchenMenuItem(
        menuId: 2, name: 'b', listed: true, soldOut: true,
      );
      const unlisted = KitchenMenuItem(
        menuId: 3, name: 'c', listed: false, soldOut: false,
      );

      expect(listedAvailable.orderable, isTrue);
      expect(soldOut.orderable, isFalse);
      expect(unlisted.orderable, isFalse);
    });
  });
}
