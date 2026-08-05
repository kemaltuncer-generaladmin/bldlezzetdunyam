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

  @override
  Future<KitchenHealthStatus> report(KitchenHealthReport report) async {
    reports.add(report);
    if (fails) throw const ApiException.network();

    return KitchenHealthStatus(
      serverTime: DateTime.utc(2026, 8, 5, 12),
      ordersToday: ordersToday,
      ordersActive: ordersActive,
    );
  }
}
