/// Uygulama-içi duyuru sağlayıcıları — `docs/openapi.yaml` §Duyuru.
///
/// **PUSH (FCM) YOKTUR** (iş kararı 11): duyuru yalnız uygulama açıkken
/// çekilir. Bu yüzden bant, ekran çizilirken sorulan basit bir
/// `FutureProvider`'dır; arka planda dinleyen bir kanal yok.
///
/// Kapatma işareti **cihazda** tutuluyor. Sözleşmede
/// `POST /announcements/{id}/dismiss` var ama `bld_api_client`'ın
/// `AnnouncementService` arayüzü yalnız [AnnouncementService.list] açıyor;
/// o metodu eklemek başka bir kulvarın işi. Yerel işaret bu boşluğu
/// kapatıyor: müşteri kapattığı duyuruyu bu cihazda bir daha görmüyor —
/// karşılığı, ikinci bir cihazda bir kez daha görmesi.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'infra_providers.dart';
import 'session_provider.dart';

/// Kullanıcının kapattığı duyuru kimlikleri; cihazda kalıcı.
///
/// Durum bir **liste**, küme değil: tavana budama en eskiyi atmak demek ve
/// sırasız bir küme "en eski" sorusuna cevap veremez
/// (`LocalCache.dismissedAnnouncementLimit`). Üyelik sorusu bu boyda bir
/// listede zaten tek geçişte cevaplanıyor.
class DismissedAnnouncementsNotifier extends Notifier<List<int>> {
  @override
  List<int> build() =>
      ref.watch(localCacheProvider).readDismissedAnnouncements();

  /// Duyuruyu bu cihazda kapatır.
  ///
  /// Zaten kapatılmış duyuruda hiçbir şey yapmaz: yeniden yazmak listeyi
  /// gereksizce tazeler ve bandı boşuna yeniden çizerdi.
  Future<void> dismiss(int id) async {
    if (state.contains(id)) return;
    state = await ref.read(localCacheProvider).writeDismissedAnnouncement(id);
  }
}

final dismissedAnnouncementsProvider =
    NotifierProvider<DismissedAnnouncementsNotifier, List<int>>(
      DismissedAnnouncementsNotifier.new,
    );

/// Bir yerleşimde sunucunun **şu an gösterilmesi gerektiğini söylediği**
/// duyurular.
///
/// Aile anahtarı yerleşimdir (`AnnouncementPlacement.*`): ana sayfa bandı ile
/// sepet bandı aynı listeyi paylaşmaz.
///
/// **Yayın penceresi elemesi SUNUCUNUNDUR** — istemci `starts_at`/`ends_at`'e
/// kendi saatiyle bakmaz. Saati kaymış bir telefon, geçerli duyuruyu gizler ya
/// da süresi dolmuşu göstermeye devam ederdi.
///
/// **Yerel kapatma işareti BURAYA GİRMEZ**, [firstVisibleAnnouncement] ile
/// çizim anında uygulanır: kapatılanları burada elese, her kapatma bu
/// sağlayıcıyı tazeler ve tek bir çarpıya dokunmak listeyi ağdan yeniden
/// indirirdi.
///
/// **HATA YUTULUR.** Duyuru bir süstür, ekranın içeriği değil: uç 500 dönerse
/// ya da ağ yoksa ana sayfa duyurusuz açılmalıdır. Hatayı yukarı taşımak,
/// bir bandın yüzünden bütün vitrini hata ekranına çevirirdi. Aynı sebeple
/// [ConnectivityNotifier] de beslenmiyor — "çevrimdışı" kararı sipariş ve menü
/// çağrılarının işidir, duyurunun değil.
final announcementsProvider = FutureProvider.autoDispose
    .family<List<Announcement>, String>((ref, placement) async {
      // Uç müşteri token'ı istiyor. Giriş yapmamış kullanıcıya sormak `401`
      // demek; sözleşmedeki `all` kitlesi giriş yapmamış ziyaretçiyi kapsıyor
      // ama o ziyaretçi SİTEDE. Uygulamada oturumsuz duyuru yoktur.
      final session = ref.watch(sessionProvider).valueOrNull;
      if (session == null || !session.isSignedIn) {
        return const <Announcement>[];
      }

      try {
        return await ref
            .watch(apiProvider)
            .announcements
            .list(placement: placement);
      } on ApiException {
        return const <Announcement>[];
      }
    });

/// Bantta çizilecek duyuru; yoksa `null`.
///
/// **Aynı anda TEK duyuru.** Sıralama sunucunundur (önce `critical`, sonra
/// yeni olan), yani listenin başı zaten en önemlisidir. Hepsini üst üste
/// dizmek, üç duyurulu bir günde ana sayfanın menüsünü ekrandan iterdi;
/// kapatılabilir bir duyuru kapatıldığında sıradaki kendiliğinden görünür.
///
/// [placement] İSTEMCİDE de doğrulanıyor: yerleşim kapalı bir enum değil ve
/// süzgeci yok sayan bir sunucu sepet duyurusunu ana sayfaya astırırdı.
/// Tanınmayan yeri çizmemek sözleşmenin kuralı.
Announcement? firstVisibleAnnouncement({
  required List<Announcement> announcements,
  required List<int> dismissed,
  required String placement,
}) {
  for (final announcement in announcements) {
    if (!announcement.isFor(placement)) continue;
    // `dismissed` sunucunun bildiği kapatma, [dismissed] listesi bu cihazın
    // bildiği; ikisi de aynı sonucu doğuruyor ve ikisine de bakılıyor çünkü
    // istemci kapatmayı sunucuya YAZAMIYOR (bkz. kitaplık açıklaması).
    if (announcement.dismissed) continue;
    if (dismissed.contains(announcement.id)) continue;
    return announcement;
  }
  return null;
}
