/// Klavyeyle kart seçimi.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/kds/board.dart';
import 'package:mutfakapp/src/kds/board_selection.dart';

const Map<KdsColumn, int> full = {
  KdsColumn.yeni: 3,
  KdsColumn.hazirlaniyor: 2,
  KdsColumn.hazir: 1,
};

void main() {
  test('açılışta seçim yoktur', () {
    expect(BoardSelection.none.isEmpty, isTrue);
  });

  test('ilk ok tuşu ilk dolu sütunun ilk kartını seçer', () {
    final selection = BoardSelection.none.moveVertically(1, full);
    expect(selection.column, KdsColumn.yeni);
    expect(selection.index, 0);
  });

  test('boş panoda seçim oluşmaz', () {
    final sizes = {for (final c in KdsColumn.values) c: 0};
    expect(BoardSelection.none.moveVertically(1, sizes).isEmpty, isTrue);
  });

  test('sütun içinde aşağı/yukarı gezinir ve uçlarda durur', () {
    var selection = const BoardSelection(column: KdsColumn.yeni);
    selection = selection.moveVertically(1, full);
    expect(selection.index, 1);

    selection = selection.moveVertically(1, full).moveVertically(1, full);
    expect(selection.index, 2, reason: 'Son kartta durmalı.');

    selection = selection
        .moveVertically(-1, full)
        .moveVertically(-1, full)
        .moveVertically(-1, full);
    expect(selection.index, 0, reason: 'İlk kartta durmalı.');
  });

  test('yana geçerken sıra taşarsa kırpılır', () {
    // "YENİ"nin üçüncü kartındayken iki kartlı sütuna geçmek, olmayan bir
    // kartı seçmek olurdu.
    const selection = BoardSelection(column: KdsColumn.yeni, index: 2);
    final moved = selection.moveHorizontally(1, full);

    expect(moved.column, KdsColumn.hazirlaniyor);
    expect(moved.index, 1);
  });

  test('boş sütun atlanır', () {
    // Boş sütunda durmak `Enter`'ın hiçbir şey yapmadığı ölü bir durumdur.
    const sizes = {
      KdsColumn.yeni: 2,
      KdsColumn.hazirlaniyor: 0,
      KdsColumn.hazir: 1,
    };
    final moved = const BoardSelection(
      column: KdsColumn.yeni,
    ).moveHorizontally(1, sizes);

    expect(moved.column, KdsColumn.hazir);
  });

  test('kenardan dışarı çıkılmaz', () {
    const selection = BoardSelection(column: KdsColumn.yeni);
    expect(selection.moveHorizontally(-1, full).column, KdsColumn.yeni);

    const last = BoardSelection(column: KdsColumn.hazir);
    expect(last.moveHorizontally(1, full).column, KdsColumn.hazir);
  });

  test('liste küçülünce seçim sınıra çekilir', () {
    // Seçili kart onaylanıp sütun değiştirirse, sınır dışı bir seçim `Enter`
    // ile YANLIŞ siparişi ilerletebilirdi.
    const selection = BoardSelection(column: KdsColumn.yeni, index: 2);
    final clamped = selection.clampedTo({KdsColumn.yeni: 2});

    expect(clamped.index, 1);
  });

  test('sütun boşalınca seçim düşer', () {
    const selection = BoardSelection(column: KdsColumn.yeni, index: 1);
    expect(selection.clampedTo({KdsColumn.yeni: 0}).isEmpty, isTrue);
  });

  test('eşleşme sütun ve sıraya birlikte bakar', () {
    const selection = BoardSelection(column: KdsColumn.hazir, index: 1);
    expect(selection.matches(KdsColumn.hazir, 1), isTrue);
    expect(selection.matches(KdsColumn.hazir, 0), isFalse);
    expect(selection.matches(KdsColumn.yeni, 1), isFalse);
  });
}
