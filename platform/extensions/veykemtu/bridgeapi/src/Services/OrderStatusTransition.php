<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Igniter\Admin\Models\Status;
use Igniter\Cart\Models\Order;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Services\Sms\SmsDispatcher;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Support\Money;
use Veykemtu\Payment\Refunds\RefundManager;

/**
 * Sipariş durum makinesi — `docs/02-veri-modeli.md` §3.
 *
 * **Kararı sunucu verir.** İstemci yalnızca hedef durumu ister; burası izin
 * verir veya `422 INVALID_TRANSITION` ile reddeder. İstemcideki aynı matris
 * (`packages/core`) sadece geçersiz butonu göstermemek içindir, güvenlik
 * sınırı burasıdır.
 */
class OrderStatusTransition
{
    public function __construct(
        private readonly RefundManager $refunds,
        private readonly DailyStock $stock,
        private readonly SmsDispatcher $sms,
    ) {}

    public const string NEW = 'yeni';

    public const string CONFIRMED = 'onaylandi';

    public const string PREPARING = 'hazirlaniyor';

    public const string READY = 'hazir';

    public const string ON_THE_WAY = 'yolda';

    public const string DELIVERED = 'teslim_edildi';

    public const string CANCELLED = 'iptal';

    /** Sözleşmedeki yedi kod, admin panelindeki sırayla. */
    public const array CODES = [
        self::NEW,
        self::CONFIRMED,
        self::PREPARING,
        self::READY,
        self::ON_THE_WAY,
        self::DELIVERED,
        self::CANCELLED,
    ];

    /** @var array<string, list<string>> */
    private const array MATRIX = [
        self::NEW => [self::CONFIRMED, self::CANCELLED],
        self::CONFIRMED => [self::PREPARING, self::CANCELLED],
        self::PREPARING => [self::READY, self::CANCELLED],
        self::READY => [self::ON_THE_WAY, self::DELIVERED, self::CANCELLED],
        self::ON_THE_WAY => [self::DELIVERED, self::CANCELLED],
        self::DELIVERED => [],
        self::CANCELLED => [],
    ];

    /**
     * GERİ ALMA PENCERESİ (K-10, 11.08.2026).
     *
     * `docs/05` §3 "geri alma yoktur" diyordu ve dokunmatik monitör
     * gelene kadar doğruydu: klavyeyle yanlış kartı ilerletmek zordu.
     * Dokunmatikte kartlar parmağın altında ve yanlışlıkla kaydırma
     * gerçek — geri alınamayan bir dokunuş, siparişi yanlış sütuna
     * gönderip mutfağı gereksiz fiş basmaya zorluyor.
     *
     * KURALLAR (dar tutuldu, çünkü geri alma bir kaçış kapısıdır):
     *   * yalnız TEK ADIM geri (`hazir` -> `hazirlaniyor`),
     *   * yalnız bu pencere içinde (`status_updated_at`'ten itibaren),
     *   * terminal durumlardan (`teslim_edildi`, `iptal`) ASLA — iptal
     *     cari hesaba ters kayıt yazıyor, geri alması muhasebe düzeltmesi
     *     olurdu ve bu ekranın işi değil,
     *   * `yeni`ye geri dönülemez: mutfak fişi `onaylandi`da basıldı,
     *     `yeni`ye dönmek basılı fişi geçersiz kılardı.
     */
    public const int UNDO_WINDOW_SECONDS = 120;

    /**
     * Geri alma haritası: her durumun tek bir önceki adımı.
     *
     * @var array<string, string>
     */
    private const array UNDO = [
        self::PREPARING => self::CONFIRMED,
        self::READY => self::PREPARING,
        self::ON_THE_WAY => self::READY,
    ];

