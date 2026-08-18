<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Console;

use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Throwable;
use Veykemtu\BridgeApi\Models\ClosedDay;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Services\DailyStock;
use Veykemtu\BridgeApi\Services\OrderFactory;
use Veykemtu\BridgeApi\Services\SubscriptionLifecycle;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Abonelik gece üretim işi — `docs/11-yol-haritasi.md` §7.5.
 *
 * Her gece ertesi günün siparişlerini üretir; KDS'e normal sipariş olarak
 * düşer. FAZ 4'te `registerSchedule` ile kesim saatinden ÖNCE (22:00)
 * çalışacak, böylece müşteriye sabaha kadar adet değiştirme payı kalır.
 *
 * İDEMPOTENT: `veykemtu_subscription_runs` üzerindeki
 * `UNIQUE(subscription_id, delivery_point_id, service_date)` + varlık kontrolü
 * — komut iki kez koşsa da aynı gün için ikinci sipariş doğmaz.
 *
 * `menu_mode = daily_menu` abonelikleri için ÖN KONTROL var
 * ([reportMissingDailyMenus]): o günün menüsü yayınlanmamışsa vitrin başına
 * tek bir hata satırı basılır ve o abonelikler üretime hiç sokulmaz. Koşum
 * satırı yazılmadığı için menü yayınlandıktan sonra komut yeniden
 * koşturulunca sipariş doğar — başarısızlık bir sonraki denemeyi engellemez.
 *
 * STOK: bu iş porsiyon SATMAZ, önceden ayrılmış porsiyonu SATIŞA ÇEVİRİR
 * (`DailyStock::sellReserved`). Rezervasyonu gece boyunca ileriye dönük
 * tutan `veykemtu:stok-tazele` yarım saat önce koşuyor; buradaki çevrim,
 * siparişin ve koşum satırının yazıldığı İŞLEMİN İÇİNDE olmak zorunda —
 * dışarıda kalsaydı işlem geri alındığında porsiyon satılmış görünürdü.
 */
class SubscriptionGenerateCommand extends Command
{
    protected $signature = 'veykemtu:abonelik-uret
        {--date= : Servis günü YYYY-AA-GG (varsayılan: yarın, Istanbul)}
        {--dry-run : Sipariş üretmeden neyin üretileceğini göster}';

    protected $description = 'Aboneliklerden o günün siparişlerini üretir (idempotent).';

