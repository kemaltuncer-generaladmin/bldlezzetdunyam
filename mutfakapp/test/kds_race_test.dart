/// Yarış durumları ve sunucu hatalarında ekranın davranışı.
///
/// Buradaki her test, bulunmuş bir hatanın nöbetçisidir; başlıklar hatayı
/// tarif eder, çözümü değil.
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/kds/widgets/order_card.dart';

import 'fake_kitchen_service.dart';
import 'kds_operations_test.dart' show ControllableOrderSource, settings;
import 'kds_screen_test.dart' show pumpKds, tearDownTree;

/// `setStatus` çağrılarını sayan, yanıtı testin denetlediği servis.
class StatusKitchenService extends FakeKitchenService {
  StatusKitchenService();

  /// Atılacak hata; `null` ise çağrı başarılı sayılır.
  ApiException? failure;

  /// `complete` edilene kadar çağrı askıda kalır — çift dokunma penceresi.
  Completer<void>? gate;

  @override
  Future<KitchenOrder> setStatus(int orderId, OrderStatus status) async {
    statusCalls.add((orderId, status));
    await gate?.future;

    final error = failure;
    if (error != null) throw error;

    return makeOrder(id: orderId, status: status);
  }
}

void main() {
  testWidgets('aynı karta iki kez basmak İKİ istek göndermez', (tester) async {
    // HATA: yağlı elle basılan 64 piksellik düğme kolayca iki kez tetikleniyor.
    // İkinci istek ya sebepsiz bir kırmızı uyarı üretiyor ya da — liste arada
    // tazelenmişse — siparişi bir adım fazla ilerletiyordu.
    final kitchen = StatusKitchenService()..gate = Completer<void>();

    await pumpKds(
      tester,
      settings: settings,
      orders: [makeOrder(id: 1, status: OrderStatus.yeni)],
      kitchen: kitchen,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'ONAYLA'));
    await tester.pump();

    // İlk istek hâlâ uçuyor: düğme kilitli olmalı.
    final button = tester.widget<FilledButton>(
      find.descendant(
        of: find.byType(OrderCard),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull, reason: 'İstek uçarken düğme kilitli.');

    kitchen.gate!.complete();
    await tester.pump();
    await tester.pump();

    expect(kitchen.statusCalls, hasLength(1));

    await tearDownTree(tester);
  });

  testWidgets('istek uçarken kartta ilerleme göstergesi çıkar', (tester) async {
    final kitchen = StatusKitchenService()..gate = Completer<void>();

    await pumpKds(
      tester,
      settings: settings,
      orders: [makeOrder(id: 1, status: OrderStatus.yeni)],
      kitchen: kitchen,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'ONAYLA'));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(OrderCard),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    kitchen.gate!.complete();
    await tester.pump();
    await tester.pump();

    await tearDownTree(tester);
  });

  testWidgets('sunucu hatası personele GÖRÜNÜR biçimde bildirilir', (
    tester,
  ) async {
    // Sessizce başarısız olan bir düğme, siparişin iki kez hazırlanmasıdır.
    final kitchen = StatusKitchenService()
      ..failure = const ApiException(
        code: ApiErrorCode.serverError,
        message: 'Sunucu hatası',
        statusCode: 500,
      );

    await pumpKds(
      tester,
      settings: settings,
      orders: [makeOrder(id: 1, status: OrderStatus.yeni)],
      kitchen: kitchen,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'ONAYLA'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Sunucu hatası'), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets('ağ kopukken basmak sessiz kalmaz', (tester) async {
    final kitchen = StatusKitchenService()
      ..failure = const ApiException.network();

    await pumpKds(
      tester,
      settings: settings,
      orders: [makeOrder(id: 1, status: OrderStatus.yeni)],
      kitchen: kitchen,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'ONAYLA'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Durum güncellenemedi'), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets('INVALID_TRANSITION kırmızı hata değil, bilgi mesajıdır', (
    tester,
  ) async {
    // Sipariş yönetici panelden ya da ikinci bir kasadan ilerletilmiş olabilir.
    // Personelin yapacağı bir şey yok; yapılacak şey listeyi tazelemek.
    final kitchen = StatusKitchenService()
      ..failure = const ApiException(
        code: ApiErrorCode.invalidTransition,
        message: 'Geçersiz geçiş',
        statusCode: 422,
      );

    await pumpKds(
      tester,
      settings: settings,
      orders: [makeOrder(id: 1, status: OrderStatus.yeni)],
      kitchen: kitchen,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'ONAYLA'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Bu sipariş başka bir yerden güncellenmiş. Liste tazelendi.'), findsOneWidget);
    expect(find.textContaining('Geçersiz geçiş'), findsNothing);

    await tearDownTree(tester);
  });

  testWidgets('BAYAT KART: hedef durum en güncel listeden hesaplanır', (
    tester,
  ) async {
    // Kart çizildiği andaki siparişi taşır. Parmak inene kadar yoklama onu
    // güncellemiş olabilir; widget'ın elindeki kopyaya göre istek atmak
    // siparişi yanlış duruma taşırdı.
    final source = ControllableOrderSource();
    final kitchen = StatusKitchenService();
    addTearDown(source.dispose);

    await pumpKds(
      tester,
      settings: settings,
      orders: const [],
      source: source,
      kitchen: kitchen,
    );

    source.emit([makeOrder(id: 1, status: OrderStatus.yeni)]);
    await tester.pump();

    // Sunucu siparişi bu arada "onaylandi"ya taşıdı.
    source.emit([makeOrder(id: 1, status: OrderStatus.onaylandi)]);
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'BAŞLA'));
    await tester.pump();
    await tester.pump();

    expect(kitchen.statusCalls.single, (1, OrderStatus.hazirlaniyor));

    await tearDownTree(tester);
  });

  testWidgets('ekrandan düşmüş sipariş için istek atılmaz', (tester) async {
    final source = ControllableOrderSource();
    final kitchen = StatusKitchenService()..gate = Completer<void>();
    addTearDown(source.dispose);

    await pumpKds(
      tester,
      settings: settings,
      orders: const [],
      source: source,
      kitchen: kitchen,
    );

    source.emit([makeOrder(id: 1, status: OrderStatus.yeni)]);
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'ONAYLA'));
    await tester.pump();

    // Kart ilerlerken sipariş iptal edilip listeden düşüyor.
    source.emit(const []);
    await tester.pump();
    kitchen.gate!.complete();
    await tester.pump();
    await tester.pump();

    // İstek zaten yola çıkmıştı; ekran çökmeden boş panoya dönmeli.
    expect(find.text('Bekleyen sipariş yok'), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets('yükleniyor ile "sipariş yok" AYNI ekran değildir', (
    tester,
  ) async {
    // HATA: ilk liste gelmeden pano "Bekleyen sipariş yok" yazıyordu. Mutfak
    // sabah bu yazıyı görüp sakin bir gün sanabilir — oysa henüz hiçbir şey
    // sorulmamıştır.
    final source = ControllableOrderSource();
    addTearDown(source.dispose);

    await pumpKds(tester, settings: settings, orders: const [], source: source);

    expect(find.text('Siparişler yükleniyor'), findsOneWidget);
    expect(find.text('Bekleyen sipariş yok'), findsNothing);

    source.emit(const []);
    await tester.pump();

    expect(find.text('Siparişler yükleniyor'), findsNothing);
    expect(find.text('Bekleyen sipariş yok'), findsOneWidget);

    await tearDownTree(tester);
  });
}
