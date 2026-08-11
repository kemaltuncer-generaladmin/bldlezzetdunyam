/// Sipariş düzenleme ekranı — K-14.
///
/// Ekranın iki işi var ve ikisi de yanlış yapılırsa pahalı: **sebep
/// olmadan kaydettirmemek** (revizyon belgesi sebepsiz kalır) ve
/// **değişiklik yokken kaydettirmemek** (boş revizyon fişleri yeniden
/// bastırır, mutfakta kâğıt para demek).
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/data/order_edit.dart';
import 'package:mutfakapp/src/data/providers.dart';
import 'package:mutfakapp/src/edit/order_edit_screen.dart';
import 'package:mutfakapp/src/l10n/app_localizations.dart';

import 'fake_system_audio.dart';

class _FakeOrderSource implements OrderSource {
  int refreshCount = 0;

  @override
  Stream<List<KitchenOrder>> watch() =>
      const Stream<List<KitchenOrder>>.empty();

  @override
  Stream<OrderSourceConnection> get connection =>
      Stream<OrderSourceConnection>.value(OrderSourceConnection.connected);

  @override
  Future<void> refresh() async => refreshCount++;

  @override
  Future<void> dispose() async {}
}

/// Düzenleme ekranını **bir ana ekranın üstüne iterek** kurar.
///
/// `home:` olarak vermek gerçeği yansıtmıyordu: ekran kaydedince kendini
/// kapatıyor ve altında bir `Scaffold` kalmayınca `ScaffoldMessenger`
/// bildirimleri düşürüyor. Üretimde altta pano var; test de öyle olmalı,
/// yoksa "kaydettikten sonra uyarı görünüyor mu" sorusu hiç sınanmaz.
Future<void> pumpEdit(
  WidgetTester tester,
  FakeOrderEditApi api, {
  OrderSource? source,
}) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        orderEditApiProvider.overrideWithValue(api),
        orderSourceProvider.overrideWithValue(source ?? _FakeOrderSource()),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(OrderEditScreen.route(5012)),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
}

/// "Mercimek Çorbası" satırındaki düğme.
Finder rowButton(String product, IconData icon) => find.descendant(
  of: find.ancestor(of: find.text(product), matching: find.byType(Row)).first,
  matching: find.byIcon(icon),
);

