<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Console;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Schema;
use RuntimeException;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Cari hesap verisini dosyaya döker — kaldırma göçünden ÖNCEKİ tek veri yolu.
 *
 * NEDEN VAR: `2026_08_20_000002_drop_account_tables` üç cari tablosunu ve
 * `customers.bld_credit_limit_kurus` kolonunu düşürüyor. Göçün `down()`'ı
 * ŞEMAYI geri getirir, VERİYİ getiremez. Veriyi geri getiren tek şey bu
 * komutun ürettiği dosyalardır.
 *
 * NEDEN NDJSON (satır başına bir JSON nesnesi): defter yüz binlerce satıra
 * çıkabilir ve tek bir dev JSON dizisi hem yazarken hem okurken tamamen
 * belleğe girmek zorundadır. NDJSON `grep`, `head`, `jq -c` ve satır satır
 * içe aktarma ile çalışır — arşivin okunabilir olması, arşivin kendisi
 * kadar önemlidir.
 *
 * NEDEN `storage/app/...` VE NEDEN `Storage::disk('local')` DEĞİL: Laravel
 * 11'den beri `local` diskinin kökü `storage/app/private`. Arşivin yolu
 * RUNBOOK'ta operatöre yazılı olarak veriliyor; diskin kökü bir gün
 * değişirse belgedeki yol sessizce yanlış olurdu. Mutlak yol burada
 * `storage_path()` ile kuruluyor ve ekrana da basılıyor.
 *
 * DİKKAT — YAZILAN DOSYA BİR YEDEK DEĞİLDİR. Üretimde `storage/app`
 * adlandırılmış bir Docker birimidir (`platform-storage`), yani dosya
 * normal bir yeniden dağıtımda silinmez; ama tek sunucunun diskinde durur
 * ve veritabanı yedek rotasyonuna (`infra/backup/`) GİRMEZ. Birim
 * silindiğinde ya da sunucu gittiğinde arşiv de gider.
 *
 * Bu yüzden operatör komutu ELLE koşup dizini sunucudan İNDİRİR
 * (`docs/RUNBOOK.md` §9). Göç içinden çağrılan kopya (`2026_08_20_000001`)
 * aynı birime yazar; ikinci emniyet kemeridir, birincisi değil.
 */
class AccountArchiveCommand extends Command
{
    protected $signature = 'veykemtu:cari-arsivle';

    protected $description = 'Cari hesap tablolarını ve borç limitlerini NDJSON olarak arşivler (kaldırma göçünden önce koşulmalı).';

    /** Arşiv kökü — `storage/app/` altında, dağıtımda indirilecek dizin. */
    private const string ROOT = 'app/bld-cari-arsiv';

    /**
     * Dökülecek tablolar → dosya adı.
     *
     * Sıra bilinçli: defter (asıl geçmiş), dönem özetleri (türetilmiş),
     * ödeme niyetleri (süreç izi). Arşivi eline alan biri en değerli
     * dosyayı listenin başında bulur.
     */
    private const array TABLES = [
        'veykemtu_account_ledger' => 'veykemtu_account_ledger.ndjson',
        'veykemtu_account_periods' => 'veykemtu_account_periods.ndjson',
        'veykemtu_account_payments' => 'veykemtu_account_payments.ndjson',
    ];

    /** Borç limiti dökümünün dosya adı. */
    private const string LIMITS_FILE = 'customers_credit_limits.ndjson';

    public function handle(): int
    {
        $result = self::export();

        $this->components->info('Cari hesap arşivi yazıldı.');

        foreach ($result['counts'] as $name => $count) {
            $this->components->twoColumnDetail($name, $count.' satır');
        }

        // YOL `twoColumnDetail` İLE YAZILMAZ. O bileşen satırı terminal
        // genişliğine sığdırmak için ORTASINI KIRPIYOR ve mutlak yol
        // "storagebld-cari-arsiv/…" gibi çıkıyordu — operatörün kopyalayıp
        // `docker cp` yapacağı tek dize, kopyalanamaz hâlde.
        $this->newLine();
        $this->line('  Arşiv dizini:');
        $this->line('  '.$result['path']);
        $this->newLine();

        // UYARI SON SATIRDA: operatörün ekranda en son gördüğü şey, yapması
        // gereken iş olmalı. Yukarıdaki satır sayıları arasında kaybolursa
        // dizin indirilmeden dağıtım yapılır ve veri geri dönülemez biçimde
        // gider.
        $this->components->warn(
            'Bu dizini SUNUCUDAN İNDİRİN. Dosya bir Docker biriminde duruyor '
            .'ve veritabanı yedeklerine dahil DEĞİL (docs/RUNBOOK.md §9).',
        );

        return self::SUCCESS;
    }

