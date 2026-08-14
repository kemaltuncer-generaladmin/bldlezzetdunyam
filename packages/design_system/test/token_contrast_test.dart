/// Marka paletinin DEĞİŞMEZLERİ.
///
/// Bu dosya renk beğenisi test etmiyor; bir kez pahalıya öğrenilmiş üç kuralı
/// kilitliyor:
///
///  1. Beyaz metin taşıyan hiçbir marka tonu AA'nın altına düşemez.
///  2. `brand500` beyaz metin TAŞIMAZ — 3,72 ile AA'nın altında. Kod tabanı bu
///     tuzağa eski turuncu paletle bir kez düştü (birincil buton `brand-600`
///     seçilmişti); ton adı değişince kimse yeniden ölçmez, bu yüzden tuzak
///     testle sabitleniyor.
///  3. `neutral400` işlevsel kenarlıktır: WCAG 1.4.11 için zemin üstünde en az
///     3,0 vermek zorunda. Bir zamanlar kenarlık `neutral200` idi ve her form
///     alanı 1,13 ile görünmez sayılıyordu.
///
/// Ayrıca hata rengi ile marka rengi OKLCH renk tonunda birbirinden yeterince
/// uzak mı diye bakılıyor: stok Tailwind paletinde `danger` marka turuncusuna
/// 7 derece mesafedeydi ve "sil" düğmesi "kaydet" düğmesiyle aynı renk
/// ailesinden okunuyordu.
///
/// **Kontrast fonksiyonu** `platform/extensions/veykemtu/bridgeapi/src/Admin/
/// BrandGuard.php` içindeki PHP sürümünden PORT EDİLDİ. İki dilde iki formül
/// olsaydı panel bir rengi kabul edip site aynı rengi reddedebilirdi.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:test/test.dart';

// ───────────────────────────────────────────────────────────────────────────
// BrandGuard.php portu
// ───────────────────────────────────────────────────────────────────────────

/// WCAG 2.1 AA — normal boyut metin. `BrandGuard::MIN_CONTRAST` ile aynı.
const double kTextContrastMin = 4.5;

/// WCAG 2.1 §1.4.11 — kullanıcı arayüzü bileşeni (kenarlık, ikon, odak halkası).
const double kUiContrastMin = 3.0;

/// `BrandGuard::relativeLuminance()` portu.
///
/// Kısa biçim (`#F80`) de kabul ediliyor — panelin renk seçicisi bazen böyle
/// üretiyor. Ayrıştırılamayan renkte `null`: "geçti" saymak yerine eşiğin
/// altında kalması gerekiyor.
double? relativeLuminance(String hex) {
  String value = hex.trim();
  if (value.startsWith('#')) value = value.substring(1);

  if (value.length == 3) {
    value =
        '${value[0]}${value[0]}${value[1]}${value[1]}${value[2]}${value[2]}';
  }
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)) return null;

  final List<double> channels = <double>[];
  for (final int offset in <int>[0, 2, 4]) {
    final double raw = int.parse(value.substring(offset, offset + 2), radix: 16) / 255;
    // 0,03928 eşiği bilinçli: WCAG 2.1 metni bu sayıyı yazıyor (sRGB
    // spesifikasyonundaki 0,04045 değil) ve PHP sürümü de onu kullanıyor.
    channels.add(raw <= 0.03928 ? raw / 12.92 : math.pow((raw + 0.055) / 1.055, 2.4).toDouble());
  }
  return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
}

/// `BrandGuard::contrast()` portu — 1..21.
double contrast(String first, String second) {
  final double? a = relativeLuminance(first);
  final double? b = relativeLuminance(second);
  if (a == null || b == null) return 0;
  final double lighter = math.max(a, b);
  final double darker = math.min(a, b);
  return (lighter + 0.05) / (darker + 0.05);
}

