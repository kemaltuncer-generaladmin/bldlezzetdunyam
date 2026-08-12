<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Admin;

use Igniter\Admin\Classes\AdminController;
use Igniter\Admin\Facades\AdminMenu;
use Igniter\Cart\Models\Menu;
use Igniter\Cart\Models\Order;
use Igniter\Flame\Exception\FlashException;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Request;
use Throwable;
use Veykemtu\BridgeApi\Admin\AdminRegistrar;
use Veykemtu\BridgeApi\Admin\SettingsRepository;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Models\SubscriptionException;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Services\OrderFactory;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Telefonla alınan siparişin panele girilmesi — B-13.
 *
 * Müşterilerin çoğu hâlâ telefonla arıyor. Bugüne kadar o siparişlerin
 * sisteme girmesinin hiçbir yolu yoktu: mutfak kâğıda yazıyor, sipariş
 * KDS'de görünmüyor, cirosu raporlara düşmüyor, cari hesaba işlenmiyordu.
 *
 * ÇEKİRDEK `FormController` KULLANILMIYOR. Sebep: burada kaydedilen şey tek
 * bir model değil — müşteri (belki yeni), sipariş başlığı, satırlar, cari
 * hareketi ve durum geçişi birlikte doğuyor. Çekirdeğin form denetleyicisi
 * "bir model bir kayıt" varsayımıyla çalışıyor ve bunu zorlamak, her adımda
 * ona rağmen kod yazmak olurdu.
 *
 * FİYAT VE KURALLAR YENİDEN YAZILMADI: `Services\OrderFactory::create()`
 * çağrılıyor. Aynı satır çözümleme, aynı sunucu tarafı fiyatlama, aynı adres
 * kopyalama, aynı cari kaydı. Panelin kendi hesabını yapması, web ile
 * panelin zamanla ayrışan iki fiyatı olması demekti.
 *
 * SİPARİŞ `onaylandi` DOĞAR: telefonda teyit zaten alınmış. `yeni` bırakmak,
 * yöneticiyi kapatır kapatmaz ikinci bir ekrana götürürdü ve o adım
 * unutulduğunda sipariş mutfağa hiç düşmezdi. Mutfak fişi bu geçişte basılır
 * (`docs/02-veri-modeli.md` baskı tetikleyicileri).
 */
class PhoneOrders extends AdminController
{
    private const string BASE_URI = AdminRegistrar::PHONE_ORDERS_URI;

    /** Formda başlangıçta çizilen boş satır sayısı. */
    private const int INITIAL_LINES = 6;

    protected null|string|array $requiredPermissions = AdminRegistrar::PERMISSION_PHONE_ORDERS;

    public function __construct()
    {
        parent::__construct();

        AdminMenu::setContext('bld_phone_orders', 'restaurant');
    }

    /**
     * Sipariş giriş ekranı.
     *
     * `null` döndürüyor: çekirdek `execPageAction` bunu görünce
     * `resources/views/phoneorders/index.blade.php` görünümünü çiziyor.
     */
    public function index(): void
    {
        AdminMenu::setContext('bld_phone_orders', 'restaurant');

        $this->prepareVars();
    }

