/// Servis arayüzleri — `docs/openapi.yaml`'daki uçların Dart imzaları.
///
/// Uygulamalar bu arayüzlere bağımlıdır, somut HTTP sınıflarına değil; testte
/// sahte uygulama vermek böylece bedava olur.
///
/// Her metot başarısızlıkta [ApiException] atar.
library;

import 'package:bld_core/bld_core.dart';

import 'models/auth.dart';
import 'models/catalog.dart';
import 'models/kitchen.dart';
import 'models/order.dart';

// `OrderStatus` imzalarda geçtiği için yeniden dışa aktarılır; çağıranların
// ayrıca bld_core'u import etmesi gerekmesin.
export 'package:bld_core/bld_core.dart' show OrderStatus;

/// Kimlik uçları — `customer` kapsamı üretir.
abstract interface class AuthService {
  Future<AuthResponse> register(RegisterRequest request);

  Future<AuthResponse> login(LoginRequest request);

  /// Sunucudaki token'ı iptal eder. Yerel token'ı silmek çağıranın işidir.
  Future<void> logout();

  Future<Customer> me();

  Future<void> registerPushToken(PushTokenRequest request);
}

/// Katalog uçları — kimlik gerektirmez.
abstract interface class CatalogService {
  Future<List<Location>> locations();

  Future<List<MenuCategory>> menu(int locationId);
}

/// Müşteri sipariş uçları.
abstract interface class OrderService {
  Future<OrderCreated> create(OrderCreateRequest request);

  Future<OrderPage> list({int page = 1, int perPage = 25});

  Future<OrderDetail> get(int id);

  /// Yalnızca `yeni` ve `onaylandi` durumlarında; aksi halde
  /// `INVALID_TRANSITION`.
  Future<OrderDetail> cancel(int id);
}

/// KDS uçları — `kitchen` kapsamı gerektirir.
abstract interface class KitchenService {
  /// Cihaz kaydı. Dönen token'ı saklamak çağıranın işidir.
  Future<PairResponse> pair(PairRequest request);

  /// Aktif siparişler.
  ///
  /// [after] yalnızca yeni siparişleri, [since] güncellenenleri getirir.
  /// Durum değişimlerini yakalamak için [since] kullanılmalıdır.
  Future<KitchenOrderPage> orders({
    int? after,
    DateTime? since,
    bool includeCompleted = false,
  });

  Future<KitchenOrder> setStatus(int orderId, OrderStatus status);

  /// Mutfak fişi verisi (fiyatsız).
  Future<KitchenReceipt> kitchenReceipt(int orderId);

  /// Müşteri fişi verisi (fiyatlı, adrese gönderimde adresli).
  Future<CustomerReceipt> customerReceipt(int orderId);

  /// Fiş basıldı bildirimi. İdempotenttir; başarısız olursa çağıran sessizce
  /// yutar — fişin basılmış olması bu çağrıya bağlı değildir.
  Future<void> ackPrint(int orderId, PrintAckRequest request);

  Future<ProductionList> productionList();

  Future<HeartbeatResponse> heartbeat();
}

/// Sürüm ucu — kimlik gerektirmez.
abstract interface class AppVersionService {
  Future<AppVersionInfo> check(String appId);
}
