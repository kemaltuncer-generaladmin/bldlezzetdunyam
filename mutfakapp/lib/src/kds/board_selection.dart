/// Klavyeyle kart seçimi — `docs/05-mutfakapp.md` §1: mutfakta fare
/// kullanılmıyor, giriş "kurulum için" klavye/fare diyor.
///
/// Yağlı elle fare sürüklemek yerine ok tuşlarıyla kart seçip `Enter`'a
/// basmak, mutfakta ölçülebilir biçimde hızlıdır. Seçim mantığı burada saf
/// tutulur; çizim ve tuş yakalama `kds_screen.dart`'tadır.
library;

import 'board.dart';

/// Panoda seçili kartın yeri.
///
/// [column] `null` ise hiçbir kart seçili değildir — açılıştaki ve `Esc`
/// sonrasındaki durum. Fareyle çalışan personeli rahatsız etmemek için seçim
/// kendiliğinden oluşmaz, ancak bir ok tuşuna basılınca belirir.
class BoardSelection {
  const BoardSelection({this.column, this.index = 0});

  static const BoardSelection none = BoardSelection();

  final KdsColumn? column;
  final int index;

  bool get isEmpty => column == null;

  /// [orderId] seçili mi? Kart kendi durumunu buradan öğrenir.
  bool matches(KdsColumn column, int index) =>
      this.column == column && this.index == index;

  /// Seçimi mevcut sütun boyutlarına oturtur.
  ///
  /// Liste her yoklamada değişiyor: seçili kart onaylanıp sütun değiştirebilir
  /// ya da tamamen düşebilir. Sınır dışına taşan bir seçim, `Enter`'a
  /// basıldığında ya hiçbir şey yapmaz ya da **yanlış siparişi** ilerletir.
  BoardSelection clampedTo(Map<KdsColumn, int> sizes) {
    final current = column;
    if (current == null) return none;

    final size = sizes[current] ?? 0;
    if (size == 0) return none;
    if (index < size) return this;
    return BoardSelection(column: current, index: size - 1);
  }

  /// Sütun içinde [delta] kadar ilerler (aşağı `+1`, yukarı `-1`).
  ///
  /// Seçim yokken ilk kartı seçer: personelin önce fareye uzanması gerekmesin.
  BoardSelection moveVertically(int delta, Map<KdsColumn, int> sizes) {
    final start = clampedTo(sizes);
    if (start.isEmpty) return _firstNonEmpty(sizes);

    final size = sizes[start.column] ?? 0;
    final next = (start.index + delta).clamp(0, size - 1);
    return BoardSelection(column: start.column, index: next);
  }

  /// Komşu **dolu** sütuna geçer; boş sütunlar atlanır.
  ///
  /// Boş sütunda durmak, `Enter`'ın hiçbir şey yapmadığı ölü bir durum
  /// yaratır ve personel tuşun bozuk olduğunu düşünür.
  BoardSelection moveHorizontally(int delta, Map<KdsColumn, int> sizes) {
    final start = clampedTo(sizes);
    if (start.isEmpty) return _firstNonEmpty(sizes);

    final columns = KdsColumn.values;
    var position = columns.indexOf(start.column!);

    for (var step = 0; step < columns.length; step++) {
      position += delta;
      if (position < 0 || position >= columns.length) return start;

      final candidate = columns[position];
      final size = sizes[candidate] ?? 0;
      if (size == 0) continue;
      return BoardSelection(
        column: candidate,
        index: start.index.clamp(0, size - 1),
      );
    }

    return start;
  }

  static BoardSelection _firstNonEmpty(Map<KdsColumn, int> sizes) {
    for (final column in KdsColumn.values) {
      if ((sizes[column] ?? 0) > 0) return BoardSelection(column: column);
    }
    return none;
  }

  @override
  bool operator ==(Object other) =>
      other is BoardSelection && other.column == column && other.index == index;

  @override
  int get hashCode => Object.hash(column, index);

  @override
  String toString() => 'BoardSelection($column, $index)';
}
