/// Testte saatlik sürüm denetimini susturur.
///
/// NEDEN GEREKLİ: gerçek denetim `bldApiProvider` üzerinden bir ağ isteği
/// açıyor ve HTTP istemcisinin bağlantı zaman aşımı zamanlayıcısı test
/// bittikten sonra da asılı kalıyor — `flutter_test` bunu "A Timer is still
/// pending even after the widget tree was disposed" ile düşürüyor.
///
/// `connectionAlarmPlayerProvider`'ın `SilentAlarmPlayer` ile değiştirilmesi
/// de aynı gerekçeye dayanıyor: uygulamayı bütün olarak açan her test, dış
/// dünyaya uzanan sağlayıcıları susturmak zorunda.
///
/// Denetimin KENDİ testleri `update_checker_test.dart` içinde ve orada
/// gerçek mantık sahte bir `check` ile ölçülüyor; burada susturulan şey
/// yalnızca ağ ve zamanlayıcı.
library;

import 'package:mutfakapp/src/data/providers.dart';
import 'package:mutfakapp/src/update/update_checker.dart';

class FakeUpdateCheck extends UpdateCheckController {
  @override
  UpdateStatus build() => const UpdateStatus();

  @override
  Future<void> check() async {}
}
