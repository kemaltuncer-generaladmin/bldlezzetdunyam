/// Abonelik dönem ödemesi ekranı.
///
/// **Akış uygulamanın içinde başlar ve içinde biter.** Dış tarayıcı yok:
/// simülasyonda sunucu `none` ya da `otp` döndürüyor, ikisinin de karşılığı
/// burada. `three_ds` dalı sözleşmede ilan edilmiş durumda ama bu sürümde
/// **kapalı** ve kullanıcıya açık bir cümleyle öyle gösteriliyor — sessizce
/// atlanan ya da istisnayla patlayan bir dal, kullanıcıya ne olduğunu
/// söylemezdi.
///
/// Renkler `Theme.of` ve `context.bld` üzerinden okunuyor; ham `BldColors`
/// sabiti kullanılmıyor (`bld_semantic_colors.dart` — koyu tema açıldığında
/// beyaz üstüne beyaz yazan ekranların sebebi oydu).
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_error_text.dart';
import '../../core/labels.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/subscription_providers.dart';
import '../../router/app_router.dart';
import '../../theme/bld_semantic_colors.dart';
import '../../widgets/bld_card.dart';
import '../../widgets/pill.dart';
import '../../widgets/status_views.dart';
import 'subscription_payment_controller.dart';

class SubscriptionPaymentScreen extends ConsumerStatefulWidget {
  const SubscriptionPaymentScreen({super.key, required this.id});

  /// Abonelik kimliği. Ödeme kimliği yoldan gelmez — hangi dönemin ödendiğini
  /// sunucu seçer ve paylaşılan bir bağlantı yanlış döneme işaret edemez.
  final int id;

  @override
  ConsumerState<SubscriptionPaymentScreen> createState() =>
      _SubscriptionPaymentScreenState();
}

class _SubscriptionPaymentScreenState
    extends ConsumerState<SubscriptionPaymentScreen> {
  final _otpKey = GlobalKey<FormState>();
  final _otp = TextEditingController();

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  SubscriptionPaymentController get _controller =>
      ref.read(subscriptionPaymentProvider(widget.id).notifier);

  Future<void> _refresh() => _controller.refresh();

  void _submitOtp() {
    if (!_otpKey.currentState!.validate()) return;
    // Kod alanı TEMİZLENMİYOR: yanlış koddan sonra kullanıcı çoğu zaman tek
    // hane düzeltiyor. Alanı boşaltmak, altı haneyi yeniden yazdırırdı.
    _controller.submitOtp(_otp.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subscriptionAsync = ref.watch(subscriptionProvider(widget.id));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.subscriptionPaymentTitle)),
      body: subscriptionAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(subscriptionProvider(widget.id)),
        ),
        data: (subscription) => _Body(
          subscription: subscription,
          otpKey: _otpKey,
          otpController: _otp,
          onRefresh: _refresh,
          onStart: _controller.start,
          onSubmitOtp: _submitOtp,
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.subscription,
    required this.otpKey,
    required this.otpController,
    required this.onRefresh,
    required this.onStart,
    required this.onSubmitOtp,
  });

  final Subscription subscription;
  final GlobalKey<FormState> otpKey;
  final TextEditingController otpController;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onStart;
  final VoidCallback onSubmitOtp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(subscriptionPaymentProvider(subscription.id));

    // Tazelenirken önceki durum EKRANDA KALIYOR (`valueOrNull`): aşağı
    // çekildiğinde makbuzun yerini bir iskeletin alması, kullanıcıya ödemesi
    // kaybolmuş gibi görünürdü.
    final state = async.valueOrNull;
    if (state == null) {
      return async.hasError
          ? ErrorView(
              error: async.error!,
              onRetry: () =>
                  ref.invalidate(subscriptionPaymentProvider(subscription.id)),
            )
          : const LoadingView();
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        // Kısa içerikte bile aşağı çekilebilsin: yenileme bu ekranın tek
        // "bir daha sor" yolu ve liste kaydırılamazsa hareket hiç başlamaz.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(BldSpacing.md),
        children: [
          _SummaryCard(subscription: subscription, payment: state.payment),
          const SizedBox(height: BldSpacing.md),
          _StateSection(
            subscription: subscription,
            state: state,
            l10n: l10n,
            otpKey: otpKey,
            otpController: otpController,
            onStart: onStart,
            onSubmitOtp: onSubmitOtp,
            onRefresh: onRefresh,
          ),
        ],
      ),
    );
  }
}

