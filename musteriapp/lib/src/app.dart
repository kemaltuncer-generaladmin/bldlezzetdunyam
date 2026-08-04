/// Uygulama kökü.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/bld_theme.dart';

class BldCustomerApp extends ConsumerWidget {
  const BldCustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: BldTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Tek dil: Türkçe. Cihaz dili ne olursa olsun arayüz Türkçedir
      // (`docs/03-api-sozlesmesi.md` §1.1 `Accept-Language: tr`).
      locale: const Locale('tr'),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
