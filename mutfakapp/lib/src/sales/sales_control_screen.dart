/// Satış kontrolü — sipariş almayı durdurma ve "bugün tükendi" (K-11).
///
/// NEDEN BU EKRAN VAR: sahada yazıcı bozulduğunda, malzeme bittiğinde ya da
/// ekip yetişemediğinde mutfak sipariş almaya devam ediyor, gelenleri tek
/// tek telefonla iptal ediyordu. Müşteri için "siparişim alındı, sonra
/// arandı ve iptal edildi", kapalı bir dükkândan çok daha kötü.
///
/// NEDEN TEK TUŞ DEĞİL: bu şalter ciroyu kesiyor. `docs/03` §3 eskiden
/// "mutfak personeli tek tuşla cirosu kapatabilmemeli" diyordu; kural
/// kaldırılmadı, **korumaya dönüştürüldü**. Kapatma yolu dört adım:
///
///   1. süre seçimi (varsayılan yol süreli — "kapattım, açmayı unuttum"
///      en olası hata ve süre onu kendiliğinden çözüyor),
///   2. sebep seçimi (müşteriye gösteriliyor),
///   3. kasanın açılış şifresi,
///   4. son onay.
///
/// Açmak da şifre istiyor: yanlışlıkla açılan bir dükkân, yanlışlıkla
/// kapanan kadar zararlı (mutfak hazır değilken sipariş akmaya başlar).
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../data/sales_control.dart';
import '../input/keyboard_text_field.dart';
import '../input/onscreen_keyboard.dart';
import '../l10n/app_localizations.dart';
import '../lock/unlock_password.dart';

class SalesControlScreen extends ConsumerWidget {
  const SalesControlScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const SalesControlScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(KdsColors.surface),
        title: Text(
          l10n.salesTitle,
          style: const TextStyle(
            fontSize: KdsTextScale.columnHeader,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          tooltip: l10n.settingsBack,
          iconSize: 32,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(BldSpacing.lg),
          children: const [
            _OrderingCard(),
            SizedBox(height: BldSpacing.lg),
            _ProductList(),
          ],
        ),
      ),
    );
  }
}

/// Şalterin durumu ve tek büyük düğme.
class _OrderingCard extends ConsumerWidget {
  const _OrderingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final state = ref.watch(orderingStateProvider);

    return Material(
      color: const Color(KdsColors.surface),
      borderRadius: BorderRadius.circular(BldRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(BldSpacing.lg),
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text(
            l10n.salesFailed(error is ApiException ? error.message : '$error'),
            style: const TextStyle(
              fontSize: KdsTextScale.statusBar,
              color: Color(BldColors.danger),
            ),
          ),
          data: (ordering) => _OrderingBody(ordering: ordering),
        ),
      ),
    );
  }
}

class _OrderingBody extends ConsumerWidget {
  const _OrderingBody({required this.ordering});

  final OrderingState ordering;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final open = ordering.enabled;
    final color = Color(open ? BldColors.success : BldColors.danger);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              open ? Icons.storefront : Icons.do_not_disturb_on,
              size: 44,
              color: color,
            ),
            const SizedBox(width: BldSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    open ? l10n.salesOpenTitle : l10n.salesClosedTitle,
                    style: TextStyle(
                      fontSize: KdsTextScale.columnHeader,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    open ? l10n.salesOpenBody : _closedDetail(context, ordering),
                    style: const TextStyle(fontSize: KdsTextScale.statusBar),
                  ),
                  if (!open && ordering.reason != null)
                    Text(
                      ordering.reason!,
                      style: const TextStyle(
                        fontSize: KdsTextScale.orderNumber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: BldSpacing.lg),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Color(open ? BldColors.danger : BldColors.success),
            foregroundColor: const Color(BldColors.neutral900),
            minimumSize: const Size.fromHeight(76),
          ),
          onPressed: () => unawaited(
            open ? _stop(context, ref) : _resume(context, ref),
          ),
          child: Text(open ? l10n.salesStop : l10n.salesResume),
        ),
      ],
    );
  }

  String _closedDetail(BuildContext context, OrderingState ordering) {
    final l10n = AppL10n.of(context);
    final until = ordering.resumesAt;
    if (until == null) return l10n.salesClosedIndefinite;

    final left = ordering.remaining(DateTime.now().toUtc()) ?? Duration.zero;
    final local = until.toLocal();

    return l10n.salesClosedUntil(
      '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}',
      left.inHours > 0
          ? l10n.salesRemainingHours(left.inHours, left.inMinutes % 60)
          : l10n.salesRemainingMinutes(left.inMinutes),
    );
  }

  /// Durdurma akışı: süre → sebep → şifre.
  Future<void> _stop(BuildContext context, WidgetRef ref) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final duration = await _pickDuration(context);
    if (duration == null || !context.mounted) return;

    final reason = await _pickReason(context);
    if (reason == null || !context.mounted) return;

    if (!await _askPassword(context)) return;

    await _apply(
      ref,
      messenger,
      l10n,
      enabled: false,
      reason: reason,
      minutes: duration.minutes,
      success: l10n.salesStopped,
    );
  }

  /// Açma akışı: yalnız şifre.
  ///
  /// Sebep ve süre sorulmuyor: açmak geri döndürülebilir bir işlem ve
  /// mutfağın hazır olduğu anda gecikmemeli.
  Future<void> _resume(BuildContext context, WidgetRef ref) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!await _askPassword(context)) return;

    await _apply(
      ref,
      messenger,
      l10n,
      enabled: true,
      success: l10n.salesResumed,
    );
  }

  Future<void> _apply(
    WidgetRef ref,
    ScaffoldMessengerState messenger,
    AppL10n l10n, {
    required bool enabled,
    required String success,
    String? reason,
    int? minutes,
  }) async {
    try {
      await ref
          .read(salesControlApiProvider)
          .setOrdering(enabled: enabled, reason: reason, minutes: minutes);

      // Şerit ve ekran aynı sağlayıcıdan besleniyor; tazelemek ikisini
      // birden günceller.
      ref.invalidate(orderingStateProvider);

      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(BldColors.success),
          content: Text(
            success,
            style: const TextStyle(
              fontSize: KdsTextScale.statusBar,
              color: Color(BldColors.neutral900),
            ),
          ),
        ),
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(BldColors.danger),
          content: Text(
            l10n.salesFailed(
              error is ApiException ? error.message : '$error',
            ),
            style: const TextStyle(fontSize: KdsTextScale.statusBar),
          ),
        ),
      );
    }
  }
}

