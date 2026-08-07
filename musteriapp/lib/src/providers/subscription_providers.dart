/// Abonelik durum sağlayıcıları.
///
/// Aksiyonlar (duraklat/devam/iptal/oluştur) doğrudan `apiProvider` üzerinden
/// çağrılıp `subscriptionsProvider` invalidate edilir — sipariş iptalindeki
/// (order_tracking) kalıp gibi; ayrı bir notifier'a gerek yok.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'infra_providers.dart';
import 'session_provider.dart';

/// Müşterinin abonelikleri. Giriş yoksa boş liste — ekran giriş istemez,
/// yalnız boş durum gösterir.
final subscriptionsProvider = FutureProvider.autoDispose<List<Subscription>>((
  ref,
) async {
  final session = ref.watch(sessionProvider).valueOrNull;
  if (session == null || !session.isSignedIn) {
    return const <Subscription>[];
  }
  return ref.watch(apiProvider).subscriptions.list();
});

/// Tek abonelik detayı.
final subscriptionProvider = FutureProvider.autoDispose
    .family<Subscription, int>((ref, id) {
      return ref.watch(apiProvider).subscriptions.get(id);
    });
