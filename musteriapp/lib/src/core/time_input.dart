/// Kullanıcının seçtiği zamanı sözleşmenin beklediği biçime çevirir.
///
/// `packages/core`'daki [TurkishTime] UTC → Türkiye yönünü kapsıyor; tersi
/// (kullanıcının girdiği duvar saati → UTC) orada yok. Tek yer olsun diye
/// burada tutuluyor; core'a taşınması `docs/BILINMEYENLER.md`'de not edildi.
library;

import 'package:bld_core/bld_core.dart';

/// Kullanıcının gördüğü Türkiye duvar saatini UTC'ye çevirir.
///
/// Girdinin zaman dilimi **yok sayılır**: kullanıcı saat seçicide "12:30"
/// gördüyse kastettiği Türkiye saatiyle 12:30'dur, cihazın zaman dilimi ne
/// olursa olsun.
DateTime istanbulWallClockToUtc(DateTime wallClock) => DateTime.utc(
  wallClock.year,
  wallClock.month,
  wallClock.day,
  wallClock.hour,
  wallClock.minute,
).subtract(istanbulOffset);

/// Şu anın Türkiye duvar saati — tarih/saat seçicilerin başlangıcı.
DateTime istanbulNow() => TurkishTime.toIstanbul(DateTime.now().toUtc());