/// Dönem, tutar ve durum başlığı.
///
/// Tutar her zaman SUNUCUNUN rakamıdır: ödeme kaydı varsa onun tutarı, yoksa
/// dönem özetininki. İstemci porsiyon × fiyat çarpımını burada tekrarlamaz.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.subscription, required this.payment});

  final Subscription subscription;
  final SubscriptionPayment? payment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final summary = subscription.payment;

    final period = payment?.period ?? summary?.period;
    final amount = payment?.amount ?? summary?.amount;
    final status = payment?.status ?? summary?.status;
    final dueDate = summary?.dueDate;

    return BldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  period == null
                      ? l10n.subscriptionPaymentPeriod
                      : _periodLabel(period),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (status != null)
                BldPill(
                  label: paymentStatusLabel(status, l10n),
                  variant: status == PaymentStatus.paid
                      ? BldPillVariant.success
                      : BldPillVariant.info,
                ),
            ],
          ),
          const SizedBox(height: BldSpacing.md),
          Text(
            amount == null ? l10n.subscriptionNoPrice : Money.format(amount),
            style: theme.textTheme.headlineSmall,
          ),
          Text(
            l10n.subscriptionPaymentServerCalculates,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (dueDate != null) ...[
            const SizedBox(height: BldSpacing.sm),
            Text(
              l10n.subscriptionPaymentDueDate(BusinessDate.long(dueDate)),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

/// Durum makinesinin ekrandaki karşılığı.
class _StateSection extends StatelessWidget {
  const _StateSection({
    required this.subscription,
    required this.state,
    required this.l10n,
    required this.otpKey,
    required this.otpController,
    required this.onStart,
    required this.onSubmitOtp,
    required this.onRefresh,
  });

  final Subscription subscription;
  final SubscriptionPaymentState state;
  final AppLocalizations l10n;
  final GlobalKey<FormState> otpKey;
  final TextEditingController otpController;
  final Future<void> Function() onStart;
  final VoidCallback onSubmitOtp;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      SubscriptionPaymentIdle() => _idle(context),
      SubscriptionPaymentStarting() => _Waiting(
        message: l10n.subscriptionPaymentStarting,
      ),
      SubscriptionPaymentAwaitingOtp(:final error) => _OtpForm(
        formKey: otpKey,
        controller: otpController,
        error: error,
        onSubmit: onSubmitOtp,
        onRestart: onStart,
      ),
      SubscriptionPaymentVerifying() => _Waiting(
        message: l10n.subscriptionPaymentVerifying,
      ),
      SubscriptionPaymentPolling(:final attempt, :final total) => _ThreeDsPanel(
        attempt: attempt,
        total: total,
      ),
      SubscriptionPaymentSucceeded(:final payment) => _Receipt(payment: payment),
      // Değişken bağlayan biçim: `_Failure` kaydın kendisini istiyor ve alan
      // üzerinden yapılan tip denetimi gövdede yükseltme (promotion) vermez.
      final SubscriptionPaymentFailed failed => _Failure(
        state: failed,
        onRetry: onStart,
        onRefresh: onRefresh,
      ),
    };
  }

  Widget _idle(BuildContext context) {
    final summary = subscription.payment;

    // İptal edilmiş abonelikte ödeme düğmesi hiç çizilmez: sunucu `422`
    // döndürecek ve kullanıcı reddedileceği kesin bir işi yapmış olacaktı.
    if (subscription.isCancelled) {
      return _Notice(
        icon: Icons.block_outlined,
        message: l10n.subscriptionPaymentCancelled,
      );
    }

    // Fiyatı girilmemiş talebin ödenecek dönemi de yok.
    if (summary == null) {
      return _Notice(
        icon: Icons.hourglass_empty_outlined,
        message: l10n.subscriptionPaymentNotReady,
      );
    }

    if (summary.isPaid) {
      return _Notice(
        icon: Icons.check_circle_outline,
        message: l10n.subscriptionPaymentAlreadyPaid,
        tone: _NoticeTone.success,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Notice(
          icon: Icons.lock_outline,
          message: l10n.subscriptionPaymentIntro,
        ),
        const SizedBox(height: BldSpacing.md),
        FilledButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.payment_outlined),
          label: Text(l10n.subscriptionPaymentStart),
        ),
      ],
    );
  }
}

