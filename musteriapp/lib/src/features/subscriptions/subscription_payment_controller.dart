/// Abonelik dönem ödemesinin durum makinesi — `docs/openapi.yaml`
/// §Ödeme (`/subscriptions/{id}/payments...`).
///
/// **Ödeme uygulamanın İÇİNDE başlar ve içinde biter.** Dış tarayıcıya
/// çıkılmaz: simülasyonda sunucu `none` ya da `otp` döndürüyor ve ikisinin de
/// karşılığı yerli bir ekran. Tek dış adım `three_ds` ve o dal bugün
/// **kapalı** — kapalılığı bir istisna fırlatarak değil, kullanıcıya açık bir
/// cümleyle söyleyerek belirtiliyor (`AGENTS.md` §2.5 yarım bırakılmış dalı
/// "bitti" saymıyor). PSP bağlandığında yalnız o tek dal gövde kazanır.
///
/// **Tutar burada HESAPLANMAZ.** Dönem tutarını sunucu üretir (servis günü ×
/// porsiyon × anlaşmalı fiyat, atlanan günler düşülmüş); istemci onu yalnız
/// gösterir. İki yerde hesaplanan bir tutar, iki farklı rakam göstermenin en
/// kısa yoludur.
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../providers/infra_providers.dart';
import '../../providers/subscription_providers.dart';

part 'subscription_payment_controller.freezed.dart';

/// `three_ds` dalının yoklama takvimi: 2 sn × 5, sonra 5 sn × 12, sonra DUR.
///
/// **Neden sınırlı:** sipariş takibinin sonsuz 5 saniyelik yoklaması bir
/// ödeme ekranına kopyalanamaz. Sipariş ekranı açık kaldıkça mutfak durumu
/// değişmeye devam eder; ödeme ise ya birkaç dakika içinde sonuçlanır ya da
/// sağlayıcıda takılmıştır. İkinci durumda saatlerce yoklamak yalnız oran
/// sınırını doldurur (sözleşme: en az 2 sn aralık) ve sınıra takılan istemci,
/// başarılı olmuş bir ödemede başarısız ekranı gösterir.
///
/// Kademe de bilinçli: ilk 10 saniye sık, sonrası seyrek. Sağlayıcıdan gelen
/// yanıtların çoğu ilk saniyelere düşüyor; sonrasını aynı sıklıkta yoklamak
/// kazanç getirmeden istek üretirdi. Bütçe dolunca ekran susar ve kullanıcıya
/// aşağı çekerek yenilemeyi önerir — karar onun olur.
final List<Duration> kSubscriptionPaymentPollSchedule = List.unmodifiable([
  ...List.filled(5, const Duration(seconds: 2)),
  ...List.filled(12, const Duration(seconds: 5)),
]);

/// Ödemenin yürümediği durumun SEBEBİ.
///
/// Metin değil sebep taşınıyor: denetleyicide `BuildContext` yok ve Türkçe
/// cümleyi oradan üretmek, l10n'i atlayıp koda gömülü metin doğururdu
/// (`AGENTS.md` §4). Cümleyi ekran kurar.
enum SubscriptionPaymentFailure {
  /// Sunucu hata döndü; ayrıntı [SubscriptionPaymentFailed.error] içinde.
  api,

  /// Sağlayıcı ödemeyi reddetti — sebebi sunucu Türkçe yazıyor
  /// (`SubscriptionPayment.failureReason`).
  declined,

  /// Sözleşmeye sonradan eklenmiş, bu sürümün bilmediği bir adım
  /// (`PaymentNextAction.unknown`). Kullanıcıya yapacağı iş söylenir:
  /// uygulamayı güncellemek.
  unsupportedStep,

  /// `three_ds` yoklama bütçesi doldu ve ödeme hâlâ sonuçlanmadı.
  pollExhausted,

  /// Ek adım yok (`none`) ama ödeme `paid` de değil. Simülasyonda beklenmeyen
  /// bir durum; sessizce "başarılı" saymak, ödenmemiş bir dönemi ödenmiş
  /// göstermek olurdu.
  unsettled,
}

/// Ödeme ekranının durumu.
///
/// `AsyncValue` bunun yerini TUTMAZ: `AsyncValue` "yükleniyor / veri / hata"
/// üçlüsünü bilir, oysa burada beklemenin üç ayrı türü var (başlatılıyor,
/// kod doğrulanıyor, sonuç yoklanıyor) ve her birinin ekranda kurduğu cümle
/// ayrı. `AsyncValue` sarmalayıcı olarak duruyor — ilk yükleme ve tazeleme
/// onunla, akış bununla anlatılıyor.
@freezed
sealed class SubscriptionPaymentState with _$SubscriptionPaymentState {
  /// Henüz ödeme başlatılmadı.
  const factory SubscriptionPaymentState.idle() = SubscriptionPaymentIdle;

