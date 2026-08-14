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
      darkTheme: BldTheme.dark(),
      // KOYU TEMA TANIMLI AMA HENÜZ AÇIK DEĞİL — bilinçli bir karar.
      //
      // `dark()` bu turda baştan sona yazıldı ve rolleri marka kılavuzuyla
      // birebir aynı. Yine de `system`'e açmıyoruz: koyu temayı 19 ekranın
      // tamamında gözle görmeden göndermek, düzeltmesi App Store inceleme
      // döngüsü kadar süren TEK geri dönülemez risk. Yayınlanmış bir sürümde
      // okunmayan bir ekranı geri almanın yolu yok; yayınlanmamış bir temayı
      // açmanın yolu ise tek satır.
      //
      // Somut gerekçe: `lib/` içinde tema dosyasının dışında hâlâ doğrudan
      // `BldColors` çağıran ekranlar var ve bir kısmı `neutral0`'ı "beyaz"
      // diye kullanıyor. Bunlar koyu temada beyaz zemin üstünde beyaz metne
      // dönüşür; derleme hatası vermez, yalnız cihazda görünür. Ekran turu
      // yapıldıktan ve o çağrılar `Theme.of`/`BldSemanticColors` üzerinden
      // geçirildikten sonra burası `ThemeMode.system` olur — başka hiçbir
      // değişiklik gerekmez.
      themeMode: ThemeMode.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Tek dil: Türkçe. Cihaz dili ne olursa olsun arayüz Türkçedir
      // (`docs/03-api-sozlesmesi.md` §1.1 `Accept-Language: tr`).
      locale: const Locale('tr'),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
