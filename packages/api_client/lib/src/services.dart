/// Servis arayüzleri — `docs/openapi.yaml`'daki uçların Dart imzaları.
///
/// Uygulamalar bu arayüzlere bağımlıdır, somut HTTP sınıflarına değil; testte
/// sahte uygulama vermek böylece bedava olur.
///
/// Her metot başarısızlıkta [ApiException] atar.
library;

import 'package:bld_core/bld_core.dart';

import 'models/account.dart';
import 'models/auth.dart';
import 'models/catalog.dart';
import 'models/kitchen.dart';
import 'models/order.dart';
import 'models/subscription.dart';

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

/// Adres defteri — `docs/openapi.yaml` §Adresler. Müşteri token'ı gerektirir.
abstract interface class AddressService {
  /// Varsayılan adres başta döner.
  Future<List<SavedAddress>> list();

  /// İlk adres kendiliğinden varsayılan olur.
  Future<SavedAddress> create(SavedAddressInput input);

  Future<SavedAddress> update(int id, SavedAddressInput input);

  /// Silinen adres varsayılansa kalanlardan biri varsayılan yapılır.
  Future<void> delete(int id);
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

  /// Bugün + yarının abonelik siparişleri (salt bilgi; mutfak planlaması).
  Future<KitchenSubscriptionOrders> subscriptionOrders();

  /// Mutfak fişi verisi (fiyatsız).
  Future<KitchenReceipt> kitchenReceipt(int orderId);

  /// Müşteri fişi verisi (fiyatlı, adrese gönderimde adresli).
  Future<CustomerReceipt> customerReceipt(int orderId);

  /// Kurye fişi (K-14) — ad, telefon, adres, tahsil edilecek tutar.
  ///
  /// Yalnız `delivery` siparişte anlamlı; gel-al'da kurye yoktur.
  Future<CourierReceipt> courierReceipt(int orderId);

  /// Fiş basıldı bildirimi. İdempotenttir; başarısız olursa çağıran sessizce
  /// yutar — fişin basılmış olması bu çağrıya bağlı değildir.
  Future<void> ackPrint(int orderId, PrintAckRequest request);

  Future<ProductionList> productionList();

  Future<HeartbeatResponse> heartbeat();

  /// Yoğunluk şalteri. Sipariş almayı DURDURMAZ; müşteri arayüzlerinde
  /// yalnızca gecikme uyarısı çıkarır.
  Future<BusyState> setBusy(bool busy);
}

/// Sürüm ucu — kimlik gerektirmez.
abstract interface class AppVersionService {
  Future<AppVersionInfo> check(String appId);
}

/// Abonelik uçları — müşteri token'ı gerektirir. Anlaşmalı fiyat müşteri
/// tarafından set edilmez; [create] bir TALEP açar (`status = pending`).
abstract interface class SubscriptionService {
  Future<List<Subscription>> list();

  Future<Subscription> get(int id);

  Future<Subscription> create(SubscriptionCreateRequest request);

  /// Yalnızca `active` iken; aksi halde `VALIDATION_FAILED`.
  Future<Subscription> pause(int id);

  /// Yalnızca `paused` iken.
  Future<Subscription> resume(int id);

  Future<Subscription> cancel(int id);

  /// Tek-günlük istisna (atla veya adet değiştir).
  Future<Subscription> addException(
    int id,
    SubscriptionExceptionRequest request,
  );
}

/// Cari hesap uçları — müşteri token'ı gerektirir.
abstract interface class AccountService {
  Future<AccountSummary> summary();

  /// [from]/[to] `YYYY-AA-GG`; verilmezse sunucu son 3 ayı döner.
  Future<AccountStatement> statement({String? from, String? to});
}