void main() {
  group('Açılış', () {
    testWidgets('TELEFON ve "önce arayın" uyarısı en üstte durur', (
      tester,
    ) async {
      // Sıralama tersine çevrilirse müşteriye haber verilmeden değişmiş
      // bir sipariş oluşur.
      await pumpEdit(tester, FakeOrderEditApi());

      expect(find.text('0555 123 45 67'), findsOneWidget);
      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(
        find.text('Kaydetmeden ÖNCE müşteriyi arayın ve anlaşın.'),
        findsOneWidget,
      );
    });

    testWidgets('kalemler mevcut adetleriyle gelir', (tester) async {
      await pumpEdit(tester, FakeOrderEditApi());

      expect(find.text('Mercimek Çorbası'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('FİYAT GÖSTERİLMEZ (ADR-08)', (tester) async {
      await pumpEdit(tester, FakeOrderEditApi());

      expect(find.textContaining('₺'), findsNothing);
      expect(find.textContaining('TL'), findsNothing);
    });

    testWidgets('abonelik siparişinde YALNIZ BUGÜN uyarısı çıkar', (
      tester,
    ) async {
      // Uyarı olmasa personel "her gün 10 olsun" sanır.
      final api = FakeOrderEditApi(
        order: const EditableOrder(
          id: 5012,
          orderNumber: 'S-5012',
          status: OrderStatus.onaylandi,
          deliveryType: DeliveryType.delivery,
          isSubscription: true,
          items: [EditableItem(menuId: 1, name: 'Çorba', quantity: 4)],
        ),
      );

      await pumpEdit(tester, api);

      expect(find.textContaining('YALNIZ bugünü etkiler'), findsOneWidget);
    });
  });

  group('Kaydetme koruması', () {
    testWidgets('DEĞİŞİKLİK YOKKEN kaydedilemez', (tester) async {
      // Boş revizyon fişleri yeniden bastırır — kâğıt para demek.
      await pumpEdit(tester, FakeOrderEditApi());

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Hiçbir şey değişmedi.'),
      );

      expect(button.onPressed, isNull);
    });

    testWidgets('SEBEP SEÇİLMEDEN kaydedilemez', (tester) async {
      final api = FakeOrderEditApi();
      await pumpEdit(tester, api);

      await tester.tap(rowButton('Mercimek Çorbası', Icons.remove));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'KAYDET VE FİŞ BAS'));
      await tester.pumpAndSettle();

      expect(find.text('Sebep seçmeden kaydedilemez.'), findsOneWidget);
      expect(api.lastRevision, isNull);
    });

    testWidgets('ONAY PENCERESİNDEN vazgeçilirse istek gitmez', (tester) async {
      final api = FakeOrderEditApi();
      await pumpEdit(tester, api);

      await tester.tap(rowButton('Mercimek Çorbası', Icons.remove));
      await tester.pump();
      await tester.tap(find.text('Müşteri talebi'));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'KAYDET VE FİŞ BAS'));
      await tester.pumpAndSettle();

      expect(find.text('Değişikliği kaydet'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Vazgeç'));
      await tester.pumpAndSettle();

      expect(api.lastRevision, isNull);
    });
  });

  group('Adet değiştirme', () {
    testWidgets('eksi düğmesi adedi azaltır', (tester) async {
      await pumpEdit(tester, FakeOrderEditApi());

      await tester.tap(rowButton('Mercimek Çorbası', Icons.remove));
      await tester.pump();

      expect(find.text('19'), findsOneWidget);
    });

    testWidgets('ADET SIFIRA İNİNCE kalem kalkar', (tester) async {
      // Eksiye basa basa sıfıra inen personelin beklentisi kalkması.
      final api = FakeOrderEditApi(
        order: const EditableOrder(
          id: 5012,
          orderNumber: 'S-5012',
          status: OrderStatus.onaylandi,
          deliveryType: DeliveryType.delivery,
          items: [
            EditableItem(menuId: 1, name: 'Çorba', quantity: 1),
            EditableItem(menuId: 2, name: 'Pilav', quantity: 2),
          ],
        ),
      );
      await pumpEdit(tester, api);

      await tester.tap(rowButton('Çorba', Icons.remove));
      await tester.pumpAndSettle();

      expect(find.text('Çorba'), findsNothing);
      expect(find.text('Pilav'), findsOneWidget);
    });

    testWidgets('çöp düğmesi kalemi kaldırır', (tester) async {
      await pumpEdit(tester, FakeOrderEditApi());

      await tester.tap(rowButton('Pilav', Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Pilav'), findsNothing);
    });

    testWidgets('TÜM KALEMLER kaldırılırsa kaydetme kapalı kalır', (
      tester,
    ) async {
      // Tümünü kaldırmak "iptal" demek ve o ayrı bir akış.
      final api = FakeOrderEditApi(
        order: const EditableOrder(
          id: 5012,
          orderNumber: 'S-5012',
          status: OrderStatus.onaylandi,
          deliveryType: DeliveryType.delivery,
          items: [EditableItem(menuId: 1, name: 'Çorba', quantity: 1)],
        ),
      );
      await pumpEdit(tester, api);

      await tester.tap(rowButton('Çorba', Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Sipariş boş bırakılamaz'),
        findsOneWidget,
      );

      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byType(Material),
          matching: find.byType(FilledButton),
        ).last,
      );
      expect(button.onPressed, isNull);
    });
  });

  group('Kaydetme', () {
    Future<void> saveWithReason(WidgetTester tester) async {
      await tester.tap(find.text('Müşteri talebi'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'KAYDET VE FİŞ BAS'));
      await tester.pumpAndSettle();
      // Onay penceresindeki kaydet.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'KAYDET VE FİŞ BAS'),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sebep ve kalemler sunucuya geçirilir', (tester) async {
      final api = FakeOrderEditApi();
      await pumpEdit(tester, api);

      await tester.tap(rowButton('Mercimek Çorbası', Icons.remove));
      await tester.pump();
      await saveWithReason(tester);

      expect(api.lastRevision, isNotNull);
      expect(api.lastRevision!.reason, 'Müşteri talebi');
      expect(
        api.lastRevision!.items.firstWhere((i) => i.menuId == 1).quantity,
        19,
      );
    });

    testWidgets('kaydedince sipariş kaynağı TAZELENİR', (tester) async {
      // Tazelenmezse fişler bir yoklama turu geç tetiklenir.
      final api = FakeOrderEditApi();
      final source = _FakeOrderSource();
      await pumpEdit(tester, api, source: source);

      await tester.tap(rowButton('Mercimek Çorbası', Icons.remove));
      await tester.pump();
      await saveWithReason(tester);

      expect(source.refreshCount, greaterThan(0));
    });

    testWidgets('ELLE TAMAMLANACAK iade personele bildirilir', (tester) async {
      // Sessiz geçilirse müşteri parasını bekler ve kimse bir şey bilmez.
      final api = FakeOrderEditApi()
        ..result = const RevisionResult(
          revisionNo: 1,
          refundKurus: 18000,
          extraChargeKurus: 0,
          settlementStatus: 'manual',
          settlementMessage: 'Elden iade edilecek.',
        );
      await pumpEdit(tester, api);

      await tester.tap(rowButton('Mercimek Çorbası', Icons.remove));
      await tester.pump();
      await saveWithReason(tester);

      expect(find.textContaining('elle tamamlanacak'), findsOneWidget);
    });

    testWidgets('BAŞARISIZ iade personele bildirilir', (tester) async {
      final api = FakeOrderEditApi()
        ..result = const RevisionResult(
          revisionNo: 1,
          refundKurus: 18000,
          extraChargeKurus: 0,
          settlementStatus: 'failed',
        );
      await pumpEdit(tester, api);

      await tester.tap(rowButton('Mercimek Çorbası', Icons.remove));
      await tester.pump();
      await saveWithReason(tester);

      expect(find.textContaining('iade başlatılamadı'), findsOneWidget);
    });

    testWidgets('İADE TUTARI kaydedildi mesajında görünür', (tester) async {
      // Personel bu değişikliği müşteriyle telefonda konuşarak giriyor;
      // "ne kadarı iade edildi" sorusunun cevabını kapatmadan önce
      // görmeli. Kaydetmeden önce gösterilemiyor: fiyatı istemci
      // bilmiyor (ADR-08), sunucu farkı ancak kayıtla döndürüyor.
      final api = FakeOrderEditApi()
        ..result = const RevisionResult(
          revisionNo: 1,
          refundKurus: 18000,
          extraChargeKurus: 0,
        );
      await pumpEdit(tester, api);

      await tester.tap(rowButton('Mercimek Çorbası', Icons.remove));
      await tester.pump();
      await saveWithReason(tester);

      expect(find.textContaining('180,00 ₺'), findsOneWidget);
      expect(find.textContaining('iade edilecek'), findsOneWidget);
    });

    testWidgets('EK TAHSİLAT tutarı kaydedildi mesajında görünür', (
      tester,
    ) async {
      final api = FakeOrderEditApi()
        ..result = const RevisionResult(
          revisionNo: 2,
          refundKurus: 0,
          extraChargeKurus: 4550,
        );
      await pumpEdit(tester, api);

      await tester.tap(rowButton('Mercimek Çorbası', Icons.add));
      await tester.pump();
      await saveWithReason(tester);

      expect(find.textContaining('45,50 ₺'), findsOneWidget);
      expect(find.textContaining('Tahsil edilecek'), findsOneWidget);
    });

    testWidgets('FARK YOKSA tutar satırı eklenmez', (tester) async {
      // Adet değişmeden not düzeltilirse para hareketi yok; "0,00 ₺"
      // yazmak personeli boşuna kasaya yollar.
      final api = FakeOrderEditApi()
        ..result = const RevisionResult(
          revisionNo: 3,
          refundKurus: 0,
          extraChargeKurus: 0,
        );
      await pumpEdit(tester, api);

      await tester.tap(rowButton('Mercimek Çorbası', Icons.remove));
      await tester.pump();
      await saveWithReason(tester);

      expect(find.textContaining('₺'), findsNothing);
    });

    testWidgets('sunucu hatası ekranda kalır ve gerekçesini söyler', (
      tester,
    ) async {
      final api = FakeOrderEditApi()..failRevision = true;
      await pumpEdit(tester, api);

      await tester.tap(rowButton('Mercimek Çorbası', Icons.remove));
      await tester.pump();
      await saveWithReason(tester);

      expect(find.textContaining('sunucu hatası'), findsOneWidget);
      expect(find.byType(OrderEditScreen), findsOneWidget);
    });
  });

  group('Ürün ekleme', () {
    testWidgets('menüden seçilen ürün listeye girer', (tester) async {
      final api = FakeOrderEditApi(
        menuItems: const [
          (menuId: 9, name: 'Ayran'),
          (menuId: 10, name: 'Cacık'),
        ],
      );
      await pumpEdit(tester, api);

      await tester.tap(find.widgetWithText(FilledButton, 'Ürün ekle'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ayran'));
      await tester.pumpAndSettle();

      expect(find.text('Ayran'), findsOneWidget);
    });

    testWidgets('AYNI ÜRÜN ikinci kez eklenirse adet artar, satır açılmaz', (
      tester,
    ) async {
      // İki ayrı satır fişte de iki satır olur ve mutfak aynı yemeği
      // iki kez hazırlar.
      final api = FakeOrderEditApi(
        menuItems: const [(menuId: 2, name: 'Pilav')],
      );
      await pumpEdit(tester, api);

      await tester.tap(find.widgetWithText(FilledButton, 'Ürün ekle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilav').last);
      await tester.pumpAndSettle();

      expect(find.text('Pilav'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('ürün arama TÜRKÇE büyük/küçük harfe duyarsızdır', (
      tester,
    ) async {
      // "ISPANAK" yazan personel "ıspanak"ı bulmalı.
      final api = FakeOrderEditApi(
        menuItems: const [
          (menuId: 9, name: 'Ispanak Yemeği'),
          (menuId: 10, name: 'Cacık'),
        ],
      );
      await pumpEdit(tester, api);

      await tester.tap(find.widgetWithText(FilledButton, 'Ürün ekle'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'ıspanak');
      await tester.pumpAndSettle();

      expect(find.text('Ispanak Yemeği'), findsOneWidget);
      expect(find.text('Cacık'), findsNothing);
    });
  });

  group('EditableItem', () {
    test('istek gövdesinde FİYAT yoktur', () {
      const item = EditableItem(menuId: 1, name: 'Çorba', quantity: 3);

      expect(item.toRequest(), {'menu_id': 1, 'quantity': 3});
    });

    test('not varsa gövdeye girer', () {
      const item = EditableItem(
        menuId: 1,
        name: 'Çorba',
        quantity: 3,
        note: 'Az tuzlu',
      );

      expect(item.toRequest()['note'], 'Az tuzlu');
    });

    test('eşitlik adet ve nota bakar — ad değişimi fark değildir', () {
      // Ad sunucudan geliyor; menüde ürün adı düzeltilirse bu bir
      // "değişiklik" sayılıp boş revizyon üretmemeli.
      const a = EditableItem(menuId: 1, name: 'Çorba', quantity: 3);
      const b = EditableItem(menuId: 1, name: 'Mercimek Çorbası', quantity: 3);
      const c = EditableItem(menuId: 1, name: 'Çorba', quantity: 4);

      expect(a, b);
      expect(a, isNot(c));
    });
  });
}
