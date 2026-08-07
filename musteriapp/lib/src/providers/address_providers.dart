/// Adres defteri sağlayıcıları — `GET/POST/PATCH/DELETE /addresses`.
///
/// Defterdeki kayıt siparişe **kopyalanır**, bağlanmaz: müşteri adresini
/// düzelttiğinde teslim edilmiş bir siparişin nereye gittiği değişmemeli
/// (`docs/openapi.yaml` §SavedAddress). Kopyalama `SavedAddress.toOrderAddress`
/// içinde.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'infra_providers.dart';
import 'session_provider.dart';

/// Müşterinin adres defteri. Varsayılan adres başta gelir.
///
/// Giriş yapılmamışsa boş liste döner — `/addresses` `401` verirdi ve hesap
/// sekmesi giriş yapmamış kullanıcıya zaten adres göstermiyor.
class AddressBookNotifier extends AsyncNotifier<List<SavedAddress>> {
  @override
  Future<List<SavedAddress>> build() async {
    final session = await ref.watch(sessionProvider.future);
    if (!session.isSignedIn) return const <SavedAddress>[];

    try {
      final list = await ref.read(apiProvider).addresses.list();
      ref.read(connectivityProvider.notifier).reportSuccess();
      return list;
    } on ApiException catch (error) {
      ref.read(connectivityProvider.notifier).reportFailure(error);
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<SavedAddress>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => build());
  }

  /// Başarısızlıkta [ApiException] atar; çağıran ekranda gösterir.
  Future<SavedAddress> create(SavedAddressInput input) async {
    final created = await ref.read(apiProvider).addresses.create(input);
    await refresh();
    return created;
  }

  Future<SavedAddress> edit(int id, SavedAddressInput input) async {
    final updated = await ref.read(apiProvider).addresses.update(id, input);
    await refresh();
    return updated;
  }

  Future<void> remove(int id) async {
    await ref.read(apiProvider).addresses.delete(id);
    await refresh();
  }
}

final addressBookProvider =
    AsyncNotifierProvider<AddressBookNotifier, List<SavedAddress>>(
      AddressBookNotifier.new,
    );

/// Ödeme ekranında önceden seçili gelecek adres.
///
/// Sunucu varsayılanı başta döndürüyor ama `is_default` işaretine bakmak daha
/// dürüst: liste sırasının anlamı sözleşmede garanti değil, işaret garanti.
final defaultAddressProvider = Provider<SavedAddress?>((ref) {
  final book = ref.watch(addressBookProvider).valueOrNull;
  if (book == null || book.isEmpty) return null;
  for (final address in book) {
    if (address.isDefault) return address;
  }
  return book.first;
});
