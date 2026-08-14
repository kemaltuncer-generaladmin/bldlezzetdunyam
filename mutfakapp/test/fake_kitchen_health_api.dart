/// Testler için sahte sağlık ucu.
///
/// Gerçek istemci `dart:io` ile ağa çıkar; testte asla kullanılmamalı.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:mutfakapp/src/data/kitchen_health.dart';

class FakeKitchenHealthApi implements KitchenHealthApi {
  FakeKitchenHealthApi({this.ordersToday = 0, this.ordersActive = 0});

  int ordersToday;
  int ordersActive;

  /// `true` ise çağrı ağ hatası atar.
  bool fails = false;

  /// Gönderilen bildirimler — değerlerin gerçek olduğunu doğrulamak için.
  final List<KitchenHealthReport> reports = <KitchenHealthReport>[];

  /// Yanıtla birlikte inecek ayarlar.
  KitchenManagedSettings settings = KitchenManagedSettings.empty;

  /// Bir sonraki yanıtta teslim edilecek komutlar.
  ///
  /// TESLİM EDİLDİKTEN SONRA BOŞALIYOR — sunucudaki davranışın aynısı
  /// (`KitchenController::takeCommands` teslim ettiğini işaretliyor). Sabit
  /// kalsaydı komut her yoklamada yeniden çalışır ve "yeniden başlat"
  /// testleri sonsuz döngüye girerdi.
  List<KitchenCommand> commands = const <KitchenCommand>[];

  @override
  Future<KitchenHealthStatus> report(KitchenHealthReport report) async {
    reports.add(report);
    if (fails) throw const ApiException.network();

    final teslim = commands;
    commands = const <KitchenCommand>[];

    return KitchenHealthStatus(
      serverTime: DateTime.utc(2026, 8, 5, 12),
      ordersToday: ordersToday,
      ordersActive: ordersActive,
      settings: settings,
      commands: teslim,
    );
  }
}
