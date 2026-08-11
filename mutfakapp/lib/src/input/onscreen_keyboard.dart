/// Ekran klavyesi — dokunmatik monitörde harici klavye olmadan yazmak için.
///
/// NEDEN ELLE YAZILDI: kasada masaüstü ortamı yok (kiosk kipinde tek pencere
/// çalışıyor), dolayısıyla GNOME/onboard gibi bir sistem klavyesi açılmıyor.
/// Pub'daki Linux masaüstü klavyeleri ya yalnız mobil için ya da bakımsız;
/// yeni bir bağımlılık eklemeden çizilebilecek kadar basit bir iş
/// (AGENTS §2.4 — "kendi kütüphaneni yazma" kuralı **paket** içindir,
/// birkaç düğmelik bir widget için paket aramak kuralın amacına aykırı).
///
/// İKİ DÜZEN: sayısal (adet, şifre) ve Türkçe QWERTY (arama, sebep metni).
/// Türkçe düzen şart — `ı`, `ğ`, `ü`, `ş`, `ö`, `ç` olmadan mutfak notu
/// yazılamaz ve İngilizce düzende bunlar hiç yok.
library;

import 'package:bld_core/escpos.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Klavye düzeni.
enum OnscreenKeyboardLayout {
  /// 0-9 + sil + temizle. Adet ve şifre girişi.
  numeric,

  /// Türkçe QWERTY (F değil Q — mutfakta kimse F klavye beklemiyor).
  turkish,
}

/// Türkçe QWERTY satırları — küçük harf.
///
/// Büyük harf `packages/core`'daki `TurkishCase` ile üretiliyor,
/// `toUpperCase()` ile DEĞİL: Dart'ın varsayılanı `i` → `I` yapar,
/// Türkçe'de `i` → `İ` olmalı. Arama da (`order_filter.dart`) aynı sınıfı
/// kullanıyor; iki taraf ayrı bir kural kullansaydı klavyeyle yazılan
/// metin aramayı tutturmazdı.
const List<List<String>> turkishKeyRows = [
  ['q', 'w', 'e', 'r', 't', 'y', 'u', 'ı', 'o', 'p', 'ğ', 'ü'],
  ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'ş', 'i'],
  ['z', 'x', 'c', 'v', 'b', 'n', 'm', 'ö', 'ç', '.'],
];

/// Sayısal düzen satırları.
const List<List<String>> numericKeyRows = [
  ['1', '2', '3'],
  ['4', '5', '6'],
  ['7', '8', '9'],
  ['0'],
];

/// Bir metin denetleyicisine bağlı ekran klavyesi.
///
/// Denetleyiciyi doğrudan güncelliyor: `onChanged` geri çağrısı yerine
/// denetleyici kullanmak, alanın kendisinin (fiziksel klavyeyle) de
/// yazılabilir kalmasını sağlıyor. Kasada bazen klavye takılı oluyor ve
/// personel ikisini karışık kullanıyor.
class OnscreenKeyboard extends StatefulWidget {
  const OnscreenKeyboard({
    super.key,
    required this.controller,
    this.layout = OnscreenKeyboardLayout.turkish,
    this.onSubmit,
  });

  final TextEditingController controller;
  final OnscreenKeyboardLayout layout;

  /// "Tamam" tuşu. `null` ise tuş çizilmez.
  final VoidCallback? onSubmit;

  @override
  State<OnscreenKeyboard> createState() => _OnscreenKeyboardState();
}

class _OnscreenKeyboardState extends State<OnscreenKeyboard> {
  bool _upper = false;

  @override
  Widget build(BuildContext context) {
    final rows = widget.layout == OnscreenKeyboardLayout.numeric
        ? numericKeyRows
        : turkishKeyRows;

    return Material(
      color: const Color(KdsColors.surfaceRaised),
      borderRadius: BorderRadius.circular(BldRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(BldSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in rows)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final key in row)
                    _Key(
                      label: _display(key),
                      onTap: () => _insert(_display(key)),
                    ),
                ],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.layout == OnscreenKeyboardLayout.turkish) ...[
                  _Key(
                    label: _upper ? 'abc' : 'ABC',
                    flex: 2,
                    onTap: () => setState(() => _upper = !_upper),
                  ),
                  _Key(label: 'boşluk', flex: 4, onTap: () => _insert(' ')),
                ],
                _Key(
                  icon: Icons.backspace_outlined,
                  flex: 2,
                  onTap: _backspace,
                ),
                _Key(icon: Icons.clear, flex: 2, onTap: _clear),
                if (widget.onSubmit != null)
                  _Key(
                    icon: Icons.check,
                    flex: 2,
                    accent: const Color(BldColors.success),
                    onTap: widget.onSubmit!,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _display(String key) => _upper ? TurkishCase.toUpperCase(key) : key;

  /// İmleç konumunu koruyarak metin ekler.
  ///
  /// Sona eklemek yeterli görünüyor ama personel bir harfi düzeltmek için
  /// imleci ortaya alıp yazdığında metin sonuna eklenirdi.
  void _insert(String text) {
    final controller = widget.controller;
    final value = controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);

    final next = value.text.replaceRange(selection.start, selection.end, text);

    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: selection.start + text.length),
    );
  }

  void _backspace() {
    final controller = widget.controller;
    final value = controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);

    if (selection.start == 0 && selection.isCollapsed) return;

    final start = selection.isCollapsed ? selection.start - 1 : selection.start;

    controller.value = TextEditingValue(
      text: value.text.replaceRange(start, selection.end, ''),
      selection: TextSelection.collapsed(offset: start),
    );
  }

  void _clear() => widget.controller.clear();
}

class _Key extends StatelessWidget {
  const _Key({
    this.label,
    this.icon,
    required this.onTap,
    this.flex = 1,
    this.accent,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final int flex;
  final Color? accent;

  /// Tuş yüksekliği: 64 px.
  ///
  /// Material'ın 48 px önerisi parmak ucu içindir; mutfakta eldivenli ya da
  /// yağlı elle basılıyor ve 48 px'te komşu tuşa basma oranı yüksek.
  static const double height = 64;

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.all(3),
      child: SizedBox(
        height: height,
        child: FilledButton.tonal(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, height),
            padding: EdgeInsets.zero,
            backgroundColor: accent,
            foregroundColor: accent == null ? null : const Color(0xFF0B0B0B),
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: icon != null
              ? Icon(icon, size: 26)
              : Text(
                  label!,
                  style: const TextStyle(
                    fontSize: KdsTextScale.orderNumber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    ),
  );
}