/// Sunucu yanıtı beklenirken.
class _Waiting extends StatelessWidget {
  const _Waiting({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return BldCard(
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: BldSpacing.md),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

/// SMS kodu formu.
class _OtpForm extends StatelessWidget {
  const _OtpForm({
    required this.formKey,
    required this.controller,
    required this.error,
    required this.onSubmit,
    required this.onRestart,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final ApiException? error;
  final VoidCallback onSubmit;
  final Future<void> Function() onRestart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.subscriptionPaymentOtpTitle,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: BldSpacing.sm),
                Text(
                  l10n.subscriptionPaymentOtpBody,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: BldSpacing.md),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  // Sözleşme 4-8 hane diyor; alan da onu kabul ediyor.
                  maxLength: 8,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.subscriptionPaymentOtpLabel,
                  ),
                  onFieldSubmitted: (_) => onSubmit(),
                  validator: (value) {
                    final code = (value ?? '').trim();
                    if (code.length < 4 || code.length > 8) {
                      return l10n.subscriptionPaymentOtpLength;
                    }
                    return null;
                  },
                ),
                Text(
                  l10n.subscriptionPaymentOtpAttemptWarning,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: BldSpacing.sm),
            FormErrorBox(message: apiErrorDisplayMessage(error!, l10n)),
          ],
          const SizedBox(height: BldSpacing.md),
          FilledButton(
            onPressed: onSubmit,
            child: Text(l10n.subscriptionPaymentOtpSubmit),
          ),
          const SizedBox(height: BldSpacing.sm),
          // Deneme hakkı bittiğinde tek çıkış yolu yeni bir ödeme kaydı.
          TextButton(
            onPressed: () => onRestart(),
            child: Text(l10n.subscriptionPaymentRetry),
          ),
        ],
      ),
    );
  }
}

/// `three_ds` dalı — ilan edilmiş, bu sürümde KAPALI.
///
/// Kapalılığı `throw UnimplementedError()` ile değil bir cümleyle söylüyoruz:
/// istisna kullanıcıya hiçbir şey anlatmaz ve `AGENTS.md` §2.5 onu "bitti"
/// saymaz. Ödeme kaydı sunucuda duruyor, o yüzden sonucu sınırlı bir bütçeyle
/// izliyoruz — dışarıdan sonuçlanırsa ekran onu yakalar.
class _ThreeDsPanel extends StatelessWidget {
  const _ThreeDsPanel({required this.attempt, required this.total});

  final int attempt;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bld = context.bld;