  /// `POST /subscriptions/{id}/payments` sürüyor.
  const factory SubscriptionPaymentState.starting() =
      SubscriptionPaymentStarting;

  /// Kullanıcıdan SMS kodu bekleniyor.
  ///
  /// [error] yalnız yanlış/eksik koddan sonra dolar ve ekran kod alanını
  /// KAPATMAZ: yanlış kod girildiğinde kullanıcıyı akışın başına atmak,
  /// tüketilmiş bir deneme karşılığında hiçbir şey kazandırmaz.
  const factory SubscriptionPaymentState.awaitingOtp({
    required SubscriptionPayment payment,
    ApiException? error,
  }) = SubscriptionPaymentAwaitingOtp;

  /// Girilen kod sağlayıcıya iletildi, yanıt bekleniyor.
  const factory SubscriptionPaymentState.verifying({
    required SubscriptionPayment payment,
  }) = SubscriptionPaymentVerifying;

  /// `three_ds` dalı: sonuç sınırlı bütçeyle yoklanıyor.
  ///
  /// [attempt] `0` iken henüz ilk yoklama yapılmadı (bekleme aralığındayız).
  const factory SubscriptionPaymentState.polling({
    required SubscriptionPayment payment,
    required int attempt,
    required int total,
  }) = SubscriptionPaymentPolling;

  /// Ödeme kesinleşti; ekran makbuzu gösterir.
  const factory SubscriptionPaymentState.succeeded({
    required SubscriptionPayment payment,
  }) = SubscriptionPaymentSucceeded;

  /// Ödeme yürümedi. [payment] varsa durum yeniden yoklanabilir.
  const factory SubscriptionPaymentState.failed({
    required SubscriptionPaymentFailure reason,
    SubscriptionPayment? payment,
    ApiException? error,
  }) = SubscriptionPaymentFailed;

  const SubscriptionPaymentState._();

  /// Elimizdeki ödeme kaydı; hiç başlatılmadıysa `null`.
  SubscriptionPayment? get payment => switch (this) {
    SubscriptionPaymentIdle() => null,
    SubscriptionPaymentStarting() => null,
    SubscriptionPaymentAwaitingOtp(:final payment) => payment,
    SubscriptionPaymentVerifying(:final payment) => payment,
    SubscriptionPaymentPolling(:final payment) => payment,
    SubscriptionPaymentSucceeded(:final payment) => payment,
    SubscriptionPaymentFailed(:final payment) => payment,
  };

  /// Sunucudan yanıt bekleniyor mu? Düğmeler bu sırada kapanır — çift dokunuş
  /// ikinci bir ödeme kaydı açmaz ama boşuna bir istek üretir.
  bool get isBusy =>
      this is SubscriptionPaymentStarting ||
      this is SubscriptionPaymentVerifying;
}

