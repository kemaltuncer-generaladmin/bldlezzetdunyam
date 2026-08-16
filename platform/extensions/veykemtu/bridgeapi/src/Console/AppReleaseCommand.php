<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Console;

use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Veykemtu\BridgeApi\Models\AppRelease;

/**
 * Uygulama sürümü yayınlama — `docs/05-mutfakapp.md` §9, görev `B-10`.
 *
 * Kasa `GET /api/app-version` ile buraya yazılan satırı okur; `.deb`'i
 * `download_url`'den indirir ve `sha256` ile doğrular. Satır yoksa uç
 * `download_url: null` döner ve hiçbir kasa güncellenemez.
 *
 *   php artisan veykemtu:surum
 *   php artisan veykemtu:surum --publish --app=mutfakapp --surum=1.1.0 \
 *       --url=https://github.com/.../mutfakapp_1.1.0_amd64.deb \
 *       --file=build/mutfakapp_1.1.0_amd64.deb \
 *       --notes="Fiş kod sayfası düzeltmesi"
 *
 * `--file` YALNIZCA ÖZET İÇİNDİR, yükleme yapmaz. Paket GitHub Releases'te
 * duruyor (`infra/kasa/paketle.sh` yüklüyor); burada yapılan iş, sahaya
 * gidecek baytların özetini kayda geçirmek. Özet yükleyenin değil,
 * yayınlayanın elindeki dosyadan alınır — aradaki fark, bozuk yüklemenin
 * fark edilmesini sağlayan şeydir.
 */
class AppReleaseCommand extends Command
{
    /**
     * SEÇENEK ADI `--surum`, `--version` DEĞİL.
     *
     * `--version` Symfony Console'un AYRILMIŞ genel seçeneğidir (`-V` ile
     * eş). Komut onu kendi adına tanımlasa bile konsol katmanı isteği önce
     * yakalıyor ve çerçevenin sürümünü yazdırıp çıkıyor: komut hiç
     * çalışmıyor, hata da vermiyor. Sahada "Laravel Framework 12.64.0"
     * yazıp sessizce dönüyordu (16.08.2026).
     */
    protected $signature = 'veykemtu:surum
        {--publish : Yeni sürüm yayınla (aşağıdaki seçenekler bununla anlamlı)}
        {--app=mutfakapp : Uygulama: mutfakapp veya musteriapp}
        {--surum= : Yayınlanan sürüm, örn. 1.1.0}
        {--url= : .deb adresi (mutfakapp için zorunlu)}
        {--file= : Yerel .deb yolu — sha256 ve boyut buradan hesaplanır}
        {--sha256= : Özeti elle ver (--file yoksa)}
        {--min-supported= : Bundan eski istemciler engellenir (varsayılan: değiştirme)}
        {--notes= : Sürüm notu}';

    protected $description = 'Uygulama sürümlerini listeler ve yeni sürüm yayınlar.';

    /**
     * Sürüm kaydı hiç yokken varsayılan alt sınır.
     *
     * Sahadaki kasalar `AppConfig.appVersion` = `1.0.0` ile derlendi. Alt
     * sınırı yayınlanan sürüme eşitlemek, güncellemeyi almamış her kasayı
     * anında engelleyici ekrana düşürürdü — güncellemenin kendisi o ekranın
     * arkasında kalırdı.
     */
    private const string DEFAULT_MIN_SUPPORTED = '1.0.0';

    public function handle(): int
    {
        return $this->option('publish') ? $this->publish() : $this->listReleases();
    }

    private function listReleases(): int
    {
        $releases = AppRelease::query()
            ->orderBy('app_id')
            ->orderByDesc('released_at')
            ->get();

        if ($releases->isEmpty()) {
            $this->components->warn('Hiç sürüm kaydı yok — kasalar güncelleme göremez.');
            $this->line('  Yayınlamak için: php artisan veykemtu:surum --publish --help');

            return self::SUCCESS;
        }

        $this->table(
            ['Uygulama', 'Sürüm', 'Alt sınır', 'Özet', 'Boyut', 'Yayın'],
            $releases->map(fn(AppRelease $r): array => [
                $r->app_id,
                $r->version,
                $r->min_supported,
                $r->sha256 !== null ? substr($r->sha256, 0, 12).'…' : '—',
                $r->size_bytes !== null ? $this->humanSize($r->size_bytes) : '—',
                $r->released_at->format('d.m.Y H:i'),
            ])->all(),
        );

        return self::SUCCESS;
    }

