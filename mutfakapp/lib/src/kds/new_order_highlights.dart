/// "Yeni sipariş 3 saniye yanıp söner + sesli uyarı" kuralı
/// (`docs/05-mutfakapp.md` §3, `docs/10-test-kabul.md` S1 adım 5).
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';

/// Şu an vurgulanan sipariş kimlikleri.
final newOrderHighlightsProvider =
    NotifierProvider<NewOrderHighlights, Set<int>>(NewOrderHighlights.new);

/// Listeye yeni düşen `yeni` durumundaki siparişleri kısa süre işaretler.
///
/// Yalnızca `yeni` durumundakiler vurgulanır: uygulama yeniden başladığında
/// (elektrik kesintisi, güncelleme) ekrandaki tüm kartların yanıp sönmesi
/// mutfakta gürültüden başka bir şey değildir; dikkat isteyen kart, henüz
/// onaylanmamış olandır.
class NewOrderHighlights extends Notifier<Set<int>> {
  /// `docs/05` §3: kart 3 saniye yanıp söner.
  static const Duration highlightDuration = Duration(seconds: 3);

  final Set<int> _seen = <int>{};
  final Map<int, Timer> _timers = <int, Timer>{};

  /// İlk yayın "zaten ekranda olanlar" kabul edilir, uyarı üretmez.
  bool _primed = false;

  @override
  Set<int> build() {
    ref.onDispose(() {
      for (final timer in _timers.values) {
        timer.cancel();
      }
      _timers.clear();
    });

    ref.listen<AsyncValue<List<KitchenOrder>>>(kitchenOrdersProvider, (
      _,
      next,
    ) {
      final orders = next.value;
      if (orders != null) _onOrders(orders);
    }, fireImmediately: true);

    return const <int>{};
  }

  void _onOrders(List<KitchenOrder> orders) {
    final currentIds = orders.map((order) => order.id).toSet();
    _seen.retainWhere(currentIds.contains);

    final arrivals = <int>[];
    for (final order in orders) {
      if (!_seen.add(order.id)) continue;
      if (order.status == OrderStatus.yeni) arrivals.add(order.id);
    }

    if (!_primed) {
      _primed = true;
      return;
    }
    if (arrivals.isEmpty) return;

    // Tek "ding": aynı anda üç sipariş düşerse üç kez öttürmek gürültüdür.
    unawaited(SystemSound.play(SystemSoundType.alert));

    state = {...state, ...arrivals};
    for (final id in arrivals) {
      _timers[id]?.cancel();
      _timers[id] = Timer(highlightDuration, () => _expire(id));
    }
  }

  void _expire(int id) {
    _timers.remove(id);
    if (!state.contains(id)) return;
    state = {...state}..remove(id);
  }
}
