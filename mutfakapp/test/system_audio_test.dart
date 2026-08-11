/// Hoparlör denetimi — `wpctl` / `pactl` çıktılarının ayrıştırılması.
///
/// Çıktılar GERÇEK makineden alındı (Ubuntu 24.04 + PipeWire 1.6.2,
/// 11.08.2026). Elle uydurulmuş örnek, biçim değiştiğinde testin
/// geçmeye devam etmesi demekti.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/sound/system_audio.dart';

/// Gerçek `wpctl status` çıktısı (kısaltılmış ama biçimi bozulmamış).
const String wpctlStatus = '''
PipeWire 'pipewire-0' [1.6.2, kemal@kasa, cookie:1916434540]
 └─ Clients:
        33. WirePlumber                         [1.6.2, kemal@kasa, pid:1877]

Audio
 ├─ Devices:
 │      48. Yerleşik Ses                       [alsa]
 │
 ├─ Sinks:
 │  *   55. Yerleşik Ses Analog Çevresel Ses 4.0 [vol: 0.88]
 │      58. HDMI / DisplayPort                 [vol: 1.00]
 │
 ├─ Sources:
 │      56. Yerleşik Ses Analog Stereo         [vol: 1.00]
 │
 ├─ Filters:
 │
 └─ Streams:

Video
 ├─ Devices:
 │
 ├─ Sinks:
 │
''';

const String pactlSinks = '''
43\talsa_output.pci-0000_00_1f.3.analog-stereo\tmodule-alsa-card.c\ts16le 2ch 48000Hz\tRUNNING
44\talsa_output.pci-0000_01_00.1.hdmi-stereo\tmodule-alsa-card.c\ts16le 2ch 48000Hz\tSUSPENDED
''';

void main() {
  group('wpctl status', () {
    test('yalnız SES çıkışlarını okur, video bölümüne taşmaz', () {
      final sinks = parseWpctlSinks(wpctlStatus);

      expect(sinks, hasLength(2));
      expect(sinks.first.label, 'Yerleşik Ses Analog Çevresel Ses 4.0');
      expect(sinks.last.label, 'HDMI / DisplayPort');
    });

    test('varsayılan çıkışı yıldızdan tanır', () {
      final sinks = parseWpctlSinks(wpctlStatus);

      expect(sinks.first.isDefault, isTrue);
      expect(sinks.last.isDefault, isFalse);
    });

    test('ad olarak düğüm kimliği kullanılır — `--target` bunu kabul eder', () {
      final sinks = parseWpctlSinks(wpctlStatus);

      expect(sinks.first.name, '55');
      expect(sinks.last.name, '58');
    });

    test('kaynaklar (mikrofonlar) çıkış listesine karışmaz', () {
      final sinks = parseWpctlSinks(wpctlStatus);

      expect(
        sinks.map((s) => s.label),
        isNot(contains('Yerleşik Ses Analog Stereo')),
      );
    });
  });

  group('pactl list short sinks', () {
    test('sekmeyle ayrılmış satırdan adı alır', () {
      final sinks = parsePactlSinks(pactlSinks);

      expect(sinks, hasLength(2));
      expect(sinks.first.name, 'alsa_output.pci-0000_00_1f.3.analog-stereo');
    });

    test('okunabilir etiket üretir', () {
      final sinks = parsePactlSinks(pactlSinks);

      expect(sinks.first.label, 'Analog Stereo');
      expect(sinks.last.label, 'Hdmi Stereo');
    });

    test('bozuk satır listeyi çökertmez', () {
      expect(parsePactlSinks('saçmasapan\n\n'), isEmpty);
    });
  });

  group('ses seviyesi okuma', () {
    test('wpctl ondalık değeri yüzdeye çevirir', () {
      expect(parseWpctlVolume('Volume: 0.88'), 88);
      expect(parseWpctlVolume('Volume: 1.00'), 100);
    });

    test('SESSİZE ALINMIŞSA 0 döner', () {
      // Personelin gördüğü değer duyduğu sesle tutarlı olmalı: %88 yazıp
      // hiç ses çıkmaması, aramayı yanlış yere yönlendirir.
      expect(parseWpctlVolume('Volume: 0.88 [MUTED]'), 0);
    });

    test('okunamayan çıktı null döner', () {
      expect(parseWpctlVolume('bağlanamadı'), isNull);
    });

    test('amixer yüzdesini okur', () {
      const output = '''
Simple mixer control 'Master',0
  Playback channels: Front Left - Front Right
  Front Left: Playback 65 [65%] [-13.50dB] [on]
''';

      expect(parseAmixerVolume(output), 65);
    });

    test('amixer kapalıysa 0 döner', () {
      expect(parseAmixerVolume('Front Left: Playback 65 [65%] [off]'), 0);
    });
  });
}
