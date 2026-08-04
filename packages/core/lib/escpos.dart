/// ESC/POS yazdırma motoru — `docs/05-mutfakapp.md` §5.
///
/// Ayrı bir giriş noktasıdır (`bld_core.dart` değil) çünkü yalnızca `mutfakapp`
/// kullanır; müşteri uygulaması ve web sitesi yazıcı bilmez.
///
/// ```dart
/// import 'package:bld_core/escpos.dart';
///
/// final bytes = buildKitchenReceipt(data);   // Uint8List, yan etkisiz
/// ```
///
/// Motor **yalnızca bayt üretir**. Cihaza yazmak ve tekrar denemek yazdırma
/// kuyruğunun işidir (`docs/05` §5.4).
library;

export 'src/escpos/commands.dart';
export 'src/escpos/pc857.dart';
export 'src/escpos/receipt_data.dart';
export 'src/escpos/receipt_templates.dart';
export 'src/escpos/turkish_case.dart';