/// Ödeme akışını yürüten denetleyici.
///
/// Aile argümanı **abonelik kimliğidir**; ödeme kimliği durumun içinde taşınır.
class SubscriptionPaymentController
    extends AutoDisposeFamilyAsyncNotifier<SubscriptionPaymentState, int> {
  /// Sağlayıcı atıldı mı? Yoklama döngüsü ve gecikmiş yanıtlar buna bakar;
  /// atılmış bir sağlayıcıya durum yazmak istisna fırlatır.
  bool _disposed = false;

  /// Yürüyen yoklamanın kuşağı. Her yeni eylem kuşağı artırır; eski döngü
  /// uyandığında kendi kuşağının geçtiğini görür ve sessizce çekilir.
  ///
  /// **Neden `Timer` değil:** takvim kademeli (2 sn × 5, sonra 5 sn × 12) ve
  /// her adımda bir ağ isteği var. `Timer.periodic` sabit aralık verir ve
  /// yavaş bir yanıt gelirken bir sonraki isteği başlatır.
  int _generation = 0;

  SubscriptionService get _service => ref.read(apiProvider).subscriptions;

  @override
  Future<SubscriptionPaymentState> build(int arg) async {
    // `onDispose` sağlayıcı YENİDEN HESAPLANIRKEN de çalışır; bayrağı her
    // yapımda sıfırlamak zorundayız, yoksa bir kez tazelenen ekran bir daha
    // durum yazamaz.
    _disposed = false;
    _generation++;
    ref.onDispose(() => _disposed = true);

    // `watch` DEĞİL `read`: aboneliği izleseydik, ödeme kesinleşince
    // yaptığımız tazeleme (`_apply`) bu yapımı yeniden koşturur ve makbuzu
    // ekrandan silerdi. Sunucunun abonelik özeti ödemeden bir an sonra hâlâ
    // eski hâliyle dönebiliyor; o an ekrana "henüz ödeme başlatılmadı"
    // yazmak, parasını yeni ödemiş aboneye ödemesini kaybettirmek olurdu.
    // Akışın sahibi bu denetleyici, abonelik ise yalnızca başvuru kaydı.
    final subscription = await ref.read(subscriptionProvider(arg).future);

    // Bu dönem için açılmış bir ödeme var mı? `payment_id` yoksa ödeme hiç
    // başlamamıştır — `0` diye bir kayıt yok, `null` ile karıştırılmaz.
    final paymentId = subscription.payment?.paymentId;
    if (paymentId == null) return const SubscriptionPaymentState.idle();

    // Özet "ne bekleniyor"u söyler ama sıradaki ADIMI söylemez; onu yalnız
    // ödeme kaydı taşıyor. Yarım kalmış bir akışa geri dönen abone, kod
    // ekranını burada bulur.
    final payment = await _service.payment(arg, paymentId);
    return _derive(payment);
  }

  /// Dönem ödemesini başlatır.
  ///
  /// Aynı dönemde açık bir ödeme varsa sunucu `200` ile MEVCUT kaydı döner;
  /// bu yüzden düğme "yeniden dene" olarak da kullanılabilir ve ikinci bir
  /// tahsilat kaydı doğurmaz.
  Future<void> start() async {
    final current = state.valueOrNull;
    if (current != null && current.isBusy) return;

    // Yürüyen bir yoklama varsa iptal: kullanıcı yeni bir akış başlattı.
    _generation++;
    _emit(const SubscriptionPaymentState.starting());

    try {
      final payment = await _service.startPayment(arg);
      _apply(payment);
    } on ApiException catch (error) {
      _emit(
        SubscriptionPaymentState.failed(
          reason: SubscriptionPaymentFailure.api,
          payment: current?.payment,
          error: error,
        ),
      );
    }
  }

  /// SMS kodunu sağlayıcıya iletir.
  ///
  /// Yanlış kod **denemeyi tüketir** ve kullanıcı kod ekranında kalır; hak
  /// bittiğinde sunucunun mesajı bunu söyler ve abone yeni bir ödeme başlatır.
  Future<void> submitOtp(String code) async {
    final current = state.valueOrNull;
    if (current is! SubscriptionPaymentAwaitingOtp) return;

    final payment = current.payment;
    _generation++;
    _emit(SubscriptionPaymentState.verifying(payment: payment));

    try {
      final updated = await _service.confirmPayment(
        arg,
        payment.paymentId,
        otp: code,
      );
      _apply(updated);
    } on ApiException catch (error) {
      _emit(
        SubscriptionPaymentState.awaitingOtp(payment: payment, error: error),
      );
    }
  }

  /// Ödemenin güncel hâlini sunucudan okur — aşağı çekerek yenile.
  ///
  /// Henüz ödeme başlatılmamışsa aboneliğin kendisi tazelenir: fiyatı yeni
  /// girilmiş bir talep, ancak o zaman ödenebilir hâle gelir.
  Future<void> refresh() async {
    final payment = state.valueOrNull?.payment;
    if (payment == null) {
      // Elimizde ödeme kaydı yok; sorulacak tek şey aboneliğin kendisi.
      // Kendimizi de tazeliyoruz: fiyatı yeni girilmiş bir talebin ödemesi
      // ancak bu yapım yeniden koştuğunda görünür hâle gelir.
      ref.invalidate(subscriptionProvider(arg));
      ref.invalidateSelf();
      return;
    }

    _generation++;
    try {
      final updated = await _service.payment(arg, payment.paymentId);
      _apply(updated);
    } on ApiException catch (error) {
      _emit(
        SubscriptionPaymentState.failed(
          reason: SubscriptionPaymentFailure.api,
          payment: payment,
          error: error,
        ),
      );
    }
  }

  /// Sunucudan gelen ödeme kaydını duruma çevirir ve yazar.
  ///
  /// Ödeme kesinleştiyse abonelik sağlayıcıları da tazelenir: `awaiting_payment`
  /// olan abonelik sunucuda `active` oldu ve listede eski durumuyla kalması,
  /// ödemesini yeni yapmış aboneye "hâlâ ödeme bekleniyor" demek olurdu.
  void _apply(SubscriptionPayment payment) {
    final next = _derive(payment);
    _emit(next);
    if (next is SubscriptionPaymentSucceeded) {
      ref.invalidate(subscriptionsProvider);
      ref.invalidate(subscriptionProvider(arg));
    }
  }

  /// Ödeme kaydının durum karşılığı. **Yan etkisi vardır:** `three_ds`
  /// dalında sınırlı yoklamayı başlatır.
  SubscriptionPaymentState _derive(SubscriptionPayment payment) {
    if (payment.isPaid) {
      return SubscriptionPaymentState.succeeded(payment: payment);
    }

    // Sağlayıcının reddi, sıradaki adımdan ÖNCE bakılır: reddedilmiş bir
    // ödemede `next_action` hâlâ eski değeriyle gelebiliyor ve kullanıcıyı
    // kabul edilmeyecek bir kod ekranına oturtmak, bir denemeyi daha boşa
    // harcatırdı.
    final failureReason = payment.failureReason;
    if (failureReason != null && failureReason.trim().isNotEmpty) {
      return SubscriptionPaymentState.failed(
        reason: SubscriptionPaymentFailure.declined,
        payment: payment,
      );
    }

    return switch (payment.nextAction) {
      PaymentNextAction.otp => SubscriptionPaymentState.awaitingOtp(
        payment: payment,
      ),
      PaymentNextAction.threeDs => _trackThreeDs(payment),
      PaymentNextAction.none => SubscriptionPaymentState.failed(
        reason: SubscriptionPaymentFailure.unsettled,
        payment: payment,
      ),
      PaymentNextAction.unknown => SubscriptionPaymentState.failed(
        reason: SubscriptionPaymentFailure.unsupportedStep,
        payment: payment,
      ),
    };
  }

  /// `three_ds`: yönlendirme YAPILMAZ, sonuç sınırlı bütçeyle izlenir.
  ///
  /// Banka doğrulama sayfası bu sürümde açılmıyor (PSP bağlı değil) ama ödeme
  /// kaydı sunucuda duruyor ve dışarıdan sonuçlanabilir. Ekranı hemen
  /// "başarısız" yazıp kapatmak, sonuçlanmış bir ödemeyi göstermezdi.
  SubscriptionPaymentState _trackThreeDs(SubscriptionPayment payment) {
    unawaited(_pollThreeDs(payment));
    return SubscriptionPaymentState.polling(
      payment: payment,
      attempt: 0,
      total: kSubscriptionPaymentPollSchedule.length,
    );
  }

  Future<void> _pollThreeDs(SubscriptionPayment payment) async {
    final generation = ++_generation;
    final schedule = kSubscriptionPaymentPollSchedule;
    var current = payment;

    for (var attempt = 0; attempt < schedule.length; attempt++) {
      // Bekleme ÖNCE: `POST .../payments` yanıtı saniyenin içinde geldi,
      // hemen tekrar sormak sözleşmenin 2 saniyelik alt sınırını çiğnerdi.
      await Future<void>.delayed(schedule[attempt]);
      if (_isStale(generation)) return;

      _emit(
        SubscriptionPaymentState.polling(
          payment: current,
          attempt: attempt + 1,
          total: schedule.length,
        ),
      );

      try {
        current = await _service.payment(arg, payment.paymentId);
      } on ApiException catch (error) {
        if (_isStale(generation)) return;
        _emit(
          SubscriptionPaymentState.failed(
            reason: SubscriptionPaymentFailure.api,
            payment: current,
            error: error,
          ),
        );
        return;
      }
      if (_isStale(generation)) return;

      // Adım değiştiyse (ya da ödeme kapandıysa) döngü biter; `_apply` yeni
      // durumu kurar. `three_ds` sürerken sürdürülür.
      if (current.isPaid || current.nextAction != PaymentNextAction.threeDs) {
        _apply(current);
        return;
      }
    }

    if (_isStale(generation)) return;
    _emit(
      SubscriptionPaymentState.failed(
        reason: SubscriptionPaymentFailure.pollExhausted,
        payment: current,
      ),
    );
  }

  /// Bu döngü hâlâ geçerli mi? Atılmış sağlayıcı ya da geçilmiş kuşak.
  bool _isStale(int generation) => _disposed || generation != _generation;

  void _emit(SubscriptionPaymentState next) {
    if (_disposed) return;
    state = AsyncValue.data(next);
  }
}

/// Abonelik ödeme akışı — aile argümanı abonelik kimliğidir.
final subscriptionPaymentProvider =
    AsyncNotifierProvider.autoDispose
        .family<
          SubscriptionPaymentController,
          SubscriptionPaymentState,
          int
        >(SubscriptionPaymentController.new);
