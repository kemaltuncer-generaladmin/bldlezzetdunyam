/// Uygulama kökü.
///
/// İki ekran vardır ve aralarındaki geçiş tek bir koşula bağlıdır: cihaz
/// eşlenmiş mi? (`docs/05-mutfakapp.md` §7)
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/providers.dart';
import 'kds/kds_screen.dart';
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
  /// Eşleme ekranına iptal yüzünden mi düşüldü? Yalnızca uyarı metni içindir.
  bool _revoked = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(deviceSessionProvider);

    // Eşlenmemişken sipariş kaynağını hiç kurmayız: token'sız polling
    // sunucuya boşuna 401 üretir.
    if (!session.isPaired) return PairingScreen(revoked: _revoked);

    return _PairedRoot(onRevoked: () => setState(() => _revoked = true));
  }
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
