/// Günün menüsü testleri için ortak kurgu.
///
/// NEDEN ORTAK: B-19'dan sonra menü ekranını çizen her widget testi üç şeyi
/// birden sahtelemek zorunda — vitrin, günün menüsü ve menü takvimi. Üçü de
/// aile (`family`) sağlayıcısı ve aile anahtarları BUGÜNÜN TARİHİNE bağlı.
/// Her dosyada ayrı ayrı kurulduğunda biri takvimi unutuyor, diğeri günü
/// `DateTime.now()` ile hesaplayıp gece yarısı kırılan bir test bırakıyordu.
///
/// **Gün SABİTLENİYOR** ([fixedToday]): `BusinessDate.today()` cihaz saatini
/// okur; testin beklediği metin ("14 Ağustos 2026 menüsü") o zaman koştuğu
/// güne göre değişirdi.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musteriapp/src/providers/catalog_providers.dart';

/// Testlerin "bugün" saydığı işletme günü.
const String fixedToday = '2026-08-20';

/// Bir gün sonrası — ileri tarihli sipariş senaryoları için.
const String fixedTomorrow = '2026-08-21';

class _FixedToday extends BusinessTodayNotifier {
  @override
  String build() => fixedToday;
}

/// Bir günün örnek menüsü: iki kalem + paket.
DailyMenu sampleDailyMenu({
  String date = fixedToday,
  bool isOrderable = true,
  bool closed = false,
  bool withPackage = true,
  List<MenuItem> items = const [
    MenuItem(
      id: 101,
      name: 'Mercimek Çorbası',
      price: 6000,
      currency: 'TRY',
      isAvailable: true,
    ),
    MenuItem(
      id: 102,
      name: 'Etli Nohut',
      price: 14000,
      currency: 'TRY',
      isAvailable: true,
    ),
  ],
  DailyMenuUnavailableReason unavailableReason =
      DailyMenuUnavailableReason.none,
}) {
  return DailyMenu(
    id: 7,
    date: date,
    currency: 'TRY',
    closed: closed,
    isOrderable: isOrderable,
    title: 'Ev Yemeği Menüsü',
    itemsTotal: items.fold<int>(0, (total, item) => total + item.price),
    unavailableReason: unavailableReason,
    package: withPackage
        ? const DailyMenuPackage(
            menuId: 900,
            name: 'Günün Menüsü',
            price: 18000,
            isAvailable: true,
            components: [
              DailyMenuPackageComponent(
                menuId: 101,
                name: 'Mercimek Çorbası',
                quantity: 1,
              ),
              DailyMenuPackageComponent(
                menuId: 102,
                name: 'Etli Nohut',
                quantity: 1,
              ),
            ],
          )
        : null,
    items: items,
  );
}

/// Menü ekranını çizebilmek için gereken sağlayıcı override'ları.
///
/// [lookaheadDays] vitrinin `max_lookahead_days` değeriyle AYNI olmalı:
/// takvim ailesinin anahtarı ondan hesaplanıyor ve tutmazsa override hiç
/// eşleşmez, test sessizce gerçek ağ katmanına düşerdi.
List<Override> dailyMenuOverrides({
  DailyMenu? today,
  DailyMenu? tomorrow,
  List<MenuCalendarDay>? calendar,
  int lookaheadDays = 30,
}) {
  final todayMenu = today ?? sampleDailyMenu();
  final tomorrowMenu = tomorrow ?? sampleDailyMenu(date: fixedTomorrow);

  return [
    businessTodayProvider.overrideWith(_FixedToday.new),
    dailyMenuProvider(fixedToday).overrideWith(
      (ref) async => DailyMenuSnapshot(menu: todayMenu, fromCache: false),
    ),
    dailyMenuProvider(fixedTomorrow).overrideWith(
      (ref) async => DailyMenuSnapshot(menu: tomorrowMenu, fromCache: false),
    ),
    menuCalendarProvider((
      from: fixedToday,
      to: BusinessDate.addDays(fixedToday, lookaheadDays),
    )).overrideWith(
      (ref) async =>
          calendar ??
          const [
            MenuCalendarDay(
              date: fixedToday,
              hasMenu: true,
              closed: false,
              isOrderable: true,
              title: 'Ev Yemeği Menüsü',
              packagePrice: 18000,
            ),
            MenuCalendarDay(
              date: fixedTomorrow,
              hasMenu: true,
              closed: false,
              isOrderable: true,
              packagePrice: 18000,
            ),
          ],
    ),
  ];
}