    /**
     * Durum kodu -> SMS şablon anahtarı (`docs/control/sms.md` "Şablonlar").
     *
     * ANAHTARLAR ORADA SABİTTİR, burada türetilmezler: `'order.'.$to` gibi
     * bir birleştirme `order.onaylandi` üretirdi ve panelde o anahtarla bir
     * şablon YOK — `PATCH /templates/order.onaylandi` sözleşme gereği 404.
     * Eşleme elle yazıldı ki iki taraf da aynı sözlüğü konuşsun.
     *
     * ÜÇ DURUM BİLEREK LİSTEDE YOK. `yeni` bir geçiş hedefi değil;
     * `hazirlaniyor` ve `hazir` ise mutfağın kendi ritmi — müşteriye "yemeğiniz
     * tencereye girdi" diye SMS atmak, tek siparişte beş mesaj demekti ve
     * `sms.md` o şablonları tanımlamıyor.
     *
     * @var array<string, string>
     */
    private const array SMS_TEMPLATES = [
        self::CONFIRMED => 'order_confirmed',
        self::ON_THE_WAY => 'order_on_the_way',
        self::DELIVERED => 'order_delivered',
        self::CANCELLED => 'order_cancelled',
    ];

    /**
     * Sipariş durumunu ilerletir.
     *
     * `$comment` geçişin **neden** olduğunu `status_history`'ye yazar; boş
     * bırakılırsa çekirdeğin varsayılanı geçerli olur. Mevcut çağıranların
     * hiçbiri etkilenmiyor.
     *
     * `$notifyCustomer` MÜŞTERİ SMS'İNİ kapatır, çekirdeğin `notify`
     * bayrağını değil. İki sebebi var ve ikisi de gerçek: `docs/control/
     * orders.md` iptal ucuna `notify_customer` alanı koyuyor (elden haber
     * verilmiş bir iptalde ikinci kez SMS atmamak için), ve
     * `confirmDelivery()` aşağıda ara adımı susturmak zorunda. Varsayılan
     * `true` — mevcut çağıranların davranışı değişmiyor.
     *
     * @throws ApiException geçersiz geçişte
     */
    public function apply(
        Order $order,
        string $to,
        ?int $userId = null,
        ?string $comment = null,
        bool $notifyCustomer = true,
    ): Order {
        $from = $this->codeOf($order);
        $this->assertAllowed($order, $from, $to);

        // GERİ ALMA SMS ÜRETMEZ ve bu, tetikleyicinin en kolay atlanan
        // köşesi. `hazirlaniyor -> onaylandi` geri adımı matriste yok ama
        // buradan geçiyor; şablon eşlemesine körü körüne bakan bir tetikleyici
        // müşteriye İKİNCİ bir "siparişiniz onaylandı" SMS'i atardı. Yanlış
        // dokunuşu düzeltmenin bedeli, müşterinin telefonunda ikinci bir
        // mesaj olmamalı. Hesap `updateOrderStatus()` ÖNCESİNDE yapılıyor:
        // sonrasında `$from` artık geçmişte kalır.
        $isUndo = (self::UNDO[$from] ?? null) === $to;

        $status = $this->statusByCode($to);

        // Çekirdeğin kendi metodu kullanılır: status_history kaydını,
        // bildirim tetiklerini ve status_updated_at'i o yönetir.
        // Kendi UPDATE'imizi yazmak bu üçünü sessizce atlardı.
        $order->updateOrderStatus($status->status_id, array_filter([
            'notify' => (bool) $status->notify_customer,
            'user_id' => $userId,
            'comment' => $comment,
        ], static fn($value): bool => $value !== null));

        if ($to === self::CANCELLED) {
            /*
             * STOK GERİ VERİLİR (S2) — ve YALNIZ BİR KEZ.
             *
             * İptal edilen sipariş pişmeyecek; porsiyonları başkasına
             * satılabilmeli. Çift kredi koruması `orders.
             * bld_stock_released_at` ile ve `releaseOrder()` içinde ATOMİK:
             * çift tıklama ya da KDS'in yeniden denemesi ikinci bir kredi
             * üretmez. Detayı orada.
             *
             * İADEDEN ÖNCE: iade kaydı `RefundManager` üzerinden dış bir
             * geçide uzanabiliyor. Stok geri verme yerel ve ucuz bir işlem;
             * geçit yavaşladığında porsiyonun satışa dönmesini bekletmenin
             * bir sebebi yok.
             *
             * ABONELİK SİPARİŞİNDE DE AYNI SATIR, FAZLASI DEĞİL. Abonelikler
             * stoku ÖNCE rezerve ediyor (iş kararı 6) ve iptal edilen
             * porsiyon serbest satışa dönmeli — aboneye düşen tek gerçek yan
             * etki bu. ABONELİĞİN SAYAÇLARINA DOKUNULMAZ: abonelik durmaz,
             * ödenmiş 30 gün 29'a inmez, `veykemtu_subscription_runs` satırı
             * silinmez (`docs/control/orders.md`) — silinseydi gece işi
             * ertesi koşuda aynı günü yeniden üretir ve iptal kendini geri
             * alırdı. `SubscriptionLifecycle`'ın dört olayı da abonelik
             * düzeyindedir; tek bir günün siparişini karşılayan bir olayı
             * YOKTUR ve buradan oraya bir çağrı, sipariş iptalini abonelik
             * durumuna bağlayan ilk halka olurdu.
             */
            $this->stock->releaseOrder($order);

            $this->openRefundOnCancel($order);
        }

        /*
         * SMS EN SONDA — sırası tesadüf değil.
         *
         * Yukarıdaki işler yerel ve ucuz (durum yazımı, stok kredisi, iade
         * kaydı); SMS ise ağa çıkıyor. Önce sıraya konsaydı, sağlayıcının
         * yavaşladığı bir dakikada mutfağın kart ilerletmesi o gecikmenin
         * arkasında beklerdi.
         *
         * `try` İLE SARILMADI ve bu bilinçli: `SmsDispatcher` gönderim
         * hatasında fırlatmıyor, kendi kaydına `failed` satırı yazıp
         * dönüyor (`docs/control/sms.md` — "sağlayıcı hata verirse 502
         * değil, status: failed"). Buraya bir `catch` koymak, dispatcher'ın
         * bir gün sözleşmesini değiştirmesi hâlinde hatayı görünmez kılardı.
         */
        if ($notifyCustomer && !$isUndo) {
            $this->notifyCustomer($order, $to, $comment);
        }

        return $order->refresh();
    }

