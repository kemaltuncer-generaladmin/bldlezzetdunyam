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
import 'models/daily_menu.dart';
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

  /// Bir günün menüsü — satılabilir olan yalnız budur (B-19).
  ///
  /// [date] `YYYY-AA-GG`; verilmezse **bugün**. Menüsü olmayan gün de
  /// başarıyla döner ([DailyMenu.exists] yanlış) — boş gün bir hata değil,
  /// bir cevaptır ve istemciyi hata ekranına sokmaz.
  Future<DailyMenu> dailyMenu(int locationId, {String? date});

  /// Bir aralıktaki günlerin durumu — gün seçiciyi çizmek için.
  ///
  /// [from] verilmezse bugün, [to] verilmezse `from` + 30 gün. Aralık en
  /// fazla **92 gün**; daha genişi `VALIDATION_FAILED` atar.
  ///
  /// Yalnız menüsü olan ya da kapalı olan günler döner; listede olmayan gün
  /// "o gün bir şey yok" demektir.
  Future<List<MenuCalendarDay>> menuCalendar(
    int locationId, {
    String? from,
    String? to,
  });
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

  /// Adres önerisi — müşteri yazarken açılan liste (B-21).
  ///
  /// Sonuçlar hizmet alanına kilitlidir; kutu dışı eşleşmeler yanıta hiç
  /// girmez. Sağlayıcıya ulaşılamazsa **hata değil, boş liste** döner:
  /// öneri bir kolaylıktır, adres alanları elle de doldurulabiliyor. İstemci
  /// bu yüzden öneri listesini hiçbir zaman zorunlu bir adım yapmaz — liste
  /// boşken form yine gönderilebilir olmalıdır.
  ///
  /// [query] 3 karakterden kısaysa **ağa hiç çıkılmaz** ve boş liste döner;
  /// gerekçe uygulamada. [limit] 1..10 aralığına kısılır.
  Future<List<AddressSuggestion>> suggest(String query, {int limit = 5});

  /// Koordinattan adres (ters geocoding) — haritaya iğne bırakıldığında.
  ///
  /// `null` döner: sağlayıcı o noktayı bilmiyor ya da şu an erişilemiyor.
  /// İkisinde de doğru davranış aynıdır — **iğne korunur**, metin alanları
  /// elle doldurulur.
  ///
  /// Hizmet alanı dışındaki nokta `VALIDATION_FAILED` atar (`details.reason
  /// = "out_of_service_area"`): kullanıcı haritayı gördü ve teslimat
  /// yapmadığımız bir yeri kasten seçti; söylenecek net bir şey var.
  Future<AddressSuggestion?> reverse(double lat, double lng);
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
///
/// **MÜŞTERİ ARAYÜZLERİNDEN ÇAĞRILMIYOR, BİLEREK.** Cari hesap B-19'da web
/// ve mobil yüzeylerden kaldırıldı; bakiye ve ekstre artık yalnızca admin
/// panelinde görülüyor. Arka uç, uçlar ve panel AYNEN duruyor — bu yüzden
/// arayüz de silinmedi: silmek yayınlanmış bir sözleşme parçasını kaldırmak
/// olurdu (`AGENTS.md` §2.3, yalnızca ekleme yapılır) ve panelin okuduğu
/// veriyi istemci tarafında görünmez kılmak, yarın geri açılacağı zaman
/// yeniden yazmak demekti.
///
/// Yeni bir müşteri ekranı bunu çağırmadan önce kararın değiştiğini
/// doğrulayın: bugün doğru davranış çağırmamaktır.
abstract interface class AccountService {
  Future<AccountSummary> summary();

  /// [from]/[to] `YYYY-AA-GG`; verilmezse sunucu son 3 ayı döner.
  Future<AccountStatement> statement({String? from, String? to});
}
