/// KDS'nin sesli uyardığı olaylar ve her birinin ses dosyası.
///
/// NEDEN OLAY BAZLI: mutfakta personel ekrana bakamadan ses duyar. Tek bir
/// "bip" hangi olayın olduğunu söylemez; personel yeni sipariş sanıp ekrana
/// koşar, orada bir şey bulamaz ve zamanla sesi ciddiye almayı bırakır.
/// Ayrı sesler, ekrana bakmadan doğru tepkiyi verdirir.
///
/// Her olay ayrı ayrı kapatılabilir: kasa bir süre yazıcısız çalışıyorsa
/// yazıcı uyarısı sürekli çalıp yeni sipariş sesini bastırmamalı.
library;

/// Sesli uyarı gerektiren olaylar.
enum KdsSoundEvent {
  /// Onaylanmamış yeni sipariş var. Onaylanana kadar tekrar eder.
  newOrder('assets/sounds/yeni_siparis.wav', 'Yeni sipariş'),

  /// Sipariş gecikme eşiğini aştı.
  lateOrder('assets/sounds/gecikme.wav', 'Geciken sipariş'),

  /// Sunucuya ulaşılamıyor. Susturulamaz (bkz. `connection_alarm.dart`).
  connectionLost('assets/sounds/baglanti_yok.wav', 'Bağlantı koptu'),

  /// Yazıcı yok ya da kuyrukta başarısız fiş birikti.
  printerError('assets/sounds/yazici_hatasi.wav', 'Yazıcı sorunu'),

  /// Abonelik üretimi hatırlatması.
  subscriptionReminder('assets/sounds/abonelik.wav', 'Abonelik hatırlatması'),

  /// BBD Store'dan sipariş düştü (K-16).
  bbdOrder('assets/sounds/bbd_siparis.wav', 'BBD Store siparişi');

  const KdsSoundEvent(this.assetPath, this.label);

  /// Çalınacak dosyanın varlık yolu.
  final String assetPath;

  /// Ayar ekranında ve tanılamada görünen ad.
  final String label;

  /// Ayar anahtarı eki — `shared_preferences` anahtarları bundan türer.
  ///
  /// Enum adının kendisi kullanılıyor; bir kez yayımlandıktan sonra
  /// DEĞİŞTİRİLMEZ, değişirse kasadaki ayar sessizce varsayılana döner.
  String get settingsKey => 'kds_sound_${name}_enabled';

  /// Personel bu uyarıyı kapatabilir mi?
  ///
  /// Bağlantı kopması kapatılamaz: ekran son bilinen listeyi gösterir ve
  /// DOĞRU görünür, yeni sipariş hiç gelmez. Tek uyarıyı kapatmak mutfağı
  /// kör bırakır (`docs/05` §5.5).
  bool get canBeDisabled => this != KdsSoundEvent.connectionLost;
}
