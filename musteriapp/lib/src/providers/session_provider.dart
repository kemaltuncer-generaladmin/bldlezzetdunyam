/// Oturum durumu — token var mı, kim giriş yapmış?
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'infra_providers.dart';

/// Oturumun anlık görüntüsü.
///
/// [customer] `null` olabilir ama [isSignedIn] yine `true` olabilir: cihazda
/// geçerli bir token var ama profil henüz çekilemedi (çevrimdışı açılış).
/// Bu durumda kullanıcıyı giriş ekranına atmak yanlış olurdu.
@immutable
class Session {
  const Session({required this.isSignedIn, this.customer});

  static const Session signedOut = Session(isSignedIn: false);

  final bool isSignedIn;
  final Customer? customer;

  // `canOrder` KALDIRILDI (Faz 0). Cari hesap kalkınca "yalnız kurumsal onaylı
  // hesaplar sipariş verir" kuralının dayanağı da kalktı; herkes sipariş
  // veriyor. Sunucu bir gün yine bir hesabı kapatırsa bunu `POST /orders`
  // üzerinden söyler ve istemci hata metnini gösterir — istemcide bir kapı
  // tutmak, sunucunun kararını ikinci kez ve eskimiş bir kopyayla uygulamaktı.

  @override
  bool operator ==(Object other) =>
      other is Session &&
      other.isSignedIn == isSignedIn &&
      other.customer == customer;

  @override
  int get hashCode => Object.hash(isSignedIn, customer);
}

class SessionNotifier extends AsyncNotifier<Session> {
  @override
  Future<Session> build() => _load();

  Future<Session> _load() async {
    final token = await ref.read(tokenStoreProvider).read();
    if (token == null) return Session.signedOut;

    try {
      final customer = await ref.read(apiProvider).auth.me();
      ref.read(connectivityProvider.notifier).reportSuccess();
      return Session(isSignedIn: true, customer: customer);
    } on ApiException catch (error) {
      ref.read(connectivityProvider.notifier).reportFailure(error);

      // Token gerçekten geçersizse temizle; başka her hatada (ağ yok, 500)
      // token'ı koru — sunucu erişilemez diye kullanıcıyı çıkarmayız.
      if (error.isUnauthenticated) {
        await ref.read(tokenStoreProvider).clear();
        return Session.signedOut;
      }
      return const Session(isSignedIn: true);
    }
  }

  /// Token'ı yeniden doğrular. Açılış ekranı ve "tekrar dene" bunu çağırır.
  Future<void> refresh() async {
    state = const AsyncLoading<Session>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  /// Başarısızlıkta [ApiException] atar; çağıran ekranda gösterir.
  Future<void> login({required String email, required String password}) async {
    final api = ref.read(apiProvider);
    await api.auth.login(LoginRequest(email: email, password: password));
    ref.read(connectivityProvider.notifier).reportSuccess();
    state = AsyncData(await _load());
  }

  /// Başarısızlıkta [ApiException] atar; çağıran ekranda gösterir.
  Future<void> register(RegisterRequest request) async {
    final api = ref.read(apiProvider);
    await api.auth.register(request);
    ref.read(connectivityProvider.notifier).reportSuccess();
    state = AsyncData(await _load());
  }

  /// Sunucu erişilemez olsa bile yerel token silinir (api_client `logout`
  /// bunu garanti eder), yani kullanıcı her koşulda çıkabilir.
  Future<void> logout() async {
    try {
      await ref.read(apiProvider).auth.logout();
    } on ApiException {
      // Yutulur: yerel token zaten silindi, kullanıcı çıkışı tamamlanmıştır.
    }
    state = const AsyncData(Session.signedOut);
  }
}

final sessionProvider = AsyncNotifierProvider<SessionNotifier, Session>(
  SessionNotifier.new,
);
