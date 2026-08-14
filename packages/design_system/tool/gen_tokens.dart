/// Marka belirteci üreteci — `tokens/bld.tokens.json` → üç yüzeyin dosyaları.
///
/// **Neden üreteç var:** aynı palet üç ayrı teknolojide (Dart sabitleri,
/// Tailwind `@theme`, TastyIgniter panelinin Bootstrap değişkenleri) tekrar
/// yazılıyordu. Elle tutulan üç kopya birbirinden kaçınılmaz olarak ayrıştı:
/// panel eski turuncuyu, site yenisini gösterdi. Artık tek dosya değişir,
/// üçü birden yeniden üretilir; CI de üretimin bayat olmadığını doğrular.
///
/// **Neden saf Dart, dart:io + dart:convert dışında bağımlılık yok:** bu
/// script'in `pub get` gerektirmeden, çıplak bir Dart SDK'sıyla koşabilmesi
/// gerekiyor — CI'daki belirteç tazelik kapısı bağımlılık çözümlemesini
/// beklemeden bunu koşuyor.
///
/// Kullanım:
///   dart run packages/design_system/tool/gen_tokens.dart
///   dart run packages/design_system/tool/gen_tokens.dart --check
///
/// `--check` hiçbir dosya yazmaz; çıktı diskteki hâlden farklıysa 1 ile çıkar.
library;

import 'dart:convert';
import 'dart:io';

/// Üretilen her dosyanın ilk satırlarına basılan uyarı.
const String _bannerTitle = 'ÜRETİLDİ — ELLE DÜZENLEME';

const String _sourceRelative = 'packages/design_system/tokens/bld.tokens.json';
const String _toolRelative = 'packages/design_system/tool/gen_tokens.dart';

/// `colors.dart` içinde üretimin bittiği yer.
///
/// Bu işaretin ALTI korunur: `KdsColors` elle yazılmıştır ve mutfak ekranının
/// kendi okuma mesafesi vardır (bir metreden okunan koyu ekran), müşteri
/// yüzeylerinin rol tablosuyla aynı kurallara tabi değildir.
const String _dartHandWrittenMarker =
    '// ═══ ÜRETİM SONU — AŞAĞISI ELLE YAZILIR ═══';

void main(List<String> args) {
  final bool checkOnly = args.contains('--check');
  final Directory root = _repoRoot();
  final File source = File('${root.path}/$_sourceRelative');

  if (!source.existsSync()) {
    stderr.writeln('Belirteç kaynağı bulunamadı: ${source.path}');
    exitCode = 2;
    return;
  }

  final Tokens tokens = Tokens.parse(
    jsonDecode(source.readAsStringSync()) as Map<String, dynamic>,
  );

  final Map<String, String> outputs = <String, String>{
    'packages/design_system/lib/src/colors.dart': _renderDart(
      tokens,
      File('${root.path}/packages/design_system/lib/src/colors.dart'),
    ),
    'website/app/tokens.css': _renderWebsiteCss(tokens),
    'platform/extensions/veykemtu/bridgeapi/resources/css/tokens.css':
        _renderAdminCss(tokens),
  };

  final List<String> stale = <String>[];
  outputs.forEach((String relative, String content) {
    final File target = File('${root.path}/$relative');
    final String? current = target.existsSync()
        ? target.readAsStringSync()
        : null;
    if (current == content) {
      stdout.writeln('= $relative');
      return;
    }
    stale.add(relative);
    if (checkOnly) {
      stdout.writeln('! $relative (bayat)');
      return;
    }
    target.parent.createSync(recursive: true);
    target.writeAsStringSync(content);
    stdout.writeln('+ $relative');
  });

  if (checkOnly && stale.isNotEmpty) {
    stderr.writeln(
      'Üretilen belirteç dosyaları bayat: ${stale.join(', ')}. '
      '`dart run $_toolRelative` koşup sonucu commitleyin.',
    );
    exitCode = 1;
    return;
  }

  stdout.writeln(
    '${tokens.primitiveCount} primitif + ${tokens.aliasCount} takma ad + '
    '${tokens.light.length} açık rol + ${tokens.dark.length} koyu rol = '
    '${tokens.totalCount} belirteç.',
  );
}