    /**
     * Siparişi oluşturur ve mutfağa gönderir.
     *
     * Tek `onCreateOrder` var, "kaydet" ve "kaydet+mutfağa gönder" diye iki
     * ayrı düğme yok: telefonla alınan sipariş zaten teyit edilmiş bir
     * siparştir. İki düğme, yanlış olanına basıldığında siparişin mutfağa
     * hiç ulaşmaması demekti.
     */
    public function onCreateOrder(): RedirectResponse
    {
        $post = Request::post();

        $location = resolve(SettingsRepository::class)->location();
        throw_if($location === null, new FlashException(
            lang('veykemtu.bridgeapi::phoneorder.alert_no_location'),
        ));

        $items = $this->collectItems($post);
        throw_if($items === [], new FlashException(
            lang('veykemtu.bridgeapi::phoneorder.alert_no_items'),
        ));

        $deliveryType = ($post['delivery_type'] ?? Order::DELIVERY) === Order::DELIVERY
            ? Order::DELIVERY
            : Order::COLLECTION;

        $requestedAt = $this->collectRequestedAt($post);
        $subscriptionId = $this->collectSubscriptionId($post);

        /*
         * MÜŞTERİ VE SİPARİŞ TEK TRANSACTION'DA.
         *
         * Yeni müşteri kaydedilip sipariş bir doğrulama hatasına takılsaydı,
         * sistemde hiç sipariş vermemiş yetim bir kurumsal kayıt kalırdı —
         * ve telefonu kapatmayan yönetici aynı müşteriyi bir kez daha
         * oluştururdu.
         */
        try {
            $order = DB::transaction(function () use (
                $post, $location, $items, $deliveryType, $requestedAt, $subscriptionId,
            ): Order {
                $customer = $this->resolveCustomer($post);

                $order = resolve(OrderFactory::class)->create(
                    customer: $customer,
                    location: $location,
                    deliveryType: $deliveryType,
                    items: $items,
                    address: $deliveryType === Order::DELIVERY ? $this->collectAddress($post) : null,
                    requestedAt: $requestedAt,
                    paymentMethod: (string) ($post['payment_method'] ?? 'cash'),
                    customerNote: $this->trimmedOrNull($post['customer_note'] ?? null),
                    adminContext: true,
                    subscriptionId: $subscriptionId,
                );

                return $order;
            });
        } catch (ApiException $e) {
            // API sözleşmesinin hata biçimi panelde işe yaramaz; yöneticiye
            // düz Türkçe cümle gösteriyoruz. Ayrıntı (limit, kalan tutar)
            // mesajın kendisinde zaten var.
            throw new FlashException($e->getMessage());
        }

        /*
         * DURUM GEÇİŞİ TRANSACTION'IN DIŞINDA VE BİLİNÇLİ OLARAK SONRA.
         *
         * `onaylandi` geçişi fiş kuyruğuna iş yazıyor. Sipariş transaction'ı
         * geri alınırsa mutfakta var olmayan bir siparişin fişi basılırdı;
         * sipariş kesinleştikten sonra tetiklemek bunu imkânsız kılıyor.
         *
         * Geçiş burada patlarsa sipariş `yeni` olarak durur — kaybolmaz,
         * sipariş listesinden elle onaylanabilir. Yöneticiye de bu söyleniyor.
         */
        try {
            resolve(OrderStatusTransition::class)->apply(
                $order,
                OrderStatusTransition::CONFIRMED,
                (int) ($this->currentUser?->getKey() ?? 0) ?: null,
            );
        } catch (Throwable $e) {
            flash()->warning(sprintf(
                lang('veykemtu.bridgeapi::phoneorder.alert_confirm_failed'),
                $order->order_id,
                $e->getMessage(),
            ));

            return $this->redirect('orders/edit/'.$order->order_id);
        }

        flash()->success(sprintf(
            lang('veykemtu.bridgeapi::phoneorder.alert_created'),
            $order->order_id,
        ));

        return $this->redirect('orders/edit/'.$order->order_id);
    }

    // ── Görünüm verisi ────────────────────────────────────────────────────

    private function prepareVars(): void
    {
        $location = resolve(SettingsRepository::class)->location();

        $this->vars['location'] = $location;
        $this->vars['initialLines'] = self::INITIAL_LINES;
        $this->vars['today'] = BusinessTime::now()->toDateString();

        $this->vars['customers'] = ApiCustomer::query()
            ->where('bld_account_type', 'corporate')
            ->orderBy('bld_org_name')
            ->get(['customer_id', 'bld_org_name', 'first_name', 'last_name', 'telephone', 'bld_credit_limit_kurus']);

        // Satılabilir ürünler. `menu_status` kapalı olanlar hiç listelenmiyor:
        // yönetici telefonda okuduğu menüden seçiyor, satışta olmayan bir
        // ürünü görmesi yanlış söz vermesine yol açar.
        $this->vars['menus'] = Menu::query()
            ->where('menu_status', true)
            ->orderBy('menu_name')
            ->get(['menu_id', 'menu_name', 'menu_price']);

        // Abonelikler müşteriye göre istemci tarafında filtreleniyor; kurumsal
        // müşteri sayısı onlarla ifade ediliyor, ayrı bir AJAX ucu açmak
        // fazladan bir kırılma noktası olurdu.
        $this->vars['subscriptions'] = Subscription::query()
            ->where('status', Subscription::STATUS_ACTIVE)
            ->orderBy('id')
            ->get(['id', 'customer_id', 'delivery_type', 'default_quantity']);

        $this->vars['paymentMethods'] = $location !== null
            ? resolve(LocationGate::class)->paymentMethods($location)
            : [];
    }

    // ── Girdi toplama ─────────────────────────────────────────────────────

