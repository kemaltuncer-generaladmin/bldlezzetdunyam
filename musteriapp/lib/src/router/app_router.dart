/// Yönlendirme — `go_router`.
///
/// İki kapı vardır ve ikisi de burada uygulanır:
/// 1. **Zorunlu güncelleme:** sürüm `min_supported` altındaysa her yol
///    engelleyici ekrana döner (`docs/07-musteriapp.md` §2).
/// 2. **Oturum:** sipariş ve hesap yolları giriş ister; menü istemez
///    (katalog uçları kimlik gerektirmez, `docs/openapi.yaml` §Katalog).
///
/// ÜÇÜNCÜ BİR KAPI YOK: `can_order` sipariş kapısı Faz 0'da kaldırıldı. Cari
/// hesapla birlikte "yalnız onaylı kurumsal hesap sipariş verir" kuralı da
/// düştü; ödeme yöntemleri `online` ve `cash` ve ikisi de herkese açık.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_screen.dart';
import '../features/account/address_book_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/cart/cart_screen.dart';
import '../features/home/home_screen.dart';
import '../features/checkout/checkout_screen.dart';
import '../features/menu/daily_menu_item_screen.dart';
import '../features/menu/menu_screen.dart';
import '../features/orders/order_tracking_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/shell/home_shell.dart';
import '../features/splash/splash_screen.dart';
import '../features/subscriptions/subscription_create_screen.dart';
import '../features/subscriptions/subscription_detail_screen.dart';
import '../features/subscriptions/subscriptions_screen.dart';
import '../features/update/force_update_screen.dart';
import '../providers/catalog_providers.dart';
import '../providers/session_provider.dart';

abstract final class Routes {
  static const String splash = '/';
  static const String update = '/update';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String menu = '/menu';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String subscriptions = '/subscriptions';
  static const String subscriptionNew = '/subscriptions/new';
  static const String orders = '/orders';
  static const String account = '/account';
  static const String addresses = '/account/addresses';

  /// Günün menüsündeki bir kalemin detayı.
  ///
  /// Yolda GÜN de var: aynı ürün farklı günlerde farklı fiyatta satılabiliyor
  /// (`DailyMenuItem.effective_unit_price`) ve bir kalem her gün menüde
  /// olmayabiliyor. Yalnız ürün kimliğini taşıyan bir yol, hangi güne ait
  /// olduğunu söyleyemez — paylaşılan bir bağlantı yarın başka bir fiyat
  /// gösterirdi.
  static String dailyMenuItem(String serviceDate, int menuItemId) =>
      '/menu/$serviceDate/$menuItemId';

  static String orderTracking(int orderId) => '/orders/$orderId';

  static String subscriptionDetail(int id) => '/subscriptions/$id';
}

/// Giriş isteyen yollar.
///
/// Menü, sepet ve hesap sekmesi serbesttir — katalog uçları kimlik gerektirmez
/// ve hesap sekmesi giriş yapmamış kullanıcıya giriş düğmesi gösterir. Sipariş
/// yüzeyleri token olmadan zaten `401` alırdı.
bool _requiresAuth(String path) =>
    path.startsWith(Routes.orders) ||
    path.startsWith(Routes.checkout) ||
    // Adres defteri `/addresses` uçlarını kullanır; token yoksa 401 alırdı.
    path == Routes.addresses ||
    // Abonelik LİSTESİ (sekme) serbest — giriş yoksa boş görünür. Detay ve
    // yeni-talep uçları token ister.
    path.startsWith('${Routes.subscriptions}/');

/// Riverpod durum değişimlerini `go_router`'a bağlayan köprü.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(versionGateProvider, (_, _) => notifyListeners());
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.matchedLocation;
      final gate = ref.read(versionGateProvider);
      final session = ref.read(sessionProvider);

      // Sürüm ve oturum bilinmeden hiçbir ekran çizilmez; açılış ekranı
      // beklemeyi ve hatayı kendi gösterir.
      if (!gate.hasValue || !session.hasValue) {
        return path == Routes.splash ? null : Routes.splash;
      }

      if (gate.requireValue.updateRequired) {
        return path == Routes.update ? null : Routes.update;
      }
      // Açılış ana sayfaya: uygulama vitrinle karşılıyor. Menü ikinci
      // sekmede duruyor ve doğrudan adresle de açılabiliyor.
      if (path == Routes.update || path == Routes.splash) return Routes.home;

      if (!session.requireValue.isSignedIn && _requiresAuth(path)) {
        final next = Uri.encodeComponent(state.uri.toString());
        return '${Routes.login}?next=$next';
      }

      // SİPARİŞ KAPISI KALDIRILDI (Faz 0). Cari hesap kalkınca "yalnız
      // kurumsal onaylı hesap sipariş verir" kuralının dayanağı da kalktı:
      // ödeme artık online ya da nakit ve ikisi de herkese açık. Sepet/ödeme
      // yolları bu yüzden yalnızca OTURUM istiyor.
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.update,
        builder: (context, state) => const ForceUpdateScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) =>
            LoginScreen(nextLocation: state.uri.queryParameters['next']),
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, state) =>
            RegisterScreen(nextLocation: state.uri.queryParameters['next']),
      ),
      GoRoute(
        path: Routes.addresses,
        builder: (context, state) => const AddressBookScreen(),
      ),
      GoRoute(
        path: Routes.cart,
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: Routes.checkout,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/menu/:date/:id',
        builder: (context, state) => DailyMenuItemScreen(
          // Bozuk gün metni boş bırakılıyor: ekran o günün menüsünü
          // çözemeyince "bulunamadı" gösterir. Bugüne düşürmek, paylaşılan
          // bozuk bir bağlantıyı sessizce başka bir güne yönlendirirdi.
          date: state.pathParameters['date'] ?? '',
          menuItemId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) => OrderTrackingScreen(
          orderId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      // `new` statik yolu `:id`'den ÖNCE tanımlanır; aksi halde ":id" "new"i
      // yakalar ve talep ekranı hiç açılmaz.
      GoRoute(
        path: Routes.subscriptionNew,
        builder: (context, state) => const SubscriptionCreateScreen(),
      ),
      GoRoute(
        path: '/subscriptions/:id',
        builder: (context, state) => SubscriptionDetailScreen(
          id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          // Ana sayfa İLK dal: uygulama vitrinle açılıyor, düz listeyle
          // değil. Menü kaldırılmadı, ikinci sekmede duruyor.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.menu,
                builder: (context, state) => const MenuScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.subscriptions,
                builder: (context, state) => const SubscriptionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.orders,
                builder: (context, state) => const OrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.account,
                builder: (context, state) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