    public function handle(OrderFactory $factory, DailyStock $stock): int
    {
        $serviceDate = ($this->option('date') !== null
            ? Carbon::parse((string) $this->option('date'))
            : BusinessTime::now()->addDay())->startOfDay();
        $dryRun = (bool) $this->option('dry-run');

        if (ClosedDay::isClosed($serviceDate)) {
            $this->components->warn(
                $serviceDate->toDateString().' kapalı gün (tatil) — üretim atlandı.',
            );

            return self::SUCCESS;
        }

        // DURUM ÖNCE HİZAYA GETİRİLİR: ileri tarihli duraklatma bugün
        // başlamış ya da dün bitmiş olabilir (aşağıdaki metodun kutusuna
        // bakın). Üretim listesi çıkarılmadan önce koşmak zorunda.
        $this->syncPauseStates($dryRun);

        $subscriptions = Subscription::query()
            ->active()
            ->with(['lines', 'delivery_points', 'pauses', 'exceptions', 'customer'])
            ->get()
            ->filter(static fn(Subscription $s): bool => $s->runsOnDate($serviceDate));

        $lapsed = $this->reportLapsedPeriods($subscriptions, $serviceDate, $dryRun);

        if ($lapsed !== []) {
            $subscriptions = $subscriptions->reject(
                static fn(Subscription $s): bool => in_array((int) $s->id, $lapsed, true),
            );
        }

        $this->components->info(sprintf(
            '%s — %d abonelik bugün üretecek%s',
            $serviceDate->toDateString(),
            $subscriptions->count(),
            $dryRun ? ' (kuru koşum)' : '',
        ));

        $locationsWithoutMenu = $this->reportMissingDailyMenus($subscriptions, $serviceDate);

        $created = 0;
        $skipped = 0;
        $failed = 0;

        foreach ($subscriptions as $subscription) {
            $points = $subscription->delivery_points->all();
            // Teslimat noktası yoksa noktasız tek üretim (delivery_point_id = 0).
            $targets = $points === []
                ? [[null, 0]]
                : array_map(static fn($p): array => [$p, (int) $p->id], $points);

            foreach ($targets as [$point, $pointId]) {
                $exists = DB::table('veykemtu_subscription_runs')
                    ->where('subscription_id', $subscription->id)
                    ->where('delivery_point_id', $pointId)
                    ->where('service_date', $serviceDate->toDateString())
                    ->exists();

                if ($exists) {
                    $skipped++;

                    continue;
                }

                /*
                 * SEBEBİ ZATEN BİR KEZ SÖYLENDİ.
                 *
                 * Menüsü olmayan bir vitrinin `daily_menu` abonelikleri
                 * burada üretime hiç sokulmuyor: `OrderFactory` her biri
                 * için ayrı ayrı patlar ve 40 abonelikte 40 satırlık,
                 * hepsi aynı şeyi söyleyen bir hata yığını çıkardı.
                 * Hata SAYILIYOR (komut FAILURE dönsün, zamanlayıcı
                 * sessizce başarılı görünmesin) ama tekrar yazılmıyor.
                 */
                if ($subscription->menu_mode === Subscription::MENU_DAILY
                    && in_array((int) $subscription->location_id, $locationsWithoutMenu, true)
                ) {
                    $failed++;

                    continue;
                }

                if ($dryRun) {
                    $this->components->twoColumnDetail(
                        'Abonelik #'.$subscription->id.($pointId > 0 ? ' / nokta '.$pointId : ''),
                        $subscription->quantityForDate($serviceDate).' porsiyon üretilecek',
                    );
                    $created++;

                    continue;
                }

                try {
                    DB::transaction(function () use (
                        $factory, $stock, $subscription, $point, $pointId, $serviceDate,
                    ): void {
                        $order = $factory->createForSubscription($subscription, $point, $serviceDate);

                        DB::table('veykemtu_subscription_runs')->insert([
                            'subscription_id' => $subscription->id,
                            'delivery_point_id' => $pointId,
                            'service_date' => $serviceDate->toDateString(),
                            'order_id' => $order->order_id,
                            'created_at' => BusinessTime::forStorage(BusinessTime::now()),
                        ]);

                        /*
                         * REZERVASYON SATIŞA DÖNÜYOR — tek atomik ifadeyle.
                         *
                         * Talep YAZILMIŞ SATIRLARDAN okunuyor
                         * (`demandOf`), abonelik kuralından değil: satışa
                         * çevrilen miktar, mutfağa gerçekten düşen satırların
                         * ta kendisi olmalı. İptal geldiğinde stoku geri
                         * veren `releaseOrder()` de aynı kaynağı okuyor;
                         * ikisi ayrılırsa iptal, satılandan başka bir
                         * miktarı geri verir ve fark her seferinde birikir.
                         */
                        $stock->sellReserved(
                            (int) $subscription->location_id,
                            $serviceDate,
                            $stock->demandOf($order),
                        );
                    });
                    $created++;
                } catch (Throwable $e) {
                    $this->components->error('Abonelik #'.$subscription->id.': '.$e->getMessage());
                    $failed++;
                }
            }
        }

        $this->components->info(sprintf(
            '%d üretildi, %d zaten vardı, %d hata.',
            $created,
            $skipped,
            $failed,
        ));

        return $failed > 0 ? self::FAILURE : self::SUCCESS;
    }

