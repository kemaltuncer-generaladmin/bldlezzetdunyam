/// Riverpod bağlantı noktaları.
///
/// Ekran kodu somut sınıf bilmez: [orderSourceProvider] bugün
/// `PollingOrderSource`, Faz 1.5'te `WebSocketOrderSource` döndürecek ve
/// arayüzde tek satır değişmeyecek (ADR-05).
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/escpos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../kds/board.dart';
import '../printing/print_queue.dart';
import '../printing/print_service.dart';
import '../printing/print_triggers.dart';
import '../printing/printer_device.dart';
import 'device_session.dart';
import 'polling_order_source.dart';
import 'printer_probe.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

/// `main` bunları gerçek örneklerle geçersiz kılar; testler kendi sahtesini
/// verir. Diskten okuma asenkron olduğu için açılışta bir kez yapılır ve
/// buraya enjekte edilir — sağlayıcılar senkron kalır.
final deviceSessionStoreProvider = Provider<DeviceSessionStore>(
  (ref) => DeviceSessionStore(),
);

final initialDeviceSessionProvider = Provider<DeviceSession>(
  (ref) => DeviceSession(baseUrl: ref.watch(appConfigProvider).baseUrl),
);

/// Cihazın hangi sunucuya, hangi token'la bağlı olduğu.
final deviceSessionProvider =
    NotifierProvider<DeviceSessionController, DeviceSession>(
      DeviceSessionController.new,
    );

/// Eşleme, eşlemeyi bozma ve adres değişikliği tek yerden geçer.
class DeviceSessionController extends Notifier<DeviceSession> {
  @override
  DeviceSession build() => ref.watch(initialDeviceSessionProvider);

  /// Eşleme kodunu token'a çevirir (`docs/05-mutfakapp.md` §7 adım 3).
  ///
  /// Adres önce kaydedilir ve duruma yazılır; [bldApiProvider] bu durumu
  /// izlediği için sonraki okumada **yeni adrese** kurulmuş bir istemci gelir.
  Future<void> pair({
    required String baseUrl,
    required String pairingCode,
    required String deviceName,
  }) async {
    await ref.read(deviceSessionStoreProvider).writeBaseUrl(baseUrl);
    state = DeviceSession(baseUrl: baseUrl);

    // `BldApi.kitchen.pair` dönen token'ı zaten TokenStore'a yazar.
    final response = await ref
        .read(bldApiProvider)
        .kitchen
        .pair(PairRequest(pairingCode: pairingCode, deviceName: deviceName));

    state = DeviceSession(baseUrl: baseUrl, token: response.token);
  }

  /// Token iptal edildi (`403 DEVICE_REVOKED`) ya da personel sıfırladı.
  Future<void> clearToken() async {
    if (!state.isPaired) return;
    await ref.read(deviceSessionStoreProvider).clearToken();
    state = DeviceSession(baseUrl: state.baseUrl);
  }
}

final bldApiProvider = Provider<BldApi>((ref) {
  final session = ref.watch(deviceSessionProvider);
  final api = BldApi(
    config: BldApiConfig(
      baseUrl: session.baseUrl,
      appId: AppConfig.appId,
      appVersion: AppConfig.appVersion,
    ),
    tokenStore: ref.watch(deviceSessionStoreProvider).tokens,
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

// ────────────────────────── Yazdırma (K-04, K-06) ──────────────────────────

/// Diskteki kuyruk. `main` gerçek dosya yoluyla geçersiz kılar; varsayılan
/// bellek içi olması testlerin yanlışlıkla diske yazmasını önler.
final printQueueProvider = Provider<PrintQueue>((ref) {
  final queue = PrintQueue.inMemory();
  ref.onDispose(queue.close);
  return queue;
});

final printerDeviceProvider = Provider<PrinterDevice>(
  (ref) => UsbPrinterDevice(ref.watch(appConfigProvider).printerDevicePath),
);

final printServiceProvider = Provider<PrintService>((ref) {
  final config = ref.watch(appConfigProvider);
  final service = PrintService(
    queue: ref.watch(printQueueProvider),
    device: ref.watch(printerDeviceProvider),
    kitchen: ref.watch(kitchenServiceProvider),
    style: ReceiptStyle(codePage: config.printerCodePage),
  )..start();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

/// Bekleyen yazdırma işi sayısı — durum çubuğundaki "Kuyruk: n".
final printQueueCountProvider = StreamProvider<int>(
  (ref) => ref.watch(printServiceProvider).pendingCount,
);

/// Sipariş listesindeki olayları otomatik olarak fişe çevirir (`docs/05` §5.5).
///
/// Dinleyicisi olmayan bir sağlayıcı hiç kurulmaz; bu yüzden ekran kökü bunu
/// açıkça izler.
final printTriggersProvider = NotifierProvider<PrintTriggerRunner, int>(
  PrintTriggerRunner.new,
);

/// Kuyruğa eklenen toplam iş sayısını tutar.
///
/// Durum değerinin kendisi arayüzde kullanılmaz; tetiklerin çalıştığını
/// gözlenebilir kılar ve testte doğrulanmasını sağlar.
class PrintTriggerRunner extends Notifier<int> {
  final PrintTriggers _triggers = PrintTriggers();

  @override
  int build() {
    ref.listen<AsyncValue<List<KitchenOrder>>>(kitchenOrdersProvider, (
      _,
      next,
    ) {
      final orders = next.value;
      if (orders != null) _dispatch(orders);
    }, fireImmediately: true);

    return 0;
  }

  void _dispatch(List<KitchenOrder> orders) {
    final service = ref.read(printServiceProvider);
    var queued = 0;
    for (final job in _triggers.jobsFor(orders)) {
      if (service.enqueue(job.orderId, job.type)) queued++;
    }
    if (queued > 0) state = state + queued;
  }
}

// ────────────────────────────────── Pano ──────────────────────────────────

final boardProvider = Provider<Map<KdsColumn, List<KitchenOrder>>>((ref) {
  final orders = ref.watch(kitchenOrdersProvider).value;
  return groupIntoColumns(orders ?? const <KitchenOrder>[]);
});

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
    // üretim şeridini, sütun sayaçlarını ve yazdırma tetiklerini tek adımda
    // tutarlı kılar.
    await _source.refresh();
  }
}
