/// Riverpod bağlantı noktaları.
///
/// Ekran kodu somut sınıf bilmez: [orderSourceProvider] bugün
/// `PollingOrderSource`, Faz 1.5'te `WebSocketOrderSource` döndürecek ve
/// arayüzde tek satır değişmeyecek (ADR-05).
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../kds/board.dart';
import 'polling_order_source.dart';
import 'printer_probe.dart';
import 'token_store.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

/// `main` bunu gerçek depoyla geçersiz kılar; testler kendi sahtesini verir.
final tokenStoreProvider = Provider<TokenStore>(
  (ref) => SharedPreferencesTokenStore(),
);

final bldApiProvider = Provider<BldApi>((ref) {
  final config = ref.watch(appConfigProvider);
  final api = BldApi(
    config: BldApiConfig(
      baseUrl: config.baseUrl,
      appId: AppConfig.appId,
      appVersion: AppConfig.appVersion,
    ),
    tokenStore: ref.watch(tokenStoreProvider),
  );
  ref.onDispose(api.close);
  return api;
});

final kitchenServiceProvider = Provider<KitchenService>(
  (ref) => ref.watch(bldApiProvider).kitchen,
);

final orderSourceProvider = Provider<OrderSource>((ref) {
  final source = PollingOrderSource(
    kitchen: ref.watch(kitchenServiceProvider),
    interval: ref.watch(appConfigProvider).pollInterval,
  )..start();
  ref.onDispose(() => unawaited(source.dispose()));
  return source;
});

/// Ekranda çizilecek tam liste. Her yayın diff değil, listenin tamamıdır.
final kitchenOrdersProvider = StreamProvider<List<KitchenOrder>>(
  (ref) => ref.watch(orderSourceProvider).watch(),
);

final connectionProvider = StreamProvider<OrderSourceConnection>(
  (ref) => ref.watch(orderSourceProvider).connection,
);

final printerStatusProvider = StreamProvider<PrinterAvailability>(
  (ref) => PrinterProbe(ref.watch(appConfigProvider).printerDevicePath).watch(),
);

/// Bekleyen yazdırma işi sayısı — durum çubuğundaki "Kuyruk: n".
///
/// Kuyruğun kendisi `K-04`'te SQLite ile gelir ve [PrintQueueCount.update]
/// üzerinden bu sayacı besler; yazdırma henüz devrede olmadığı için değer
/// sıfırdır.
final printQueueCountProvider = NotifierProvider<PrintQueueCount, int>(
  PrintQueueCount.new,
);

/// Durum çubuğunun okuduğu kuyruk sayacı.
class PrintQueueCount extends Notifier<int> {
  @override
  int build() => 0;

  void update(int pendingJobs) => state = pendingJobs;
}

/// Sütunlara dağıtılmış pano.
final boardProvider = Provider<Map<KdsColumn, List<KitchenOrder>>>((ref) {
  final orders = ref.watch(kitchenOrdersProvider).value;
  return groupIntoColumns(orders ?? const <KitchenOrder>[]);
});

/// Üretim şeridi satırları.
final productionTotalsProvider = Provider<List<ProductionTotal>>((ref) {
  final orders = ref.watch(kitchenOrdersProvider).value;
  return productionTotals(orders ?? const <KitchenOrder>[]);
});

/// Personelin bastığı ileri adımı sunucuya iletir.
///
/// Kararı sunucu verir; istemcideki geçiş matrisi yalnızca geçersiz butonu
/// göstermemek içindir (`bld_core/order_status.dart`).
final orderStatusControllerProvider = Provider<OrderStatusController>(
  (ref) => OrderStatusController(
    kitchen: ref.watch(kitchenServiceProvider),
    source: ref.watch(orderSourceProvider),
  ),
);

/// Durum ilerletme isteğini atıp listeyi tazeler.
class OrderStatusController {
  const OrderStatusController({
    required KitchenService kitchen,
    required OrderSource source,
  }) : _kitchen = kitchen,
       _source = source;

  final KitchenService _kitchen;
  final OrderSource _source;

  /// [order]'ı bir sonraki duruma taşır. Terminal durumda hiçbir şey yapmaz.
  ///
  /// Hata çağırana bırakılır: mutfakta sessizce başarısız olan bir buton,
  /// personelin siparişi iki kez hazırlamasına yol açar.
  Future<void> advance(KitchenOrder order) async {
    final next = order.nextStatus;
    if (next == null) return;

    await _kitchen.setStatus(order.id, next);
    // Sunucu güncel siparişi döndürüyor ama listeyi kaynaktan tazelemek
    // üretim şeridini ve sütun sayaçlarını da tek adımda tutarlı kılar.
    await _source.refresh();
  }
}