    /**
     * Kuryenin QR'la verdiği teslim onayı — K-20.
     *
     * NEDEN AYRI METOT VE NEDEN İKİ ADIM: fiş `hazir` durumunda basılıyor,
     * ama `assertAllowed()` adrese gönderimde `hazir -> teslim_edildi`
     * geçişini açıkça reddediyor ("önce yola çıkarılmalı", `docs/02` §3) ve
     * mutfakta kimse "yolda" düğmesine basmamış olabilir.
     *
     * MATRİS GEVŞETİLMEDİ. Gevşetmek, `yolda` adımını atlama iznini
     * **bütün** istemcilere verirdi ve `docs/02`'de bir değişiklik
     * gerektirirdi. Bunun yerine burada iki dürüst geçiş yapılıyor: kurye
     * gerçekten yola çıktı ve gerçekten vardı — ikisini aynı anda öğrendik.
     *
     * TEK İŞLEM İÇİNDE: arada bir hata olursa sipariş "yolda"da asılı
     * kalmasın, ya ikisi de olsun ya hiçbiri.
     *
     * ARA ADIM SESSİZ (`notifyCustomer: false`). İki geçiş bir defter
     * düzeltmesidir, iki ayrı olay değil: kurye kapıda QR'ı okuttuğunda
     * "kuryeniz yola çıktı" SMS'i ile "siparişiniz teslim edildi" SMS'i
     * saniyeler arayla giderdi ve birincisi ARTIK DOĞRU DEĞİL. Müşteriye
     * gerçekten olan tek şey bildiriliyor: teslimat.
     *
     * @throws ApiException zaten teslim edilmiş, iptal edilmiş ya da henüz
     *                      hazır olmayan siparişte
     */
    public function confirmDelivery(Order $order, string $comment): Order
    {
        return DB::transaction(function () use ($order, $comment): Order {
            $current = $this->codeOf($order);

            if ($current === self::READY && $order->order_type === Order::DELIVERY) {
                $order = $this->apply($order, self::ON_THE_WAY, null, $comment, false);
            }

            return $this->apply($order, self::DELIVERED, null, $comment);
        });
    }

