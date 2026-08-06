import 'package:bld_core/bld_core.dart';
import 'package:test/test.dart';

void main() {
  // docs/03-api-sozlesmesi.md §1.3'teki örnek: 2026-08-04T11:30:00Z
  final ornek = DateTime.utc(2026, 8, 4, 11, 30);

  group('UTC → Türkiye saati', () {
    test('sabit +3 ofset uygulanır', () {
      expect(TurkishTime.time(ornek), '14:30');
      expect(TurkishTime.date(ornek), '04.08.2026');
      expect(TurkishTime.dateTime(ornek), '04.08.2026 14:30');
    });

    test('gün sınırını doğru geçer', () {
      // UTC 22:00 → Türkiye ertesi gün 01:00
      final gece = DateTime.utc(2026, 8, 4, 22);
      expect(TurkishTime.dateTime(gece), '05.08.2026 01:00');
    });

    test('yıl sınırını doğru geçer', () {
      final yilbasi = DateTime.utc(2026, 12, 31, 21, 30);
      expect(TurkishTime.dateTime(yilbasi), '01.01.2027 00:30');
    });

    test('yerel saatli girdi önce UTC\'ye çevrilir', () {
      final yerel = ornek.toLocal();
      expect(TurkishTime.time(yerel), TurkishTime.time(ornek));
    });

    test('yaz saati uygulanmaz — ocak ve temmuz aynı ofset', () {
      final ocak = DateTime.utc(2026, 1, 15, 12);
      final temmuz = DateTime.utc(2026, 7, 15, 12);
      expect(TurkishTime.time(ocak), '15:00');
      expect(TurkishTime.time(temmuz), '15:00');
    });
  });

  group('Fiş ve arayüz biçimleri', () {
    test('fişteki kısa teslim zamanı', () {
      // docs/05-mutfakapp.md §5.3: "Teslim: 05.08 09:30"
      final teslim = DateTime.utc(2026, 8, 5, 6, 30);
      expect(TurkishTime.shortDateTime(teslim), '05.08 09:30');
    });

    test('okunur uzun biçim', () {
      expect(TurkishTime.longDateTime(ornek), '4 Ağustos 2026, 14:30');
    });
  });

  group('isSameIstanbulDay', () {
    test('UTC günü farklı ama Türkiye günü aynı', () {
      final a = DateTime.utc(2026, 8, 4, 23, 30); // TR: 05.08 02:30
      final b = DateTime.utc(2026, 8, 5, 5); //      TR: 05.08 08:00
      expect(TurkishTime.isSameIstanbulDay(a, b), isTrue);
    });

    test('UTC günü aynı ama Türkiye günü farklı', () {
      final a = DateTime.utc(2026, 8, 4, 10); // TR: 04.08 13:00
      final b = DateTime.utc(2026, 8, 4, 22); // TR: 05.08 01:00
      expect(TurkishTime.isSameIstanbulDay(a, b), isFalse);
    });
  });

  group('relativeFromNow', () {
    test('KDS kartındaki bekleme süresi', () {
      final now = DateTime.utc(2026, 8, 4, 12);
      expect(
        TurkishTime.relativeFromNow(
          DateTime.utc(2026, 8, 4, 11, 59, 30),
          now: now,
        ),
        'şimdi',
      );
      expect(
        TurkishTime.relativeFromNow(DateTime.utc(2026, 8, 4, 11, 57), now: now),
        '3 dk önce',
      );
      expect(
        TurkishTime.relativeFromNow(DateTime.utc(2026, 8, 4, 10), now: now),
        '2 sa önce',
      );
      expect(
        TurkishTime.relativeFromNow(DateTime.utc(2026, 8, 2, 12), now: now),
        '2 gün önce',
      );
    });

    test('gelecekteki zaman çökmez', () {
      final now = DateTime.utc(2026, 8, 4, 12);
      expect(
        TurkishTime.relativeFromNow(DateTime.utc(2026, 8, 5), now: now),
        'birazdan',
      );
    });
  });

  group('minuteWindow — dakika aralığı → saat penceresi', () {
    test('sözleşme örneği: 60-85 dakika', () {
      // TR 12:15'te verilen sipariş → 13:15-13:40
      final simdi = DateTime.utc(2026, 8, 4, 9, 15);
      expect(TurkishTime.minuteWindow(simdi, 60, 85), '13:15-13:40');
    });

    test('gel-al aralığı ayrı hesaplanır', () {
      final simdi = DateTime.utc(2026, 8, 4, 9, 15); // TR 12:15
      expect(TurkishTime.minuteWindow(simdi, 40, 55), '12:55-13:10');
    });

    test('beş dakikaya yuvarlanır — alt aşağı, üst yukarı', () {
      // TR 12:17 + 60 = 13:17 → 13:15; + 85 = 13:42 → 13:45
      final simdi = DateTime.utc(2026, 8, 4, 9, 17);
      expect(TurkishTime.minuteWindow(simdi, 60, 85), '13:15-13:45');
    });

    test('yuvarlama saat sınırını taşırabilir', () {
      // TR 12:00 + 58 = 12:58 → üst uç 13:00
      final simdi = DateTime.utc(2026, 8, 4, 9);
      expect(TurkishTime.minuteWindow(simdi, 55, 58), '12:55-13:00');
    });

    test('gece yarısını doğru geçer', () {
      final simdi = DateTime.utc(2026, 8, 4, 20, 30); // TR 23:30
      expect(TurkishTime.minuteWindow(simdi, 40, 55), '00:10-00:25');
    });

    test('ters sıralı sınırlar yer değiştirir', () {
      final simdi = DateTime.utc(2026, 8, 4, 9, 15);
      expect(
        TurkishTime.minuteWindow(simdi, 85, 60),
        TurkishTime.minuteWindow(simdi, 60, 85),
      );
    });

    test('yerel saatli girdi önce UTC\'ye çevrilir', () {
      final simdi = DateTime.utc(2026, 8, 4, 9, 15);
      expect(
        TurkishTime.minuteWindow(simdi.toLocal(), 60, 85),
        TurkishTime.minuteWindow(simdi, 60, 85),
      );
    });
  });
}
