import 'package:bld_core/bld_core.dart';
import 'package:test/test.dart';

void main() {
  group('BusinessDate.today', () {
    test('gün sınırı Türkiye saatinde hesaplanır', () {
      // 19 Ağustos 22:00 UTC = 20 Ağustos 01:00 Türkiye. UTC'ye baksaydık
      // müşteri gece yarısından sonra hâlâ DÜNÜN menüsünü görürdü.
      expect(
        BusinessDate.today(nowUtc: DateTime.utc(2026, 8, 19, 22)),
        '2026-08-20',
      );
    });

    test('Türkiye günü daha dönmediyse UTC günü ilerlemiş olsa da dünüdür', () {
      // 20 Ağustos 00:30 UTC = 20 Ağustos 03:30 Türkiye — aynı gün.
      expect(
        BusinessDate.today(nowUtc: DateTime.utc(2026, 8, 20, 0, 30)),
        '2026-08-20',
      );
    });
  });

  group('BusinessDate.tryParse', () {
    test('geçerli gün ayrıştırılır', () {
      expect(BusinessDate.tryParse('2026-08-20'), DateTime.utc(2026, 8, 20));
    });

    test('olmayan gün REDDEDİLİR', () {
      // DateTime.utc(2026, 2, 31) sessizce 3 Mart üretir; geçerli saymak
      // olmayan bir güne sipariş verdirirdi.
      expect(BusinessDate.tryParse('2026-02-31'), isNull);
      expect(BusinessDate.tryParse('2026-13-01'), isNull);
    });

    test('biçim dışı metin reddedilir', () {
      expect(BusinessDate.tryParse('20.08.2026'), isNull);
      expect(BusinessDate.tryParse('2026-8-20'), isNull);
      expect(BusinessDate.tryParse('2026-08-20T12:00:00Z'), isNull);
      expect(BusinessDate.tryParse(''), isNull);
    });

    test('artık yıl 29 Şubat geçerlidir', () {
      expect(BusinessDate.isValid('2028-02-29'), isTrue);
      expect(BusinessDate.isValid('2026-02-29'), isFalse);
    });
  });

  group('gün aritmetiği', () {
    test('ay ve yıl sınırını aşar', () {
      expect(BusinessDate.addDays('2026-08-31', 1), '2026-09-01');
      expect(BusinessDate.addDays('2026-12-31', 1), '2027-01-01');
      expect(BusinessDate.addDays('2026-01-01', -1), '2025-12-31');
    });

    test('otuz günlük ileri görüş penceresi', () {
      expect(BusinessDate.addDays('2026-08-13', 30), '2026-09-12');
      expect(BusinessDate.daysBetween('2026-08-13', '2026-09-12'), 30);
    });

    test('bozuk girdi çökertmez, metin geri döner', () {
      expect(BusinessDate.addDays('çarşamba', 1), 'çarşamba');
      expect(BusinessDate.daysBetween('çarşamba', '2026-08-20'), isNull);
    });
  });

  group('sıralama', () {
    test('metin karşılaştırması kronolojiktir', () {
      final days = ['2026-09-01', '2026-08-31', '2026-08-09', '2026-12-01'];
      days.sort(BusinessDate.compare);

      expect(days, ['2026-08-09', '2026-08-31', '2026-09-01', '2026-12-01']);
    });

    test('önce/sonra', () {
      expect(BusinessDate.isBefore('2026-08-09', '2026-08-10'), isTrue);
      expect(BusinessDate.isAfter('2026-09-01', '2026-08-31'), isTrue);
      expect(BusinessDate.isBefore('2026-08-20', '2026-08-20'), isFalse);
    });
  });

  group('biçimleme', () {
    test('uzun ve kısa biçim', () {
      expect(BusinessDate.long('2026-08-20'), '20 Ağustos 2026');
      expect(BusinessDate.short('2026-08-20'), '20 Ağustos');
      expect(BusinessDate.long('2026-01-01'), '1 Ocak 2026');
    });

    test('hafta günü', () {
      // 20 Ağustos 2026 bir Perşembe.
      expect(BusinessDate.weekday('2026-08-20'), 'Perşembe');
      expect(BusinessDate.weekday('2026-08-16'), 'Pazar');
    });

    test('bozuk gün ekranı çökertmez', () {
      expect(BusinessDate.long('bozuk'), 'bozuk');
      expect(BusinessDate.weekday('bozuk'), '');
    });
  });

  group('BusinessDate.label', () {
    test('bugün ve yarın adlarıyla anılır', () {
      expect(BusinessDate.label('2026-08-13', todayIso: '2026-08-13'), 'Bugün');
      expect(BusinessDate.label('2026-08-14', todayIso: '2026-08-13'), 'Yarın');
    });

    test('daha ileri günlerde gün adı yazılır', () {
      expect(
        BusinessDate.label('2026-08-20', todayIso: '2026-08-13'),
        '20 Ağustos Perşembe',
      );
    });

    test('ay sonunda yarın doğru hesaplanır', () {
      expect(BusinessDate.label('2026-09-01', todayIso: '2026-08-31'), 'Yarın');
    });
  });

  group('BusinessDate.month', () {
    test('ay adı ve yıl döner, gün taşımaz', () {
      // Takvim sayfasının başlığı bir ayın TAMAMINI adlandırır.
      expect(BusinessDate.month('2026-08-20'), 'Ağustos 2026');
      expect(BusinessDate.month('2026-01-01'), 'Ocak 2026');
      expect(BusinessDate.month('2025-12-31'), 'Aralık 2025');
    });

    test('bozuk gün ekranı çökertmez', () {
      expect(BusinessDate.month('bozuk'), 'bozuk');
    });
  });
}