    return BldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 20, color: bld.warningFg),
              const SizedBox(width: BldSpacing.sm),
              Expanded(
                child: Text(
                  l10n.subscriptionPaymentThreeDsTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: bld.warningFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BldSpacing.sm),
          Text(
            l10n.subscriptionPaymentThreeDsBody,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: BldSpacing.md),
          Row(
            children: [
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: BldSpacing.sm),
              Expanded(
                child: Text(
                  attempt == 0
                      ? l10n.subscriptionPaymentWatching
                      : l10n.subscriptionPaymentPollProgress(attempt, total),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ödeme makbuzu — mali değeri yoktur, fatura ayrıca düzenlenir.
class _Receipt extends StatelessWidget {
  const _Receipt({required this.payment});

  final SubscriptionPayment payment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bld = context.bld;
    final paidAt = payment.paidAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BldCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 20,
                    color: bld.successFg,
                  ),
                  const SizedBox(width: BldSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.subscriptionPaymentSucceededTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: bld.successFg,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BldSpacing.sm),
              Text(
                l10n.subscriptionPaymentSucceededBody,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: BldSpacing.md),
              Divider(height: 1, color: bld.decorativeBorder),
              const SizedBox(height: BldSpacing.md),
              Text(
                l10n.subscriptionPaymentReceipt,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: BldSpacing.sm),
              _ReceiptRow(
                label: l10n.subscriptionPaymentNumber,
                value: '${payment.paymentId}',
              ),
              _ReceiptRow(
                label: l10n.subscriptionPaymentPeriod,
                value: _periodLabel(payment.period),
              ),
              _ReceiptRow(
                label: l10n.subscriptionPaymentAmount,
                value: Money.format(payment.amount),
              ),
              if (paidAt != null)
                _ReceiptRow(
                  label: l10n.subscriptionPaymentPaidAt,
                  value: TurkishTime.longDateTime(paidAt),
                ),
              const SizedBox(height: BldSpacing.sm),
              Text(
                l10n.subscriptionPaymentReceiptNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: BldSpacing.md),
        FilledButton(
          onPressed: () =>
              context.go(Routes.subscriptionDetail(payment.subscriptionId)),
          child: Text(l10n.subscriptionPaymentBack),
        ),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hata yolları. Hepsi bir CÜMLE ve en az bir çıkış yolu taşır.
class _Failure extends StatelessWidget {
  const _Failure({
    required this.state,
    required this.onRetry,
    required this.onRefresh,
  });

  final SubscriptionPaymentFailed state;
  final Future<void> Function() onRetry;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final message = switch (state.reason) {
      SubscriptionPaymentFailure.api => state.error == null
          ? l10n.errorUnknown
          : apiErrorDisplayMessage(state.error!, l10n),
      // Sağlayıcının Türkçe gerekçesi varsa o gösterilir; ham hata kodu
      // sözleşme gereği hiç gelmiyor.
      SubscriptionPaymentFailure.declined =>
        state.payment?.failureReason ?? l10n.subscriptionPaymentDeclined,
      SubscriptionPaymentFailure.unsupportedStep =>
        l10n.subscriptionPaymentUnsupportedStep,
      SubscriptionPaymentFailure.pollExhausted =>
        l10n.subscriptionPaymentPollExhausted,
      SubscriptionPaymentFailure.unsettled => l10n.subscriptionPaymentUnsettled,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormErrorBox(message: message),
        const SizedBox(height: BldSpacing.md),
        // Kayıt duruyorsa önce onu sormak gerekir: yeni bir ödeme başlatmak
        // sonuçlanmış bir tahsilatı ikinci kez denemek olabilirdi.
        if (state.payment != null)
          OutlinedButton.icon(
            onPressed: () => onRefresh(),
            icon: const Icon(Icons.refresh_outlined),
            label: Text(l10n.subscriptionPaymentRefresh),
          ),
        if (state.payment != null) const SizedBox(height: BldSpacing.sm),
        FilledButton(
          onPressed: () => onRetry(),
          child: Text(l10n.subscriptionPaymentRetry),
        ),
      ],
    );
  }
}

enum _NoticeTone { info, success }

/// Nötr bilgi kutusu — hata değil, durum.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.message,
    this.tone = _NoticeTone.info,
  });

  final IconData icon;
  final String message;
  final _NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bld = context.bld;
    final (background, foreground) = switch (tone) {
      _NoticeTone.info => (bld.infoBg, bld.infoFg),
      _NoticeTone.success => (bld.successBg, bld.successFg),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BldSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(BldRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: BldSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// `YYYY-AA` dönemini `"Ağustos 2026"` yapar.
///
/// [BusinessDate.month] gün bekliyor, dönem ise gün TAŞIMIYOR (bir ay, bir
/// tarih değil). Ayın ilk gününü ekleyip ona veriyoruz; ay adlarını burada
/// ikinci bir tabloda tutmak, Türkçe ay isimlerinin iki yerde yaşaması
/// demekti.
String _periodLabel(String period) {
  if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(period)) return period;
  return BusinessDate.month('$period-01');
}
