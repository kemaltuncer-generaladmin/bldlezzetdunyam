/// Bellekte tutan [KdsSettingsStore] — testler `shared_preferences` platform
/// kanalına dokunmasın.
///
/// Kanal testte kurulu olmadığı için gerçek deponun her yazması istisna atar
/// ve bu istisna, ayarı değiştiren düğmeye basan her testi düşürür.
library;

import 'package:mutfakapp/src/settings/kds_settings.dart';
import 'package:mutfakapp/src/settings/kds_settings_store.dart';

class FakeKdsSettingsStore implements KdsSettingsStore {
  KdsSettings? _saved;

  /// Testin doğrulaması için: en son diske yazılan ayar.
  KdsSettings? get saved => _saved;

  @override
  Future<KdsSettings> read(KdsSettings defaults) async => _saved ?? defaults;

  @override
  Future<void> write(KdsSettings settings) async => _saved = settings;
}
