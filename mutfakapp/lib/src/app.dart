/// Uygulama kökü. Tek ekran vardır (`docs/05-mutfakapp.md` §3), bu yüzden
/// yönlendirici yoktur.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'kds/kds_screen.dart';
import 'l10n/app_localizations.dart';
import 'theme/kds_theme.dart';

class MutfakApp extends StatelessWidget {
  const MutfakApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (context) => AppL10n.of(context).appTitle,
    debugShowCheckedModeBanner: false,
    theme: KdsTheme.build(),
    // Tek dil: Türkçe. Cihaz dili ne olursa olsun mutfak Türkçe görür.
    locale: const Locale('tr'),
    localizationsDelegates: const [
      AppL10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppL10n.supportedLocales,
    home: const KdsScreen(),
  );
}
