<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Console;

use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Models\SmsTemplate;
use Veykemtu\BridgeApi\Services\Sms\SmsDispatcher;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Günün menüsü SMS duyurusu — B1.
 *
 * `Extension::registerSchedule()` bunu her gün panelden ayarlanan saatte
 * (`bld_menu_announce_time`, varsayılan 09:00) koşturur.
 *
 * ═════════════════════════════════════════════════════════════════════════
 * DUYURU BİR GÜN ÖNCEDEN GİDER (18.08.2026, kullanıcı kararı).
 *
 * Pazartesi koşan iş SALI'nın menüsünü duyurur. Sebep işin kendi mantığı:
 * müşteri menüyü görüp sipariş verecek, ama siparişin bir KESİM SAATİ var
 * (`bld_order_cutoff`). Aynı günün menüsü sabah duyurulduğunda müşteriye
 * karar vermek için birkaç saat kalıyor ve kesim saatini kaçıranlar için
 * duyuru bir işe yaramıyordu — okunduğunda sipariş verilemeyen bir menü.
 *
 * BU YÜZDEN MENÜNÜN BİR GÜN ÖNCEDEN YAYINLANMIŞ OLMASI GEREKİR. Yayınlanmamış
 * bir gün için duyuru GİTMEZ (aşağıdaki `STATUS_PUBLISHED` süzgeci) ve komut
 * bunu uyarı olarak yazar — sessizce boş geçmez. Yani menü girilmemişse
 * müşteriye "yarın şu var" diyen bir SMS asla çıkmaz.
 *
 * `--date` verilirse o gün duyurulur; bir gün ekleme YAPILMAZ. Elle koşan
 * kişi hangi günü istediğini zaten söylemiştir.
 * ═════════════════════════════════════════════════════════════════════════
 *
 * ═════════════════════════════════════════════════════════════════════════
 * ŞABLON (`dailymenu.announce`) İMZA GELENE KADAR **KAPALI** KALIR.
 *
 * Bu bir teknik eksiklik değil, HUKUKİ bir sınırdır. Sipariş durum SMS'i
 * müşterinin kendi verdiği siparişin bilgilendirmesidir ve izin gerektirmez;
 * günün menüsü duyurusu ise TİCARİ ELEKTRONİK İLETİDİR. 6563 sayılı kanun
 * ve İYS (İleti Yönetim Sistemi) alıcının ÖNCEDEN ONAYINI, onay kaydının
 * İYS'ye işlenmesini ve her iletide çıkış hakkını zorunlu kılar. Onaysız
 * toplu ticari SMS'in bedeli alıcı başına idari para cezasıdır ve gönderim
 * geri alınamaz.
 *
 * `customers.bld_sms_opt_out` bugün REDDİ tutuyor, ONAYI değil — ikisi
 * aynı şey değildir. Komut bu yüzden eksiksiz çalışır durumda duruyor ama
 * şablon kapalı olduğu için hiçbir şey göndermiyor: iş tarafı onay akışını
 * kurup şablonu açtığı gün altyapı hazır olacak, o gün aceleyle yazılmış
 * bir toplu gönderim koşmayacak.
 * ═════════════════════════════════════════════════════════════════════════
 *
 * SINIF ADI `Extension::registerPendingConsoleCommands()` TARAFINDAN
 * SABİTLENMİŞTİR (`Console\MenuAnnounceCommand`). Orası bu eklentinin
 * "rota dosyası"dır: kayıt sınıf adını dize olarak taşıyor, sınıf ona uyar.
 * Ad ayrışsaydı `class_exists()` `false` dönerdi, komut hiç kaydedilmezdi
 * ve zamanlama her gün sessizce boşa koşardı — açılışta da `route:list`
 * benzeri hiçbir denetimde de hata görünmezdi.
 */
class MenuAnnounceCommand extends Command
{
    /**
     * Kitle penceresi: son bu kadar günde siparişi olan müşteriler.
     *
     * `docs/control/sms.md` `active_customers` kitlesini "son 180 günde
     * siparişi olan" diye tanımlıyor; duyuru kitlesi onunla aynı olmak
     * zorunda, yoksa panelde görünen tahminle gerçekte gidenler ayrışır.
     */
    private const int RECENT_ORDER_DAYS = 180;

