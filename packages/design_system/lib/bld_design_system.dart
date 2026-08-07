/// Benim Lezzet Dünyam — tasarım belirteçleri.
///
/// **Neden saf Dart ve `ThemeData` yok:** belirteçler Flutter'dan bağımsızdır;
/// aynı değerleri `website/`'in Tailwind yapılandırmasına da üretebilmek
/// istiyoruz. Flutter `ThemeData`'sı, Flutter uygulamaları workspace'e
/// katıldığında (`K-01`, `M-01`) bu paketin `flutter/` alt kütüphanesinde
/// kurulur ve buradaki değerleri okur.
///
/// **Geçici:** palet yer tutucudur. Logo ve nihai renkler için
/// `docs/BILINMEYENLER.md` soru #11.
library;

export 'src/colors.dart';
export 'src/elevation.dart';
export 'src/motion.dart';
export 'src/spacing.dart';
export 'src/typography.dart';
