/// Ödeme ekranı — teslimat tipi/adres, istenen saat, ödeme yöntemi
/// (`docs/07-musteriapp.md` §2) ve `POST /api/orders`.
///
/// Üç şeyi sunucu belirler ve bu ekran onları uygular (§3):
/// - sipariş alınıyor mu → `is_open` + `ordering_enabled`
/// - hangi ödeme yöntemleri açık → `payment_methods`
/// - tutar → istemcinin gönderdiği tutar yok sayılır, sunucu hesaplar
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_error_text.dart';
import '../../core/eta_text.dart';
import '../../core/labels.dart';
import '../../core/time_input.dart';
import '../../core/validators.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/address_providers.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/infra_providers.dart';
import '../../router/app_router.dart';
import '../../widgets/eta_notice.dart';
import '../../widgets/status_views.dart';
import '../cart/cart_controller.dart';

class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locationAsync = ref.watch(locationProvider);
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkoutTitle)),
      body: locationAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(locationProvider),
        ),
        data: (snapshot) {
          if (cart.isEmpty) {
            return Center(child: Text(l10n.cartEmpty));
          }
          return _CheckoutForm(location: snapshot.location);
        },
      ),
    );
  }
}

class _CheckoutForm extends ConsumerStatefulWidget {
  const _CheckoutForm({required this.location});

  final Location location;

  @override
  ConsumerState<_CheckoutForm> createState() => _CheckoutFormState();
}

class _CheckoutFormState extends ConsumerState<_CheckoutForm> {
  final _formKey = GlobalKey<FormState>();
  final _line1 = TextEditingController();
  final _district = TextEditingController();
  final _city = TextEditingController();
  final _addressNote = TextEditingController();

  /// Seçili kayıtlı adres. `null` = elle giriş.
  int? _savedAddressId;

  /// Varsayılan adres bir kez dolduruldu mu?
  ///
  /// Bayrak olmadan, defter her yenilendiğinde kullanıcının o sipariş için
  /// elle düzelttiği kapı numarası geri silinirdi.
  bool _appliedDefaultAddress = false;
  final _customerNote = TextEditingController();

  DeliveryType _deliveryType = DeliveryType.delivery;
  PaymentMethod? _paymentMethod;
  DateTime? _requestedAtIstanbul;

