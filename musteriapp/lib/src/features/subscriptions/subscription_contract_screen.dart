/// Abonelik sözleşmesi onay ekranı — imzalı bağlantının uygulamadaki yüzü.
///
/// ## Neden uygulamada da var?
///
/// Onay bağlantısı SMS ile gidiyor ve **uygulama kurmamış** birine de
/// çalışmak zorunda; o yüzden kanonik iniş yeri web
/// (`website/app/sozlesme/[token]`). Ama uygulamayı kullanan abone kendi
/// sözleşmesini onaylamak için tarayıcıya atılmamalı — abonelik detayından
/// buraya geliyor. İki yüzey de aynı uç çiftini kullanıyor.
///
/// ## Oturum İSTEMEZ
///
/// Uçlar kimlik gerektirmiyor: onaylayan kişi çoğu zaman uygulamada oturum
/// açmış kişi değil, satın almayı onaylayan yetkilidir. Yetki adresteki imzalı
/// belirteçte, ikinci etken SMS kodunda.
///
/// ## Metin neden düz basılıyor?
///
/// Sunucu HTML göndermiyor (`body_format: markdown | plain`) ve uygulamaya
/// HTML/Markdown işleyici KURULMADI: tek ekran için ağır bir bağımlılık ve
/// `AGENTS.md` §2.4 yeni bağımlılık için önce sormayı istiyor. Metin düz
/// okunduğunda da eksiksiz; kaybolan tek şey kalın yazı.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error_text.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/infra_providers.dart';
import '../../widgets/bld_card.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/money_text.dart';
import '../../widgets/otp_field.dart';
import '../../widgets/pill.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_views.dart';
import 'subscriptions_screen.dart';

/// Belirtece göre sözleşme.
///
/// `subscription_providers.dart`'a KONMADI: oradaki sağlayıcılar müşteri
/// oturumuna bağlı (`sessionProvider`), bu uç ise kimlik istemiyor. Aynı
/// dosyada durmaları, birinin oturum kapanınca ötekini de düşürmesi riskini
/// getirirdi.
final contractProvider = FutureProvider.autoDispose
    .family<SubscriptionContract, String>((ref, token) {
      return ref.watch(apiProvider).contracts.get(token);
    });

class SubscriptionContractScreen extends ConsumerStatefulWidget {
  const SubscriptionContractScreen({super.key, required this.token});

  /// İmzalı bağlantının belirteci. Kayıt kimliği taşımaz.
  final String token;

  @override
  ConsumerState<SubscriptionContractScreen> createState() =>
      _SubscriptionContractScreenState();
}

class _SubscriptionContractScreenState
    extends ConsumerState<SubscriptionContractScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  /// Kod bir kez istendi mi? Kutu bundan sonra AÇIK KALIR — yanlış kod
  /// girildiğinde birinci adıma dönseydi, kullanıcı elindeki SMS'i girecek
  /// yeri kaybederdi.
  bool _codeRequested = false;
  bool _busy = false;
  String? _failure;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  ContractService get _contracts => ref.read(apiProvider).contracts;

  Future<void> _requestCode() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _failure = null;
    });

    try {
      await _contracts.requestOtp(widget.token);
      if (!mounted) return;
      setState(() => _codeRequested = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.contractCodeSent)));
    } on ApiException catch (error) {
      if (!mounted) return;
      // Oran sınırına takılan istek kutuyu KAPATMAZ: kullanıcının elinde
      // çoktan gelmiş bir kod olabilir ve tek yapması gereken onu girmek.
      setState(() => _failure = apiErrorDisplayMessage(error, l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _failure = null;
    });

    try {
      await _contracts.approve(widget.token, _code.text.trim());
      if (!mounted) return;
      // Ekran sunucudan yeniden okunuyor: onay sonrası durum rozeti,
      // "onaylandı" bilgisi ve onay anı tazelensin. Yerel bir bayrakla
      // çizilseydi, sunucunun kaydettiği anı gösteremezdik.
      ref.invalidate(contractProvider(widget.token));
      _code.clear();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _failure = apiErrorDisplayMessage(error, l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(contractProvider(widget.token));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.contractTitle)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (error, _) => _ContractError(
          error: error,
          onRetry: () => ref.invalidate(contractProvider(widget.token)),
        ),
        data: (contract) => Form(
          key: _formKey,
          child: _Body(
            contract: contract,
            codeController: _code,
            codeRequested: _codeRequested,
            busy: _busy,
            failure: _failure,
            onRequestCode: _requestCode,
            onApprove: _approve,
          ),
        ),
      ),
    );
  }
}