    /**
     * İptal edilen siparişin parası için iade kaydı açar (K-13).
     *
     * İade kaydı `pending`/`manual` olarak açılır ve admin panelde biri
     * tamamlayana kadar açık durur — kaydetmemek, müşterinin parasını
     * görünmez biçimde beklemesi demekti.
     *
     * ÖDENMEMİŞ SİPARİŞ İADE ÜRETMEZ: kapıda ödeme henüz tahsil
     * edilmediyse iade edilecek bir şey yok.
     *
     * CARİ İSTİSNASI KALKTI. Eskiden `payment === 'account'` olan sipariş
     * buradan erken dönüyordu: para hareketi yoktu, borç deftere ters
     * kayıtla nötrleniyordu. Defter kaldırıldığına göre o telafi de yok.
     * Arşivde kalan eski bir cari siparişi bugün iptal edilirse — ki
     * `processed` işaretliyse parası bir yerde tahsil edilmiş demektir —
     * `RefundManager` onu `ManualRefund`'a düşürür ve panelde ELLE
     * kapatılacak bir iade satırı açar. İptali sessizce yutmak, o parayı
     * kimsenin bakmadığı bir yerde bırakırdı.
     */
    private function openRefundOnCancel(Order $order): void
    {
        if (!(bool) $order->processed) {
            return;
        }

        $this->refunds->refund(
            $order,
            Money::toKurus($order->order_total),
            'Sipariş iptal edildi',
        );
    }

    /** @throws ApiException */
    public function assertAllowed(Order $order, string $from, string $to): void
    {
        if (!in_array($to, self::CODES, true)) {
            throw ApiException::validationFailed('Geçersiz durum kodu.', [
                'status' => 'Şunlardan biri olmalı: '.implode(', ', self::CODES),
            ]);
        }

        if ($from === $to) {
            throw ApiException::invalidTransition(
                $from,
                $to,
                'Sipariş zaten bu durumda.',
            );
        }

        if (!in_array($to, self::MATRIX[$from] ?? [], true)) {
            // Geri alma, matriste olmayan tek istisnadır. Matrise
            // eklenmedi: eklenseydi `allowedFrom()` geri adımı normal bir
            // seçenek gibi sunar ve arayüzde kalıcı bir "GERİ" düğmesi
            // olurdu. Geri alma kalıcı bir yol değil, dar bir penceredir.
            if ($this->canUndoTo($order, $from, $to)) {
                return;
            }

            throw ApiException::invalidTransition(
                $from,
                $to,
                'Sipariş bu duruma geçirilemez.',
            );
        }

        // `hazir` sonrası dal teslimat tipine bağlıdır (docs/02 §3):
        // adrese gönderimde kurye adımı atlanamaz, gel-al'da kurye adımı yoktur.
        if ($from === self::READY) {
            $isDelivery = $order->order_type === Order::DELIVERY;

            if ($to === self::ON_THE_WAY && !$isDelivery) {
                throw ApiException::invalidTransition(
                    $from,
                    $to,
                    'Gel-al siparişi yola çıkarılamaz.',
                );
            }

            if ($to === self::DELIVERED && $isDelivery) {
                throw ApiException::invalidTransition(
                    $from,
                    $to,
                    'Adrese gönderim siparişi önce yola çıkarılmalı.',
                );
            }
        }
    }

    /**
     * Siparişin mevcut durum kodu.
     *
     * Kodsuz bir durum (TastyIgniter varsayılanı) `yeni` sayılır: eski bir
     * sipariş veya elle değiştirilmiş bir kayıt yüzünden API çökmemeli.
     */
    public function codeOf(Order $order): string
    {
        $code = Status::where('status_id', $order->status_id)->value('status_code');

        return is_string($code) && $code !== '' ? $code : self::NEW;
    }

    /** @throws ApiException */
    public function statusByCode(string $code): Status
    {
        $status = Status::where('status_code', $code)->first();

        if ($status === null) {
            // Kurulum eksik demektir — istemcinin suçu değil.
            throw ApiException::serverError(
                "Durum tanımlı değil: {$code}. `php artisan veykemtu:setup` çalıştırılmalı.",
            );
        }

        return $status;
    }

    /** @return list<string> */
    public function allowedFrom(Order $order): array
    {
        $from = $this->codeOf($order);
        $allowed = self::MATRIX[$from] ?? [];

        if ($from !== self::READY) {
            return $allowed;
        }

        $isDelivery = $order->order_type === Order::DELIVERY;

        return array_values(array_filter(
            $allowed,
            static fn(string $to): bool => match ($to) {
                self::ON_THE_WAY => $isDelivery,
                self::DELIVERED => !$isDelivery,
                default => true,
            },
        ));
    }