    /**
     * Duyuru kaç gün sonrasının menüsünü anlatır.
     *
     * 1 = YARIN. Sabit tutuluyor: ayara bağlansaydı "0" yazan bir kurulum
     * aynı günü duyurur ve kesim saatini kaçıran müşteriye işe yaramaz bir
     * SMS gönderirdi — kaçtığımız davranış tam olarak buydu.
     */
    private const int ANNOUNCE_DAYS_AHEAD = 1;

    protected $signature = 'veykemtu:menu-duyur
        {--date= : Menü günü YYYY-AA-GG (varsayılan: YARIN, Istanbul)}
        {--dry-run : Hiçbir SMS göndermeden kimlere gideceğini yaz}
        {--limit= : En çok bu kadar alıcıya gönder}';

    protected $description = 'YARININ menüsünü, son siparişi olan müşterilere SMS ile duyurur.';

    public function handle(SmsDispatcher $sms): int
    {
        // Varsayılan YARIN. `--date` verildiyse ona dokunulmaz: elle koşan
        // kişi hangi günü istediğini söylemiştir, üstüne bir gün eklemek
        // "istediğim gün gitmedi" demenin en kolay yoluydu.
        $date = $this->option('date') !== null
            ? Carbon::parse((string) $this->option('date'))->startOfDay()
            : BusinessTime::now()->startOfDay()->addDays(self::ANNOUNCE_DAYS_AHEAD);

        $dryRun = (bool) $this->option('dry-run');
        $limit = $this->option('limit') !== null ? (int) $this->option('limit') : null;

        if (!$this->assertTemplateReady()) {
            return self::SUCCESS;
        }

        $menus = DailyMenu::query()
            ->with(['items', 'items.menu'])
            ->whereDate('menu_date', $date->toDateString())
            ->where('status', DailyMenu::STATUS_PUBLISHED)
            ->get();

        if ($menus->isEmpty()) {
            /*
             * Menüsüz gün olağandır (hafta sonu, tatil) ve HATA DEĞİLDİR:
             * FAILURE dönseydi zamanlayıcı her hafta sonu iki kez alarm
             * üretir, gerçek arızalar o gürültünün içinde kaybolurdu.
             */
            $this->components->warn(sprintf(
                '%s için YAYINLANMIŞ menü yok — duyuru atlandı. Duyuru bir gün '
                .'önceden gittiği için o günün menüsünün bugün yayınlanmış '
                .'olması gerekir (taslak yetmez).',
                $date->toDateString(),
            ));

            return self::SUCCESS;
        }

        $sent = 0;

        foreach ($menus as $menu) {
            $remaining = $limit !== null ? $limit - $sent : null;

            if ($remaining !== null && $remaining <= 0) {
                break;
            }

            $sent += $this->announce($sms, $menu, $date, $dryRun, $remaining);
        }

        $this->components->info(sprintf(
            '%s — %d alıcı%s',
            $date->toDateString(),
            $sent,
            $dryRun ? ' (kuru koşum, hiçbir SMS gönderilmedi)' : '',
        ));

        return self::SUCCESS;
    }

    /**
     * Şablon var mı ve açık mı?
     *
     * KAPALI ŞABLON YÜKSEK SESLE SÖYLENİR. `SmsDispatcher` kapalı şablonda
     * sessizce dönüyor; komut da sessiz kalsaydı çıktı "0 alıcı" olurdu ve
     * yönetici sebebi kitle sorgusunda, opt-out kolonunda, menü yayınında
     * ararken şablon anahtarını aklına bile getirmezdi.
     */
    private function assertTemplateReady(): bool
    {
        $template = SmsTemplate::findByKey(SmsTemplate::KEY_DAILY_MENU_ANNOUNCE);

        if ($template === null) {
            $this->components->error(sprintf(
                '`%s` şablonu yok — göçler koşturulmamış olabilir '
                    .'(`php artisan igniter:up`).',
                SmsTemplate::KEY_DAILY_MENU_ANNOUNCE,
            ));

            return false;
        }

        if (!$template->enabled) {
            $this->components->warn(sprintf(
                '`%s` şablonu KAPALI — hiçbir SMS gönderilmedi. Toplu ticari '
                    .'ileti için İYS onayı ve açık rıza gerekiyor; şablon o imza '
                    .'gelene kadar kapalı kalır.',
                SmsTemplate::KEY_DAILY_MENU_ANNOUNCE,
            ));

            return false;
        }

        return true;
    }

