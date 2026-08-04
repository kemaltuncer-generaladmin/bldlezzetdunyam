/// `K-07` eşleme ekranı testleri — `docs/05-mutfakapp.md` §7.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/app.dart';
import 'package:mutfakapp/src/data/device_session.dart';
import 'package:mutfakapp/src/data/providers.dart';
import 'package:mutfakapp/src/printing/print_queue.dart';

import 'fake_device_session_store.dart';
import 'fake_kitchen_service.dart';

class PairingKitchenService extends FakeKitchenService {
  PairResponse? response;
  ApiException? failure;
  PairRequest? lastRequest;

  @override
  Future<PairResponse> pair(PairRequest request) async {
    lastRequest = request;
    final error = failure;
    if (error != null) throw error;
    return response ??
        PairResponse(
          deviceId: 1,
          token: 'kdev_test',
          serverTime: DateTime.utc(2026, 8, 5),
        );
  }
}

Future<FakeDeviceSessionStore> pumpPairing(
  WidgetTester tester, {
  required PairingKitchenService kitchen,
  String baseUrl = 'http://localhost:4010/api',
}) async {
  await tester.binding.setSurfaceSize(const Size(1920, 1080));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final store = FakeDeviceSessionStore(baseUrl: baseUrl);
  final queue = PrintQueue.inMemory();
  addTearDown(queue.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deviceSessionStoreProvider.overrideWithValue(store),
        initialDeviceSessionProvider.overrideWithValue(
          DeviceSession(baseUrl: baseUrl),
        ),
        kitchenServiceProvider.overrideWithValue(kitchen),
        printQueueProvider.overrideWithValue(queue),
      ],
      child: const MutfakApp(),
    ),
  );
  await tester.pump();
  return store;
}

Future<void> tearDownTree(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox.shrink());

void main() {
  testWidgets('eşlenmemiş cihaz eşleme ekranıyla açılır', (tester) async {
    await pumpPairing(tester, kitchen: PairingKitchenService());

    expect(find.text('Mutfak ekranını eşle'), findsOneWidget);
    expect(find.text('Sunucu adresi'), findsOneWidget);
    expect(find.text('Eşleme kodu'), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets('sunucu adresi kayıtlı değerle dolu gelir', (tester) async {
    await pumpPairing(
      tester,
      kitchen: PairingKitchenService(),
      baseUrl: 'http://kasa.local/api',
    );

    expect(find.text('http://kasa.local/api'), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets('geçersiz kod sunucuya gönderilmez', (tester) async {
    final kitchen = PairingKitchenService();
    await pumpPairing(tester, kitchen: kitchen);

    await tester.enterText(_field('Eşleme kodu'), 'ABC');
    await tester.tap(find.text('EŞLE'));
    await tester.pump();

    expect(kitchen.lastRequest, isNull);
    expect(
      find.text('Eşleme kodu 4-4 biçiminde olmalı (ABCD-1234).'),
      findsOneWidget,
    );

    await tearDownTree(tester);
  });

  testWidgets('başarılı eşleme KDS ekranına geçirir', (tester) async {
    final kitchen = PairingKitchenService();
    final store = await pumpPairing(tester, kitchen: kitchen);

    await tester.enterText(_field('Eşleme kodu'), 'BLD1-MOCK');
    await tester.tap(find.text('EŞLE'));
    await tester.pump();
    await tester.pump();

    expect(kitchen.lastRequest?.pairingCode, 'BLD1-MOCK');
    expect(await store.tokens.read(), 'kdev_test');
    // Eşleme ekranı kalkar; pano gelir.
    expect(find.text('Mutfak ekranını eşle'), findsNothing);
    expect(find.text('ÜRETİM LİSTESİ'), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets('sunucu adresi normalleştirilip kaydedilir', (tester) async {
    final kitchen = PairingKitchenService();
    final store = await pumpPairing(tester, kitchen: kitchen);

    await tester.enterText(_field('Sunucu adresi'), '192.168.1.5:8080');
    await tester.enterText(_field('Eşleme kodu'), 'BLD1-MOCK');
    await tester.tap(find.text('EŞLE'));
    await tester.pump();
    await tester.pump();

    expect(store.savedBaseUrl, 'http://192.168.1.5:8080/api');

    await tearDownTree(tester);
  });

  testWidgets('geçersiz kodda sunucu hatası gösterilir', (tester) async {
    final kitchen = PairingKitchenService()
      ..failure = const ApiException(
        code: ApiErrorCode.notFound,
        message: 'Eşleme kodu geçersiz veya süresi dolmuş.',
        statusCode: 404,
      );
    await pumpPairing(tester, kitchen: kitchen);

    await tester.enterText(_field('Eşleme kodu'), 'XXXX-YYYY');
    await tester.tap(find.text('EŞLE'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Eşleme kodu geçersiz veya süresi dolmuş.'),
      findsOneWidget,
    );
    expect(find.text('Mutfak ekranını eşle'), findsOneWidget);

    await tearDownTree(tester);
  });

  group('normalizeBaseUrl', () {
    test('şema yoksa http eklenir', () {
      expect(
        normalizeBaseUrl('192.168.1.5:8080'),
        'http://192.168.1.5:8080/api',
      );
    });

    test('/api zaten varsa tekrarlanmaz', () {
      expect(
        normalizeBaseUrl('https://api.example.com/api'),
        'https://api.example.com/api',
      );
    });

    test('sondaki eğik çizgiler temizlenir', () {
      expect(
        normalizeBaseUrl('https://api.example.com///'),
        'https://api.example.com/api',
      );
    });

    test('https korunur', () {
      expect(
        normalizeBaseUrl('https://api.benimlezzetdunyam.com.tr'),
        'https://api.benimlezzetdunyam.com.tr/api',
      );
    });

    test('boş girdi boş kalır — doğrulama ayrı iş', () {
      expect(normalizeBaseUrl('   '), '');
    });
  });
}

Finder _field(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextFormField));