Future<OrderingPauseDuration?> _pickDuration(BuildContext context) {
  final l10n = AppL10n.of(context);

  return showDialog<OrderingPauseDuration>(
    context: context,
    builder: (context) => SimpleDialog(
      backgroundColor: const Color(KdsColors.surface),
      title: Text(l10n.salesDurationTitle),
      children: [
        for (final option in OrderingPauseDuration.values)
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(
              horizontal: BldSpacing.lg,
              vertical: BldSpacing.md,
            ),
            onPressed: () => Navigator.of(context).pop(option),
            child: Text(
              option.label,
              style: const TextStyle(fontSize: KdsTextScale.orderNumber),
            ),
          ),
      ],
    ),
  );
}

Future<String?> _pickReason(BuildContext context) async {
  final l10n = AppL10n.of(context);

  final options = <String>[
    l10n.salesReasonBusy,
    l10n.salesReasonFault,
    l10n.salesReasonStock,
  ];

  final selected = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      backgroundColor: const Color(KdsColors.surface),
      title: Text(l10n.salesReasonTitle),
      children: [
        for (final option in [...options, l10n.salesReasonOther])
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(
              horizontal: BldSpacing.lg,
              vertical: BldSpacing.md,
            ),
            onPressed: () => Navigator.of(context).pop(option),
            child: Text(
              option,
              style: const TextStyle(fontSize: KdsTextScale.orderNumber),
            ),
          ),
      ],
    ),
  );

  if (selected == null) return null;
  if (selected != l10n.salesReasonOther) return selected;
  if (!context.mounted) return null;

  return _promptReasonText(context);
}

/// "Diğer" seçilince serbest metin — ekran klavyesiyle.
Future<String?> _promptReasonText(BuildContext context) async {
  final text = await showDialog<String>(
    context: context,
    builder: (context) => const _KeyboardPrompt(obscure: false),
  );

  final trimmed = text?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// Kasanın açılış şifresini sorar.
///
/// AYRI BİR ŞİFRE YOK — `unlock_password.dart` içindeki mevcut doğrulayıcı
/// yeniden kullanılıyor. İkinci bir şifre, iki şifrenin de duvara
/// yazılmasıyla sonuçlanırdı (`docs/05` §7.5'teki PIN kararının aynısı).
Future<bool> _askPassword(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => const _KeyboardPrompt(obscure: true),
  );

  return ok == true;
}

/// Ekran klavyeli metin/şifre penceresi.
///
/// NEDEN AYRI BİR `StatefulWidget`: denetleyiciyi pencerenin KENDİSİ
/// sahipleniyor. `showDialog` döndükten hemen sonra elden çıkarmak,
/// pencere kapanma animasyonu sürerken denetleyiciye erişilmesine ve
/// "TextEditingController was used after being disposed" hatasına yol
/// açıyordu — testte yakalandı, kasada da olurdu.
///
/// İÇERİK KAYDIRILABİLİR: ekran klavyesi ~330 px yer kaplıyor ve 1080 px
/// yükseklikteki kasa ekranında pencere taşıyordu.
class _KeyboardPrompt extends StatefulWidget {
  const _KeyboardPrompt({required this.obscure});

  /// `true` ise şifre sorulur ve doğrulanır; `false` ise düz metin döner.
  final bool obscure;

  @override
  State<_KeyboardPrompt> createState() => _KeyboardPromptState();
}

