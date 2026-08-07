/// Cari hesap durum sağlayıcıları.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'infra_providers.dart';

/// Güncel cari bakiye (ana sayfadaki kısayol + hesabım da okur).
final accountSummaryProvider = FutureProvider.autoDispose<AccountSummary>((
  ref,
) {
  return ref.watch(apiProvider).account.summary();
});

/// Cari ekstre — varsayılan aralık (son 3 ay) sunucudan gelir.
final accountStatementProvider = FutureProvider.autoDispose<AccountStatement>((
  ref,
) {
  return ref.watch(apiProvider).account.statement();
});
