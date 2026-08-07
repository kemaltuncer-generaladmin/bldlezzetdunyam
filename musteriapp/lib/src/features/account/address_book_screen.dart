/// Adres defteri — `docs/07-musteriapp.md` §2 "Hesabım: profil, adresler".
///
/// Defterdeki kayıt siparişe **kopyalanır**, bağlanmaz. Bu yüzden adres silmek
/// veya düzeltmek geçmiş siparişleri değiştirmez ve silme onayında bunu açıkça
/// yazıyoruz — kullanıcı "geçmişim bozulur mu?" diye tereddüt etmesin.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_error_text.dart';
import '../../core/validators.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/address_providers.dart';
import '../../widgets/status_views.dart';
import '../location/pin_field.dart';

class AddressBookScreen extends ConsumerWidget {
  const AddressBookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final booked = ref.watch(addressBookProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addressBookTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(l10n.addressBookAdd),
      ),
      body: booked.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.read(addressBookProvider.notifier).refresh(),
        ),
        data: (addresses) {
          if (addresses.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(BldSpacing.lg),
              child: Center(
                child: Text(
                  l10n.addressBookEmpty,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }

          return ListView.separated(
            // Kayan listenin son kaydı yüzen düğmenin altında kalmasın.
            padding: const EdgeInsets.fromLTRB(
              BldSpacing.md,
              BldSpacing.md,
              BldSpacing.md,
              96,
            ),
            itemCount: addresses.length,
            separatorBuilder: (_, _) => const SizedBox(height: BldSpacing.sm),
            itemBuilder: (context, index) => _AddressTile(
              address: addresses[index],
              onEdit: () => _openForm(context, ref, existing: addresses[index]),
              onDelete: () => _confirmDelete(context, ref, addresses[index]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    SavedAddress? existing,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddressForm(existing: existing),
  );

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SavedAddress address,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(address.label ?? address.line1),
        content: Text(l10n.addressBookDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.addressBookDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(addressBookProvider.notifier).remove(address.id);
    } on ApiException catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(apiErrorDisplayMessage(error, l10n))),
      );
    }
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.address,
    required this.onEdit,
    required this.onDelete,
  });

  final SavedAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(BldSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    address.label ?? address.line1,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (address.isDefault)
                  Chip(
                    label: Text(l10n.addressBookDefault),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: BldSpacing.xs),
            Text(address.summary, style: theme.textTheme.bodyMedium),
            if (address.note != null && address.note!.isNotEmpty) ...[
              const SizedBox(height: BldSpacing.xs),
              Text(address.note!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: BldSpacing.sm),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(l10n.addressBookEdit),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(l10n.addressBookDelete),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Ekleme ve düzenleme aynı form: alanlar birebir aynı, yalnızca başlık ve
/// gönderilecek istek değişiyor. İki ayrı ekran yazmak aynı doğrulamayı iki
/// yerde tutmak olurdu.
class _AddressForm extends ConsumerStatefulWidget {
  const _AddressForm({this.existing});

  final SavedAddress? existing;

  @override
  ConsumerState<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends ConsumerState<_AddressForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _line1;
  late final TextEditingController _district;
  late final TextEditingController _city;
  late final TextEditingController _note;
  late bool _isDefault;

  /// Haritadan seçilen nokta. `null` = iğne yok.
  LatLng? _pin;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _label = TextEditingController(text: existing?.label ?? '');
    _line1 = TextEditingController(text: existing?.line1 ?? '');
    _district = TextEditingController(text: existing?.district ?? '');
    _city = TextEditingController(text: existing?.city ?? '');
    _note = TextEditingController(text: existing?.note ?? '');
    // İlk adres sunucuda zaten varsayılan olur; kutuyu işaretli göstermek
    // kullanıcıya olmayan bir seçim yaptığını düşündürürdü.
    _isDefault = existing?.isDefault ?? false;
    _pin = existing != null && existing.hasPin
        ? LatLng(existing.latitude!, existing.longitude!)
        : null;
  }

  @override
  void dispose() {
    _label.dispose();
    _line1.dispose();
    _district.dispose();
    _city.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _emptyOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final input = SavedAddressInput(
      label: _emptyOrNull(_label),
      line1: _line1.text.trim(),
      district: _district.text.trim(),
      city: _city.text.trim(),
      note: _emptyOrNull(_note),
      isDefault: _isDefault,

      // İğne yokken bilerek `null` gönderiliyor ve bu, sunucuda "koordinatı
      // sil" demek (`SavedAddressInput` belgesine bakın). Alanı atlamak
      // "değiştirme" anlamına gelirdi ve iğnesini kaldıran müşterinin eski
      // noktası kayıtta kalırdı.
      latitude: _pin?.latitude,
      longitude: _pin?.longitude,
    );

    final notifier = ref.read(addressBookProvider.notifier);
    try {
      final existing = widget.existing;
      if (existing == null) {
        await notifier.create(input);
      } else {
        await notifier.edit(existing.id, input);
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = apiErrorDisplayMessage(error, AppLocalizations.of(context));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      // Klavye açıldığında form alanları klavyenin altında kalmasın.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(BldSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null
                    ? l10n.addressNewTitle
                    : l10n.addressEditTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: BldSpacing.md),
              TextFormField(
                controller: _label,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.addressLabel),
              ),
              const SizedBox(height: BldSpacing.sm),
              TextFormField(
                controller: _line1,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.addressLine1),
                validator: (value) => validateRequired(value, l10n),
              ),
              const SizedBox(height: BldSpacing.sm),
              TextFormField(
                controller: _district,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.addressDistrict),
                validator: (value) => validateRequired(value, l10n),
              ),
              const SizedBox(height: BldSpacing.sm),
              TextFormField(
                controller: _city,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.addressCity),
                validator: (value) => validateRequired(value, l10n),
              ),
              const SizedBox(height: BldSpacing.sm),
              TextFormField(
                controller: _note,
                decoration: InputDecoration(labelText: l10n.addressNote),
              ),
              const SizedBox(height: BldSpacing.sm),
              PinField(
                point: _pin,
                onChanged: (value) => setState(() => _pin = value),
              ),
              const SizedBox(height: BldSpacing.sm),
              CheckboxListTile(
                value: _isDefault,
                onChanged: (value) =>
                    setState(() => _isDefault = value ?? false),
                title: Text(l10n.addressBookMakeDefault),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_error != null) ...[
                const SizedBox(height: BldSpacing.sm),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: BldSpacing.md),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.addressSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
