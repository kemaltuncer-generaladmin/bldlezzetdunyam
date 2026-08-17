<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;
use Illuminate\Support\Facades\DB;

/**
 * Belge numarası sayacı — boşluksuzluğun tek sahibi.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * `MAX(sequence)+1` ASLA KULLANILMAZ.
 *
 * Eşzamanlı iki kesim aynı en büyük değeri okur, ikisi de bir ekler ve
 * `UNIQUE(series, year, sequence)` ikincisini reddeder: kullanıcı yazdır
 * düğmesinde 500 görür. Yarış her zaman yoğun saatte çıkar.
 *
 * DOĞRU İLKE — SATIR KİLİDİ:
 *
 *   SELECT next_sequence FROM veykemtu_invoice_counters
 *    WHERE series = :s AND year = :y FOR UPDATE
 *   UPDATE ... SET next_sequence = next_sequence + 1 WHERE ...
 *
 * InnoDB satırı İŞLEM SONUNA KADAR kilitler; ikinci kesim bekler ve artmış
 * değeri okur. `DailyStock`'taki koşullu `UPDATE` ilkesiyle çelişmiyor:
 * orada bir KOŞUL sınanıyor ("yer var mı"), burada bir DEĞER ayrılıyor.
 * Sayaç için koşul yok, yalnızca sıralı erişim var.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * ELOQUENT'LE YAZILMAZ. Bu sınıf okuma/inceleme içindir; ayırma `DB`
 * cephesiyle yapılır, çünkü bileşik birincil anahtarı (`series`, `year`)
 * Eloquent desteklemez ve `save()` ile yapılan bir artırma tam da
 * kaçındığımız "oku → değiştir → yaz" penceresidir.
 */
class InvoiceCounter extends Model
{
    /** Tek seri — `docs/control/invoices.md` → `BLD-<yıl>-<6 hane>`. */
    public const string SERIES = 'BLD';

    /** Sıra alanının basamak sayısı; `000001` biçimi buradan çıkar. */
    public const int SEQUENCE_PAD = 6;

    public const string TABLE = 'veykemtu_invoice_counters';

    protected $table = self::TABLE;

    public $timestamps = true;

    /**
     * Bileşik anahtar Eloquent'te yok; tekil anahtar varmış gibi
     * davranmasın diye artırma kapatıldı.
     */
    public $incrementing = false;

    protected $primaryKey = 'series';

    protected $keyType = 'string';

    protected $guarded = [];

    protected $casts = [
        'year' => 'integer',
        'next_sequence' => 'integer',
    ];

    /**
     * Sıradaki numarayı AYIRIR ve sayacı ilerletir.
     *
     * KENDİ İŞLEMİNİ AÇAR. Dışarıdaki bir işlemin içinde çağrıldığında
     * bu bir savepoint olur ve kilit yine EN DIŞTAKİ işlem bitene kadar
     * tutulur — yani iç içe çağrı güvenlidir. İşlemsiz çağrıda ise
     * `FOR UPDATE` kilidi `SELECT` biter bitmez bırakılırdı ve iki kesim
     * aynı sayıyı alırdı; bu yüzden sarmalama burada, çağrı yerinde
     * değil.
     *
     * @return array{0: int, 1: string}  [sıra, belge numarası]
     */
    public static function allocate(int $year, string $series = self::SERIES): array
    {
        /** @var array{0: int, 1: string} */
        return DB::transaction(static function () use ($year, $series): array {
            $sequence = self::nextSequence($series, $year);

            return [$sequence, self::format($series, $year, $sequence)];
        });
    }

    /** `BLD-2026-000001` */
    public static function format(string $series, int $year, int $sequence): string
    {
        return $series.'-'.$year.'-'.str_pad(
            (string) $sequence,
            self::SEQUENCE_PAD,
            '0',
            STR_PAD_LEFT,
        );
    }

    /**
     * Kilitli okuma + ilerletme.
     *
     * SATIR YOKSA ÖNCE AÇILIR: yılın ilk kesimi sayacı kendisi doğurur.
     * `insertOrIgnore` seçildi çünkü aynı anda iki kesim de satırı
     * açmaya kalkabilir; ikincisi sessizce yok sayılır ve hemen ardından
     * gelen kilitli `SELECT` ikisini de sıraya sokar. `firstOrCreate`
     * burada yanlış olurdu — çakışmayı istisnaya çevirirdi.
     */
    private static function nextSequence(string $series, int $year): int
    {
        $row = self::lockedRow($series, $year);

        if ($row === null) {
            $now = now();

            DB::table(self::TABLE)->insertOrIgnore([
                'series' => $series,
                'year' => $year,
                'next_sequence' => 1,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $row = self::lockedRow($series, $year);
        }

        // Satır az önce açıldı ya da zaten vardı; yoksa veritabanı
        // seviyesinde bir arıza var ve sessizce 1'e düşmek, ikinci bir
        // belgeye aynı numarayı verirdi.
        if ($row === null) {
            throw new \RuntimeException(
                "Fatura sayacı açılamadı: seri={$series}, yıl={$year}.",
            );
        }

        $sequence = (int) $row->next_sequence;

        DB::table(self::TABLE)
            ->where('series', $series)
            ->where('year', $year)
            ->update([
                'next_sequence' => $sequence + 1,
                'updated_at' => now(),
            ]);

        return $sequence;
    }

    private static function lockedRow(string $series, int $year): ?object
    {
        return DB::table(self::TABLE)
            ->where('series', $series)
            ->where('year', $year)
            ->lockForUpdate()
            ->first(['next_sequence']);
    }
}