/// `0xFFRRGGBB` → `#RRGGBB`.
String hexOf(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

// ───────────────────────────────────────────────────────────────────────────
// OKLCH renk tonu
// ───────────────────────────────────────────────────────────────────────────

/// sRGB → OKLCH renk tonu (derece).
///
/// Burada sRGB doğrusallaştırma eşiği 0,04045: bu renk uzayı dönüşümü, WCAG'in
/// parlaklık formülü değil. İki eşiği karıştırmamak için ayrı fonksiyon.
double oklchHue(String hex) {
  final String value = hex.startsWith('#') ? hex.substring(1) : hex;
  double lin(int start) {
    final double c = int.parse(value.substring(start, start + 2), radix: 16) / 255;
    return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final double r = lin(0);
  final double g = lin(2);
  final double b = lin(4);

  final double l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
  final double m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
  final double s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;

  final double lp = math.pow(l, 1 / 3).toDouble();
  final double mp = math.pow(m, 1 / 3).toDouble();
  final double sp = math.pow(s, 1 / 3).toDouble();

  final double a = 1.9779984951 * lp - 2.4285922050 * mp + 0.4505937099 * sp;
  final double bb = 0.0259040371 * lp + 0.7827717662 * mp - 0.8086757660 * sp;

  final double degrees = math.atan2(bb, a) * 180 / math.pi;
  return degrees < 0 ? degrees + 360 : degrees;
}

/// İki renk tonu arasındaki en kısa açısal mesafe (0..180).
double hueDistance(double first, double second) {
  final double raw = (first - second).abs();
  return raw > 180 ? 360 - raw : raw;
}

// ───────────────────────────────────────────────────────────────────────────
// Belirteç kaynağı
// ───────────────────────────────────────────────────────────────────────────

const String _tokensRelative = 'packages/design_system/tokens/bld.tokens.json';

/// Belirteç dosyasını bulur.
///
/// Test hem depo kökünden (`dart test packages/design_system`) hem paket
/// dizininden koşulabiliyor; ikisinde de aynı dosyayı bulmak zorunda.
File findTokensFile() {
  for (final Directory start in <Directory>[
    Directory.current,
    File.fromUri(Platform.script).parent,
  ]) {
    Directory current = start;
    for (int depth = 0; depth < 12; depth++) {
      final File candidate = File('${current.path}/$_tokensRelative');
      if (candidate.existsSync()) return candidate;
      final File local = File('${current.path}/tokens/bld.tokens.json');
      if (local.existsSync()) return local;
      final Directory parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }
  }
  throw StateError('bld.tokens.json bulunamadı.');
}

Map<String, dynamic> loadTokens() =>
    jsonDecode(findTokensFile().readAsStringSync()) as Map<String, dynamic>;

/// `{"brand": {"500": {"value": "#DD5D02"}}}` → `{"brand.500": "#DD5D02"}`
Map<String, String> flatPrimitives(Map<String, dynamic> tokens) {
  final Map<String, String> out = <String, String>{};
  (tokens['primitives'] as Map<String, dynamic>).forEach((
    String family,
    dynamic shades,
  ) {
    (shades as Map<String, dynamic>).forEach((String shade, dynamic entry) {
      out['$family.$shade'] = (entry as Map<String, dynamic>)['value'] as String;
    });
  });
  return out;
}

void main() {
  final Map<String, dynamic> tokens = loadTokens();
  final Map<String, dynamic> invariants =
      tokens['invariants'] as Map<String, dynamic>;
  final Map<String, String> primitives = flatPrimitives(tokens);

  group('BrandGuard.php portu', () {
    test('bilinen referans değerleri üretir', () {
      expect(contrast('#000000', '#FFFFFF'), closeTo(21, 0.01));
      expect(contrast('#FFFFFF', '#FFFFFF'), closeTo(1, 0.001));
      // PHP dosyasının docblock'unda yazan ölçüm — port aynı sayıyı vermeli.
      expect(contrast('#C2410C', '#FFFFFF'), closeTo(5.18, 0.01));
    });

    test('kısa biçimi çözer, geçersiz girdide 0 döner', () {
      expect(relativeLuminance('#FFF'), closeTo(1.0, 0.0001));
      expect(relativeLuminance('kirmizi'), isNull);
      // Ayrıştırılamayan renk "geçti" sayılmamalı.
      expect(contrast('#ZZZZZZ', '#FFFFFF'), 0);
    });
  });

  group('Marka rampası', () {
    final int whiteTextFrom = invariants['brandWhiteTextFromShade'] as int;
    final int trap = invariants['brandWhiteTextTrapShade'] as int;

    test('beyaz metin taşıyan her marka tonu AA geçer', () {
      final List<String> carriers = primitives.keys
          .where((String key) => key.startsWith('brand.'))
          .where(
            (String key) =>
                int.parse(key.split('.')[1]) >= whiteTextFrom,
          )
          .toList();

      // Rampanın kuyruğu boşalırsa test sessizce hiçbir şey doğrulamaz.
      expect(carriers.length, greaterThanOrEqualTo(4));

      for (final String key in carriers) {
        expect(
          contrast(primitives[key]!, '#FFFFFF'),
          greaterThanOrEqualTo(kTextContrastMin),
          reason: '$key beyaz metinle AA geçmiyor',
        );
      }
    });

    test('brand$trap beyaz metinle AA geçMEZ — tuzak kilitli', () {
      // Bu bir hata değil, KURAL: bir gün biri "birincil rengi logonunkiyle
      // aynı yapalım" derse test onu burada durdurur.
      expect(
        contrast(primitives['brand.$trap']!, '#FFFFFF'),
        lessThan(kTextContrastMin),
        reason:
            'brand$trap beyaz metinle AA geçiyorsa palet değişmiştir; '
            'birincil dolgu kuralı yeniden yazılmalı.',
      );
      for (final int shade in <int>[50, 100, 200, 300, 400, 500]) {
        expect(
          contrast(primitives['brand.$shade']!, '#FFFFFF'),
          lessThan(kTextContrastMin),
          reason: 'brand$shade beyaz metin taşıyamaz',
        );
      }
    });

    test('Dart sabitleri JSON ile aynı', () {
      // Üreteç koşulmadan JSON değiştirilirse üç yüzey ayrışır; bunu testte
      // yakalamak CI'daki tazelik kapısından daha erken uyarı verir.
      expect(hexOf(BldColors.brand500), primitives['brand.500']!.toUpperCase());
      expect(hexOf(BldColors.brand700), primitives['brand.700']!.toUpperCase());
      expect(
        hexOf(BldColors.neutral400),
        primitives['neutral.400']!.toUpperCase(),
      );
      expect(hexOf(BldLightColors.primary), primitives['brand.700']!.toUpperCase());
      expect(hexOf(BldDarkColors.primary), primitives['brand.300']!.toUpperCase());
    });
  });

  group('İşlevsel kenarlık (WCAG 1.4.11)', () {
    test('neutral400 açık tema zeminlerinde >= 3,0', () {
      final String border = primitives['neutral.400']!;
      for (final String surface in <String>['neutral.0', 'neutral.50']) {
        expect(
          contrast(border, primitives[surface]!),
          greaterThanOrEqualTo(kUiContrastMin),
          reason: 'neutral400, $surface üstünde kontrol kenarlığı olarak yetersiz',
        );
      }
    });

    test('neutral200 kontrol kenarlığı DEĞİLDİR', () {
      // Ayrımın kendisi test ediliyor: neutral200 dekoratif kalmalı, aksi
      // halde "border ile input aynı" hatası geri gelir.
      expect(
        contrast(primitives['neutral.200']!, primitives['neutral.0']!),
        lessThan(kUiContrastMin),
      );
      expect(hexOf(BldLightColors.input), primitives['neutral.400']!.toUpperCase());
      expect(hexOf(BldLightColors.border), primitives['neutral.200']!.toUpperCase());
    });
  });

  group('Renk tonu ayrımı', () {
    test('danger ailesi marka ailesinden OKLCH tonunda yeterince uzak', () {
      final double minDistance =
          (invariants['minDangerBrandHueDistanceDeg'] as num).toDouble();

      final Iterable<String> brands =
          primitives.keys.where((String k) => k.startsWith('brand.'));
      final Iterable<String> dangers =
          primitives.keys.where((String k) => k.startsWith('danger.'));

      for (final String brand in brands) {
        for (final String danger in dangers) {
          final double distance = hueDistance(
            oklchHue(primitives[brand]!),
            oklchHue(primitives[danger]!),
          );
          expect(
            distance,
            greaterThan(minDistance),
            reason:
                '$brand (${oklchHue(primitives[brand]!).toStringAsFixed(1)}°) ile '
                '$danger (${oklchHue(primitives[danger]!).toStringAsFixed(1)}°) '
                'arası ${distance.toStringAsFixed(1)}° — yıkıcı eylem marka '
                'rengiyle karışır.',
          );
        }
      }
    });
  });

  group('Rol tabloları', () {
    /// Rol tablosunu `kind`/`on`/`label` alanlarına göre denetler.
    ///
    /// Kurallar JSON'da veri olarak duruyor; yeni bir rol eklendiğinde test
    /// otomatik kapsıyor — testi güncellemeyi unutmak mümkün değil.
    void checkTheme(String theme) {
      final Map<String, dynamic> roles =
          (tokens['roles'] as Map<String, dynamic>)[theme]
              as Map<String, dynamic>;

      String hexFor(String name) {
        final String value =
            (roles[name] as Map<String, dynamic>)['value'] as String;
        return value.startsWith('#') ? value : primitives[value]!;
      }

      expect(roles, isNotEmpty);

      roles.forEach((String name, dynamic raw) {
        final Map<String, dynamic> entry = raw as Map<String, dynamic>;
        final String kind = entry['kind'] as String;
        switch (kind) {
          case 'text':
            final String on = entry['on'] as String;
            expect(
              contrast(hexFor(name), hexFor(on)),
              greaterThanOrEqualTo(kTextContrastMin),
              reason: '$theme/$name metni $on üstünde AA geçmiyor',
            );
          case 'ui':
            final String on = entry['on'] as String;
            expect(
              contrast(hexFor(name), hexFor(on)),
              greaterThanOrEqualTo(kUiContrastMin),
              reason: '$theme/$name kontrolü $on üstünde 1.4.11 geçmiyor',
            );
          case 'fill':
            final String label = entry['label'] as String;
            expect(
              contrast(hexFor(name), hexFor(label)),
              greaterThanOrEqualTo(kTextContrastMin),
              reason: '$theme/$name dolgusu $label etiketiyle AA geçmiyor',
            );
          case 'surface':
          case 'on-fill':
          case 'decorative':
            break;
          default:
            fail('$theme/$name bilinmeyen kind: $kind');
        }
      });
    }

    test('koyu tema rollerinin tamamı AA', () {
      checkTheme('dark');
    });

    test('açık tema rollerinin tamamı AA', () {
      checkTheme('light');
    });

    test('her iki tema aynı rol adlarını tanımlar', () {
      // Bir rolü yalnız bir temada tanımlamak, diğer temada sessizce miras
      // alınan (ve yanlış) bir renk demek.
      final Set<String> light =
          ((tokens['roles'] as Map<String, dynamic>)['light']
                  as Map<String, dynamic>)
              .keys
              .toSet();
      final Set<String> dark =
          ((tokens['roles'] as Map<String, dynamic>)['dark']
                  as Map<String, dynamic>)
              .keys
              .toSet();
      expect(light.difference(dark), isEmpty);
      expect(dark.difference(light), isEmpty);
    });
  });
}
