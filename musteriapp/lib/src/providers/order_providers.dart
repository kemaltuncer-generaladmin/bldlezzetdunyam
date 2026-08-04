/// Sipariş sağlayıcıları: liste ve canlı takip.
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'infra_providers.dart';

/// `GET /orders` — en yeni önce.
final ordersProvider = FutureProvider.autoDispose<OrderPage>((ref) async {
  try {
    final page = await ref.watch(apiProvider).orders.list();
    ref.read(connectivityProvider.notifier).reportSuccess();
    return page;
  } on ApiException catch (error) {
    ref.read(connectivityProvider.notifier).reportFailure(error);
    rethrow;
  }
});

/// Sipariş takibi — 5 saniyede bir `GET /orders/{id}`.
///
/// WebSocket Faz 1.5'e ertelendiği için yoklama yapılır
/// (`infra/mock/README.md`). Sipariş terminal duruma (`teslim_edildi`,
/// `iptal`) ulaşınca yoklama durur; değişmeyecek bir kaydı dakikada 12 kez
/// istemenin anlamı yok.
final orderTrackingProvider = StreamProvider.autoDispose
    .family<OrderDetail, int>((ref, orderId) {
      final api = ref.watch(apiProvider);
      final connectivity = ref.read(connectivityProvider.notifier);
      final controller = StreamController<OrderDetail>();

      var hasEmitted = false;
      var finished = false;
      Timer? timer;

      Future<void> poll() async {
        try {
          final order = await api.orders.get(orderId);
          connectivity.reportSuccess();
          if (controller.isClosed) return;

          hasEmitted = true;
          controller.add(order);
          if (order.status.isTerminal) {
            finished = true;
            timer?.cancel();
          }
        } on ApiException catch (error, stackTrace) {
          connectivity.reportFailure(error);
          if (controller.isClosed) return;

          // Bir kez veri gösterebildiysek geçici hatada ekranı boşaltmayız;
          // son bilinen durum kalır ve bir sonraki tur düzeltir.
          if (!hasEmitted) controller.addError(error, stackTrace);
        }
      }

      unawaited(poll());
      timer = Timer.periodic(AppConfig.orderPollInterval, (t) {
        if (finished) {
          t.cancel();
          return;
        }
        unawaited(poll());
      });

      ref.onDispose(() {
        timer?.cancel();
        controller.close();
      });

      return controller.stream;
    });
