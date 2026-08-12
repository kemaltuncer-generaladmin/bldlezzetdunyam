/// Dokunmatik kipte KLAVYE VE FARE GEREKMEZ — 12.08.2026 kuralı.
///
/// Kasada dokunmatik kip açıkken harici klavye takılı olmayacak. Bu, iki
/// somut şart demek:
///
///   1. **Her metin alanı kendi klavyesini getirmeli.** Getirmeyen tek bir
///      alan, personeli kasanın arkasına klavye aramaya gönderir.
///   2. **Her klavye kısayolunun dokunmatik karşılığı olmalı.** Yalnız F7
///      ile açılabilen bir ekran, dokunmatik kasada yok demektir.
///
/// SAHADA YAKALANDI: satış kontrolü (F7) yalnız satış **kapalıyken** çıkan
/// kırmızı şeritten açılabiliyordu. Yani dokunmatik kasada satışı kapatmanın
/// hiçbir yolu yoktu — kapatmak için önce kapalı olması gerekiyordu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/input/keyboard_text_field.dart';
import 'package:mutfakapp/src/input/onscreen_keyboard.dart';
import 'package:mutfakapp/src/l10n/app_localizations.dart';
import 'package:mutfakapp/src/settings/kds_settings.dart';

import 'kds_screen_test.dart' show pumpKds, tearDownTree;

Future<void> pumpField(
  WidgetTester tester, {
  required bool touchMode,
  required TextEditingController controller,
  ValueChanged<String>? onChanged,
}) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: KeyboardTextField(
          controller: controller,
          touchMode: touchMode,
          label: 'Ürün ara',
          onChanged: onChanged,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Metin alanı', () {
    testWidgets('DOKUNMATİKTE dokununca ekran klavyesi açılır', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpField(tester, touchMode: true, controller: controller);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.byType(OnscreenKeyboard), findsOneWidget);
    });

    testWidgets('KLASİK KİPTE pencere açılmaz — alan doğrudan yazılır', (
      tester,
    ) async {
      // Klavyesi olan bir kasada her dokunuşta pencere açmak yavaşlatır.
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpField(tester, touchMode: false, controller: controller);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.byType(OnscreenKeyboard), findsNothing);
    });

    testWidgets('dokunmatikte alan SALT OKUNUR — imleç yanıp sönmez', (
      tester,
    ) async {
      // Sistem klavyesi yokken yazılamayan bir alanda imlecin yanıp
      // sönmesi, personeli "bozuk" sanmaya iter.
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpField(tester, touchMode: true, controller: controller);

      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    });

    testWidgets('KLAVYEDEN YAZILAN metin alana ve onChanged\'e geçer', (
      tester,
    ) async {
      // `onChanged` kendiliğinden çalışmıyor: denetleyiciye programla
      // yazmak alanın geri çağrısını tetiklemiyor ve arama alanları buna
      // bağlı — çağırmazsak yazılan metin listeyi hiç süzmez.
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? seen;

      await pumpField(
        tester,
        touchMode: true,
        controller: controller,
        onChanged: (value) => seen = value,
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      for (final key in const ['p', 'i', 'l', 'a', 'v']) {
        await tester.tap(find.widgetWithText(InkWell, key).first);
        await tester.pump();
      }

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Kaydet'),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.text, 'pilav');
      expect(seen, 'pilav');
    });

    testWidgets('VAZGEÇİLİRSE metin değişmez', (tester) async {
      final controller = TextEditingController(text: 'çorba');
      addTearDown(controller.dispose);

      await pumpField(tester, touchMode: true, controller: controller);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(InkWell, 'x').first);
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Vazgeç'));
      await tester.pumpAndSettle();

      expect(controller.text, 'çorba');
    });
  });

  group('Kısayolların dokunmatik karşılığı', () {
    const settings = KdsSettings(
      soundEnabled: true,
      pollSeconds: 5,
      printerDevicePath: '/dev/thermal0',
      warningAfterMinutes: 10,
      lateAfterMinutes: 20,
      touchMode: true,
    );

    testWidgets('İŞLEMLER menüsü F3/F7/F8 ekranlarını sunar', (tester) async {
      // Bu üçü daha önce yalnız klavyeden ya da koşullu bir şeritten
      // açılabiliyordu.
      await pumpKds(tester, settings: settings, orders: const []);

      await tester.tap(find.byIcon(Icons.apps));
      await tester.pumpAndSettle();

      expect(find.text('Satış kontrolü'), findsOneWidget);
      expect(find.text('Abonelik üretim planı'), findsOneWidget);
      expect(find.text('Vardiya özeti'), findsOneWidget);

      await tearDownTree(tester);
    });

    testWidgets('SATIŞ AÇIKKEN de satış kontrolüne ulaşılır', (tester) async {
      // Eski hâlde satış kontrolü yalnız satış KAPALIYKEN çıkan kırmızı
      // şeritten açılıyordu: kapatmak için önce kapalı olmak gerekiyordu.
      await pumpKds(tester, settings: settings, orders: const []);

      expect(find.text('SİPARİŞ ALINMIYOR'), findsNothing);

      await tester.tap(find.byIcon(Icons.apps));
      await tester.pumpAndSettle();

      expect(find.text('Satış kontrolü'), findsOneWidget);

      await tearDownTree(tester);
    });
  });

  group('Klavye düzeni', () {
    testWidgets('RAKAMLAR VE ADRES İŞARETLERİ var', (tester) async {
      // Rakamsız bir düzende sunucu adresi (`https://api…`), eşleme kodu
      // (`A1B2-C3D4`) ve yazıcı yolu (`/dev/thermal0`) hiç yazılamıyordu:
      // dokunmatik bir kasa bu yüzden EŞLEŞEMİYORDU.
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpField(tester, touchMode: true, controller: controller);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      for (final key in const ['1', '0', '-', '/', ':', '.', '_', '@']) {
        expect(
          find.widgetWithText(InkWell, key),
          findsWidgets,
          reason: '"$key" tuşu yoksa adres ve kod alanları yazılamaz.',
        );
      }
    });

    testWidgets('adres yazılabiliyor', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpField(tester, touchMode: true, controller: controller);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      for (final key in const ['a', '1', ':', '/', '.']) {
        await tester.tap(find.widgetWithText(InkWell, key).first);
        await tester.pump();
      }

      expect(controller.text, isEmpty);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Kaydet'),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.text, 'a1:/.');
    });
  });
}
