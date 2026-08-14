/// `dart run bld_design_system:gen_tokens` giriş noktası.
///
/// Gerçek uygulama `tool/gen_tokens.dart` içinde duruyor: üreteç bir
/// GELİŞTİRME aracı, paketin yayınlanan yüzeyi değil — `lib/` altına
/// konsaydı her istemci uygulamanın derlemesine girerdi. pub yalnızca
/// `bin/` altındaki dosyaları çalıştırılabilir olarak tanıdığı için bu
/// üç satırlık köprü var.
library;

import '../tool/gen_tokens.dart' as generator;

void main(List<String> args) => generator.main(args);