/// `packages/design_system/tokens/…` içeren ilk üst dizin depo köküdür.
///
/// Script'in nereden çağrıldığına bakmıyoruz: `dart run <yol>` ile de,
/// `dart run bld_design_system:gen_tokens` ile de aynı kökü bulmalı.
Directory _repoRoot() {
  Directory current = File.fromUri(Platform.script).parent;
  for (int depth = 0; depth < 12; depth++) {
    if (File('${current.path}/$_sourceRelative').existsSync()) {
      return current;
    }
    final Directory parent = current.parent;
    if (parent.path == current.path) break;
    current = parent;
  }
  return Directory.current;
}

// ───────────────────────────────────────────────────────────────────────────
// Model
// ───────────────────────────────────────────────────────────────────────────

/// Tek bir renk belirteci: çözülmüş hex + gerekçe notu.
class Token {
  const Token({
    required this.name,
    required this.hex,
    required this.note,
    this.kind = 'primitive',
    this.reference,
  });

  /// `brand-500`, `muted-foreground` gibi kebab-case ad.
  final String name;

  /// `#RRGGBB` — büyük harf.
  final String hex;

  final String note;

  /// `primitive` | `surface` | `text` | `fill` | `on-fill` | `ui` | `decorative`
  final String kind;

  /// Rol bir primitife işaret ediyorsa `brand-700` gibi; ham hex ise `null`.
  final String? reference;
}

class Tokens {
  Tokens({
    required this.primitives,
    required this.aliases,
    required this.light,
    required this.dark,
    required this.meta,
  });

  /// Aile adı → sıralı ton listesi.
  final Map<String, List<Token>> primitives;
  final List<Token> aliases;
  final List<Token> light;
  final List<Token> dark;
  final Map<String, dynamic> meta;

  int get primitiveCount =>
      primitives.values.fold(0, (int sum, List<Token> v) => sum + v.length);
  int get aliasCount => aliases.length;
  int get totalCount =>
      primitiveCount + aliasCount + light.length + dark.length;