/// Hata ekranı.
///
/// `404` (belirteç tanınmadı) SÜRESİ DOLMUŞ BAĞLANTIDAN AYRIDIR: o `200` +
/// `status: expired` ile geliyor ve gövdede kendi cümlesini kuruyor. İkisi
/// aynı ekrana indirgenseydi, süresi dolan bağlantıyı elinde tutan kişiye
/// "böyle bir sözleşme yok" denirdi.
class _ContractError extends StatelessWidget {
  const _ContractError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notFound =
        error is ApiException &&
        (error as ApiException).code == ApiErrorCode.notFound;

    if (!notFound) return ErrorView(error: error, onRetry: onRetry);

    return EmptyView(
      tone: BldStatusTone.error,
      icon: Icons.link_off_outlined,
      title: l10n.contractNotFoundTitle,
      message: l10n.contractNotFoundBody,
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.contract,
    required this.codeController,
    required this.codeRequested,
    required this.busy,
    required this.failure,
    required this.onRequestCode,
    required this.onApprove,
  });

  final SubscriptionContract contract;
  final TextEditingController codeController;
  final bool codeRequested;
  final bool busy;
  final String? failure;
  final VoidCallback onRequestCode;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final (statusLabel, statusVariant) = _statusPresentation(
      contract.status,
      l10n,
    );
    final notice = _notice(contract, l10n);

    return ListView(
      padding: const EdgeInsets.all(BldSpacing.md),
      children: [
        BldCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  BldPill(label: statusLabel, variant: statusVariant),
                  const Spacer(),
                  Text(
                    l10n.contractVersion(contract.version),
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BldSpacing.md),
              Text(
                contract.title ?? l10n.contractTitle,
                style: textTheme.titleLarge,
              ),
              if (contract.customerLabel != null) ...[
                const SizedBox(height: BldSpacing.xs),
                Text(
                  contract.customerLabel!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),

        if (notice != null) ...[
          const SizedBox(height: BldSpacing.md),
          _NoticeCard(notice: notice),
        ],

        const SizedBox(height: BldSpacing.md),

        /*
         * FİYAT METNİN ÜSTÜNDE ve en büyük tutar. Onaylayan kişi neyi
         * imzaladığını sayfalarca metnin arasından çıkarmak zorunda kalmamalı;
         * aylık tahmin de porsiyon fiyatından zihninde çarparak değil, yazılı
         * bir rakamla görünüyor.
         */
        BldCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.subscriptionAgreedPrice,
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: BldSpacing.xs),
              MoneyText(contract.unitPrice, scale: MoneyScale.xl),
              const SizedBox(height: BldSpacing.md),
              if (contract.monthlyEstimate != null)
                _InfoRow(
                  icon: Icons.calendar_month_outlined,
                  label: l10n.contractMonthlyEstimate,
                  value: Money.format(contract.monthlyEstimate!),
                ),
              if (contract.defaultQuantity != null)
                _InfoRow(
                  icon: Icons.restaurant_outlined,
                  label: l10n.contractQuantity,
                  value: '${contract.defaultQuantity}',
                ),
              _InfoRow(
                icon: Icons.date_range_outlined,
                label: l10n.subscriptionPeriod,
                value: _period(contract, l10n),
              ),
            ],
          ),
        ),

        if (contract.serviceDays.isNotEmpty) ...[
          SectionHeader(
            title: l10n.subscriptionDays,
            padding: const EdgeInsets.only(
              left: BldSpacing.xs,
              top: BldSpacing.md,
              bottom: BldSpacing.sm,
            ),
          ),
          Wrap(
            spacing: BldSpacing.sm,
            runSpacing: BldSpacing.sm,
            children: [
              for (final day in contract.serviceDays)
                BldPill(
                  label: subscriptionDayLabel(day, l10n),
                  variant: BldPillVariant.brand,
                ),
            ],
          ),
        ],

        SectionHeader(
          title: l10n.contractBodyTitle,
          padding: const EdgeInsets.only(
            left: BldSpacing.xs,
            top: BldSpacing.md,
            bottom: BldSpacing.sm,
          ),
        ),
        BldCard(child: _ContractText(body: contract.body)),

        if (contract.canApprove) ...[
          SectionHeader(
            title: l10n.contractApproveTitle,
            padding: const EdgeInsets.only(
              left: BldSpacing.xs,
              top: BldSpacing.lg,
              bottom: BldSpacing.sm,
            ),
          ),
          _ApprovalCard(
            contract: contract,
            codeController: codeController,
            codeRequested: codeRequested,
            busy: busy,
            failure: failure,
            onRequestCode: onRequestCode,
            onApprove: onApprove,
          ),
        ],

        const SizedBox(height: BldSpacing.xl),
      ],
    );
  }

  String _period(SubscriptionContract contract, AppLocalizations l10n) {
    final start = contract.startDate;
    if (start == null) return l10n.subscriptionOpenEnded;
    final end = contract.endDate;
    final endText = end == null
        ? l10n.subscriptionOpenEnded
        : BusinessDate.long(end);
    return '${BusinessDate.long(start)} → $endText';
  }
}

