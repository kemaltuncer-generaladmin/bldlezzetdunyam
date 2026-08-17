<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Console;

use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Veykemtu\BridgeApi\Models\ErrorEvent;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Eskimiş hata olaylarını siler — `veykemtu:hata-temizle`, her gece 03:30.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * SAKLAMA KURALI OLMADAN `veykemtu_error_events` DİSKİ DOLDURAN TABLODUR.
 *
 * Parmak izi toplaması satır sayısını bastırıyor ama sıfırlamıyor: her yeni
 * sürüm yeni yığın izleri, her yeni ekran yeni hata türleri üretir. Kimse
 * hata kaydı silmeyi düşünmez — "belki lazım olur" — ve tablo yıllar içinde
 * sessizce büyür. Bu komut o kararı bir kez veriyor ve her gece uyguluyor.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * İKİ FARKLI SÜRE, İKİ FARKLI SORU:
 *
 *   ÇÖZÜLMÜŞ (30 gün): soru cevaplanmış. Kayıt yalnız "ne zaman olmuştu"
 *   diye dönüp bakmak için duruyor ve bir ay o bakış için fazlasıyla yeter.
 *
 *   ÇÖZÜLMEMİŞ (90 gün): kimse ilgilenmemiş olabilir ama hata AÇIK. Üç ay,
 *   mevsimlik bir arızanın (yılbaşı yoğunluğu, yaz menüsü) tekrarını
 *   görmeye yetecek kadar uzun. Çözülmüşle aynı süreyi vermek, bakılmamış
 *   bir arızayı bakılmış olanla aynı kefeye koymak olurdu.
 *
 * ÖLÇÜ ALINAN DAMGALAR DA FARKLI: çözülmüşte `resolved_at` (karar anından
 * itibaren), açıkta `last_seen_at` (son tekrardan itibaren). Açık bir olayda
 * `resolved_at` zaten yok; `first_seen_at` kullanılsaydı üç aydır HER GÜN
 * tekrarlayan bir hata, hâlâ sürerken silinirdi.
 *
 *   php artisan veykemtu:hata-temizle          # siler
 *   php artisan veykemtu:hata-temizle --kuru   # yalnız sayar
 */
class MonitorPurgeCommand extends Command
{
    protected $signature = 'veykemtu:hata-temizle
        {--kuru : Hiçbir şey silme, yalnızca sayıları göster.}
        {--gun-cozulmus=30 : Çözülmüş olayların saklama süresi (gün).}
        {--gun-acik=90 : Çözülmemiş olayların saklama süresi (gün).}';

    protected $description = 'Eskimiş hata olaylarını siler (çözülmüş 30, çözülmemiş 90 günden eski).';

    public function handle(): int
    {
        $now = BusinessTime::forStorage(Carbon::now());

        $resolvedBefore = $now->copy()->subDays(self::days($this->option('gun-cozulmus'), 30));
        $openBefore = $now->copy()->subDays(self::days($this->option('gun-acik'), 90));

        $resolved = ErrorEvent::query()
            ->whereNotNull('resolved_at')
            ->where('resolved_at', '<', $resolvedBefore);

        $open = ErrorEvent::query()
            ->whereNull('resolved_at')
            ->where('last_seen_at', '<', $openBefore);

        if ($this->option('kuru')) {
            $this->table(['Küme', 'Silinecek'], [
                ['Çözülmüş', (string) $resolved->count()],
                ['Çözülmemiş', (string) $open->count()],
            ]);

            $this->warn('Kuru prova: hiçbir satır silinmedi.');

            return self::SUCCESS;
        }

        // İki `delete` ayrı ayrı koşuyor, tek bir `orWhere` ile değil:
        // birleşik koşulda parantez hatası (`whereNull` ile `orWhere`nin
        // önceliği) bütün tabloyu silebilirdi. İki dar sorgu, tek geniş
        // sorgudan daha güvenli.
        $deletedResolved = $resolved->delete();
        $deletedOpen = $open->delete();

        $this->info(sprintf(
            'Hata olayları temizlendi: %d çözülmüş, %d çözülmemiş satır silindi.',
            $deletedResolved,
            $deletedOpen,
        ));

        return self::SUCCESS;
    }

    /**
     * Gün seçeneğini okur; anlamsız değer varsayılana döner.
     *
     * Sıfır ya da eksi bir gün, "her şeyi sil" demek olurdu ve elle
     * yazılan bir seçeneğin yazım hatası bütün hata geçmişini götürürdü.
     */
    private static function days(mixed $value, int $default): int
    {
        if (!is_numeric($value)) {
            return $default;
        }

        $days = (int) $value;

        return $days > 0 ? $days : $default;
    }
}
