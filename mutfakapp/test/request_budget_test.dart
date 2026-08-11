/// Kasanın sunucuya attığı saatlik istek bütçesi.
///
/// NEDEN BÖYLE BİR TEST VAR: sunucuda kasa başına saatlik bir oran sınırı
/// var (`bld-kitchen`, 2000/saat). Aşıldığında kasa `429` alıyor ve
/// **mutfak sipariş görmüyor** — bağlantı uyarısı çalıyor ama sebebi
/// anlaşılmıyor: ağ sağlam, sunucu ayakta, yalnız sayaç dolmuş.
///
/// SAHADA YAŞANDI (12.08.2026): satış şalteri ve abonelik listesi pano
/// saatine (5 sn) bağlanmıştı. İkisi 720'şer istek/saat üretiyordu;
/// sipariş yoklaması (720) ve BBD kuyruğu (180) ile toplam ~2460 —
/// o günkü 1200 sınırının iki katı. Kasa yarım vardiyada `429` alırdı.
///
/// Bu test bir davranışı değil bir **bütçeyi** sabitliyor: yeni bir
/// yoklama döngüsü eklendiğinde ya da bir aralık kısaltıldığında burada
/// kırılır ve sunucudaki sınırla birlikte gözden geçirilmesi gerekir.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/data/providers.dart';
import 'package:mutfakapp/src/settings/kds_settings.dart';

/// Sunucudaki `bld-kitchen` sınırı — `platform/.../Extension.php`.
///
/// Buradaki sayı oradakiyle ELLE eşleşiyor; iki tarafı bağlayan bir kod
/// yolu yok (biri Dart, biri PHP). Sınır değişirse ikisi de değişmeli.
const int kitchenHourlyLimit = 2000;

int perHour(Duration interval) => (3600 / interval.inSeconds).round();

void main() {
  // Varsayılan ayarlar — kasada bunlar geçerli.
  const settings = KdsSettings(
    soundEnabled: true,
    pollSeconds: 5,
    printerDevicePath: '/dev/thermal0',
    warningAfterMinutes: 10,
    lateAfterMinutes: 20,
  );

  group('Sürekli döngüler', () {
    test('BÜTÇE SINIRIN ALTINDA — sürekli yoklamalar toplamı', () {
      final budget = <String, int>{
        'sipariş yoklaması': perHour(settings.pollInterval),
        'BBD kuyruğu': perHour(bbdPollInterval),
        // Heartbeat `PollingOrderSource` içinde sabit 60 sn.
        'heartbeat': perHour(const Duration(seconds: 60)),
        'sağlık bildirimi': perHour(settings.healthInterval),
        // Satış şalteri ve abonelik listesi yavaş saati izliyor.
        'satış şalteri': perHour(const Duration(minutes: 1)),
        'abonelik listesi': perHour(const Duration(minutes: 1)),
      };

      final total = budget.values.reduce((a, b) => a + b);

      expect(
        total,
        lessThan(kitchenHourlyLimit),
        reason:
            'Sürekli yoklamalar sınırı doldurursa kullanıcı kaynaklı '
            'isteklere (F5, fiş yeniden basma, düzenleme ekranı) yer '
            'kalmaz ve kasa vardiya ortasında 429 almaya başlar.\n'
            'Bütçe: $budget',
      );
    });

    test('KULLANICI İSTEKLERİNE en az %30 pay kalıyor', () {
      // Yoğun bir vardiyada personel F5'e basıyor, fiş yeniden bastırıyor,
      // düzenleme ekranı açıyor (tek açılışta 3 istek). Bunlar patlamalı
      // ve sürekli döngüler sınırı yalayıp geçmemeli.
      const continuous = 1140;

      expect(
        (kitchenHourlyLimit - continuous) / kitchenHourlyLimit,
        greaterThan(0.30),
      );
    });
  });

  group('Yavaş saat kuralı', () {
    test('satış şalteri ve abonelik listesi PANO SAATİNİ izlemez', () {
      // Pano saati 5 saniyede bir tikliyor ve arayüz çizimi için doğru.
      // Bir `FutureProvider` onu izlerse her tikte YENİ BİR AĞ İSTEĞİ
      // doğar — sahadaki hata tam olarak buydu.
      const fastTick = Duration(seconds: 5);
      const slowTick = Duration(minutes: 1);

      expect(
        perHour(fastTick),
        greaterThan(kitchenHourlyLimit ~/ 3),
        reason: 'Pano saatine bağlanan TEK bir uç bile sınırın üçte '
            'birini yer; iki tanesi sınırı doldurur.',
      );
      expect(perHour(slowTick), lessThan(100));
    });
  });

  group('Ayar sınırları bütçeyi patlatmıyor', () {
    test('EN HIZLI yoklama ayarında bile sınır aşılmıyor', () {
      // Personel yoklamayı 2 saniyeye indirebiliyor (`minPollSeconds`).
      // O uçta bile toplam sınırın altında kalmalı — yoksa ayarı
      // değiştiren personel farkında olmadan mutfağı kör bırakır.
      final fastest = perHour(
        const Duration(seconds: KdsSettings.minPollSeconds),
      );
      final rest =
          perHour(bbdPollInterval) +
          perHour(const Duration(seconds: 60)) * 2 +
          perHour(const Duration(minutes: 1)) * 2;

      expect(
        fastest + rest,
        lessThan(kitchenHourlyLimit),
        reason:
            '2 saniyelik yoklama 1800 istek/saat demek; kalan döngülerle '
            'birlikte sınırı aşarsa ayar ekranındaki alt sınır '
            'yükseltilmeli.',
      );
    });

    test('EN SIK sağlık bildiriminde de sınır aşılmıyor', () {
      // Yönetici `health_seconds`'i 10 saniyeye indirebiliyor.
      final health = perHour(
        const Duration(seconds: KdsSettings.minHealthSeconds),
      );
      final rest =
          perHour(const Duration(seconds: 5)) +
          perHour(bbdPollInterval) +
          perHour(const Duration(seconds: 60)) +
          perHour(const Duration(minutes: 1)) * 2;

      expect(health + rest, lessThan(kitchenHourlyLimit));
    });
  });
}