    /**
     * Arşivi yazar ve sonucu döndürür.
     *
     * `handle()` DIŞINDA AYRI BİR METOT: aynı işi göç de çağırıyor
     * (`2026_08_20_000001_export_account_data_before_drop`). Göçten
     * `Artisan::call()` ile komut tetiklemek, göçün çıktısını ve hatasını
     * yutan bir dolaylılık katmanı eklerdi.
     *
     * TABLO YOKSA SESSİZCE ATLANIR, PATLAMAZ: komut kaldırma göçünden sonra
     * ikinci kez koşulabilir (operatör "acaba almış mıydım" diye). O durumda
     * boş bir arşiv üretmek, hata verip operatörü paniğe sokmaktan iyidir —
     * satır sayısı `0` zaten durumu söylüyor.
     *
     * @return array{path: string, counts: array<string, int>}
     */
    public static function export(): array
    {
        $path = storage_path(self::ROOT.'/'.BusinessTime::now()->format('Y-m-d-His'));

        File::ensureDirectoryExists($path);

        $counts = [];

        foreach (self::TABLES as $table => $file) {
            $counts[$table] = Schema::hasTable($table)
                ? self::dumpTable($table, $path.'/'.$file)
                : 0;
        }

        $counts['customers.bld_credit_limit_kurus'] = Schema::hasColumn('customers', 'bld_credit_limit_kurus')
            ? self::dumpCreditLimits($path.'/'.self::LIMITS_FILE)
            : 0;

        // Manifest: arşivi aylar sonra eline alan biri, dosyaların eksik mi
        // yoksa gerçekten boş mu olduğunu satır sayısına bakarak anlar.
        self::putContents($path.'/ozet.json', self::encodeJson([
            'created_at' => BusinessTime::now()->toIso8601String(),
            'counts' => $counts,
            'note' => 'Cari hesap kaldırma arşivi. Şema geri alınabilir, veri yalnızca buradan döner.',
        ]).PHP_EOL);

        return ['path' => $path, 'counts' => $counts];
    }

    /**
     * Tabloyu satır satır dosyaya döker.
     *
     * `chunkById` yerine `orderBy('id')->chunk()` YETMEZDİ diye düşünülüp
     * `chunkById` seçildi: dökümün ortasında tabloya yazan bir istek
     * (henüz canlıdayız — komut dağıtımdan önce koşuluyor) `chunk`'ta
     * sayfa kaymasına yol açar ve satır atlanır. Arşivde atlanan satır,
     * geri dönüşü olmayan kayıptır.
     */
    private static function dumpTable(string $table, string $file): int
    {
        $handle = self::openArchiveFile($file);
        $count = 0;

        try {
            DB::table($table)->chunkById(500, function ($rows) use ($handle, &$count): void {
                foreach ($rows as $row) {
                    self::writeRow($handle, (array) $row);
                    $count++;
                }
            });
        } finally {
            fclose($handle);
        }

        return $count;
    }

    /**
     * `customers.customer_id + bld_credit_limit_kurus` çiftleri.
     *
     * TÜM MÜŞTERİLER DÖKÜLÜR, yalnızca limiti olanlar değil. Kolonun üç
     * hâli var (`NULL` sınırsız, `0` cari kapalı, `n` tavan) ve `NULL`
     * satırı atlamak "sınırsız" ile "kayıt yok"u ayırt edilemez kılardı —
     * geri yüklemede en kritik ayrım tam olarak bu.
     */
    private static function dumpCreditLimits(string $file): int
    {
        $handle = self::openArchiveFile($file);
        $count = 0;

        try {
            DB::table('customers')
                ->select(['customer_id', 'bld_credit_limit_kurus'])
                ->chunkById(500, function ($rows) use ($handle, &$count): void {
                    foreach ($rows as $row) {
                        self::writeRow($handle, [
                            'customer_id' => (int) $row->customer_id,
                            'bld_credit_limit_kurus' => $row->bld_credit_limit_kurus === null
                                ? null
                                : (int) $row->bld_credit_limit_kurus,
                        ]);
                        $count++;
                    }
                }, 'customer_id');
        } finally {
            fclose($handle);
        }

        return $count;
    }

    /** @return resource */
    private static function openArchiveFile(string $file)
    {
        $handle = fopen($file, 'wb');

        if ($handle === false) {
            throw new RuntimeException("Arşiv dosyası açılamadı: {$file}");
        }

        return $handle;
    }

    /**
     * @param  resource  $handle
     * @param  array<string, mixed>  $row
     */
    private static function writeRow($handle, array $row): void
    {
        fwrite($handle, self::encodeJson($row).PHP_EOL);
    }

    private static function putContents(string $file, string $contents): void
    {
        File::put($file, $contents);
    }

    /**
     * `JSON_THROW_ON_ERROR` bilinçli: bozuk kodlamada sessizce `false`
     * yazmak yerine patlamak istiyoruz — yarım bir arşiv, arşiv değildir.
     *
     * @param  array<string, mixed>  $value
     */
    private static function encodeJson(array $value): string
    {
        return json_encode(
            $value,
            JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR,
        );
    }
}