    /**
     * Bu geçiş bir geri alma mı ve süresi geçmemiş mi?
     *
     * Süre `status_updated_at` üzerinden ölçülüyor: çekirdek bu alanı
     * `updateOrderStatus()` içinde yazıyor, yani "son durum değişikliğinin
     * üstünden ne kadar geçti" sorusunun doğru cevabı orada.
     */
    public function canUndoTo(Order $order, string $from, string $to): bool
    {
        if ((self::UNDO[$from] ?? null) !== $to) {
            return false;
        }

        $changedAt = $order->status_updated_at;

        // Zaman damgası yoksa geri almaya İZİN VERİLMEZ. "Bilinmiyorsa
        // serbest" demek, eski bir siparişin günler sonra geri alınabilmesi
        // olurdu.
        if ($changedAt === null) {
            return false;
        }

        return $changedAt->diffInSeconds(BusinessTime::now()) <= self::UNDO_WINDOW_SECONDS;
    }

    /**
     * Şu an geri alınabilecek durum — yoksa `null`.
     *
     * Arayüz "Geri al" şeridini yalnız bu doluyken gösterir.
     */
    public function undoTargetFor(Order $order): ?string
    {
        $from = $this->codeOf($order);
        $to = self::UNDO[$from] ?? null;

        return $to !== null && $this->canUndoTo($order, $from, $to) ? $to : null;
    }

    /** Müşteri iptal edebilir mi? — `docs/03` §4. */
    public function customerCanCancel(Order $order): bool
    {
        return in_array($this->codeOf($order), [self::NEW, self::CONFIRMED], true);
    }

    /**
     * Durum SMS'i — `docs/control/sms.md`.
     *
     * ÇEKİRDEĞİN BİLDİRİM SİSTEMİNE BAĞLANILMADI. TastyIgniter'ın kendi
     * `order status` şablonları var ve `updateOrderStatus()` içindeki
     * `notify` bayrağı onları tetikliyor; buradan İKİNCİ bir kanal açmak
     * değil, MÜŞTERİYE GİDEN TEK SMS'i bizim şablon defterimize bağlamak
     * amaçlandı. Çekirdeğin şablonları e-posta tarafındadır ve panelden
     * yönetilen SMS metinlerimizden habersizdir; ikisini birleştirmek aynı
     * olay için iki farklı metin demekti.
     *
     * İKİ SESSİZ ÇIKIŞ VAR ve ikisi de "gönderilecek bir şey yok" diyor:
     * şablonsuz durum ve telefonsuz sipariş. Kapalı şablonun ya da eksik
     * kaydın denetimi burada DEĞİL — onlar `SmsDispatcher`'ın verdiği
     * sözler (`sms.md`: kapalı şablon iz bırakmaz, aynı olay iki mesaj
     * üretmez). Burada tekrarlamak, `enabled` bayrağının iki yerde
     * yorumlanması olurdu.
     *
     * TEKİLLEŞTİRME ANAHTARI `('order', order_id)`: dispatcher bunu şablon
     * anahtarıyla birleştirip `UNIQUE` bir satır yazıyor, yani KDS'in
     * yeniden denemesi ya da çift dokunuş ikinci bir mesaj üretemez.
     */
    private function notifyCustomer(Order $order, string $to, ?string $comment): void
    {
        $template = self::SMS_TEMPLATES[$to] ?? null;

        if ($template === null) {
            return;
        }

        // Numarası olmayan sipariş var: admin panelinden telefonla alınan
        // kurumsal siparişte alan boş bırakılabiliyor. Dispatcher boş
        // numaraya `skipped` satırı yazardı; yazacak bir olay yokken kaydı
        // gürültüyle doldurmanın anlamı yok.
        $phone = trim((string) ($order->telephone ?? ''));

        if ($phone === '') {
            return;
        }

        $this->sms->send(
            $template,
            $phone,
            $this->smsVariables($order, $to, $comment),
            'order',
            (int) $order->order_id,
        );
    }

