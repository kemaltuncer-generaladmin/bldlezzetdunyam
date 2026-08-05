<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Console;

use Illuminate\Console\Command;
use Veykemtu\BridgeApi\Services\TranslationAudit;

/**
 * Türkçe çevirilerin kapsamını ve sağlamlığını raporlar.
 *
 * NEDEN KOMUT DA VAR, SADECE TEST DEĞİL: testler bu projede yalnızca
 * GitHub Actions'ta koşuyor ve orası şu an hiç çalışmıyor. Çeviri
 * yazarken kapsamın nereye geldiğini görmenin ve dağıtımdan sonra
 * sunucudaki gerçek dosyaları denetlemenin bir yolu olmalı.
 *
 * Denetim mantığı `TranslationAudit` içinde; burası yalnızca yazdırıyor.
 */
class TranslationAuditCommand extends Command
{
    protected $signature = 'veykemtu:ceviri-denetle';

    protected $description = 'Türkçe çeviri dosyalarını İngilizce kaynaklarıyla karşılaştırır';

    public function handle(): int
    {
        $denetim = new TranslationAudit(base_path());
        $rapor = $denetim->run();

        // Yükleme kontrolü AYRI: statik karşılaştırma dosyanın doğru
        // yazıldığını gösterir, çevirmenin onu bulduğunu göstermez.
        foreach ($denetim->translationFiles() as $dizin => $dosyalar) {
            foreach ($dosyalar as $dosya) {
                $yukleme = $denetim->loadProblems($dizin, $dosya);

                if ($yukleme === []) {
                    continue;
                }

                foreach ($rapor as $sira => $satir) {
                    if ($satir['dosya'] === $dizin.'/'.basename($dosya)) {
                        $rapor[$sira]['sorunlar'] = [...$satir['sorunlar'], ...$yukleme];
                    }
                }
            }
        }

        if ($rapor === []) {
            $this->warn('Hiç çeviri dosyası bulunamadı (lang/vendor/*/tr/*.php).');

            return self::FAILURE;
        }

        $toplamKaynak = 0;
        $toplamCeviri = 0;
        $sorunlu = 0;

        foreach ($rapor as $satir) {
            $toplamKaynak += $satir['kaynak'];
            $toplamCeviri += $satir['ceviri'];

            $oran = $satir['kaynak'] > 0
                ? sprintf('%%%d', (int) round(100 * $satir['ceviri'] / $satir['kaynak']))
                : '-';

            $this->line(sprintf(
                '  %-34s %5d/%-5d %6s',
                $satir['dosya'],
                $satir['ceviri'],
                $satir['kaynak'],
                $oran,
            ));

            foreach ($satir['sorunlar'] as $sorun) {
                $sorunlu++;
                $this->error('      '.$sorun);
            }
        }

        $this->newLine();
        $this->line(sprintf(
            '  TOPLAM %d/%d anahtar (%%%d)',
            $toplamCeviri,
            $toplamKaynak,
            $toplamKaynak > 0 ? (int) round(100 * $toplamCeviri / $toplamKaynak) : 0,
        ));

        if ($sorunlu > 0) {
            $this->error(sprintf('  %d sorun bulundu.', $sorunlu));

            return self::FAILURE;
        }

        $this->info('  Sorun yok.');

        return self::SUCCESS;
    }
}
