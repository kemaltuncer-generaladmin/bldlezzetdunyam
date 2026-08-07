/// Adres formlarındaki il/ilçe alanları — `ServiceAreaFields`.
///
/// Kural (`docs/00-genel-bakis.md` §4.1): il sabit Konya, ilçe yalnızca
/// Selçuklu veya Karatay.
library;

import 'package:bld_core/bld_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musteriapp/src/features/location/service_area_fields.dart';
import 'package:musteriapp/src/l10n/app_localizations.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Material(child: child)),
  );

  testWidgets('il sabit gösterilir, düzenlenemez', (tester) async {
    await tester.pumpWidget(
      wrap(ServiceAreaFields(district: 'Selçuklu', onDistrictChanged: (_) {})),
    );

    expect(find.text(ServiceArea.city), findsOneWidget);
    // İl için düzenlenebilir bir alan olmamalı: denenip reddedilen bir alan,
    // hiç sunulmayan alandan kötü.
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('yalnızca hizmet verilen ilçeler listelenir', (tester) async {
    await tester.pumpWidget(
      wrap(ServiceAreaFields(district: null, onDistrictChanged: (_) {})),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    for (final district in ServiceArea.districts) {
      expect(find.text(district), findsWidgets);
    }
    expect(find.text('Meram'), findsNothing);
  });

  testWidgets('dışarıdan gelen ilçe seçimi ekrana yansır', (tester) async {
    // Ödeme ekranında kayıtlı adres seçilince ilçe dışarıdan değişir.
    // Yansımazsa kullanıcı eski seçimi görür ve formun bozuk olduğunu sanar.
    await tester.pumpWidget(
      wrap(ServiceAreaFields(district: 'Selçuklu', onDistrictChanged: (_) {})),
    );
    expect(find.text('Selçuklu'), findsOneWidget);

    await tester.pumpWidget(
      wrap(ServiceAreaFields(district: 'Karatay', onDistrictChanged: (_) {})),
    );
    await tester.pump();

    expect(find.text('Karatay'), findsOneWidget);
    expect(find.text('Selçuklu'), findsNothing);
  });

  testWidgets('hizmet alanı dışındaki eski ilçe seçili gösterilmez', (
    tester,
  ) async {
    // Kural daralmadan önce kaydedilmiş adresler var. Listede olmayan bir
    // değer dropdown'ı çalışma anında düşürür; dahası müşteri artık teslimat
    // yapmadığımız ilçeyi seçili görmemeli.
    await tester.pumpWidget(
      wrap(ServiceAreaFields(district: 'Nilüfer', onDistrictChanged: (_) {})),
    );

    expect(find.text('Nilüfer'), findsNothing);
    expect(ServiceAreaFields.sanitize('Nilüfer'), isNull);
  });
}
