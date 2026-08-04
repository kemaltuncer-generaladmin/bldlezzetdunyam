<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Console;

use Illuminate\Console\Command;
use Veykemtu\BridgeApi\Models\KitchenDevice;

/**
 * Mutfak cihazı yönetimi — `docs/05-mutfakapp.md` §7.
 *
 * Admin paneli ekranı gelene kadar eşleme kodunu üreten yer burasıdır.
 * Kod tek kullanımlıktır ve 10 dakika geçerlidir.
 *
 *   php artisan veykemtu:kds                      # cihazları listele
 *   php artisan veykemtu:kds --new="Mutfak Kasası"  # yeni cihaz + kod
 *   php artisan veykemtu:kds --code=1             # #1 için yeni kod üret
 *   php artisan veykemtu:kds --revoke=1           # #1'i iptal et
 */
class KitchenDeviceCommand extends Command
{
    protected $signature = 'veykemtu:kds
        {--new= : Yeni cihaz oluştur ve eşleme kodu üret}
        {--code= : Var olan cihaz için yeni eşleme kodu üret}
        {--revoke= : Cihazı iptal et (token silinir)}';

    protected $description = 'Mutfak kasalarını listeler, eşleme kodu üretir, cihaz iptal eder.';

    public function handle(): int
    {
        if (($name = $this->option('new')) !== null) {
            return $this->createDevice((string) $name);
        }

        if (($id = $this->option('code')) !== null) {
            return $this->refreshCode((int) $id);
        }

        if (($id = $this->option('revoke')) !== null) {
            return $this->revoke((int) $id);
        }

        return $this->listDevices();
    }

    private function createDevice(string $name): int
    {
        $device = new KitchenDevice;
        $device->name = mb_substr(trim($name), 0, 64);
        $device->save();

        $code = $device->refreshPairingCode();

        $this->components->info("Cihaz oluşturuldu: #{$device->id} {$device->name}");
        $this->showCode($code);

        return self::SUCCESS;
    }

    private function refreshCode(int $id): int
    {
        $device = KitchenDevice::find($id);
        if ($device === null) {
            $this->components->error("Cihaz bulunamadı: #{$id}");

            return self::FAILURE;
        }

        if ($device->isRevoked()) {
            $this->components->error('Cihaz iptal edilmiş. Yeni cihaz oluşturun.');

            return self::FAILURE;
        }

        $this->showCode($device->refreshPairingCode());

        return self::SUCCESS;
    }

    private function revoke(int $id): int
    {
        $device = KitchenDevice::find($id);
        if ($device === null) {
            $this->components->error("Cihaz bulunamadı: #{$id}");

            return self::FAILURE;
        }

        $device->revoke();
        $this->components->info("Cihaz iptal edildi: #{$device->id}. Bir sonraki istekte KDS eşleme ekranına döner.");

        return self::SUCCESS;
    }

    private function listDevices(): int
    {
        $devices = KitchenDevice::orderBy('id')->get();

        if ($devices->isEmpty()) {
            $this->components->warn('Kayıtlı cihaz yok. `--new="Mutfak Kasası"` ile oluşturun.');

            return self::SUCCESS;
        }

        $this->table(
            ['#', 'Ad', 'Durum', 'Son görülme', 'Bekleyen kod'],
            $devices->map(static fn(KitchenDevice $d): array => [
                $d->id,
                $d->name,
                $d->isRevoked() ? 'İPTAL' : ($d->tokens()->exists() ? 'eşli' : 'eşlenmemiş'),
                $d->last_seen_at?->diffForHumans() ?? '-',
                $d->pairingCodeIsUsable() ? $d->pairing_code : '-',
            ])->all(),
        );

        return self::SUCCESS;
    }

    private function showCode(string $code): void
    {
        $this->newLine();
        $this->line("  Eşleme kodu:  <fg=black;bg=yellow;options=bold> {$code} </>");
        $this->line('  Geçerlilik:   '.KitchenDevice::PAIRING_TTL_MINUTES.' dakika');
        $this->newLine();
    }
}