class _KeyboardPromptState extends State<_KeyboardPrompt> {
  final TextEditingController _controller = TextEditingController();
  bool _wrong = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!widget.obscure) {
      Navigator.of(context).pop(_controller.text);
      return;
    }

    if (unlockPasswordMatches(_controller.text)) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() => _wrong = true);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AlertDialog(
      backgroundColor: const Color(KdsColors.surface),
      title: Text(
        widget.obscure ? l10n.salesPasswordTitle : l10n.salesReasonTitle,
      ),
      content: SizedBox(
        width: 900,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.obscure) ...[
                Text(
                  l10n.salesPasswordHint,
                  style: const TextStyle(fontSize: KdsTextScale.statusBar),
                ),
                const SizedBox(height: BldSpacing.md),
              ],
              TextField(
                controller: _controller,
                autofocus: true,
                obscureText: widget.obscure,
                maxLength: widget.obscure ? null : 160,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(fontSize: KdsTextScale.orderNumber),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  errorText: _wrong ? l10n.salesPasswordWrong : null,
                ),
              ),
              const SizedBox(height: BldSpacing.md),
              OnscreenKeyboard(controller: _controller, onSubmit: _submit),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(widget.obscure ? false : null),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
          onPressed: _submit,
          child: Text(widget.obscure ? l10n.unlockAction : l10n.save),
        ),
      ],
    );
  }
}

/// Ürün listesi ve "bugün tükendi" anahtarları.
class _ProductList extends ConsumerStatefulWidget {
  const _ProductList();

  @override
  ConsumerState<_ProductList> createState() => _ProductListState();
}

class _ProductListState extends ConsumerState<_ProductList> {
  final TextEditingController _search = TextEditingController();
  final Set<int> _busy = <int>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final items = ref.watch(kitchenMenuProvider);

    return Material(
      color: const Color(KdsColors.surface),
      borderRadius: BorderRadius.circular(BldRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(BldSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.salesProducts,
              style: const TextStyle(
                fontSize: KdsTextScale.columnHeader,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: BldSpacing.md),
            KeyboardTextField(
              controller: _search,
              touchMode: ref.watch(
                kdsSettingsProvider.select((settings) => settings.touchMode),
              ),
              isDense: true,
              label: l10n.salesProductSearch,
              prefixIcon: Icons.search,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: BldSpacing.md),
            items.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(BldSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text(
                l10n.salesFailed(
                  error is ApiException ? error.message : '$error',
                ),
                style: const TextStyle(
                  fontSize: KdsTextScale.statusBar,
                  color: Color(BldColors.danger),
                ),
              ),
              data: _list,
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<KitchenMenuItem> all) {
    final l10n = AppL10n.of(context);
    final query = _search.text.trim().toLowerCase();

    final filtered = query.isEmpty
        ? all
        : all.where((item) => item.name.toLowerCase().contains(query)).toList();

    if (filtered.isEmpty) {
      return Text(
        l10n.salesProductsEmpty,
        style: const TextStyle(
          fontSize: KdsTextScale.statusBar,
          color: Color(KdsColors.onSurfaceMuted),
        ),
      );
    }

    // TÜKENENLER ÜSTTE: mutfağın bakmak istediği liste "neyi kapattım"dır,
    // tüm menü değil. Alfabetik sıra ikincil.
    final sorted = [...filtered]
      ..sort((a, b) {
        if (a.soldOut != b.soldOut) return a.soldOut ? -1 : 1;
        return a.name.compareTo(b.name);
      });

    return Column(
      children: [
        for (final item in sorted)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: item.soldOut,
            // Yöneticinin kapattığı ürün burada değiştirilemez: mutfak
            // "açtım ama görünmüyor" durumuna düşmemeli.
            onChanged: !item.listed || _busy.contains(item.menuId)
                ? null
                : (value) => unawaited(_toggle(item, value)),
            title: Text(
              item.name,
              style: TextStyle(
                fontSize: KdsTextScale.orderNumber,
                decoration: item.listed ? null : TextDecoration.lineThrough,
                color: item.listed ? null : const Color(KdsColors.onSurfaceMuted),
              ),
            ),
            subtitle: Text(
              item.listed
                  ? (item.soldOutReason ?? l10n.salesSoldOut)
                  : l10n.salesNotListed,
              style: const TextStyle(
                fontSize: KdsTextScale.statusBar,
                color: Color(KdsColors.onSurfaceMuted),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _toggle(KitchenMenuItem item, bool soldOut) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy.add(item.menuId));
    try {
      await ref
          .read(salesControlApiProvider)
          .setMenuAvailability(menuId: item.menuId, soldOut: soldOut);
      ref.invalidate(kitchenMenuProvider);
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(BldColors.danger),
          content: Text(
            l10n.salesFailed(
              error is ApiException ? error.message : '$error',
            ),
            style: const TextStyle(fontSize: KdsTextScale.statusBar),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(item.menuId));
    }
  }
}