    /**
     * Var olan müşteriyi bulur ya da yenisini oluşturur.
     *
     * Yeni müşteri HER ZAMAN kurumsal doğar: sipariş kapısı `can_order`
     * kurumsal hesapta açık (`docs/00` B2B kararı) ve panelden girilen bir
     * siparişin müşterisi tanım gereği bizimle çalışan bir kurum.
     *
     * Cari limiti YAZILMIYOR — kolonun varsayılanı NULL değil, migration'da
     * bilerek NULL bırakılmış olsa da yeni kayıtta 0 veriyoruz: veresiye
     * ayrı bir güven kararı ve telefonda alınan bir siparişle birlikte
     * verilmemeli (`2026_08_13_000001` gerekçesi).
     */
    private function resolveCustomer(array $post): ApiCustomer
    {
        $customerId = (int) ($post['customer_id'] ?? 0);

        if ($customerId > 0) {
            $existing = ApiCustomer::query()->find($customerId);

            throw_unless($existing instanceof ApiCustomer, new FlashException(
                lang('veykemtu.bridgeapi::phoneorder.alert_customer_missing'),
            ));

            return $existing;
        }

        $orgName = $this->trimmedOrNull($post['new_org_name'] ?? null);
        $phone = $this->trimmedOrNull($post['new_phone'] ?? null);

        throw_if($orgName === null || $phone === null, new FlashException(
            lang('veykemtu.bridgeapi::phoneorder.alert_new_customer_fields'),
        ));

        $contact = $this->trimmedOrNull($post['new_contact'] ?? null) ?? $orgName;

        $customer = new ApiCustomer;
        $customer->first_name = mb_substr($contact, 0, 48);
        $customer->last_name = '';
        // E-posta çekirdekte zorunlu ve tekil. Telefonla arayan kurumsal
        // müşterinin e-postası çoğu zaman yok; yer tutucu üretiyoruz ki
        // kayıt açılabilsin. Alan adı `invalid.` — RFC 6761 ile ayrılmış,
        // yani buraya kazara posta gönderilse bile hiçbir yere ulaşmaz.
        $customer->email = 'tel-'.preg_replace('/\D+/', '', $phone).'@bld.invalid';
        $customer->telephone = $phone;
        $customer->status = true;
        $customer->bld_account_type = 'corporate';
        $customer->bld_org_name = $orgName;
        $customer->bld_contact_person = $contact;
        $customer->bld_org_phone = $phone;
        $customer->bld_credit_limit_kurus = 0;
        $customer->save();

        return $customer;
    }

    /**
     * Form satırlarını `OrderFactory`'nin beklediği biçime çevirir.
     *
     * Adet 0 ya da ürün seçilmemiş satırlar sessizce atlanıyor: form altı
     * boş satırla açılıyor ve yöneticinin kullanmadıklarını tek tek
     * silmesini beklemek anlamsız.
     *
     * @return array<int, array{menu_id:int, quantity:int, note?:string|null}>
     */
    private function collectItems(array $post): array
    {
        $menuIds = (array) ($post['line_menu_id'] ?? []);
        $quantities = (array) ($post['line_quantity'] ?? []);
        $notes = (array) ($post['line_note'] ?? []);

        $items = [];
        foreach ($menuIds as $index => $menuId) {
            $menuId = (int) $menuId;
            $quantity = (int) ($quantities[$index] ?? 0);

            if ($menuId <= 0 || $quantity <= 0) {
                continue;
            }

            $items[] = [
                'menu_id' => $menuId,
                'quantity' => $quantity,
                'note' => $this->trimmedOrNull($notes[$index] ?? null),
            ];
        }

        return $items;
    }

    /**
     * @return array<string, mixed>
     */
    private function collectAddress(array $post): array
    {
        return [
            'line1' => (string) ($post['address_line1'] ?? ''),
            'district' => (string) ($post['address_district'] ?? ''),
            'city' => (string) ($post['address_city'] ?? ''),
            'note' => $this->trimmedOrNull($post['address_note'] ?? null),
        ];
    }

    /**
     * Teslim zamanı. Boş bırakılırsa `null` döner ve sipariş "en kısa
     * sürede" olur — `OrderFactory` bunu `order_time_is_asap` ile işaretler.
     */
    private function collectRequestedAt(array $post): ?Carbon
    {
        $date = trim((string) ($post['requested_date'] ?? ''));
        $time = trim((string) ($post['requested_time'] ?? ''));

        if ($date === '' || $time === '') {
            return null;
        }

        return Carbon::parse($date.' '.$time, BusinessTime::ZONE);
    }

