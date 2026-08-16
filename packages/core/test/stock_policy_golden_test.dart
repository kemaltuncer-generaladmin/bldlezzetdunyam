/// Stok aritmetiği golden testleri — `docs/03-api-sozlesmesi.md` §15.7.
///
/// Vakalar **dosyadan okunur**, buraya kopyalanmaz:
/// `docs/contract/sales-rules.cases.json` kuralın normatif kaynağıdır ve aynı
/// dosyayı `website/e2e` ile `platform/tests/Unit` de okur. Kopyalasaydık
/// kural değiştiğinde bu test yeşil kalır, üç dilden biri sessizce sapardı —
/// altın veri kümesinin bütün amacı tam olarak bunu engellemektir.
///
/// Yeni bir kenar durum, bu dosyaya değil o dosyaya eklenir.
library;

import 'dart:convert';
import 'dart:io';

import 'package:bld_core/bld_core.dart';
import 'package:test/test.dart';

void main() {
  // Veri kümesi main() içinde, senkron okunur: vaka başına bir test ÜRETİLİYOR
  // ve testlerin bildirimi koşucu başlamadan bitmek zorunda. setUpAll çok geç
  // kalırdı.
  final dataset = _readDataset();
  final cases = (dataset['cases']! as List<dynamic>)
      .map((entry) => entry as Map<String, dynamic>)
      .toList();

  group('Altın veri kümesi', () {
    test('okundu ve boş değil', () {
      // Boş liste, aşağıdaki döngüyü hiç kurmadan testi yeşil bırakırdı.
      expect(cases, isNotEmpty);
      expect(dataset['version'], 1);
    });

    test('vaka kimlikleri tekil', () {
      final ids = cases.map((c) => c['id'] as String).toList();
      expect(ids.toSet().length, ids.length, reason: 'yinelenen vaka kimliği');
    });

    test('dört bandın hepsi kapsanıyor', () {
      final covered = cases
          .map((c) => (c['expect']! as Map<String, dynamic>)['stock_level'])
          .toSet();
      for (final level in StockLevel.values) {
        expect(
          covered,
          contains(level.wireName),
          reason: '${level.wireName} bandını sınayan vaka yok',
        );
      }
    });

    test('varsayılanlar sözleşmedeki değerler', () {
      final defaults = dataset['defaults']! as Map<String, dynamic>;
      // hard_max, website/lib/cart.ts içindeki MAX_QUANTITY ile aynı olmalı.
      expect(defaults['hard_max'], 99);
      expect(defaults['low_threshold'], 5);
    });
  });

  group('maxAddable', () {
    for (final testCase in cases) {
      final id = testCase['id'] as String;
      final input = testCase['input']! as Map<String, dynamic>;
      final expected = (testCase['expect']! as Map<String, dynamic>);

      test(id, () {
        expect(
          maxAddable(
            dayRemaining: _optionalInt(input, 'day_remaining'),
            itemRemaining: _optionalInt(input, 'item_remaining'),
            alreadyInCartForDay: _requiredInt(input, 'in_cart_day'),
            alreadyInCartForItem: _requiredInt(input, 'in_cart_item'),
            hardMax: _requiredInt(input, 'hard_max'),
          ),
          expected['max_addable'],
          reason: testCase['note'] as String?,
        );
      });
    }
  });

  group('stockLevel', () {
    for (final testCase in cases) {
      final id = testCase['id'] as String;
      final input = testCase['input']! as Map<String, dynamic>;
      final expected = (testCase['expect']! as Map<String, dynamic>);

      test(id, () {
        final wanted = StockLevel.tryParse(expected['stock_level'] as String);
        expect(
          wanted,
          isNotNull,
          reason: 'veri kümesinde bilinmeyen band: ${expected['stock_level']}',
        );

        expect(
          stockLevel(
            // Band girdisi EFEKTİF KALAN üzerinden kurulur
            // (`case_input_binding`); sepetten arındırılmaz, çünkü band
            // sepetten bağımsızdır.
            remaining: _effectiveRemaining(
              _optionalInt(input, 'day_remaining'),
              _optionalInt(input, 'item_remaining'),
            ),
            lowThreshold: _requiredInt(input, 'low_threshold'),
          ),
          wanted,
          reason: testCase['note'] as String?,
        );
      });
    }
  });
}

/// Veri kümesindeki `case_input_binding` kuralı: iki tavandan dar olanı.
int? _effectiveRemaining(int? dayRemaining, int? itemRemaining) {
  if (dayRemaining == null) return itemRemaining;
  if (itemRemaining == null) return dayRemaining;
  return dayRemaining < itemRemaining ? dayRemaining : itemRemaining;
}

int? _optionalInt(Map<String, dynamic> input, String key) {
  final value = input[key];
  return value == null ? null : value as int;
}

int _requiredInt(Map<String, dynamic> input, String key) => input[key]! as int;

/// Altın veri kümesini bulur ve çözer.
///
/// Dosya çalışma dizininden yukarı doğru aranır. NEDEN paket URI'si değil:
/// `mutfakapp` pub workspace'e katıldığından beri testler yerine göre
/// `dart test` ya da `flutter test` ile koşuyor ve ikisinin çalışma dizini
/// aynı değil; `Isolate.resolvePackageUriSync` ise `flutter test` altında
/// desteklenmiyor (bkz. `escpos_golden_test.dart`).
Map<String, dynamic> _readDataset() {
  const relative = 'docs/contract/sales-rules.cases.json';

  var directory = Directory.current;
  for (var i = 0; i < 6; i++) {
    final candidate = File('${directory.path}/$relative');
    if (candidate.existsSync()) {
      return jsonDecode(candidate.readAsStringSync()) as Map<String, dynamic>;
    }

    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }

  throw StateError(
    'Altın veri kümesi bulunamadı ($relative). '
    'Çalışma dizini: ${Directory.current.path}',
  );
}