    private function publish(): int
    {
        $appId = (string) $this->option('app');
        if (!in_array($appId, AppRelease::APPS, true)) {
            $this->components->error("Bilinmeyen uygulama: {$appId}");

            return self::FAILURE;
        }

        $version = trim((string) $this->option('surum'));
        if (!$this->isSemVer($version)) {
            $this->components->error('--surum geçerli bir sürüm olmalı, örn. 1.1.0');

            return self::FAILURE;
        }

        if (AppRelease::query()->where('app_id', $appId)->where('version', $version)->exists()) {
            // Aynı sürümü iki kez yayınlamak, hangi `.deb`'in sahada olduğunu
            // belirsizleştirir. Düzeltme gerekiyorsa yama sürümü çıkılır.
            $this->components->error("{$appId} {$version} zaten yayınlanmış.");

            return self::FAILURE;
        }

        $url = trim((string) $this->option('url'));
        if ($appId === AppRelease::MUTFAKAPP && $url === '') {
            $this->components->error('--url zorunlu: kasa .deb\'i bu adresten indiriyor.');

            return self::FAILURE;
        }

        if ($url !== '' && !str_starts_with($url, 'https://')) {
            // Paket kasaya kurulacak kod taşıyor; düz HTTP üzerinden
            // indirilen bir yürütülebilir, yolda değiştirilebilir demektir.
            $this->components->error('--url https:// ile başlamalı.');

            return self::FAILURE;
        }

        [$sha256, $sizeBytes, $error] = $this->resolveDigest();
        if ($error !== null) {
            $this->components->error($error);

            return self::FAILURE;
        }

        if ($appId === AppRelease::MUTFAKAPP && $sha256 === null) {
            // Uyarı, hata değil: sözleşme özeti zorunlu tutmuyor ve acil bir
            // yamayı özet yüzünden bloke etmek istemiyoruz. Ama sessiz de
            // geçilmemeli — doğrulamasız kurulum bilinçli bir seçim olmalı.
            $this->components->warn(
                'Özet verilmedi: kasa .deb\'i doğrulayamayacak. --file ya da --sha256 önerilir.',
            );

            if (!$this->confirm('Yine de yayınlansın mı?', false)) {
                return self::FAILURE;
            }
        }

        $minSupported = $this->resolveMinSupported($appId);
        if ($minSupported === null) {
            return self::FAILURE;
        }

        $release = new AppRelease;
        $release->app_id = $appId;
        $release->version = $version;
        $release->min_supported = $minSupported;
        $release->download_url = $url !== '' ? $url : null;
        $release->sha256 = $sha256;
        $release->size_bytes = $sizeBytes;
        $release->notes = ($notes = trim((string) $this->option('notes'))) !== '' ? $notes : null;
        $release->released_at = Carbon::now();
        $release->save();

        $this->components->info("Yayınlandı: {$appId} {$version} (alt sınır {$minSupported})");

        if ($sha256 !== null) {
            $this->line("  sha256: {$sha256}");
        }

        $this->newLine();
        $this->line('  Kasalar bunu en geç bir saat içinde görür. Hemen kurdurmak için');
        $this->line('  Kontrol Merkezi\'nden ilgili cihaza <options=bold>update</> komutu gönderin.');

        return self::SUCCESS;
    }

    /**
     * Özet ve boyutu `--file`'dan hesaplar ya da `--sha256`'dan alır.
     *
     * @return array{0: string|null, 1: int|null, 2: string|null} [özet, boyut, hata]
     */
    private function resolveDigest(): array
    {
        $file = trim((string) $this->option('file'));
        $given = strtolower(trim((string) $this->option('sha256')));

        if ($file !== '') {
            if (!is_file($file) || !is_readable($file)) {
                return [null, null, "Dosya okunamadı: {$file}"];
            }

            // Paketin gerçekten bir `.deb` olduğunu BURADA eliyoruz: yanlış
            // dosyanın özeti kayda girerse, sahadaki kasa doğru paketi indirip
            // "özet tutmadı" diyerek reddeder ve hata yayınlayanın masasında
            // değil mutfakta görünür.
            $handle = fopen($file, 'rb');
            $magic = $handle !== false ? (string) fread($handle, 8) : '';
            if ($handle !== false) {
                fclose($handle);
            }

            if ($magic !== "!<arch>\n") {
                return [null, null, "Bu dosya bir .deb değil (ar imzası yok): {$file}"];
            }

            $hash = hash_file('sha256', $file);
            if ($hash === false) {
                return [null, null, "Özet hesaplanamadı: {$file}"];
            }

            $size = filesize($file);

            if ($given !== '' && $given !== $hash) {
                // İkisi de verilmiş ve tutmuyorsa sessizce birini seçmek en
                // kötüsü: hangisinin doğru olduğunu bilmiyoruz.
                return [null, null, "--sha256 ile dosyanın özeti tutmuyor.\n  dosya: {$hash}\n  verilen: {$given}"];
            }

            return [$hash, $size !== false ? $size : null, null];
        }

        if ($given === '') {
            return [null, null, null];
        }

        if (preg_match('/^[0-9a-f]{64}$/', $given) !== 1) {
            return [null, null, '--sha256 64 karakterlik onaltılık bir özet olmalı.'];
        }

        return [$given, null, null];
    }

    /**
     * Alt sınırı belirler; verilmediyse öncekini taşır.
     *
     * VARSAYILAN DEĞİŞTİRMEMEKTİR. Alt sınırı yayınlanan sürüme eşitlemek
     * kolay bir varsayılan olurdu ve her yayında sahadaki tüm kasaları
     * engelleyici ekrana düşürürdü.
     */
    private function resolveMinSupported(string $appId): ?string
    {
        $given = trim((string) $this->option('min-supported'));

        if ($given === '') {
            return AppRelease::latestFor($appId)?->min_supported ?? self::DEFAULT_MIN_SUPPORTED;
        }

        if (!$this->isSemVer($given)) {
            $this->components->error('--min-supported geçerli bir sürüm olmalı, örn. 1.0.0');

            return null;
        }

        $previous = AppRelease::latestFor($appId)?->min_supported;

        if ($previous !== null && $given !== $previous) {
            $this->components->warn(
                "Alt sınır {$previous} → {$given} yükseliyor: bundan eski her kasa ".
                'engelleyici güncelleme ekranına düşer.',
            );

            if (!$this->confirm('Onaylıyor musunuz?', false)) {
                return null;
            }
        }

        return $given;
    }

    private function isSemVer(string $value): bool
    {
        return preg_match('/^\d+\.\d+\.\d+$/', $value) === 1;
    }

    private function humanSize(int $bytes): string
    {
        return $bytes >= 1048576
            ? number_format($bytes / 1048576, 1).' MB'
            : number_format($bytes / 1024, 0).' KB';
    }
}