/// Onay kutusu: kod iste → altı hane → onayla.
class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.contract,
    required this.codeController,
    required this.codeRequested,
    required this.busy,
    required this.failure,
    required this.onRequestCode,
    required this.onApprove,
  });

  final SubscriptionContract contract;
  final TextEditingController codeController;
  final bool codeRequested;
  final bool busy;
  final String? failure;
  final VoidCallback onRequestCode;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final phone = contract.maskedPhone;

    return BldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          /*
           * NUMARA SORULMUYOR ve sorulmamalı: kod, sözleşmenin kayıtlı
           * numarasına gidiyor. İstemciden alınsaydı, bağlantıyı eline
           * geçiren biri kodu kendi telefonuna ısmarlayıp sözleşmeyi
           * onaylayabilirdi — imzalı bağlantı tek başına kimlik değildir.
           */
          Text(
            phone == null
                ? l10n.contractCodeToRegisteredPhone
                : l10n.contractCodeToPhone(phone),
            style: textTheme.bodyMedium,
          ),
          if (contract.expiresAt != null) ...[
            const SizedBox(height: BldSpacing.xs),
            Text(
              l10n.contractExpiresAt(
                TurkishTime.dateTime(contract.expiresAt!.toUtc()),
              ),
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (codeRequested) ...[
            const SizedBox(height: BldSpacing.md),
            OtpField(
              controller: codeController,
              enabled: !busy,
              autofocus: true,
              onSubmitted: (_) => busy ? null : onApprove(),
            ),
            const SizedBox(height: BldSpacing.sm),
            // Onayın geri alınamaz olduğu DÜĞMEDEN ÖNCE yazılıyor; onay
            // sonrası söylenseydi kullanıcı bunu iş bittikten sonra öğrenirdi.
            Text(
              l10n.contractIrreversible,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (failure != null) ...[
            const SizedBox(height: BldSpacing.md),
            FormErrorBox(message: failure!),
          ],
          const SizedBox(height: BldSpacing.md),
          if (!codeRequested)
            FilledButton(
              onPressed: busy ? null : onRequestCode,
              child: busy
                  ? const _ButtonSpinner()
                  : Text(l10n.contractSendCode),
            )
          else ...[
            FilledButton(
              onPressed: busy ? null : onApprove,
              child: busy ? const _ButtonSpinner() : Text(l10n.contractApprove),
            ),
            const SizedBox(height: BldSpacing.xs),
            /*
             * Geri sayım YOK ve bu bilinçli: sunucunun verdiği `resend_after`
             * istemci modelinde taşınmıyor (`ContractService.requestOtp`
             * `void` döner). Sabit bir saniye yazmak, sunucudaki bekleme
             * değiştiğinde ekranın yalan söylemesi olurdu. Erken denenen
             * istek sunucudan oran sınırı hatasıyla dönüyor ve kullanıcı
             * gerçek sebebi okuyor.
             */
            TextButton(
              onPressed: busy ? null : onRequestCode,
              child: Text(l10n.contractResend),
            ),
          ],
        ],
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

/// Sözleşme metni — boş satırla ayrılan bloklar paragraf.
///
/// Blok İÇİNDEKİ satır sonları korunuyor: madde listeleri ancak böyle ayakta
/// kalıyor.
class _ContractText extends StatelessWidget {
  const _ContractText({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final blocks = body
        .split(RegExp(r'\n{2,}'))
        .where((block) => block.trim().isNotEmpty)
        .toList();

    if (blocks.isEmpty) {
      return Text(
        l10n.contractEmptyBody,
        style: textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: BldSpacing.md),
          Text(blocks[i], style: textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice});

  final _Notice notice;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return BldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                notice.icon,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: BldSpacing.sm),
              Expanded(child: Text(notice.title, style: textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: BldSpacing.xs),
          Text(
            notice.body,
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
class _Notice {
  const _Notice({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}

/// Onaya kapalı durumların açıklaması.
///
/// `expired` ile `cancelled` AYRI cümleler kuruyor: birinde abonenin yapacağı
/// iş yeni bağlantı istemek, öbüründe yapacak bir şey yok. Tek metne
/// indirgenselerdi ikisine de aynı çözüm önerilirdi.
_Notice? _notice(SubscriptionContract contract, AppLocalizations l10n) {
  if (contract.isApproved) {
    final approvedAt = contract.approvedAt;
    return _Notice(
      icon: Icons.verified_outlined,
      title: l10n.contractApprovedTitle,
      body: approvedAt == null
          ? l10n.contractApprovedBody
          : l10n.contractApprovedAt(TurkishTime.dateTime(approvedAt.toUtc())),
    );
  }
  if (contract.isExpired) {
    return _Notice(
      icon: Icons.schedule_outlined,
      title: l10n.contractExpiredTitle,
      body: l10n.contractExpiredBody,
    );
  }
  if (contract.isCancelled) {
    return _Notice(
      icon: Icons.block_outlined,
      title: l10n.contractCancelledTitle,
      body: l10n.contractCancelledBody,
    );
  }
  return null;
}

/// Sözleşme durumunun etiketi + rozet rengi.
///
/// Bilinmeyen durum ham değeriyle ve nötr renkle çiziliyor: sözleşmeye
/// eklenecek bir durumu "onaylandı" gibi göstermektense okunmaz göstermek
/// yeğdir.
(String, BldPillVariant) _statusPresentation(
  String status,
  AppLocalizations l10n,
) {
  return switch (status) {
    'draft' || 'sent' => (l10n.contractStatusAwaiting, BldPillVariant.warning),
    'approved' => (l10n.contractStatusApproved, BldPillVariant.success),
    'expired' => (l10n.contractStatusExpired, BldPillVariant.neutral),
    'cancelled' => (l10n.contractStatusCancelled, BldPillVariant.neutral),
    _ => (status, BldPillVariant.neutral),
  };
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BldSpacing.sm - 2),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: BldSpacing.md),
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