    /**
     * `daily_menu` abonelikleri için menüsü YAYINLANMAMIŞ vitrinleri bulur
     * ve her biri için TEK bir yüksek sesli hata satırı basar.
     *
     * NEDEN ÖN KONTROL: gece işi 22:00'de yarın için koşuyor. Yarının
     * menüsü o saate kadar yayınlanmamışsa yüzlerce porsiyon düşer ve bunu
     * gören tek yer bu komutun çıktısı. Kontrol döngünün içinde kalsaydı
     * mesaj abonelik sayısı kadar tekrarlanır, gerçek sebep yığın izlerinin
     * arasında kaybolurdu.
     *
     * @param  Collection<int, Subscription>  $subscriptions
     * @return list<int>  Menüsü olmayan vitrinlerin kimlikleri
     */
    private function reportMissingDailyMenus(Collection $subscriptions, Carbon $serviceDate): array
    {
        $missing = [];

        $daily = $subscriptions->filter(
            static fn(Subscription $s): bool => $s->menu_mode === Subscription::MENU_DAILY,
        );

        foreach ($daily->groupBy('location_id') as $locationId => $group) {
            $locationId = (int) $locationId;

            if (DailyMenu::findPublished($locationId, $serviceDate) !== null) {
                continue;
            }

            $missing[] = $locationId;

            $portions = $group->sum(
                static fn(Subscription $s): int => max(1, $s->quantityForDate($serviceDate)),
            );

            $this->components->error(sprintf(
                '%s için GÜNÜN MENÜSÜ YAYINLANMAMIŞ (vitrin #%d): %d abonelik, '
                    .'%d porsiyon üretilemiyor. Menüyü yayınlayıp '
                    .'`php artisan veykemtu:abonelik-uret --date=%s` komutunu tekrar koşun.',
                $serviceDate->toDateString(),
                $locationId,
                $group->count(),
                $portions,
                $serviceDate->toDateString(),
            ));
        }

        return $missing;
    }

    /**
     * Duraklatma penceresine göre abonelik durumunu hizalar — I2.
     *
     * ═════════════════════════════════════════════════════════════════════
     * NEDEN GEREKLİ: `pause()` ARTIK DURUMU HEMEN DEĞİŞTİRMİYOR.
     *
     * Eskiden ileri tarihli bir duraklatma aboneliği ANINDA `paused`
     * yapıyordu ve `runsOnDate()` ilk kontrolü `status !== active` olduğu
     * için BUGÜNÜN üretimi de sessizce kesiliyordu. Kural düzeltildi:
     * durum yalnız pencere gerçekten yürürlükteyken değişiyor.
     *
     * Bunun bedeli, pencerenin BAŞLADIĞI günü birinin fark etmesi. O iş
     * buraya düştü çünkü zaten her gece koşan ve üretim listesini çıkaran
     * yer burası; ayrı bir zamanlanmış iş yazmak, iki işin sırasına bağlı
     * yeni bir yarış açardı.
     * ═════════════════════════════════════════════════════════════════════
     *
     * İKİ YÖN DE İŞLENİYOR:
     *   · pencere bugün kapsıyor + abonelik `active` → `paused`,
     *   · pencere bitti + abonelik `paused` + AÇIK duraklatma yok → `active`.
     *
     * İKİNCİ YÖN NEDEN GÜVENLİ: `paused` iki sebepten olabiliyor (yönetici
     * duraklattı / ödenmiş dönem bitti). Geri açma YALNIZ duraklatma satırı
     * gerçekten bitmişse yapılıyor; dönem bitişiyle duraklatılan abonelikte
     * hiç duraklatma satırı YOKTUR ve buraya hiç girmez. Girseydi ödemesiz
     * üretim açardı — bu dosyadaki en pahalı hata.
     */
    private function syncPauseStates(bool $dryRun): void
    {
        $today = BusinessTime::now()->startOfDay();

        $subscriptions = Subscription::query()
            ->whereIn('status', [Subscription::STATUS_ACTIVE, Subscription::STATUS_PAUSED])
            ->with('pauses')
            ->get();

        $started = [];
        $ended = [];

        foreach ($subscriptions as $subscription) {
            $covering = $subscription->pauseCovering($today);
            $status = (string) $subscription->status;

            if ($covering !== null && $status === Subscription::STATUS_ACTIVE) {
                $started[] = (int) $subscription->id;

                if (!$dryRun) {
                    $subscription->status = Subscription::STATUS_PAUSED;
                    $subscription->save();
                }

                continue;
            }

            if ($covering !== null || $status !== Subscription::STATUS_PAUSED) {
                continue;
            }

            // BİTMİŞ BİR DURAKLATMA SATIRI ŞART. Yoksa bu `paused` başka bir
            // sebeptendir (ödenmiş dönem bitti) ve dokunulmaz.
            $hadPause = $subscription->pauses->contains(
                static fn($p): bool => $p->cancelled_at === null
                    && $p->end_date->copy()->startOfDay()->lt($today),
            );

            if (!$hadPause) {
                continue;
            }

            $ended[] = (int) $subscription->id;

            if (!$dryRun) {
                $subscription->status = Subscription::STATUS_ACTIVE;
                $subscription->save();
            }
        }

        foreach ([['duraklatma başladı', $started], ['duraklatma bitti', $ended]] as [$label, $ids]) {
            if ($ids !== []) {
                $this->components->info(sprintf(
                    '%s — %d abonelik (#%s)%s',
                    $label,
                    count($ids),
                    implode(', #', $ids),
                    $dryRun ? ' (kuru koşum — durum DEĞİŞTİRİLMEDİ)' : '',
                ));
            }
        }
    }

