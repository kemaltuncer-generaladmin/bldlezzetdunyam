<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Console;

use Igniter\Local\Models\Location;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Log;
use Veykemtu\BridgeApi\Services\DailyStock;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Abonelik rezervasyonlarının gecelik uzlaştırması — iş kuralı 6.
 *
 * NEDEN VAR: `reserved` İLERİYE DÖNÜK bir sayıdır. D+5'in serbest satışı,
 * D+5'in abonelik siparişi doğmadan çok önce açılıyor; rezervasyon sipariş
 * üretimine bağlansaydı o beş gün boyunca kapasite boşmuş gibi görünür ve
 * aboneye ayrılmış porsiyonlar serbest satışta tükenirdi. Bu yüzden
 * rezervasyon, ileri görüş penceresinin TAMAMI için ve SIFIRDAN hesaplanır
 * (`DailyStock::syncReservedWindow`).
 *
 * NEDEN HER GECE, ÜRETİMDEN ÖNCE (21:30 / 22:00): artımlı kancalar
 * (aktifleştirme, duraklatma, devam, iptal, gün atlama, menü yayınlama)
 * kaçınılmaz olarak eksik kalır — bir kanca unutulur, bir istek yarıda
 * kesilir, bir kayıt panelden elle düzeltilir. Sıfırdan hesap her gece
 * koştuğu için her artımlı hata en geç 24 saat içinde kendini onarır ve
 * onarım ÜRETİMDEN ÖNCE olur. Sıra ters olsaydı hata, üretimin sonucuna
 * yansıdıktan sonra düzeltilirdi — yani sessiz aşırı satıştan sonra.
 *
 * SAPMA GÜRÜLTÜLÜ OLMALI. Her düzeltme hem çıktıya hem günlüğe yazılıyor:
 * uzlaştırmanın sürekli aynı günü düzeltmesi, artımlı yolda kırık bir kanca
 * olduğunun tek işareti. Sessizce düzeltseydi sistem "çalışıyor" görünür,
 * asıl arıza hiç fark edilmezdi.
 *
 * KOMUT SAPMAYI HATA SAYMAZ (`SUCCESS` döner): sapma bu işin normal ürünü,
 * arıza değil. Zamanlayıcıyı kırmızıya boyamak, gerçek bir çökme ile rutin
 * bir düzeltmeyi aynı renge boyardı.
 */
class StockReconcileCommand extends Command
{
    protected $signature = 'veykemtu:stok-tazele
        {--date= : Yalnız bu servis gününü uzlaştır (YYYY-AA-GG)}
        {--location= : Yalnız bu vitrin (varsayılan: hepsi)}
        {--dry-run : Hiçbir şey yazma, yalnız sapmayı göster}';

    protected $description = 'Abonelik rezervasyonlarını ileri görüş penceresi boyunca sıfırdan hesaplar.';

    public function handle(DailyStock $stock, LocationGate $gate): int
    {
        $dryRun = (bool) $this->option('dry-run');
        $locations = $this->locations();

        if ($locations === []) {
            $this->components->warn('Uzlaştırılacak vitrin yok.');

            return self::SUCCESS;
        }

        $total = 0;

        foreach ($locations as $location) {
            [$from, $to] = $this->window($location, $gate);

            $deviations = $stock->syncReservedWindow(
                (int) $location->location_id,
                $from,
                $to,
                !$dryRun,
            );

            $this->components->info(sprintf(
                'Vitrin #%d — %s .. %s (%d gün): %d sapma%s',
                $location->location_id,
                $from->toDateString(),
                $to->toDateString(),
                $from->diffInDays($to) + 1,
                count($deviations),
                $dryRun ? ' (kuru koşum, yazılmadı)' : '',
            ));

            $this->report((int) $location->location_id, $deviations, $dryRun);
            $total += count($deviations);
        }

        $this->components->info($total === 0
            ? 'Rezervasyonlar zaten doğru.'
            : $total.' satır uzlaştırıldı.');

        return self::SUCCESS;
    }

    /**
     * Uzlaştırılacak vitrinler.
     *
     * @return list<Location>
     */
    private function locations(): array
    {
        $only = $this->option('location');

        return Location::query()
            ->when(
                is_numeric($only),
                static fn($query) => $query->where('location_id', (int) $only),
            )
            ->get()
            ->all();
    }

    /**
     * Uzlaştırma penceresi — BUGÜNDEN başlar.
     *
     * BUGÜN NEDEN DÂHİL: bugünün siparişleri dün gece üretildi ve
     * `veykemtu_subscription_runs` satırları var, yani hesap onları
     * rezerve etmez — ama üretimi başarısız olmuş bir abonelik varsa
     * porsiyonu hâlâ rezerve olmalı. Bugünü dışarıda bırakmak, o
     * porsiyonu sessizce serbest satışa açardı.
     *
     * SON GÜN VİTRİNİN İLERİ GÖRÜŞÜ: satışın açık olduğu son gün neresiyse
     * rezervasyonun da oraya kadar gitmesi gerekiyor. Daha kısa bir pencere,
     * satışa açık ama rezervasyonsuz bir kuyruk bırakırdı.
     *
     * @return array{0: Carbon, 1: Carbon}
     */
    private function window(Location $location, LocationGate $gate): array
    {
        $single = $this->option('date');

        if ($single !== null) {
            $date = Carbon::parse((string) $single)->startOfDay();

            return [$date, $date->copy()];
        }

        $from = BusinessTime::now()->startOfDay();

        return [$from, $from->copy()->addDays($gate->maxLookaheadDays($location))];
    }

    /**
     * Sapmaları çıktıya ve günlüğe yazar.
     *
     * @param  list<array{service_date: string, menu_id: int, from: int, to: int}>  $deviations
     */
    private function report(int $locationId, array $deviations, bool $dryRun): void
    {
        foreach ($deviations as $deviation) {
            $this->components->twoColumnDetail(
                $deviation['service_date'].' · '.$this->label($deviation['menu_id']),
                $deviation['from'].' → '.$deviation['to'].' porsiyon',
            );
        }

        if ($deviations === []) {
            return;
        }

        /*
         * GÜNLÜĞE DE YAZILIYOR, ÇIKTIYA DA. Zamanlanmış iş arka planda
         * koşuyor (`runInBackground`) ve çıktısını kimse okumuyor; sapmanın
         * kalıcı izi yalnız günlükte kalır. Seviye `warning`: her gece
         * tekrarlayan bir sapma, artımlı kancalardan birinin kırık olduğu
         * anlamına gelir ve bakılması gerekir.
         */
        Log::warning('Abonelik rezervasyonu uzlaştırıldı.', [
            'location_id' => $locationId,
            'dry_run' => $dryRun,
            'deviations' => $deviations,
        ]);
    }

    private function label(int $menuId): string
    {
        return $menuId === DailyStock::DAY_TOTAL
            ? 'gün toplamı'
            : 'ürün #'.$menuId;
    }
}
