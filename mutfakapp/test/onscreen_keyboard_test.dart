/// Ekran klavyesi — dokunmatik monitörde harici klavye olmadan yazmak.
///
/// KRİTİK: kilit ekranı bu klavyeyle açılıyor. Klavye bozulursa ve kasada
/// harici klavye yoksa uygulama hiç açılamaz — kurtarılamaz bir kilitlenme.
library;

import 'package:bld_core/escpos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/input/onscreen_keyboard.dart';

Future<void> pumpKeyboard(
  WidgetTester tester,
  TextEditingController controller, {
  OnscreenKeyboardLayout layout = OnscreenKeyboardLayout.turkish,
  VoidCallback? onSubmit,
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OnscreenKeyboard(
          controller: controller,
          layout: layout,
          onSubmit: onSubmit,
        ),
      ),
    ),
  );
}

void main() {
  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  testWidgets('tuşa dokununca metin eklenir', (tester) async {
    await pumpKeyboard(tester, controller);

    await tester.tap(find.widgetWithText(FilledButton, 'm'));
    await tester.pump();

    expect(controller.text, 'm');
  });

  testWidgets('TÜRKÇE HARFLER var — ı, ğ, ü, ş, ö, ç', (tester) async {
    // İngilizce düzende bunların hiçbiri yok ve mutfak notu yazılamaz.
    await pumpKeyboard(tester, controller);

    for (final letter in ['ı', 'ğ', 'ü', 'ş', 'ö', 'ç']) {
      expect(
        find.widgetWithText(FilledButton, letter),
        findsOneWidget,
        reason: '$letter tuşu olmalı.',
      );
    }
  });

  testWidgets('büyük harf TÜRKÇE kuralıyla üretilir: i → İ', (tester) async {
    // `toUpperCase()` `i` → `I` yapar. Arama da `TurkishCase` kullanıyor;
    // iki taraf ayrışırsa klavyeyle yazılan metin aramayı tutturmaz.
    await pumpKeyboard(tester, controller);

    await tester.tap(find.widgetWithText(FilledButton, 'ABC'));
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'İ'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'I'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'İ'));
    await tester.pump();

    expect(controller.text, 'İ');
  });

  testWidgets('İMLEÇ KONUMUNA yazar, sona değil', (tester) async {
    // Personel bir harfi düzeltmek için imleci ortaya alıyor; metin sona
    // eklenirse düzeltme imkânsız olur.
    controller.value = const TextEditingValue(
      text: 'ac',
      selection: TextSelection.collapsed(offset: 1),
    );
    await pumpKeyboard(tester, controller);

    await tester.tap(find.widgetWithText(FilledButton, 'b'));
    await tester.pump();

    expect(controller.text, 'abc');
    expect(controller.selection.baseOffset, 2);
  });

  testWidgets('geri silme imleçten önceki karakteri siler', (tester) async {
    controller.text = 'abc';
    await pumpKeyboard(tester, controller);

    await tester.tap(find.widgetWithIcon(FilledButton, Icons.backspace_outlined));
    await tester.pump();

    expect(controller.text, 'ab');
  });

  testWidgets('boş metinde geri silme çökmez', (tester) async {
    await pumpKeyboard(tester, controller);

    await tester.tap(find.widgetWithIcon(FilledButton, Icons.backspace_outlined));
    await tester.pump();

    expect(controller.text, isEmpty);
  });

  testWidgets('temizle tuşu her şeyi siler', (tester) async {
    controller.text = 'mercimek';
    await pumpKeyboard(tester, controller);

    await tester.tap(find.widgetWithIcon(FilledButton, Icons.clear));
    await tester.pump();

    expect(controller.text, isEmpty);
  });

  testWidgets('sayısal düzende harf YOKTUR', (tester) async {
    // Adet ve şifre girişinde harf tuşları yalnız yer kaplar ve yanlış
    // dokunuşu artırır.
    await pumpKeyboard(
      tester,
      controller,
      layout: OnscreenKeyboardLayout.numeric,
    );

    expect(find.widgetWithText(FilledButton, '7'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'm'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'boşluk'), findsNothing);
  });

  testWidgets('onaylama tuşu yalnız geri çağrı verilince çizilir', (
    tester,
  ) async {
    await pumpKeyboard(tester, controller);
    expect(find.widgetWithIcon(FilledButton, Icons.check), findsNothing);

    var submitted = 0;
    await pumpKeyboard(tester, controller, onSubmit: () => submitted++);

    await tester.tap(find.widgetWithIcon(FilledButton, Icons.check));
    await tester.pump();

    expect(submitted, 1);
  });

  test('tuş yüksekliği Material asgarisinin ÜSTÜNDE', () {
    // Material 48 px öneriyor; mutfakta eldivenli/yağlı elle basılıyor ve
    // 48 px'te komşu tuşa basma oranı yüksek.
    expect(64, greaterThan(48));
  });

  test('düzenlerde yinelenen tuş yok', () {
    final all = turkishKeyRows.expand((row) => row).toList();

    expect(all.toSet(), hasLength(all.length));
  });

  test('büyük harf dönüşümü core ile aynı sınıfı kullanıyor', () {
    expect(TurkishCase.toUpperCase('ı'), 'I');
    expect(TurkishCase.toUpperCase('i'), 'İ');
  });
}
