/// Duyuru bandının iki kuralı: **açık yönlendirme kapalı** ve **kapatılan
/// kimlikler kümesi sınırsız büyümüyor**.
///
/// İkisi de arayüz değil davranış: birincisi güvenlik açığı, ikincisi cihazda
/// sonsuza büyüyen bir kayıt.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musteriapp/src/data/local_cache.dart';
import 'package:musteriapp/src/providers/announcement_providers.dart';
import 'package:musteriapp/src/widgets/announcement_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

Announcement _announcement(
  int id, {
  String placement = AnnouncementPlacement.home,
  bool dismissed = false,
}) {
  return Announcement(
    id: id,
    placement: placement,
    body: '$id numaralı duyuru',
    dismissible: true,
    seen: false,
    dismissed: dismissed,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnnouncementAction.resolve — beyaz liste', () {
    test('beyaz listedeki sabit yollar uygulama-içi kabul edilir', () {
      for (final route in kAnnouncementAllowedRoutes) {
        final action = AnnouncementAction.resolve(route);
        expect(
          action.kind,
          AnnouncementActionKind.inApp,
          reason: '$route beyaz listede',
        );
        expect(action.target, route);
      }
    });

    test('günün menüsündeki kalem yolu kabul edilir', () {
      final action = AnnouncementAction.resolve('/menu/2026-08-20/41');
      expect(action.kind, AnnouncementActionKind.inApp);
      expect(action.target, '/menu/2026-08-20/41');
    });

    test('bozuk gün ya da kalem taşıyan menü yolu reddedilir', () {
      for (final path in [
        '/menu/2026-13-40/41', // takvimde olmayan gün
        '/menu/yarin/41',
        '/menu/2026-08-20/abc',
        '/menu/2026-08-20/0',
        '/menu/2026-08-20/-1',
        '/menu/2026-08-20', // eksik parça
        '/menu/2026-08-20/41/ekstra',
      ]) {
        expect(
          AnnouncementAction.resolve(path).kind,
          AnnouncementActionKind.none,
          reason: path,
        );
      }
    });

    test('beyaz listede olmayan uygulama-içi yollar reddedilir', () {
      for (final path in [
        '/checkout',
        '/login',
        '/account/addresses',
        '/orders/12',
        '/subscriptions/7',
        '/menu/../checkout',
        '/',
        'menu', // baştaki eğik çizgi yok
      ]) {
        expect(
          AnnouncementAction.resolve(path).kind,
          AnnouncementActionKind.none,
          reason: path,
        );
      }
    });

    test('sorgu ya da çapa taşıyan yol reddedilir', () {
      expect(
        AnnouncementAction.resolve('/menu?next=https://kotu.example').kind,
        AnnouncementActionKind.none,
      );
      expect(
        AnnouncementAction.resolve('/menu#/checkout').kind,
        AnnouncementActionKind.none,
      );
    });

    test('protokole göreli adres uygulama-içi SAYILMAZ', () {
      // `startsWith('/')` denetimini geçen klasik açık yönlendirme.
      for (final path in ['//kotu.example/menu', '//kotu.example']) {
        expect(
          AnnouncementAction.resolve(path).kind,
          AnnouncementActionKind.none,
          reason: path,
        );
      }
    });
  });

  group('AnnouncementAction.resolve — dış adres', () {
    test('https adres tarayıcıda açılmak üzere kabul edilir', () {
      final action = AnnouncementAction.resolve('https://ornek.example/kampanya');
      expect(action.kind, AnnouncementActionKind.external);
      expect(action.target, 'https://ornek.example/kampanya');
    });

    test('https dışındaki her şema reddedilir', () {
      for (final url in [
        'http://ornek.example',
        'javascript:alert(1)',
        'intent://kotu#Intent;end',
        'market://details?id=x',
        'file:///etc/passwd',
        'bld://menu',
        'https:///yetkisiz',
      ]) {
        expect(
          AnnouncementAction.resolve(url).kind,
          AnnouncementActionKind.none,
          reason: url,
        );
      }
    });

    test('boş ve null adres düğme üretmez', () {
      expect(AnnouncementAction.resolve(null).kind, AnnouncementActionKind.none);
      expect(AnnouncementAction.resolve('').kind, AnnouncementActionKind.none);
      expect(AnnouncementAction.resolve('   ').kind, AnnouncementActionKind.none);
    });
  });

  group('firstVisibleAnnouncement', () {
    test('sunucunun sırasına uyar, ilkini çizer', () {
      final chosen = firstVisibleAnnouncement(
        announcements: [_announcement(3), _announcement(4)],
        dismissed: const [],
        placement: AnnouncementPlacement.home,
      );
      expect(chosen?.id, 3);
    });

    test('bu cihazda kapatılan duyuru atlanır', () {
      final chosen = firstVisibleAnnouncement(
        announcements: [_announcement(3), _announcement(4)],
        dismissed: const [3],
        placement: AnnouncementPlacement.home,
      );
      expect(chosen?.id, 4);
    });

    test('sunucuda kapatılmış duyuru atlanır', () {
      final chosen = firstVisibleAnnouncement(
        announcements: [_announcement(3, dismissed: true), _announcement(4)],
        dismissed: const [],
        placement: AnnouncementPlacement.home,
      );
      expect(chosen?.id, 4);
    });

    test('başka yerleşimin duyurusu bu banda ÇİZİLMEZ', () {
      final chosen = firstVisibleAnnouncement(
        announcements: [
          _announcement(3, placement: AnnouncementPlacement.cart),
          // Panelde tanımlanmış, istemcinin bilmediği bir yerleşim.
          _announcement(4, placement: 'kampanya-sayfasi'),
        ],
        dismissed: const [],
        placement: AnnouncementPlacement.home,
      );
      expect(chosen, isNull);
    });

    test('hepsi kapatılmışsa bant çizilmez', () {
      final chosen = firstVisibleAnnouncement(
        announcements: [_announcement(3), _announcement(4)],
        dismissed: const [3, 4],
        placement: AnnouncementPlacement.home,
      );
      expect(chosen, isNull);
    });
  });

  group('LocalCache — kapatılan duyurular', () {
    late LocalCache cache;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      cache = LocalCache(await SharedPreferences.getInstance());
    });

    test('kayıt yoksa boş liste döner', () {
      expect(cache.readDismissedAnnouncements(), isEmpty);
    });

    test('kapatılan kimlik kalıcıdır', () async {
      await cache.writeDismissedAnnouncement(7);
      await cache.writeDismissedAnnouncement(9);
      expect(cache.readDismissedAnnouncements(), [7, 9]);
    });

    test('aynı kimlik iki kez yazılınca çoğalmaz, sona taşınır', () async {
      await cache.writeDismissedAnnouncement(1);
      await cache.writeDismissedAnnouncement(2);
      await cache.writeDismissedAnnouncement(1);
      expect(cache.readDismissedAnnouncements(), [2, 1]);
    });

    test('küme tavanı aşınca EN ESKİ kimlikler düşer', () async {
      const limit = LocalCache.dismissedAnnouncementLimit;
      for (var id = 1; id <= limit + 5; id++) {
        await cache.writeDismissedAnnouncement(id);
      }

      final stored = cache.readDismissedAnnouncements();
      expect(stored, hasLength(limit));
      expect(stored.first, 6);
      expect(stored.last, limit + 5);
    });

    test('bozuk kayıt atlanır, uygulama kilitlenmez', () async {
      SharedPreferences.setMockInitialValues({
        'bld.duyuru.kapatilan': <String>['3', 'bozuk', '5'],
      });
      final broken = LocalCache(await SharedPreferences.getInstance());
      expect(broken.readDismissedAnnouncements(), [3, 5]);
    });
  });
}
