/// Uygulama kökü.
///
/// İki ekran vardır ve aralarındaki geçiş tek bir koşula bağlıdır: cihaz
/// eşlenmiş mi? (`docs/05-mutfakapp.md` §7)
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/escpos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/providers.dart';
import 'printing/startup_test_print.dart';
import 'kds/kds_screen.dart';
import 'lock/unlock_screen.dart';
import 'l10n/app_localizations.dart';
import 'pairing/pairing_screen.dart';
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
    home: const AppRoot(),
  );
}

/// Eşleme durumuna göre ekran seçer.
class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> {
  @override
  void initState() {
    super.initState();

    // Açılış test fişi — yazıcının çalıştığı KÂĞIT ÜZERİNDE görülsün.
    // Kâğıdın bittiğini ya da USB'nin çıktığını ilk siparişte öğrenmek
    // geç: o sipariş basılmadan mutfağa düşer ve kimse fark etmez.
    //
    // Kilitten ÖNCE basılıyor: personel parolayı girerken fiş çıkmış
    // olur, ayrıca bir işlem yapması gerekmez.
    final config = ref.read(appConfigProvider);
    unawaited(
      printStartupTestReceipt(
        print: ref.read(printServiceProvider).printDiagnostic,
        devicePath: config.printerDevicePath,
        now: DateTime.now(),
        style: ReceiptStyle(codePage: config.printerCodePage),
      ),
    );
  }

  /// Eşleme ekranına iptal yüzünden mi düşüldü? Yalnızca uyarı metni içindir.
  bool _revoked = false;

  /// Açılış parolası girildi mi?
  ///
  /// KALICIDIR: bir kez girildikten sonra bir daha sorulmaz. Her yeniden
  /// başlatmada sorulsaydı, çökme sonrası kendini geri getiren servis
  /// (`Restart=always`) mutfağı kilit ekranında bırakırdı ve vardiya
  /// ortasında bunu kimse fark etmezdi.
  ///
  /// Başlangıçta `null`: diskten okunana kadar hangi durumda olduğumuzu
  /// bilmiyoruz ve kilit ekranını bir an gösterip kaldırmak göz tırmalar.
  bool? _unlocked;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_unlocked != null) return;

    unawaited(
      ref.read(unlockStoreProvider).isUnlocked().then((acik) {
        if (mounted) setState(() => _unlocked = acik);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(deviceSessionProvider);

    // Eşlenmemişken sipariş kaynağını hiç kurmayız: token'sız polling
    // sunucuya boşuna 401 üretir.
    if (!session.isPaired) {
      return _unlocked == true
          ? PairingScreen(revoked: _revoked)
          : _lockScreen();
    }

    // KİLİT EKRANI ÜSTTE DURUR, AĞACIN YERİNE GEÇMEZ.
    //
    // Eskiden kilitliyken `_PairedRoot` hiç kurulmuyordu; sipariş kaynağı,
    // yazdırma tetikleri ve alarmlar da kurulmuyordu. Sonuç: kasa yeniden
    // başladığında parola girilene kadar sipariş GELMİYORDU ve bağlantı
    // alarmı da çalmıyordu — çünkü yoklama hiç başlamamıştı.
    //
    // Artık her şey arkada çalışır: siparişler düşer, fiş basılır, alarm
    // çalar. Kilit yalnızca ekrana dokunulmasını engeller.
    return Stack(
      children: [
        _PairedRoot(onRevoked: () => setState(() => _revoked = true)),
        if (_unlocked != true) _lockScreen(),
      ],
    );
  }

  Widget _lockScreen() => UnlockScreen(
    onUnlocked: () {
      setState(() => _unlocked = true);
      unawaited(ref.read(unlockStoreProvider).remember());
    },
  );
}

/// Eşliyken çalışan ağaç. Ayrı bir bileşen olması bilinçli: [orderSourceProvider]
/// ve yazdırma tetikleri yalnızca burada kurulur.
class _PairedRoot extends ConsumerWidget {
  const _PairedRoot({required this.onRevoked});

  final VoidCallback onRevoked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Yazdırma tetikleri (`K-06`) hiçbir widget tarafından okunmadığı için
    // burada açıkça canlı tutulur; yoksa sağlayıcı hiç kurulmaz ve fiş basmaz.
    ref.watch(printTriggersProvider);

    // Alarm ve sağlık bildirimi de aynı sebeple: ikisi de arayüzde
    // görünmedikleri anlarda (ayarlar ekranı açıkken, pano boşken) çalışmaya
    // devam etmeli. Bir dinleyicisi olmayan sağlayıcı hiç kurulmaz.
    ref
      ..watch(newOrderAlarmProvider)
      ..watch(connectionAlarmProvider)
      ..watch(kitchenHealthProvider);

    ref.listen<AsyncValue<OrderSourceConnection>>(connectionProvider, (
      _,
      next,
    ) {
      if (next.value != OrderSourceConnection.revoked) return;
      onRevoked();
      // Token'ı silmek eşleme ekranına dönüşü tetikler (`docs/05` §7 adım 5).
      ref.read(deviceSessionProvider.notifier).clearToken();
    });

    return const KdsScreen();
  }
}