    private function collectSubscriptionId(array $post): ?int
    {
        $id = (int) ($post['subscription_id'] ?? 0);

        if ($id <= 0) {
            return null;
        }

        $subscription = Subscription::query()->find($id);

        throw_unless($subscription instanceof Subscription, new FlashException(
            lang('veykemtu.bridgeapi::phoneorder.alert_subscription_missing'),
        ));

        // Aboneliğin sahibi ile siparişin müşterisi aynı olmalı. Aksi hâlde
        // A firmasının siparişi B firmasının sözleşmesine yazılır ve ay sonu
        // ekstresinde ikisi de yanlış çıkar.
        $customerId = (int) ($post['customer_id'] ?? 0);
        throw_if(
            $customerId > 0 && (int) $subscription->customer_id !== $customerId,
            new FlashException(lang('veykemtu.bridgeapi::phoneorder.alert_subscription_mismatch')),
        );

        return $id;
    }

    /**
     * İLERİ TARİHLİ bir servis gününe ek porsiyon işler — sipariş açmaz.
     *
     * BU AYRI BİR DÜĞME, SİPARİŞ KAYDETMENİN YAN ETKİSİ DEĞİL. İlk tasarımda
     * sipariş formunun içinde bir "ek gün" onay kutusuydu ve iki farklı işi
     * tek harekete bağlıyordu. Yanlıştı, çünkü ikisi zıt sonuçlar üretir:
     *
     *   * Sipariş kaydetmek BUGÜN teslim edilecek bir şey yaratır.
     *   * İstisna yazmak GELECEKTEKİ bir günün üretim adedini değiştirir;
     *     siparişi o gece üretim işi (`veykemtu:abonelik-uret`) açar.
     *
     * İkisi birlikte yapılsaydı aynı porsiyonlar iki kez pişerdi.
     *
     * `quantity_override` MUTLAK BİR SAYIDIR, EKLEME DEĞİL — o günün toplam
     * porsiyonunu belirler. Bu yüzden mevcut değerin (ya da aboneliğin
     * varsayılan adedinin) ÜSTÜNE ekliyoruz. Doğrudan "ek porsiyon" yazmak,
     * 100 kişilik bir aboneliği 10 kişiye düşürürdü; belirtisi de ancak
     * ertesi sabah mutfakta görülürdü.
     *
     * GEÇMİŞ TARİH REDDEDİLİR: o günün üretimi çoktan koştu, istisnanın
     * hiçbir etkisi olmaz ve yönetici bir şey yaptığını sanırdı.
     */
    public function onAddSubscriptionPortions(): RedirectResponse
    {
        $post = Request::post();

        $subscriptionId = (int) ($post['extra_subscription_id'] ?? 0);
        $subscription = Subscription::query()->find($subscriptionId);

        throw_unless($subscription instanceof Subscription, new FlashException(
            lang('veykemtu.bridgeapi::phoneorder.alert_subscription_missing'),
        ));

        $extra = (int) ($post['extra_quantity'] ?? 0);
        throw_if($extra <= 0, new FlashException(
            lang('veykemtu.bridgeapi::phoneorder.alert_extra_quantity'),
        ));

        $date = trim((string) ($post['extra_date'] ?? ''));
        throw_if($date === '', new FlashException(
            lang('veykemtu.bridgeapi::phoneorder.alert_extra_date'),
        ));

        $serviceDate = Carbon::parse($date, BusinessTime::ZONE)->startOfDay();

        throw_if(
            $serviceDate->lessThanOrEqualTo(BusinessTime::now()->startOfDay()),
            new FlashException(lang('veykemtu.bridgeapi::phoneorder.alert_extra_past')),
        );

        $existing = SubscriptionException::query()
            ->where('subscription_id', $subscriptionId)
            ->whereDate('service_date', $serviceDate->toDateString())
            ->first();

        $base = $existing?->quantity_override ?? (int) $subscription->default_quantity;
        $total = $base + $extra;

        SubscriptionException::query()->updateOrCreate(
            [
                'subscription_id' => $subscriptionId,
                'service_date' => $serviceDate->toDateString(),
            ],
            [
                'quantity_override' => $total,
                'skip' => false,
                'note' => lang('veykemtu.bridgeapi::phoneorder.exception_note'),
            ],
        );

        flash()->success(sprintf(
            lang('veykemtu.bridgeapi::phoneorder.alert_extra_saved'),
            $serviceDate->format('d.m.Y'),
            $total,
        ));

        return $this->redirect(self::BASE_URI);
    }

    private function trimmedOrNull(mixed $value): ?string
    {
        $text = trim((string) $value);

        return $text === '' ? null : $text;
    }
}
