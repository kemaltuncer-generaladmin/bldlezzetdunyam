<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Support;

use Illuminate\Support\Carbon;

/**
 * İşletme saati — Europe/Istanbul.
 *
 * İKİ AYRI KAVRAM VARDIR, KARIŞTIRILMAMALI:
 *
 * - **Depolama zamanı: UTC.** Veritabanındaki her zaman damgası UTC'dir,
 *   API'nin döndüğü her zaman damgası UTC'dir (`docs/03` §1.3).
 * - **İşletme günü: Europe/Istanbul.** "Bugünün siparişleri", "kesim saati
 *   16:00", "fişteki tarih" — bunların hepsi Türkiye duvar saatine göredir.
 *
 * `config('app.timezone')` bu iş için KULLANILMAZ: o depolama zaman dilimidir
 * (UTC) ve kurulumda yanlışlıkla başka bir değere kayarsa iş kuralları
 * sessizce bozulur. Gece 00:00–03:00 arasında "bugün" iki zaman diliminde
 * farklı gündür; UTC'ye göre filtrelenen bir mutfak ekranı o saatlerde
 * siparişleri kaybeder.
 *
 * Türkiye 2016'dan beri kalıcı UTC+3'tedir, yaz saati yoktur — ama yine de
 * IANA adı kullanılıyor: karar değişirse tek satır yeter.
 */
final class BusinessTime
{
    public const string ZONE = 'Europe/Istanbul';

    private function __construct() {}

    /** Şu anın Türkiye duvar saati. */
    public static function now(): Carbon
    {
        return Carbon::now(self::ZONE);
    }

    /** Herhangi bir anı Türkiye duvar saatine taşır. */
    public static function at(Carbon $moment): Carbon
    {
        return $moment->copy()->setTimezone(self::ZONE);
    }

    /** İşletme günü olarak bugünün tarihi (`Y-m-d`). */
    public static function today(): string
    {
        return self::now()->toDateString();
    }
}
