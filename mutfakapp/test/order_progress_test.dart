/// Kalem bazlı hazır işaretleri.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/kds/order_progress.dart';

void main() {
  test('başlangıçta hiçbir kalem işaretli değildir', () {
    expect(OrderItemProgress.empty.doneCount(1), isZero);
    expect(OrderItemProgress.empty.isDone(1, 0), isFalse);
  });

  test('işaretleme ve geri alma', () {
    final marked = OrderItemProgress.empty.toggle(1, 0);
    expect(marked.isDone(1, 0), isTrue);
    expect(marked.doneCount(1), 1);

    final cleared = marked.toggle(1, 0);
    expect(cleared.isDone(1, 0), isFalse);
    expect(cleared.trackedOrderCount, isZero);
  });

  test('değişmezdir: eski kopya etkilenmez', () {
    // Riverpod durumu referansla karşılaştırıyor; içeriği yerinde
    // değiştirmek arayüzü yeniden çizdirmezdi.
    final first = OrderItemProgress.empty.toggle(1, 0);
    final second = first.toggle(1, 1);

    expect(first.doneCount(1), 1);
    expect(second.doneCount(1), 2);
  });

  test('siparişler birbirini etkilemez', () {
    final progress = OrderItemProgress.empty.toggle(1, 0).toggle(2, 0);
    expect(progress.doneCount(1), 1);
    expect(progress.doneCount(2), 1);
    expect(progress.isDone(1, 1), isFalse);
  });

  test('tüm kalemler işaretlendi mi', () {
    final progress = OrderItemProgress.empty.toggle(1, 0).toggle(1, 1);
    expect(progress.allDone(1, 2), isTrue);
    expect(progress.allDone(1, 3), isFalse);
    // Kalemsiz sipariş "bitmiş" sayılmaz; aksi hâlde boş kart yeşil yanardı.
    expect(progress.allDone(9, 0), isFalse);
  });

  test('ekrandan düşen siparişin işaretleri silinir', () {
    // Silinmezse harita vardiya boyunca büyür ve sunucu bir kimliği yeniden
    // kullanırsa eski işaretler yeni siparişe yapışır.
    final progress = OrderItemProgress.empty.toggle(1, 0).toggle(2, 0);
    final retained = progress.retaining({2});

    expect(retained.doneCount(1), isZero);
    expect(retained.doneCount(2), 1);
    expect(retained.trackedOrderCount, 1);
  });

  test('hepsi ekrandaysa aynı örnek döner', () {
    // Gereksiz yeniden çizim olmasın: her yoklamada yeni nesne üretmek
    // panodaki kırk kartı boşuna yeniden çizerdi.
    final progress = OrderItemProgress.empty.toggle(1, 0);
    expect(identical(progress.retaining({1, 2}), progress), isTrue);
  });

  test('tek siparişin işaretleri temizlenebilir', () {
    final progress = OrderItemProgress.empty.toggle(1, 0).toggle(1, 2);
    expect(progress.clearOrder(1).doneCount(1), isZero);
    expect(identical(progress.clearOrder(9), progress), isTrue);
  });
}