  static Tokens parse(Map<String, dynamic> json) {
    final Map<String, dynamic> rawPrimitives =
        json['primitives'] as Map<String, dynamic>;
    final Map<String, String> lookup = <String, String>{};
    final Map<String, List<Token>> primitives = <String, List<Token>>{};

    rawPrimitives.forEach((String family, dynamic shades) {
      final List<Token> ramp = <Token>[];
      (shades as Map<String, dynamic>).forEach((String shade, dynamic entry) {
        final Map<String, dynamic> map = entry as Map<String, dynamic>;
        final String hex = (map['value'] as String).toUpperCase();
        lookup['$family.$shade'] = hex;
        ramp.add(
          Token(name: '$family-$shade', hex: hex, note: map['note'] as String),
        );
      });
      primitives[family] = ramp;
    });

    String resolve(String value) {
      if (value.startsWith('#')) return value.toUpperCase();
      final String? hex = lookup[value];
      if (hex == null) {
        throw StateError('Çözülemeyen belirteç referansı: $value');
      }
      return hex;
    }

    final List<Token> aliases = <Token>[];
    (json['aliases'] as Map<String, dynamic>).forEach((
      String name,
      dynamic entry,
    ) {
      final Map<String, dynamic> map = entry as Map<String, dynamic>;
      final String reference = map['value'] as String;
      aliases.add(
        Token(
          name: name,
          hex: resolve(reference),
          note: map['note'] as String,
          kind: 'alias',
          reference: reference.replaceAll('.', '-'),
        ),
      );
    });

    List<Token> roles(String theme) {
      final Map<String, dynamic> raw =
          (json['roles'] as Map<String, dynamic>)[theme]
              as Map<String, dynamic>;
      final List<Token> out = <Token>[];
      raw.forEach((String name, dynamic entry) {
        final Map<String, dynamic> map = entry as Map<String, dynamic>;
        final String value = map['value'] as String;
        out.add(
          Token(
            name: name,
            hex: resolve(value),
            note: map['note'] as String,
            kind: map['kind'] as String,
            reference: value.startsWith('#')
                ? null
                : value.replaceAll('.', '-'),
          ),
        );
      });
      return out;
    }

    return Tokens(
      primitives: primitives,
      aliases: aliases,
      light: roles('light'),
      dark: roles('dark'),
      meta: json['meta'] as Map<String, dynamic>,
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Biçimlendirme yardımcıları
// ───────────────────────────────────────────────────────────────────────────

/// `brand-500` → `brand500`, `muted-foreground` → `mutedForeground`.
String _camel(String kebab) {
  final List<String> parts = kebab.split('-');
  final StringBuffer buffer = StringBuffer(parts.first);
  for (final String part in parts.skip(1)) {
    if (part.isEmpty) continue;
    // Ton numaraları harf gibi büyütülemez; doğrudan eklenir (brand-500).
    final bool numeric = int.tryParse(part) != null;
    buffer.write(numeric ? part : part[0].toUpperCase() + part.substring(1));
  }
  return buffer.toString();
}

/// `#FEF2E8` → `0xFFFEF2E8`.
String _argb(String hex) => '0xFF${hex.substring(1).toUpperCase()}';

/// Doküman yorumunu 76 sütuna sararak yazar (dart format yorumları sarmaz).
List<String> _docComment(String text, {String indent = '  '}) {
  const int width = 74;
  final List<String> words = text.split(RegExp(r'\s+'));
  final List<String> lines = <String>[];
  StringBuffer line = StringBuffer();
  for (final String word in words) {
    if (line.isEmpty) {
      line.write(word);
    } else if (line.length + 1 + word.length <= width) {
      line.write(' $word');
    } else {
      lines.add(line.toString());
      line = StringBuffer(word);
    }
  }
  if (line.isNotEmpty) lines.add(line.toString());
  return lines.map((String l) => '$indent/// $l').toList();
}

/// CSS yorumunu 76 sütuna sarar.
List<String> _cssComment(String text, {String indent = '  '}) {
  const int width = 72;
  final List<String> words = text.split(RegExp(r'\s+'));
  final List<String> lines = <String>[];
  StringBuffer line = StringBuffer();
  for (final String word in words) {
    if (line.isEmpty) {
      line.write(word);
    } else if (line.length + 1 + word.length <= width) {
      line.write(' $word');
    } else {
      lines.add(line.toString());
      line = StringBuffer(word);
    }
  }
  if (line.isNotEmpty) lines.add(line.toString());
  if (lines.length == 1) return <String>['$indent/* ${lines.first} */'];
  return <String>[
    '$indent/*',
    ...lines.map((String l) => '$indent * $l'),
    '$indent */',
  ];
}

String _banner(String commentOpen, String commentLine, String commentClose) {
  final List<String> body = <String>[
    _bannerTitle,
    '',
    'Bu dosya `$_sourceRelative` dosyasından üretildi.',
    'Değişiklik oraya yazılır, sonra:',
    '  dart run $_toolRelative',
    'Buraya elle yazılan her şey bir sonraki üretimde silinir.',
  ];
  return <String>[
    commentOpen,
    ...body.map(
      (String l) => l.isEmpty ? commentLine.trimRight() : '$commentLine$l',
    ),
    commentClose,
  ].join('\n');
}

// ───────────────────────────────────────────────────────────────────────────
// Çıktı 1 — Dart
// ───────────────────────────────────────────────────────────────────────────

String _renderDart(Tokens tokens, File existing) {
  final StringBuffer out = StringBuffer();
  out.writeln(_banner('//', '// ', '//'));
  out.writeln('//');
  out.writeln(
    '// Değerler `0xAARRGGBB` biçiminde `int`\'tir; Flutter `Color(...)` ile,',
  );
  out.writeln(
    '// web `#RRGGBB` olarak tüketir. `dart:ui` KULLANILMAZ — paket saf Dart',
  );
  out.writeln(
    '// kalsın ki üreteç ve testler Flutter SDK\'sı olmadan da koşabilsin.',
  );
  out.writeln('library;');
  out.writeln();

  out.writeln('/// Ham palet — logodan ölçüldü.');
  out.writeln('///');
  out.writeln('/// İKİ KURAL:');
  out.writeln(
    '///  1. brand500 ve daha AÇIĞI beyaz metin TAŞIMAZ (3,72 < 4,50).',
  );
  out.writeln('///     Beyaz yazı brand700\'den başlar.');
  out.writeln(
    '///  2. neutral400 METİN DEĞİLDİR: kenarlık, ayraç, ikon rengidir.',
  );
  out.writeln('abstract final class BldColors {');
  bool firstFamily = true;
  tokens.primitives.forEach((String family, List<Token> ramp) {
    if (!firstFamily) out.writeln();
    firstFamily = false;
    out.writeln('  // ── ${family.toUpperCase()} ──');
    for (final Token token in ramp) {
      out.writeln();
      _docComment(token.note).forEach(out.writeln);
      out.writeln(
        '  static const int ${_camel(token.name)} = ${_argb(token.hex)};',
      );
    }
  });
  out.writeln();
  out.writeln('  // ── ÇIPLAK TAKMA ADLAR ──');
  for (final Token token in tokens.aliases) {
    out.writeln();
    _docComment(token.note).forEach(out.writeln);
    out.writeln(
      '  static const int ${_camel(token.name)} = ${_camel(token.reference!)};',
    );
  }
  out.writeln('}');
  out.writeln();

  out.writeln(
    _roleClass(
      'BldLightColors',
      'Açık tema rol tablosu — müşteri yüzeylerinin (web, mobil) varsayılanı.',
      tokens.light,
    ),
  );
  out.writeln();
  out.writeln(
    _roleClass(
      'BldDarkColors',
      'Koyu tema rol tablosu.\n///\n'
          '/// KOYU temada yükseltme AÇIKLIK adımıdır, gölge değil; bu yüzden\n'
          '/// `surface1`/`surface2` gerçek renk taşır, açık temada ikisi de karttır.',
      tokens.dark,
    ),
  );
  out.writeln();
  // İşaret satır sonu OLMADAN yazılır: korunan kuyruk zaten kendi satır
  // başlangıcını taşıyor, ikisi birleşince fazladan boş satır oluşup
  // `dart format --set-exit-if-changed` kapısını düşürüyordu.
  out.write(_dartHandWrittenMarker);

  // Elle yazılmış kuyruk (KdsColors) korunur.
  final String tail = _handWrittenTail(existing);
  out.write(tail.isEmpty ? '\n' : tail);
  return out.toString();
}

String _roleClass(String className, String doc, List<Token> roles) {
  final StringBuffer out = StringBuffer();
  for (final String line in doc.split('\n')) {
    out.writeln(line.startsWith('///') ? line : '/// $line');
  }
  out.writeln('abstract final class $className {');
  bool first = true;
  for (final Token token in roles) {
    if (!first) out.writeln();
    first = false;
    _docComment(token.note).forEach(out.writeln);
    final String value = token.reference == null
        ? _argb(token.hex)
        : 'BldColors.${_camel(token.reference!)}';
    out.writeln('  static const int ${_camel(token.name)} = $value;');
  }
  out.write('}');
  return out.toString();
}

/// İşaretin altındaki elle yazılmış bölümü döndürür.
///
/// Dosya henüz yoksa (temiz klon değil, ilk üretim) boş döner — üreteç
/// elle yazılmış kodu ASLA uydurmaz.
String _handWrittenTail(File existing) {
  if (!existing.existsSync()) return '';
  final String content = existing.readAsStringSync();
  final int index = content.indexOf(_dartHandWrittenMarker);
  if (index < 0) return '';
  return content.substring(index + _dartHandWrittenMarker.length);
}

// ───────────────────────────────────────────────────────────────────────────
// Çıktı 2 — website/app/tokens.css
// ───────────────────────────────────────────────────────────────────────────

String _renderWebsiteCss(Tokens tokens) {
  final StringBuffer out = StringBuffer();
  out.writeln(_banner('/*', ' * ', ' */'));
  out.writeln();
  out.writeln('/*');
  out.writeln(' * KATMAN 1 — PRIMITIF');
  out.writeln(' *');
  out.writeln(
    ' * `@theme` blokları Tailwind\'in varsayılan temasından SONRA gelmek',
  );
  out.writeln(
    ' * zorundadır, yoksa `--color-neutral-*` gibi çakışan adlarda çekirdek',
  );
  out.writeln(' * palet kazanır. Bu yüzden `globals.css` bu dosyayı');
  out.writeln(' * `@import \'tailwindcss\'` satırından SONRA import eder.');
  out.writeln(' */');
  out.writeln('@theme {');
  bool firstFamily = true;
  tokens.primitives.forEach((String family, List<Token> ramp) {
    if (!firstFamily) out.writeln();
    firstFamily = false;
    for (final Token token in ramp) {
      _cssComment(token.note).forEach(out.writeln);
      out.writeln('  --color-${token.name}: ${token.hex.toLowerCase()};');
    }
  });
  out.writeln();
  for (final Token token in tokens.aliases) {
    _cssComment(token.note).forEach(out.writeln);
    out.writeln('  --color-${token.name}: ${token.hex.toLowerCase()};');
  }
  out.writeln('}');
  out.writeln();

  out.writeln('/*');
  out.writeln(' * KATMAN 2 — SEMANTİK ROLLER (açık tema)');
  out.writeln(' *');
  out.writeln(
    ' * shadcn/ui\'ın beklediği sözleşme. Bileşenler YALNIZCA bunları',
  );
  out.writeln(' * kullanır; tema değiştirmek tek bloğu değiştirmek demektir.');
  out.writeln(' */');
  out.writeln(':root {');
  for (final Token token in tokens.light) {
    _cssComment(token.note).forEach(out.writeln);
    out.writeln('  --${token.name}: ${_cssValue(token)};');
  }
  out.writeln();
  out.writeln('  color-scheme: light;');
  out.writeln('}');
  out.writeln();

  out.writeln('/* KATMAN 2 — SEMANTİK ROLLER (koyu tema) */');
  out.writeln('.dark {');
  for (final Token token in tokens.dark) {
    _cssComment(token.note).forEach(out.writeln);
    out.writeln('  --${token.name}: ${_cssValue(token)};');
  }
  out.writeln();
  out.writeln('  color-scheme: dark;');
  out.writeln('}');
  return out.toString();
}

String _cssValue(Token token) => token.reference == null
    ? token.hex.toLowerCase()
    : 'var(--color-${token.reference})';

// ───────────────────────────────────────────────────────────────────────────
// Çıktı 3 — yönetim panelinin belirteçleri
// ───────────────────────────────────────────────────────────────────────────

String _renderAdminCss(Tokens tokens) {
  final StringBuffer out = StringBuffer();
  out.writeln(_banner('/*', ' * ', ' */'));
  out.writeln();
  out.writeln('/*');
  out.writeln(
    ' * Yönetim paneli (TastyIgniter) yalnız AÇIK temada çalışıyor; koyu rol',
  );
  out.writeln(
    ' * tablosu buraya basılmaz. `admin.css` bu değişkenleri Bootstrap\'in',
  );
  out.writeln(
    ' * `--bs-*` değişkenlerine çevirir — panelin kendi CSS\'i düzenlenmez',
  );
  out.writeln(' * (AGENTS.md §2.1: `platform/vendor/` dokunulmaz).');
  out.writeln(' */');
  out.writeln(':root {');
  bool firstFamily = true;
  tokens.primitives.forEach((String family, List<Token> ramp) {
    if (!firstFamily) out.writeln();
    firstFamily = false;
    out.writeln('  /* ${family.toUpperCase()} */');
    for (final Token token in ramp) {
      out.writeln('  --bld-${token.name}: ${token.hex.toLowerCase()};');
    }
  });
  out.writeln();
  out.writeln('  /* Çıplak takma adlar — metin adımına işaret eder. */');
  for (final Token token in tokens.aliases) {
    out.writeln('  --bld-${token.name}: ${token.hex.toLowerCase()};');
  }
  out.writeln();
  out.writeln('  /* Açık tema rolleri. */');
  for (final Token token in tokens.light) {
    out.writeln('  --bld-role-${token.name}: ${token.hex.toLowerCase()};');
  }
  out.writeln('}');
  return out.toString();
}
