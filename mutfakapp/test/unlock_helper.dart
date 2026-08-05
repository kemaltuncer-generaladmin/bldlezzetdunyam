/// Widget testleri için açılış kilidini geçer.
///
/// Üretim koduna "testte kilidi atla" bayrağı EKLEMİYORUZ. Böyle bir
/// bayrak, kilidi kazara devre dışı bırakacak tek satırlık bir hata
/// yüzeyi olurdu ve testler onu göremezdi. Bunun yerine gerçek parolayı
/// gerçek alana yazıyoruz; kilit her testte fiilen çalışıyor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/lock/unlock_screen.dart';

Future<void> unlockApp(WidgetTester tester) async {
  // Kilit ekranı artık KDS'in ÜSTÜNDE duruyor ve arkadaki ekranın kendi
  // metin kutuları var (arama). Bulucuyu kilit ekranına daraltmazsak
  // "birden fazla eşleşme" hatası alınır.
  await tester.enterText(
    find.descendant(
      of: find.byType(UnlockScreen),
      matching: find.byType(TextField),
    ),
    'Bld2026.',
  );
  await tester.testTextInput.receiveAction(TextInputAction.go);
  await tester.pump();
}