    /**
     * Tek bir vitrinin menüsünü o vitrinin kitlesine duyurur.
     *
     * @param  ?int  $remaining  Kalan gönderim hakkı (`--limit`); `null` sınırsız.
     * @return int Ele alınan alıcı sayısı.
     */
    private function announce(
        SmsDispatcher $sms,
        DailyMenu $menu,
        Carbon $date,
        bool $dryRun,
        ?int $remaining,
    ): int {
        $items = $menu->items
            ->map(static fn($item): string => (string) ($item->menu?->menu_name ?? ''))
            ->filter(static fn(string $name): bool => $name !== '')
            ->implode(', ');

        if ($items === '') {
            $this->components->warn(sprintf(
                'Vitrin #%d menüsünde kalem yok — duyuru atlandı.',
                (int) $menu->location_id,
            ));

            return 0;
        }

        $recipients = $this->recipients((int) $menu->location_id, $remaining);
        $count = 0;

        foreach ($recipients as $recipient) {
            $sms->send(
                SmsTemplate::KEY_DAILY_MENU_ANNOUNCE,
                (string) $recipient->telephone,
                [
                    'customer_name' => $this->greeting($recipient),
                    'date' => $date->format('d.m.Y'),
                    'menu' => $items,
                ],
                /*
                 * REFERANS GÜNÜ DE MÜŞTERİYİ DE TAŞIMAK ZORUNDA.
                 *
                 * Benzersiz indeks (template_key, reference_type,
                 * reference_id) üçlüsü. Gün referans TÜRÜNE girmeseydi
                 * yarının duyurusu bugünkünün satırına çarpar ve hiç
                 * gitmezdi; müşteri referans KİMLİĞİNE girmeseydi 500
                 * alıcı tek satıra çökerdi ve yalnız ilki mesaj alırdı.
                 * Yan fayda: aynı müşteri iki vitrinden sipariş vermişse
                 * duyuruyu bir kez alır.
                 */
                SmsDispatcher::REF_DAILY_MENU_PREFIX.$date->toDateString(),
                (int) $recipient->customer_id,
                $dryRun,
            );

            $count++;
        }

        return $count;
    }

    /**
     * Duyuru kitlesi: son [RECENT_ORDER_DAYS] günde bu vitrinden siparişi
     * olan, aktif, numarası olan ve **reddetmemiş** müşteriler.
     *
     * `DISTINCT` şart: bir müşterinin altı ayda on siparişi olabilir ve
     * `JOIN` onu on kez döndürürdü — indeks ikinci mesajı yutardı ama
     * `--limit` on kişilik hakkı tek müşteriye harcardı.
     *
     * @return Collection<int, object>
     */
    private function recipients(int $locationId, ?int $remaining): Collection
    {
        $since = BusinessTime::now()->subDays(self::RECENT_ORDER_DAYS)->toDateString();

        $query = DB::table('customers as c')
            ->join('orders as o', 'o.customer_id', '=', 'c.customer_id')
            ->where('o.location_id', $locationId)
            ->where('o.order_date', '>=', $since)
            ->where('c.status', 1)
            ->where('c.bld_sms_opt_out', 0)
            ->whereNotNull('c.telephone')
            ->where('c.telephone', '<>', '')
            ->select('c.customer_id', 'c.first_name', 'c.last_name', 'c.telephone')
            ->distinct()
            ->orderBy('c.customer_id');

        if ($remaining !== null) {
            $query->limit($remaining);
        }

        return $query->get();
    }

    /**
     * SMS'teki hitap.
     *
     * Adı olmayan müşteri için "Sayın ," yazmaktansa nötr bir hitap: boş
     * bırakılan bir değişken müşteriye eksik cümle olarak gider.
     */
    private function greeting(object $recipient): string
    {
        $name = trim((string) ($recipient->first_name ?? '').' '.(string) ($recipient->last_name ?? ''));

        return $name !== '' ? $name : 'müşterimiz';
    }
}
