<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Admin;

use Igniter\Admin\Classes\AdminController;
use Igniter\Admin\Facades\AdminMenu;
use Igniter\Cart\Models\Menu;
use Igniter\Flame\Exception\FlashException;
use Igniter\Local\Models\Location;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Request;
use Throwable;
use Veykemtu\BridgeApi\Admin\AdminRegistrar;
use Veykemtu\BridgeApi\Admin\LiraField;
use Veykemtu\BridgeApi\Admin\SettingsRepository;
use Veykemtu\BridgeApi\Models\ClosedDay;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Models\DailyMenuItem;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Services\SiteRevalidator;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Aylık menü takvimi — B-19'un kilit taşı.
 *
 * Yeni satış rejiminde katalog satılmıyor: yönetici takvimden gün gün menü
 * giriyor ve o gün YALNIZ o menü satılıyor (paket olarak ya da kalem kalem).
 * Menü girilmeden ne web ne mobil sınanabilir; bu yüzden ekran turun ilk
 * çıktısı.
 *
 * ÇEKİRDEK `ListController`/`FormController` KULLANILMIYOR. Sebep
 * `PhoneOrders` ile aynı ama daha keskin: burada kaydedilen şey tek bir model
 * değil — bir gün kaydı, N kalem satırı, kopyalama semantiği ve toplu durum
 * değişimi birlikte yaşıyor. Çekirdeğin form denetleyicisi "bir model bir
 * kayıt" varsayımıyla çalışır ve bu ekranın her adımında o varsayımla kavga
 * etmek gerekirdi. Ayrıca ekranın birincil görünümü bir LİSTE değil, bir AY
 * IZGARASI: yönetici "18 Ağustos'ta ne var" sorusunu satır satır bir listede
 * değil, takvimde cevaplıyor.
 *
 * ÜÇ KURAL — kodda ve `docs/09-gorev-plani.md`'de gerekçesiyle:
 *
 *  1. **KOPYA HER ZAMAN TASLAK OLARAK DÜŞER** (`copyDay()`). Bir ayı kazara
 *     yayına almak, `status` alanının var olma sebebi olan sızıntının ta
 *     kendisi: yarım girilmiş bir perşembe kaydedildiği anda müşteriye
 *     görünür ve pişmeyecek bir yemek satılır.
 *
 *  2. **KAPALI GÜNLER HER ZAMAN ATLANIR** (`copyDay()`), overwrite verilse
 *     bile. `DailyMenuService::verdict()` kapalı günü zaten her şeyin
 *     önünde tutuyor; kopyanın oraya menü yazması, ızgarada "yayında"
 *     görünen ama satılamayan bir gün üretirdi.
 *
 *  3. **SİPARİŞİ OLAN GÜN KİLİTLİ** (`assertUnlocked()`).
 *     `package_price_kurus`, `status` ve kalem satırları donar; başlık,
 *     açıklama ve iç not düzenlenebilir kalır (kozmetik, üstelik sipariş
 *     satırındaki ad `orderLineName()` ile zaten kopyalanmış durumda).
 *     GEREKÇE: `OrderEditor` paketi gün satırından YENİDEN fiyatlıyor.
 *     Sipariş varken fiyat değiştirilseydi, yalnızca notu düzelten bir
 *     revizyon siparişi sessizce yeniden fiyatlandırır ve cari deftere
 *     uydurma bir iade/ek ücret yazardı — üstelik defter revizyon başına
 *     idempotent olduğu için KENDİLİĞİNDEN DÜZELMEZ.
 *
 * ÖLÜMCÜL TUZAK — HER AJAX İŞLEYİCİSİNİN İLK ARGÜMANI BAĞLAMDIR. Çekirdek
 * `AdminController::processHandlers()` işleyiciyi `[$this->action, ...$params]`
 * ile çağırıyor. Tek parametreli yazılan bir `onXxx(?string $date)` metodu
 * `$date` olarak `"index"` alır, günü bulamaz ve ekran sebebi anlaşılmayan
 * bir `406` döner (B-14'te sahada oldu, `CustomerAccounts::onRecordPayment`
 * docblock'unda yazıyor). Bu yüzden buradaki her işleyicinin imzası
 * `(string $context, ?string $recordId = null)` ile başlar ve
 * `AdminDailyMenuTest` bunu yansımayla kilitliyor.
 */
class DailyMenus extends AdminController
{
    private const string BASE_URI = AdminRegistrar::DAILY_MENUS_URI;

    /** Ayı seçen sorgu parametresi (`?ay=2026-09`). */
    private const string MONTH_PARAM = 'ay';

    protected null|string|array $requiredPermissions = AdminRegistrar::PERMISSION_DAILY_MENU;

    public function __construct()
    {
        parent::__construct();

        AdminMenu::setContext('bld_daily_menus', 'restaurant');
    }

    /**
     * Ay ızgarası.
     *
     * `void` dönüyor: çekirdek `execPageAction` `null` sonucu görünce
     * `resources/views/dailymenus/index.blade.php` görünümünü çiziyor.
     */
    public function index(): void
    {
        AdminMenu::setContext('bld_daily_menus', 'restaurant');

        $this->prepareVars();
    }

    // ── İşleyiciler ───────────────────────────────────────────────────────

    /**
     * Bir günün menüsünü yazar (yoksa TASLAK olarak açar).
     *
     * YENİ GÜN HER ZAMAN TASLAK DOĞAR — kopyalamayla aynı gerekçe (sınıf
     * yorumu §1). Yayına alma ayrı bir düğme ve ayrı bir işleyicidir;
     * "kaydet" ile "sat" aynı harekete bağlansaydı yarım girilmiş bir gün
     * kaydedildiği anda satışa çıkardı.
     *
     * KİLİTLİ GÜNDE YAPISAL ALANLAR HİÇ GÖNDERİLMEZ (düzenleyici o bloğu
     * `<fieldset disabled>` ile kapatıyor ve jQuery `serialize()` devre dışı
     * alanları atlıyor). Sunucu buna güvenmiyor: alanlar yine de gelirse
     * (eski sekme, elle atılmış istek) kayıt tamamen reddedilir. Sessizce
     * yok saymak, yöneticinin girdiği fiyatın kaydedildiğini sanmasına yol
     * açardı.
     */
    public function onSaveDay(string $context, ?string $recordId = null): RedirectResponse
    {
        $post = Request::post();
        $location = $this->requireLocation();
        $date = $this->parseDate($post['day_date'] ?? null);

        $menu = $this->findDay($location, $date);
        $locked = $menu !== null && $this->orderCountFor($location, $date) > 0;

        throw_if(
            $locked && $this->structuralPayloadPresent($post),
            new FlashException(sprintf(
                lang('veykemtu.bridgeapi::dailymenu.alert_locked'),
                $date->format('d.m.Y'),
            )),
        );

        // Kalemler ve fiyat İŞLEM DIŞINDA çözülüyor: doğrulama hatası
        // (aynı ürün iki kez, paket ürünü kalem olarak) veritabanına hiç
        // dokunmadan dönmeli.
        $items = $locked ? null : $this->collectItems($post);
        $packagePrice = $locked ? null : $this->parsePackagePrice($post['package_price'] ?? null);

        $menu = DB::transaction(function () use (
            $location, $date, $menu, $locked, $items, $packagePrice, $post,
        ): DailyMenu {
            $menu ??= $this->newDraftDay($location, $date);

            $menu->title = $this->trimmedOrNull($post['title'] ?? null);
            $menu->description = $this->trimmedOrNull($post['description'] ?? null);
            $menu->internal_note = $this->trimmedOrNull($post['internal_note'] ?? null);

            if (!$locked) {
                $menu->package_price_kurus = $packagePrice;
                $menu->components_sellable = (bool) ($post['components_sellable'] ?? false);
            }

            $menu->save();

            if ($items !== null) {
                $this->replaceItems($menu, $items);
            }

            return $menu;
        });

        // Yayındaki bir günün içeriği değiştiyse site bayatladı.
        if ($menu->isPublished()) {
            $this->refreshSite();
        }

        flash()->success(sprintf(
            lang($locked
                ? 'veykemtu.bridgeapi::dailymenu.alert_saved_locked'
                : 'veykemtu.bridgeapi::dailymenu.alert_saved'),
            $date->format('d.m.Y'),
        ));

        $this->warnIfPackageUnsellable($location, $menu);

        return $this->backToMonth($date);
    }

    /**
     * Paket fiyatı girildi ama paket sitede SATILAMAZ — yöneticiye söyle.
     *
     * ## Düzeltilen gerçek kusur
     *
     * Yönetici güne 250 TL paket fiyatı giriyor, "kaydedildi" yazısını
     * görüyor ve sitede paket kartını bulamıyordu: menü sayfası kalemleri tek
     * tek listeliyordu. Sebep iki yapılandırma eksiğinden biri oluyordu
     * (vitrinin paket ürünü tanımsız ya da güne zorunlu kalem girilmemiş) ve
     * ikisi de HİÇBİR YERDE söylenmiyordu — ne kaydetme ekranında, ne
     * günlükte. "Kaydedildi" diyen bir ekranın ardından çalışmayan bir
     * özellik, hatanın en pahalı biçimi: yönetici sorunu kendinde arıyor.
     *
     * Uyarı kaydetmeyi ENGELLEMİYOR. Fiyat geçerli bir veri ve saklanması
     * doğru; eksik olan onu satılabilir kılan yapılandırma. Kaydı reddetmek,
     * yöneticinin girdiği veriyi çöpe atardı.
     */
    private function warnIfPackageUnsellable(Location $location, DailyMenu $menu): void
    {
        // Kalemler `replaceItems()` ile yeniden yazıldı; bellekteki bağıntı
        // eski satırları taşıyor ve "zorunlu kalem var mı" sorusu ona sorulamaz.
        $menu->load('items.menu');

        // Sınıfın kendi kalıbı: vitrin kapısı yapıcıda değil, çağrı anında
        // çözülüyor (bkz. `renderDayEditor`).
        $packageMenuId = resolve(LocationGate::class)->dailyPackageMenuId($location);
        $reason = $menu->packageBlockReason($packageMenuId);

        if ($reason === null || $reason === DailyMenu::PACKAGE_BLOCK_NO_PRICE) {
            return;
        }

        flash()->warning(lang(match ($reason) {
            DailyMenu::PACKAGE_BLOCK_NO_PRODUCT => 'veykemtu.bridgeapi::dailymenu.alert_package_no_product',
            default => 'veykemtu.bridgeapi::dailymenu.alert_package_no_components',
        }));
    }

    /**
     * Tek bir günü yayına alır ya da taslağa çeker.
     *
     * BOŞ VE SATILAMAZ GÜN YAYINLANAMAZ. İkisi de sessiz arıza üretirdi:
     * kalemsiz bir gün müşteriye boş bir menü gösterir, paket fiyatı olmayan
     * ve kalemleri tek tek satılmayan bir gün ise "yayında" görünüp hiçbir
     * şey satmaz. İkisinin de belirtisi ancak müşteri şikâyetiyle görülür.
     */
    public function onPublish(string $context, ?string $recordId = null): RedirectResponse
    {
        $post = Request::post();
        $location = $this->requireLocation();
        $date = $this->parseDate($post['day_date'] ?? null);

        $target = (string) ($post['publish_status'] ?? DailyMenu::STATUS_PUBLISHED);
        throw_unless(
            in_array($target, DailyMenu::STATUSES, true),
            new FlashException(lang('veykemtu.bridgeapi::dailymenu.alert_date_invalid')),
        );

        $menu = $this->findDay($location, $date);
        throw_unless($menu instanceof DailyMenu, new FlashException(
            lang('veykemtu.bridgeapi::dailymenu.alert_day_missing'),
        ));

        if ($menu->status !== $target) {
            $this->assertStatusUnlocked($location, $date);
        }

        if ($target === DailyMenu::STATUS_PUBLISHED) {
            $this->assertSellable($menu, $date);
        }

        $this->applyStatus($menu, $target);

        $this->refreshSite();

        flash()->success(sprintf(
            lang($target === DailyMenu::STATUS_PUBLISHED
                ? 'veykemtu.bridgeapi::dailymenu.alert_published'
                : 'veykemtu.bridgeapi::dailymenu.alert_unpublished'),
            $date->format('d.m.Y'),
        ));

        return $this->backToMonth($date);
    }

    /**
     * Bir haftayı bir sonraki haftaya kopyalar.
     *
     * Hafta PAZARTESİ başlar: menü planı işletmede haftalık yapılıyor ve
     * "gelecek hafta" cümlesi Pazartesi–Pazar demek. Yöneticinin haftanın
     * hangi gününü seçtiği önemsiz; seçtiği günün haftası kopyalanır.
     */
    public function onCopyWeek(string $context, ?string $recordId = null): RedirectResponse
    {
        $post = Request::post();
        $location = $this->requireLocation();

        $start = $this->parseDate($post['copy_week_start'] ?? null)
            ->startOfWeek(Carbon::MONDAY);
        $overwrite = (bool) ($post['copy_overwrite'] ?? false);

        $pairs = [];
        for ($offset = 0; $offset < 7; $offset++) {
            $source = $start->copy()->addDays($offset);
            $pairs[] = [$source, $source->copy()->addDays(7)];
        }

        $this->runCopy($location, $pairs, $overwrite);

        return $this->backToMonth($start);
    }

    /**
     * Bir günü, ızgarada işaretlenen günlere uygular.
     *
     * KAYNAK GÜNÜN KENDİSİ HEDEFLER ARASINDAYSA ATLANIR — kendi üstüne
     * kopyalamak kalemleri silip yeniden yazmaktan başka bir şey yapmaz ve
     * en iyi ihtimalle boşuna, en kötü ihtimalle o günü taslağa düşürürdü.
     */
    public function onCopyDay(string $context, ?string $recordId = null): RedirectResponse
    {
        $post = Request::post();
        $location = $this->requireLocation();

        $source = $this->parseDate($post['source_date'] ?? null);
        $overwrite = (bool) ($post['copy_overwrite'] ?? false);

        throw_unless($this->findDay($location, $source) instanceof DailyMenu, new FlashException(
            sprintf(
                lang('veykemtu.bridgeapi::dailymenu.alert_source_missing'),
                $source->format('d.m.Y'),
            ),
        ));

        $targets = $post['target_dates'] ?? [];
        throw_unless(is_array($targets) && $targets !== [], new FlashException(
            lang('veykemtu.bridgeapi::dailymenu.alert_no_targets'),
        ));

        $pairs = [];
        foreach ($targets as $target) {
            $date = $this->parseDate($target);

            if ($date->isSameDay($source)) {
                continue;
            }

            $pairs[] = [$source, $date];
        }

        $this->runCopy($location, $pairs, $overwrite);

        return $this->backToMonth($source);
    }

    /**
     * Ekrandaki ayın menülerini toplu yayına alır ya da taslağa çeker.
     *
     * KAPALI GÜN BURADA ATLANMIYOR — kopyalamadan farklı olarak. Kapalı bir
     * günün menüsünü yayına almak o günü satılabilir yapmaz
     * (`DailyMenuService::verdict()` kapalı günü her şeyin önünde tutuyor),
     * yani yanlış bir şey üretmiyor. Kopyalamada atlanmasının sebebi başka:
     * orada VERİ YAZILIYOR ve satılamayacak bir güne menü yazmak yöneticinin
     * emeğini boşa harcar.
     */
    public function onBulkStatus(string $context, ?string $recordId = null): RedirectResponse
    {
        $post = Request::post();
        $location = $this->requireLocation();

        $month = $this->parseMonth($post['month'] ?? null);
        $target = (string) ($post['bulk_status'] ?? DailyMenu::STATUS_PUBLISHED);
        throw_unless(
            in_array($target, DailyMenu::STATUSES, true),
            new FlashException(lang('veykemtu.bridgeapi::dailymenu.alert_date_invalid')),
        );

        $from = $month->copy()->startOfMonth();
        $to = $month->copy()->endOfMonth();

        $menus = DailyMenu::query()
            ->with('items')
            ->where('location_id', $location->location_id)
            ->whereBetween('menu_date', [$from->toDateString(), $to->toDateString()])
            ->orderBy('menu_date')
            ->get();

        $orderCounts = $this->orderCounts($location, $from, $to);

        $changed = 0;
        $skipped = [];

        foreach ($menus as $menu) {
            $date = $menu->menu_date;

            if ($menu->status === $target) {
                continue;
            }

            if (($orderCounts[$date->toDateString()] ?? 0) > 0) {
                $skipped[] = sprintf(
                    lang('veykemtu.bridgeapi::dailymenu.skip_orders'),
                    $date->format('d.m'),
                );

                continue;
            }

            if ($target === DailyMenu::STATUS_PUBLISHED && !$this->isSellable($menu)) {
                $skipped[] = sprintf(
                    lang('veykemtu.bridgeapi::dailymenu.skip_unsellable'),
                    $date->format('d.m'),
                );

                continue;
            }

            $this->applyStatus($menu, $target);
            $changed++;
        }

        if ($changed > 0) {
            $this->refreshSite();
        }

        $this->flashBulkResult($changed, $skipped, $target);

        return $this->backToMonth($month);
    }

    // ── Görünüm verisi ────────────────────────────────────────────────────

    private function prepareVars(): void
    {
        $location = resolve(SettingsRepository::class)->location();

        $this->vars['location'] = $location;

        if (!$location instanceof Location) {
            return;
        }

        $month = $this->parseMonth(Request::get(self::MONTH_PARAM));

        /*
         * Izgara AYIN DIŞINA TAŞAR ve bu bilinçli: hafta Pazartesi başlıyor,
         * ayın ilk günü çarşambaysa o haftanın Pazartesi ve Salı'sı önceki
         * aya ait. Onları boş çizmek, "bu haftayı gelecek haftaya kopyala"
         * düğmesinin ay sınırında yarım hafta kopyalaması demekti.
         */
        $from = $month->copy()->startOfMonth()->startOfWeek(Carbon::MONDAY);
        $to = $month->copy()->endOfMonth()->endOfWeek(Carbon::SUNDAY);

        $menus = DailyMenu::query()
            ->with('items.menu')
            ->where('location_id', $location->location_id)
            ->whereBetween('menu_date', [$from->toDateString(), $to->toDateString()])
            ->get()
            ->keyBy(static fn(DailyMenu $menu): string => $menu->menu_date->toDateString());

        $closedDays = ClosedDay::query()
            ->whereBetween('closed_on', [$from->toDateString(), $to->toDateString()])
            ->get()
            ->keyBy(static fn(ClosedDay $day): string => $day->closed_on->toDateString());

        $orderCounts = $this->orderCounts($location, $from, $to);

        $this->vars['month'] = $month;
        $this->vars['monthKey'] = $month->format('Y-m');
        $this->vars['monthLabel'] = lang('veykemtu.bridgeapi::dailymenu.month_'.$month->month)
            .' '.$month->year;
        $this->vars['prevMonth'] = $month->copy()->subMonthNoOverflow()->format('Y-m');
        $this->vars['nextMonth'] = $month->copy()->addMonthNoOverflow()->format('Y-m');
        $this->vars['thisMonth'] = BusinessTime::now()->format('Y-m');
        $this->vars['monthParam'] = self::MONTH_PARAM;
        $this->vars['baseUri'] = self::BASE_URI;

        $this->vars['weeks'] = $this->buildWeeks($month, $from, $to, $menus, $closedDays, $orderCounts);
        $this->vars['days'] = $this->buildDayPayload($this->vars['weeks']);

        $gate = resolve(LocationGate::class);
        $packageMenuId = $gate->dailyPackageMenuId($location);

        $this->vars['dailyMenuEnabled'] = $gate->dailyMenuEnabled($location);
        $this->vars['packageMenuId'] = $packageMenuId;

        /*
         * Paket ürünü listede YOK. Kendini içeren bir menü anlamsız bir satır
         * üretir: paketin kendi fiyatı 0,00 ve gerçek fiyat zaten o günün
         * paket fiyatı. Kalem olarak eklenseydi müşteri menünün içinde
         * "Günün Menüsü — 0,00 ₺" satırı görürdü.
         */
        $this->vars['products'] = Menu::query()
            ->where('menu_status', true)
            ->when(
                $packageMenuId !== null,
                static fn($query) => $query->where('menu_id', '!=', $packageMenuId),
            )
            ->orderBy('menu_name')
            ->get(['menu_id', 'menu_name', 'menu_price']);
    }

    /**
     * Ay ızgarasının hücreleri, haftalara bölünmüş.
     *
     * @param  Collection<string, DailyMenu>  $menus
     * @param  Collection<string, ClosedDay>  $closedDays
     * @param  array<string, int>  $orderCounts
     * @return list<list<array<string, mixed>>>
     */
    private function buildWeeks(
        Carbon $month,
        Carbon $from,
        Carbon $to,
        Collection $menus,
        Collection $closedDays,
        array $orderCounts,
    ): array {
        $today = BusinessTime::now()->startOfDay();

        $weeks = [];
        $week = [];

        for ($cursor = $from->copy(); $cursor->lessThanOrEqualTo($to); $cursor->addDay()) {
            $key = $cursor->toDateString();
            $menu = $menus->get($key);
            $orderCount = $orderCounts[$key] ?? 0;

            $week[] = [
                'date' => $key,
                'day_number' => $cursor->day,
                'in_month' => $cursor->month === $month->month && $cursor->year === $month->year,
                'is_today' => $cursor->isSameDay($today),
                'is_past' => $cursor->lessThan($today),
                'menu' => $menu,
                'item_count' => $menu?->items->count() ?? 0,
                'closed' => $closedDays->get($key),
                'order_count' => $orderCount,
                'locked' => $orderCount > 0,
            ];

            if (count($week) === 7) {
                $weeks[] = $week;
                $week = [];
            }
        }

        return $weeks;
    }

    /**
     * Gün düzenleyicinin okuduğu JSON.
     *
     * TEK MODAL, OTUZ BİR GÜN. Her hücre için ayrı bir modal çizmek sayfayı
     * otuz bir kopya formla şişirirdi; ürün listesi (yüz küsur `<option>`)
     * her birinde tekrarlanırdı. Bunun yerine düzenleyici tek ve boş
     * çiziliyor, içeriğini bu tablodan dolduruyor.
     *
     * @param  list<list<array<string, mixed>>>  $weeks
     * @return array<string, array<string, mixed>>
     */
    private function buildDayPayload(array $weeks): array
    {
        $payload = [];

        foreach ($weeks as $week) {
            foreach ($week as $cell) {
                /** @var DailyMenu|null $menu */
                $menu = $cell['menu'];
                /** @var ClosedDay|null $closed */
                $closed = $cell['closed'];

                $payload[$cell['date']] = [
                    'date' => $cell['date'],
                    'label' => Carbon::parse($cell['date'])->format('d.m.Y'),
                    'exists' => $menu !== null,
                    'status' => $menu?->status ?? DailyMenu::STATUS_DRAFT,
                    'title' => (string) ($menu?->title ?? ''),
                    'description' => (string) ($menu?->description ?? ''),
                    'internal_note' => (string) ($menu?->internal_note ?? ''),
                    // TL metni model üzerinden: kuruş ↔ TL dönüşümünün tek
                    // sahibi `LiraField` ve ona giden yol bu erişimci.
                    'package_price' => $menu?->package_price_lira ?? '',
                    'components_sellable' => $menu === null || (bool) $menu->components_sellable,
                    'locked' => $cell['locked'],
                    'order_count' => $cell['order_count'],
                    'closed' => $closed !== null,
                    'closed_note' => (string) ($closed?->description ?? ''),
                    'items' => $menu === null ? [] : $menu->items
                        ->map(static fn(DailyMenuItem $item): array => [
                            'menu_id' => (int) $item->menu_id,
                            'quantity' => max(1, (int) $item->quantity),
                            'price_override' => $item->price_override_lira,
                            'label' => (string) ($item->label ?? ''),
                            'is_required' => (bool) $item->is_required,
                            'sellable_alone' => (bool) $item->sellable_alone,
                        ])
                        ->values()
                        ->all(),
                ];
            }
        }

        return $payload;
    }

    // ── Kopyalama ─────────────────────────────────────────────────────────

    /**
     * Kaynak → hedef çiftlerini kopyalar ve SONUCU RAPORLAR.
     *
     * İSTENENDEN AZINI SESSİZCE YAPAN BİR KOPYA, REDDEDEN BİR KOPYADAN
     * KÖTÜDÜR. Yönetici "haftayı kopyaladım" deyip ekranı kapatırsa,
     * atlanan iki günün menüsüz kaldığını ancak o gün sabah öğrenir.
     * Bu yüzden atlananlar sayıyla değil, GÜN GÜN ve SEBEBİYLE yazılıyor:
     * "5 gün kopyalandı, 2 gün atlandı: 18.08 kapalı gün, 20.08 siparişi var".
     *
     * @param  list<array{0: Carbon, 1: Carbon}>  $pairs
     */
    private function runCopy(Location $location, array $pairs, bool $overwrite): void
    {
        $copied = 0;
        $skipped = [];

        DB::transaction(function () use ($location, $pairs, $overwrite, &$copied, &$skipped): void {
            foreach ($pairs as [$source, $target]) {
                $reason = $this->copyDay($location, $source, $target, $overwrite);

                if ($reason === null) {
                    $copied++;

                    continue;
                }

                // Kaynağında menü olmayan gün "atlandı" sayılmıyor: kopyalanacak
                // bir şey yoktu, yönetici de bunu takvimde görüyor. Raporu
                // gerçek engellerle sınırlı tutmak, listeyi okunur kılıyor.
                if ($reason !== 'empty') {
                    $skipped[] = sprintf(
                        lang('veykemtu.bridgeapi::dailymenu.skip_'.$reason),
                        $target->format('d.m'),
                    );
                }
            }
        });

        if ($copied > 0) {
            // Kopya taslak düşüyor, yani vitrin değişmiyor; yine de hedef gün
            // ÜZERİNE yazılmışsa yayındaki bir menü taslağa dönmüş olabilir.
            $this->refreshSite();
        }

        if ($copied === 0 && $skipped === []) {
            flash()->warning(lang('veykemtu.bridgeapi::dailymenu.alert_copy_none'));

            return;
        }

        if ($skipped === []) {
            flash()->success(sprintf(
                lang('veykemtu.bridgeapi::dailymenu.alert_copy_done'),
                $copied,
            ));

            return;
        }

        flash()->warning(sprintf(
            lang('veykemtu.bridgeapi::dailymenu.alert_copy_skipped'),
            $copied,
            count($skipped),
            implode(', ', $skipped),
        ));
    }

    /**
     * Tek bir günü kopyalar.
     *
     * @return string|null atlanma sebebi (`empty`, `closed`, `orders`,
     *                     `exists`) ya da kopyalandıysa `null`
     */
    private function copyDay(
        Location $location,
        Carbon $source,
        Carbon $target,
        bool $overwrite,
    ): ?string {
        $sourceMenu = $this->findDay($location, $source);

        if (!$sourceMenu instanceof DailyMenu) {
            return 'empty';
        }

        // KURAL 2 — kapalı gün her zaman atlanır, overwrite verilse bile.
        if (ClosedDay::isClosed($target)) {
            return 'closed';
        }

        // KURAL 3 — siparişi olan güne kopyalanmaz: kopya kalemleri ve
        // paket fiyatını değiştirir, o gün için verilmiş siparişler ise
        // eski fiyata bağlı.
        if ($this->orderCountFor($location, $target) > 0) {
            return 'orders';
        }

        $targetMenu = $this->findDay($location, $target);

        if ($targetMenu instanceof DailyMenu && !$overwrite) {
            return 'exists';
        }

        $targetMenu ??= $this->newDraftDay($location, $target);

        $targetMenu->title = $sourceMenu->title;
        $targetMenu->description = $sourceMenu->description;
        $targetMenu->internal_note = $sourceMenu->internal_note;
        $targetMenu->package_price_kurus = $sourceMenu->package_price_kurus;
        $targetMenu->components_sellable = (bool) $sourceMenu->components_sellable;

        // KURAL 1 — kopya HER ZAMAN taslak düşer, kaynak yayında olsa bile.
        $targetMenu->status = DailyMenu::STATUS_DRAFT;
        $targetMenu->published_at = null;
        $targetMenu->published_by = null;

        $targetMenu->save();

        $this->replaceItems($targetMenu, $sourceMenu->items
            ->map(static fn(DailyMenuItem $item): array => [
                'menu_id' => (int) $item->menu_id,
                'quantity' => max(1, (int) $item->quantity),
                'price_override_kurus' => $item->price_override_kurus === null
                    ? null
                    : (int) $item->price_override_kurus,
                'is_required' => (bool) $item->is_required,
                'sellable_alone' => (bool) $item->sellable_alone,
                'label' => $item->label,
            ])
            ->values()
            ->all());

        return null;
    }

    // ── Yazma yardımcıları ────────────────────────────────────────────────

    private function newDraftDay(Location $location, Carbon $date): DailyMenu
    {
        $menu = new DailyMenu;
        $menu->location_id = (int) $location->location_id;
        $menu->menu_date = $date->toDateString();
        $menu->status = DailyMenu::STATUS_DRAFT;
        $menu->components_sellable = true;
        $menu->created_by = $this->currentUserId();

        return $menu;
    }

    /**
     * Günün kalem satırlarını POSTALANAN listeyle değiştirir.
     *
     * SİL-YENİDEN YAZ, DİFF DEĞİL. Kalem satırlarına dışarıdan hiçbir kayıt
     * işaret etmiyor: sipariş satırı `order_menus.bld_daily_menu_id` ile
     * GÜNE bağlanıyor, kaleme değil. Bir diff algoritması burada yalnızca
     * fazladan karmaşıklık ve sıra hatası kaynağı olurdu. Kilitli günün
     * satırlarına zaten hiç gelinmiyor (`onSaveDay`).
     *
     * @param  list<array<string, mixed>>  $items
     */
    private function replaceItems(DailyMenu $menu, array $items): void
    {
        DailyMenuItem::query()->where('daily_menu_id', $menu->id)->delete();

        foreach (array_values($items) as $index => $row) {
            $item = new DailyMenuItem;
            $item->daily_menu_id = (int) $menu->id;
            $item->menu_id = (int) $row['menu_id'];
            $item->quantity = (int) $row['quantity'];
            // Sıra EKRANDAKİ SIRADIR: çorba → ana yemek → pilav → tatlı.
            // Tarayıcı formu DOM sırasıyla gönderiyor, PHP o sırayı koruyor.
            $item->sort_order = $index;
            $item->price_override_kurus = $row['price_override_kurus'];
            $item->is_required = (bool) $row['is_required'];
            $item->sellable_alone = (bool) $row['sellable_alone'];
            $item->label = $row['label'];
            $item->save();
        }

        $menu->reloadRelations();
    }

    private function applyStatus(DailyMenu $menu, string $status): void
    {
        $menu->status = $status;

        if ($status === DailyMenu::STATUS_PUBLISHED) {
            $menu->published_at = BusinessTime::forStorage(BusinessTime::now());
            $menu->published_by = $this->currentUserId();
        } else {
            // Taslağa çekilen gün "bir zamanlar yayındaydı" bilgisini
            // taşımaz: `findPublished()` yalnız `status`'e bakıyor ve iki
            // ayrı doğruluk kaynağı bir gün çelişir.
            $menu->published_at = null;
            $menu->published_by = null;
        }

        $menu->save();
    }

    // ── Girdi toplama ─────────────────────────────────────────────────────

    /**
     * Düzenleyicinin kalem satırlarını okur.
     *
     * Alan adları `items[<i>][...]` biçiminde ve indis DOM'da üretiliyor.
     * Düz liste (`item_menu_id[]`) kullanılsaydı, işaretlenmemiş bir onay
     * kutusu hiç gönderilmediği için satırlar kayardı: üçüncü satırın
     * "zorunlu" değeri dördüncü satıra yazılırdı. İndisli biçim bu hatayı
     * yapısal olarak imkânsız kılıyor.
     *
     * @return list<array<string, mixed>>
     */
    private function collectItems(array $post): array
    {
        $rows = $post['items'] ?? [];

        if (!is_array($rows)) {
            return [];
        }

        $items = [];
        $seen = [];

        foreach ($rows as $row) {
            if (!is_array($row)) {
                continue;
            }

            $menuId = (int) ($row['menu_id'] ?? 0);

            // Ürün seçilmemiş satır sessizce atlanır: düzenleyici boş satır
            // ekleyebiliyor ve kullanılmayanı tek tek silmeyi beklemek anlamsız.
            if ($menuId <= 0) {
                continue;
            }

            throw_if(DailyMenu::isPackageProduct($menuId), new FlashException(
                lang('veykemtu.bridgeapi::dailymenu.alert_package_item'),
            ));

            throw_if(isset($seen[$menuId]), new FlashException(sprintf(
                lang('veykemtu.bridgeapi::dailymenu.alert_duplicate_item'),
                (string) (Menu::query()->where('menu_id', $menuId)->value('menu_name') ?? $menuId),
            )));

            $seen[$menuId] = true;

            $items[] = [
                'menu_id' => $menuId,
                'quantity' => max(1, (int) ($row['quantity'] ?? 1)),
                'price_override_kurus' => $this->parseOptionalPrice($row['price_override'] ?? null),
                'is_required' => (bool) ($row['is_required'] ?? false),
                'sellable_alone' => (bool) ($row['sellable_alone'] ?? false),
                'label' => $this->trimmedOrNull($row['label'] ?? null),
            ];
        }

        return $items;
    }

    /**
     * Paket fiyatı: boş = paket satılmıyor (null), sıfır = REDDEDİLİR.
     *
     * Migration'ın da söylediği gibi sıfır "bedava" demek olurdu ve
     * `LineResolver` onu zaten reddediyor. Panelde sessizce kabul edilseydi,
     * yönetici paketi yayına aldığını sanır, müşteri sipariş veremezdi.
     */
    private function parsePackagePrice(mixed $value): ?int
    {
        $kurus = $this->parseOptionalPrice($value);

        throw_if($kurus === 0, new FlashException(
            lang('veykemtu.bridgeapi::dailymenu.alert_package_zero'),
        ));

        return $kurus;
    }

    /**
     * Serbest metin TL girdisini kuruşa çevirir; boş girdi `null` döner.
     *
     * `LiraField::toKurus('')` sıfır döndürüyor ve burada sıfır ile boş
     * FARKLI ŞEYLER: boş = "değer yok", sıfır = "bedava". Dönüşümün kendisi
     * yine `LiraField`'da — bu metot yalnızca boşluk ayrımını yapıyor
     * (`DailyMenu::setPackagePriceLiraAttribute` ile aynı kural).
     */
    private function parseOptionalPrice(mixed $value): ?int
    {
        $text = trim((string) $value);

        if ($text === '') {
            return null;
        }

        return max(0, LiraField::toKurus($text));
    }

    /**
     * Kilitli günde yapısal alanların GÖNDERİLMİŞ olup olmadığı.
     *
     * Değer KARŞILAŞTIRILMIYOR, VARLIĞA bakılıyor. Karşılaştırma yapılsaydı
     * devre dışı bırakılmış (ve bu yüzden hiç gönderilmeyen) fiyat alanı
     * "boş" olarak gelir, kayıtlı değerden farklı görünür ve yalnızca notu
     * düzelten meşru bir kayıt reddedilirdi.
     */
    private function structuralPayloadPresent(array $post): bool
    {
        return array_key_exists('items', $post)
            || array_key_exists('package_price', $post)
            || array_key_exists('components_sellable', $post);
    }

    // ── Kilit ve satılabilirlik ───────────────────────────────────────────

    /** @throws FlashException gün siparişliyse */
    private function assertStatusUnlocked(Location $location, Carbon $date): void
    {
        throw_if($this->orderCountFor($location, $date) > 0, new FlashException(sprintf(
            lang('veykemtu.bridgeapi::dailymenu.alert_locked_status'),
            $date->format('d.m.Y'),
        )));
    }

    /** @throws FlashException gün yayınlanacak durumda değilse */
    private function assertSellable(DailyMenu $menu, Carbon $date): void
    {
        throw_if($menu->items->isEmpty(), new FlashException(sprintf(
            lang('veykemtu.bridgeapi::dailymenu.alert_publish_empty'),
            $date->format('d.m.Y'),
        )));

        throw_unless($this->isSellable($menu), new FlashException(sprintf(
            lang('veykemtu.bridgeapi::dailymenu.alert_publish_unsellable'),
            $date->format('d.m.Y'),
        )));
    }

    /** Paket ya da kalemler — biri satılabiliyor mu? */
    private function isSellable(DailyMenu $menu): bool
    {
        if ($menu->items->isEmpty()) {
            return false;
        }

        return $menu->sellsPackage() || (bool) $menu->components_sellable;
    }

    /**
     * Bir güne verilmiş, iptal edilmemiş sipariş sayısı.
     *
     * İPTAL EDİLENLER SAYILMIYOR. İptal, cari borcu ters kayıtla zaten
     * nötrledi (`OrderStatusTransition::reverseAccountDebitOnCancel`) ve
     * durum makinesi iptal edilmiş bir siparişin revizyonuna izin vermiyor
     * — yani o sipariş üzerinden yeniden fiyatlama riski yok. Sayılsaydı,
     * tek bir iptal o günü sonsuza kadar kilitlerdi.
     *
     * @return array<string, int> gün → sipariş sayısı
     */
    private function orderCounts(Location $location, Carbon $from, Carbon $to): array
    {
        $rows = DB::table('orders')
            ->leftJoin('statuses', 'statuses.status_id', '=', 'orders.status_id')
            ->where('orders.location_id', (int) $location->location_id)
            ->whereBetween('orders.bld_service_date', [$from->toDateString(), $to->toDateString()])
            ->where(static function ($query): void {
                $query->whereNull('statuses.status_code')
                    ->orWhere('statuses.status_code', '!=', OrderStatusTransition::CANCELLED);
            })
            ->groupBy('orders.bld_service_date')
            ->selectRaw('orders.bld_service_date as service_day, COUNT(*) as order_count')
            ->get();

        /*
         * `pluck('order_count', 'service_day')` KULLANILMIYOR: Laravel'in
         * `pluck`'ı select listesini verilen iki ADLA değiştiriyor
         * (`onceWithColumns`) ve `order_count` gerçek bir kolon olmadığı için
         * MySQL "Unknown column" ile patlıyor. Toplu sorgularda takma adlarla
         * pluck sessiz değil, gürültülü bir tuzak — ama ancak koşunca görülür.
         */
        $counts = [];

        foreach ($rows as $row) {
            $counts[(string) $row->service_day] = (int) $row->order_count;
        }

        return $counts;
    }

    private function orderCountFor(Location $location, Carbon $date): int
    {
        return $this->orderCounts($location, $date, $date)[$date->toDateString()] ?? 0;
    }

    // ── Ortak yardımcılar ─────────────────────────────────────────────────

    private function requireLocation(): Location
    {
        $location = resolve(SettingsRepository::class)->location();

        throw_unless($location instanceof Location, new FlashException(
            lang('veykemtu.bridgeapi::dailymenu.alert_no_location'),
        ));

        return $location;
    }

    private function findDay(Location $location, Carbon $date): ?DailyMenu
    {
        return DailyMenu::query()
            ->with('items.menu')
            ->where('location_id', $location->location_id)
            ->whereDate('menu_date', $date->toDateString())
            ->first();
    }

    /**
     * `YYYY-AA-GG` metnini güne çevirir.
     *
     * TAŞMA DENETİMİ VAR: `createFromFormat('Y-m-d', '2026-02-31')` istisna
     * fırlatmaz, 3 Mart döner. Geri yazıp karşılaştırmak bunu kapatıyor —
     * aynı gerekçe `DailyMenuService::resolveServiceDate()` içinde de var
     * ve orada müşterinin yanlış güne sipariş vermesini engelliyor; burada
     * yöneticinin yanlış güne menü yazmasını.
     *
     * @throws FlashException
     */
    private function parseDate(mixed $value): Carbon
    {
        $text = trim((string) $value);

        try {
            $parsed = Carbon::createFromFormat('Y-m-d', $text, BusinessTime::ZONE);
        } catch (Throwable) {
            $parsed = false;
        }

        throw_unless(
            $parsed instanceof Carbon && $parsed->format('Y-m-d') === $text,
            new FlashException(lang('veykemtu.bridgeapi::dailymenu.alert_date_invalid')),
        );

        return $parsed->startOfDay();
    }

    /**
     * `YYYY-AA` metnini ayın ilk gününe çevirir; geçersizse İÇİNDE
     * BULUNULAN AY.
     *
     * Ay seçimi bir adres parçası (`?ay=2026-09`) ve elle düzenlenebiliyor.
     * Geçersiz bir değerde hata vermek yerine bu aya düşmek doğru davranış:
     * yöneticinin yaptığı iş bozulmaz, sadece istediği aya gitmez ve bunu
     * ekranda görür.
     */
    private function parseMonth(mixed $value): Carbon
    {
        $text = trim((string) $value);

        try {
            $parsed = Carbon::createFromFormat('Y-m-d', $text.'-01', BusinessTime::ZONE);
        } catch (Throwable) {
            $parsed = false;
        }

        if (!$parsed instanceof Carbon || $parsed->format('Y-m') !== $text) {
            return BusinessTime::now()->startOfMonth();
        }

        return $parsed->startOfMonth();
    }

    private function backToMonth(Carbon $date): RedirectResponse
    {
        return $this->redirect(self::BASE_URI.'?'.self::MONTH_PARAM.'='.$date->format('Y-m'));
    }

    /**
     * @param  list<string>  $skipped
     */
    private function flashBulkResult(int $changed, array $skipped, string $target): void
    {
        $verb = lang($target === DailyMenu::STATUS_PUBLISHED
            ? 'veykemtu.bridgeapi::dailymenu.text_status_published'
            : 'veykemtu.bridgeapi::dailymenu.text_status_draft');

        if ($changed === 0 && $skipped === []) {
            flash()->warning(lang('veykemtu.bridgeapi::dailymenu.alert_bulk_none'));

            return;
        }

        $message = sprintf(lang('veykemtu.bridgeapi::dailymenu.alert_bulk_done'), $changed, $verb);

        if ($skipped === []) {
            flash()->success($message);

            return;
        }

        flash()->warning($message.' '.sprintf(
            lang('veykemtu.bridgeapi::dailymenu.alert_copy_skipped'),
            $changed,
            count($skipped),
            implode(', ', $skipped),
        ));
    }

    /**
     * Sitenin ISR önbelleğini tazeler — `SiteContentObserver` ile aynı yol.
     *
     * "En iyi çaba": site kapalıysa istisna fırlatmaz, kaydı geri almaz
     * (gerekçenin tamamı `SiteRevalidator` başlığında). Menü değişikliği
     * içerik değişikliğinden daha acil: yönetici yarınki menüyü akşam
     * giriyor ve sitede bir sonraki ISR turuna kadar eski menü kalırsa
     * müşteri var olmayan bir yemeği sipariş etmeye çalışır.
     */
    private function refreshSite(): void
    {
        resolve(SiteRevalidator::class)->revalidate();
    }

    private function currentUserId(): ?int
    {
        return (int) ($this->currentUser?->getKey() ?? 0) ?: null;
    }

    private function trimmedOrNull(mixed $value): ?string
    {
        $text = trim((string) $value);

        return $text === '' ? null : $text;
    }
}
