/// Kalan porsiyon rozeti — `bld_core`'daki stok bandını `BldPill`'e giydirir.
///
/// **Hesap BURADA YAPILMIYOR.** Band `bld_core`'daki [stockLevel]'dan geliyor;
/// bu dosya yalnız hangi rozetin hangi tonda çizileceğine karar veriyor.
/// Aritmetiğin normatif kaynağı `docs/contract/sales-rules.cases.json` ve
/// aynı kural web ile PHP tarafında da yaşıyor — eşiği ya da karşılaştırmayı
/// burada yeniden yazan bir ekran, üç yüzeyin ayrıldığı yer olur.
///
/// **Rozet sepetten bağımsızdır:** ham kalanı anlatır, müşterinin sepetindeki
/// adedi düşmez. "Son 3 porsiyon" bu yüzden herkes için aynı sayıdır; sepete
/// göre değişseydi iki müşteri aynı menüde iki farklı sayı görür ve rozet bir
/// stok bilgisi olmaktan çıkardı. Sepete kaç tane daha girebileceği ayrı bir
/// sorudur ve cevabı `maxAddable`'dadır.
library;

import 'package:bld_core/bld_core.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'pill.dart';

/// "Son N porsiyon" rozetinin çıkmaya başladığı eşik.
///
/// Sözleşmede bir alanı YOK (`docs/openapi.yaml` kalan porsiyonu verir, eşiği
/// değil) ve altın veri kümesinin varsayılanı da budur
/// (`sales-rules.cases.json` → `defaults.low_threshold`). Sunucu ileride eşiği
/// bildirirse [StockPill.lowThreshold] üzerinden geçilir; sabit burada tek
/// yerde durduğu için o gün tek satır değişir.
const int kStockLowThreshold = 5;

/// Gün tavanı ile kalem tavanının BİRLEŞİK kalanı.
///
/// Altın veri kümesindeki `case_input_binding` ile aynı kural: ikisi de `null`
/// ise sınır yok, biri doluysa o, ikisi de doluysa küçüğü bağlar. Rozetin
/// gösterdiği sayı, satışı önce kapatacak olan tavanın sayısıdır — gün
/// toplamından 2 kalmışken bir yemeğin 40 porsiyonunu duyurmak, müşteriye
/// alamayacağı bir adedi vaat etmek olurdu.
///
/// **`null` SINIRSIZ demektir, asla sıfır değil.**
int? effectiveRemaining({int? dayRemaining, int? itemRemaining}) {
  if (dayRemaining == null) return itemRemaining;
  if (itemRemaining == null) return dayRemaining;
  return dayRemaining < itemRemaining ? dayRemaining : itemRemaining;
}

/// Kalan porsiyonu anlatan rozet; anlatacak bir şey yoksa hiç çizilmez.
class StockPill extends StatelessWidget {
  const StockPill({
    super.key,
    required this.remaining,
    this.lowThreshold = kStockLowThreshold,
  });

  /// Kalan porsiyon; **`null` tavan konmamış demektir**.
  final int? remaining;

  /// Altında "son N porsiyon" denen eşik; eşiğin kendisi dahildir.
  final int lowThreshold;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final level = stockLevel(remaining: remaining, lowThreshold: lowThreshold);

    return switch (level) {
      // Bolluk da sınırsızlık da SESSİZDİR: "42 porsiyon kaldı" bir aciliyet
      // kurmuyor, yalnız kartı kalabalıklaştırıyor.
      StockLevel.unlimited || StockLevel.plenty => const SizedBox.shrink(),
      StockLevel.low => BldPill(
        label: l10n.stockLowRemaining(remaining!),
        variant: BldPillVariant.warning,
        icon: Icons.local_fire_department_outlined,
      ),
      // Tükenmiş rozet NÖTR: kırmızı bir uyarı, müşterinin yaptığı bir hatayı
      // ima eder. Burada hata yok, yemek bitmiş.
      StockLevel.soldOut => BldPill(label: l10n.stockSoldOut),
    };
  }
}
