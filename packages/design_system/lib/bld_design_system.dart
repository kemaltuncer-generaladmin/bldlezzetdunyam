/// Benim Lezzet Dünyam — tasarım belirteçleri.
///
/// **Neden saf Dart ve `ThemeData` yok:** belirteçler Flutter'dan bağımsızdır;
/// aynı değerleri `website/`'in Tailwind yapılandırmasına da üretebilmek
/// istiyoruz. Flutter `ThemeData`'sı, Flutter uygulamaları workspace'e
/// katıldığında (`K-01`, `M-01`) bu paketin `flutter/` alt kütüphanesinde
/// kurulur ve buradaki değerleri okur.
///
/// **Palet artık yer tutucu değil:** logodan ölçüldü ve tek kaynağı
/// `tokens/bld.tokens.json`. `src/colors.dart` ÜRETİLEN bir dosyadır; renk
/// değiştirmek için JSON'u düzenleyip `dart run bld_design_system:gen_tokens`
/// koşulur — aynı komut web ve yönetim panelinin CSS'ini de tazeler.
library;

export 'src/colors.dart';
export 'src/elevation.dart';
export 'src/motion.dart';
export 'src/spacing.dart';
export 'src/typography.dart';