    /**
     * Şablon değişkenleri — `docs/control/sms.md` "Şablonlar" tablosu.
     *
     * HER ŞABLONA YALNIZ KENDİ DEĞİŞKENLERİ. Hepsini her seferinde
     * göndermek kolay olurdu ama `{eta}` değeri teslim SMS'inde anlamsız bir
     * yük; tablo hangi metnin neyi kullandığını söylüyor ve buradaki dallar
     * onu birebir izliyor.
     *
     * @return array<string, string>
     */
    private function smsVariables(Order $order, string $to, ?string $comment): array
    {
        /*
         * VARSAYIM: müşteriye gösterilen sipariş numarası `S-<id>`.
         * `OrderPresenter::number()` ile aynı biçim; SMS'te başka bir numara
         * yazmak, müşterinin uygulamada gördüğü siparişi bulamaması demekti.
         * ÇAĞRILMIYOR, TEKRARLANIYOR: `OrderPresenter` bu sınıfı yapıcısına
         * alıyor, buradan onu çözmek dairesel bağımlılık olurdu.
         * (`sms.md` örneklerindeki `BLD-8421` bir örnek metindir, kodda
         * karşılığı olan bir numaralandırma değil.)
         */
        $variables = ['order_no' => 'S-'.$order->order_id];

        if ($to === self::CONFIRMED || $to === self::CANCELLED) {
            $variables['service_date'] = $this->serviceDateLabel($order);
        }

        if ($to === self::ON_THE_WAY) {
            $variables['eta'] = $this->etaLabel($order);
        }

        if ($to === self::CANCELLED) {
            $variables['reason'] = $this->customerReason($comment);
        }

        return $variables;
    }

    /**
     * Servis günü, SMS'e yazılacak hâliyle.
     *
     * `d.m.Y` — API'nin `YYYY-AA-GG` biçimi sözleşme içindir, müşteriye
     * giden metin Türkçe okunur olmalı (`sms.md` örneği: `17.08.2026`).
     */
    private function serviceDateLabel(Order $order): string
    {
        $date = $order->bld_service_date ?? $order->order_date;

        return $date !== null ? Carbon::parse($date)->format('d.m.Y') : '';
    }

    /**
     * `{eta}` — kuryenin çıktığı SMS'teki tek sayı.
     *
     * MÜŞTERİNİN SEÇTİĞİ SAAT KULLANILIYOR, `EtaService` tahmini DEĞİL.
     * Catering siparişi bir saat dilimi için verilir ve müşteri o saati
     * kendisi seçti; kurye çıkarken "40-55 dakika" demek, verilmiş sözün
     * üstüne ikinci ve çelişebilen bir söz koymaktır. ASAP siparişte seçilmiş
     * bir saat yok, o zaman da sayı uydurulmuyor.
     */
    private function etaLabel(Order $order): string
    {
        $time = $order->order_time;

        if ((bool) $order->order_time_is_asap || $time === null) {
            return 'en kısa sürede';
        }

        return Carbon::parse($time)->format('H:i');
    }

    /**
     * İptal gerekçesinin MÜŞTERİYE gösterilebilir hâli.
     *
     * Kontrol Merkezi'nden gelen yorum `"Kontrol Merkezi · <yönetici>:
     * <gerekçe>"` kalıbında (`Control\ControlController::actorLabel()`).
     * YÖNETİCİNİN ADI SMS'E GİRMEZ: iç denetim izinin müşteriye gitmesi,
     * kimsenin istemediği bir şeffaflıktır ve `sms.md` denetim satırlarına
     * bile ad-telefon yazmama çizgisiyle aynı yöne bakıyor.
     *
     * Gerekçesiz iptaller var (müşterinin kendi iptali, mutfak panosu):
     * onlarda metin `Belirtilmedi` olur — `{reason}` boş kalsa SMS
     * "Sebep: ." diye biterdi.
     */
    private function customerReason(?string $comment): string
    {
        $reason = trim((string) $comment);

        if (preg_match('/^Kontrol Merkezi · [^:]+: (.+)$/su', $reason, $parts) === 1) {
            $reason = trim($parts[1]);
        }

        return $reason !== '' ? $reason : 'Belirtilmedi';
    }
}