    /**
     * Ödenmiş dönemi biten abonelikleri duraklatır ve TEK gürültülü satır basar.
     *
     * NEDEN BURADA, EKSİK MENÜ KONTROLÜNÜN YANINDA: ikisi de aynı soruyu
     * soruyor — "bu abonelik bu gece üretime girebilir mi?" — ve ikisinin de
     * cevabı üretim döngüsünden ÖNCE bilinmeli. Kontrol döngünün içinde
     * kalsaydı mesaj abonelik sayısı kadar tekrarlanır, gerçek sebep hata
     * yığınının arasında kaybolurdu.
     *
     * NEDEN KOMUT BAŞARISIZ SAYILMIYOR: dönem bitişi bir sistem arızası
     * değil, bir TAHSİLAT işidir ve normal seyrinde her ay yaşanır. Komutu
     * FAILURE döndürseydik zamanlayıcının alarmı her dönem sonunda çalar ve
     * gerçek arızaların (menü yayınlanmamış, `OrderFactory` patlamış)
     * sinyalini boğardı. Görünürlük satırın kendisinden geliyor.
     *
     * @param  Collection<int, Subscription>  $subscriptions
     * @return list<int>  Duraklatılan aboneliklerin kimlikleri
     */
    private function reportLapsedPeriods(
        Collection $subscriptions,
        Carbon $serviceDate,
        bool $dryRun,
    ): array {
        /*
         * KAPSAYICIDAN ÇÖZÜLÜYOR, `handle()` İMZASINA EKLENMİYOR: bu bir ön
         * kontrol yardımcısı ve komutun ana bağımlılıkları (sipariş üreteci,
         * stok) ile aynı düzeyde değil.
         */
        $lifecycle = app(SubscriptionLifecycle::class);

        $lapsed = [];
        $portions = 0;

        foreach ($subscriptions as $subscription) {
            if ($lifecycle->isCovered($subscription, $serviceDate)) {
                continue;
            }

            $lapsed[] = (int) $subscription->id;
            $portions += max(1, $subscription->quantityForDate($serviceDate))
                * max(1, $subscription->delivery_points->count());

            // Kuru koşumda hiçbir şey YAZILMAZ — `--dry-run` "neyin olacağını
            // göster" demek; aboneliği gerçekten duraklatsaydı en zararsız
            // seçenek en yıkıcı olanı olurdu.
            if (!$dryRun) {
                $lifecycle->transition($subscription, SubscriptionLifecycle::EVENT_PERIOD_LAPSED);
            }
        }

        if ($lapsed !== []) {
            $this->components->error(sprintf(
                '%s — ÖDENMİŞ DÖNEMİ BİTEN %d abonelik DURAKLATILDI (#%s): %d porsiyon '
                    .'üretilmedi. Yeni dönem ödemesi alınana kadar üretim durur.%s',
                $serviceDate->toDateString(),
                count($lapsed),
                implode(', #', $lapsed),
                $portions,
                $dryRun ? ' (kuru koşum — durum DEĞİŞTİRİLMEDİ)' : '',
            ));
        }

        return $lapsed;
    }
}