  bool _submitting = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    final methods = widget.location.selectablePaymentMethods;
    if (methods.isNotEmpty) _paymentMethod = methods.first;
  }

  @override
  void dispose() {
    _line1.dispose();
    _district.dispose();
    _city.dispose();
    _addressNote.dispose();
    _customerNote.dispose();
    super.dispose();
  }

  Future<void> _pickRequestedAt() async {
    final now = istanbulNow();
    final date = await showDatePicker(
      context: context,
      initialDate: _requestedAtIstanbul ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year, now.month, now.day + 30),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_requestedAtIstanbul ?? now),
    );
    if (time == null || !mounted) return;

    setState(() {
      _requestedAtIstanbul = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  /// Kayıtlı adres seçildiğinde alanları doldurur.
  ///
  /// Alanlar salt okunur YAPILMIYOR: müşteri "Ofis" adresini seçip kapı
  /// numarasını o sipariş için değiştirebilmeli. Defterdeki kayıt bundan
  /// etkilenmez — sipariş kendi kopyasını taşır.
  void _applySavedAddress(SavedAddress? address) {
    setState(() {
      _savedAddressId = address?.id;
      if (address == null) return;
      _line1.text = address.line1;
      _district.text = address.district;
      _city.text = address.city;
      _addressNote.text = address.note ?? '';
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    final method = _paymentMethod;
    if (method == null || !method.isSelectable) {
      setState(() => _failure = l10n.checkoutPaymentMethodsEmpty);
      return;
    }

    setState(() {
      _submitting = true;
      _failure = null;
    });

    final cart = ref.read(cartProvider);
    final request = OrderCreateRequest(
      locationId: widget.location.id,
      items: [for (final line in cart.lines) line.toOrderItem()],
      deliveryType: _deliveryType,
      paymentMethod: method,
      // `pickup` ise sunucu adresi yok sayar; yine de göndermeyiz.
      address: _deliveryType.requiresAddress
          ? Address(
              line1: _line1.text.trim(),
              district: _district.text.trim(),
              city: _city.text.trim(),
              note: _addressNote.text.trim().isEmpty
                  ? null
                  : _addressNote.text.trim(),
            )
          : null,
      requestedAt: _requestedAtIstanbul == null
          ? null
          : istanbulWallClockToUtc(_requestedAtIstanbul!),
      customerNote: _customerNote.text.trim().isEmpty
          ? null
          : _customerNote.text.trim(),
    );

    try {
      final created = await ref.read(apiProvider).orders.create(request);
      ref.read(connectivityProvider.notifier).reportSuccess();
      ref.read(cartProvider.notifier).clear();
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.orderPlacedBody(created.orderNumber))),
      );
      /*
       * Online ödemede sunucu bir ödeme sayfası adresi döner. Sayfa uygulama
       * İÇİNDE bir WebView'da değil, sistem tarayıcısında açılıyor
       * (`docs/07-musteriapp.md` §2 WebView diyordu):
       *
       * - 3-D Secure akışında banka sayfası uygulama içi WebView'ları giderek
       *   daha çok reddediyor; tarayıcı hem çalışıyor hem de kullanıcı adres
       *   çubuğundaki alan adını görüp doğrulayabiliyor.
       * - `webview_flutter` web hedefini desteklemiyor; tek kod yolu kalıyor.
       *
       * Açılamazsa sipariş yine oluşmuş durumda — kullanıcıya siparişin
       * durduğu, ödemeyi sonra tamamlayabileceği söyleniyor.
       */
      final redirectUrl = created.payment.redirectUrl;
      if (created.payment.requiresRedirect && redirectUrl != null) {
        final opened = await launchUrl(
          Uri.parse(redirectUrl),
          mode: LaunchMode.externalApplication,
        ).catchError((_) => false);
        if (!opened) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.checkoutPaymentPageFailed)),
          );
        }
      }
      if (!mounted) return;
      context.go(Routes.orderTracking(created.id));
    } on ApiException catch (error) {
      ref.read(connectivityProvider.notifier).reportFailure(error);
      if (!mounted) return;
      setState(() => _failure = apiErrorDisplayMessage(error, l10n));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cart = ref.watch(cartProvider);

    // Varsayılan adres geldiğinde alanları bir kez doldur. Kullanıcı seçimi
    // değiştirirse ya da alanı düzeltirse bir daha karışılmaz.
    final defaultAddress = ref.watch(defaultAddressProvider);
    if (!_appliedDefaultAddress && defaultAddress != null) {
      _appliedDefaultAddress = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applySavedAddress(defaultAddress);
      });
    }
    final offline = ref.watch(connectivityProvider);
    final methods = widget.location.selectablePaymentMethods;

    final blockers = <String>[
      if (!widget.location.acceptsOrders) l10n.checkoutOrderingClosed,
      if (offline) l10n.offlineOrderBlocked,
      if (methods.isEmpty) l10n.checkoutPaymentMethodsEmpty,
    ];

    // Kullanıcı belirli bir saat seçtiyse tahmin gösterilmez: sipariş o saate
    // planlanır, "60-85 dakika içinde" demek yanlış olurdu. Tahmin yalnızca
    // "en kısa sürede" seçiliyken anlamlıdır.
    final eta = _requestedAtIstanbul == null
        ? widget.location.etaFor(_deliveryType)
        : null;

    return Column(
      children: [
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(BldSpacing.md),
              children: [
                _SectionTitle(l10n.checkoutDeliveryType),
                SegmentedButton<DeliveryType>(
                  segments: [
                    for (final type in DeliveryType.values)
                      ButtonSegment(
                        value: type,
                        label: Text(deliveryTypeLabel(type, l10n)),
                      ),
                  ],
                  selected: {_deliveryType},
                  onSelectionChanged: _submitting
                      ? null
                      : (selection) =>
                            setState(() => _deliveryType = selection.first),
                ),

                // Teslimat tipiyle birlikte değişir: gel-alda yol süresi yok,
                // sunucu iki ayrı aralık gönderiyor.
                if (eta != null) ...[
                  const SizedBox(height: BldSpacing.md),
                  EtaNotice(
                    eta: etaBeforeOrder(
                      eta,
                      _deliveryType,
                      l10n,
                      now: DateTime.now().toUtc(),
                    ),
                  ),
                ],

                // `pickup` seçilirse adres adımı atlanır ve teslimat ücreti
                // eklenmez (`docs/07-musteriapp.md` §3).
                if (_deliveryType.requiresAddress) ...[
                  _SectionTitle(l10n.checkoutAddressSection),
                  _SavedAddressPicker(
                    selectedId: _savedAddressId,
                    onSelected: _applySavedAddress,
                  ),
                  TextFormField(
                    controller: _line1,
                    decoration: InputDecoration(labelText: l10n.addressLine1),
                    validator: (value) => validateRequired(value, l10n),
                  ),
                  const SizedBox(height: BldSpacing.sm),
                  TextFormField(
                    controller: _district,
                    decoration: InputDecoration(
                      labelText: l10n.addressDistrict,
                    ),
                    validator: (value) => validateRequired(value, l10n),
                  ),
                  const SizedBox(height: BldSpacing.sm),
                  TextFormField(
                    controller: _city,
                    decoration: InputDecoration(labelText: l10n.addressCity),
                    validator: (value) => validateRequired(value, l10n),
                  ),
                  const SizedBox(height: BldSpacing.sm),
                  TextFormField(
                    controller: _addressNote,
                    decoration: InputDecoration(labelText: l10n.addressNote),
                  ),
                ],

                _SectionTitle(l10n.checkoutRequestedAt),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _requestedAtIstanbul == null
                            ? l10n.checkoutRequestedAtAsap
                            : TurkishTime.longDateTime(
                                istanbulWallClockToUtc(_requestedAtIstanbul!),
                              ),
                      ),
                    ),
                    if (_requestedAtIstanbul != null)
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () => setState(() => _requestedAtIstanbul = null),
                        child: Text(l10n.checkoutClearRequestedAt),
                      ),
                    OutlinedButton(
                      onPressed: _submitting ? null : _pickRequestedAt,
                      child: Text(l10n.checkoutPickDateTime),
                    ),
                  ],
                ),

                _SectionTitle(l10n.checkoutPaymentMethod),
                // Yalnızca `payment_methods` içindekiler gösterilir; listede
                // olmayan yöntemle sipariş sunucuda `422` olurdu
                // (`docs/openapi.yaml` `Location.payment_methods`).
                if (methods.isEmpty)
                  FormErrorBox(message: l10n.checkoutPaymentMethodsEmpty)
                else
                  RadioGroup<PaymentMethod>(
                    groupValue: _paymentMethod,
                    onChanged: (value) {
                      // Gönderim sürerken seçim değiştirilemez.
                      if (_submitting) return;
                      setState(() => _paymentMethod = value);
                    },
                    child: Column(
                      children: [
                        for (final method in methods)
                          RadioListTile<PaymentMethod>(
                            value: method,
                            contentPadding: EdgeInsets.zero,
                            title: Text(paymentMethodLabel(method, l10n)),
                          ),
                      ],
                    ),
                  ),

                _SectionTitle(l10n.checkoutCustomerNote),
                TextFormField(
                  controller: _customerNote,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.checkoutCustomerNote,
                  ),
                ),

                if (_failure != null) ...[
                  const SizedBox(height: BldSpacing.sm),
                  FormErrorBox(message: _failure!),
                ],
              ],
            ),
          ),
        ),
        _CheckoutFooter(
          subtotal: cart.subtotal,
          blockers: blockers,
          submitting: _submitting,
          onSubmit: blockers.isEmpty && !_submitting ? _submit : null,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: BldSpacing.lg, bottom: BldSpacing.sm),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _CheckoutFooter extends StatelessWidget {
  const _CheckoutFooter({
    required this.subtotal,
    required this.blockers,
    required this.submitting,
    required this.onSubmit,
  });

  final int subtotal;
  final List<String> blockers;
  final bool submitting;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(BldSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l10n.cartSubtotal)),
                  Text(
                    Money.format(subtotal),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              Text(
                l10n.cartServerCalculatesTotal,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              for (final blocker in blockers) ...[
                const SizedBox(height: BldSpacing.sm),
                FormErrorBox(message: blocker),
              ],
              const SizedBox(height: BldSpacing.md),
              FilledButton(
                onPressed: onSubmit,
                child: submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.checkoutSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kayıtlı adres seçici.
///
/// Defter boşsa (ya da henüz yüklenmediyse) hiç çizilmez: bir tane bile adresi
/// olmayan kullanıcıya boş bir açılır liste göstermek, elle girişin önüne
/// gereksiz bir adım koymak olurdu.
class _SavedAddressPicker extends ConsumerWidget {
  const _SavedAddressPicker({required this.selectedId, required this.onSelected});

  final int? selectedId;
  final ValueChanged<SavedAddress?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final addresses = ref.watch(addressBookProvider).valueOrNull;
    if (addresses == null || addresses.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: BldSpacing.sm),
      child: DropdownButtonFormField<int?>(
        initialValue: selectedId,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.checkoutSavedAddress),
        items: [
          DropdownMenuItem<int?>(
            value: null,
            child: Text(l10n.checkoutNewAddress),
          ),
          for (final address in addresses)
            DropdownMenuItem<int?>(
              value: address.id,
              child: Text(
                address.label == null
                    ? address.summary
                    : '${address.label} — ${address.summary}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (id) => onSelected(
          id == null
              ? null
              : addresses.firstWhere((address) => address.id == id),
        ),
      ),
    );
  }
}
