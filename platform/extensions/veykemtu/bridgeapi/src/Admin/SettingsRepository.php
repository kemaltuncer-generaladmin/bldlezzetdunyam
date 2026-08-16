<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Admin;

use Igniter\Local\Models\Location;
use Illuminate\Support\Carbon;
use Veykemtu\BridgeApi\Services\LocationGate;

/**
 * "BLD Ayarları" sayfası ile `LocationGate` arasındaki çeviri katmanı.
 *
 * Değerlerin tek kaynağı `LocationGate`'tir (`docs/11-yol-haritasi.md` §8).
 * Bu sınıf ikinci bir kaynak AÇMAZ: `location_options` tablosuna doğrudan
 * tek bir sorgu bile yapmaz, yalnızca gate'in okuyucu/yazıcılarını çağırır.
 * Yaptığı iş üç şeyle sınırlıdır:
 *
 *  1. Form alan adları ile gate metotlarını eşlemek,
 *  2. TL ↔ kuruş dönüşümünü `LiraField`'e devretmek,
 *  3. Mutfak ekranıyla oluşan yoğunluk yarışını çözmek (aşağıda).
 */
final class SettingsRepository
{
    public const string FIELD_ORDERING = 'ordering_enabled';

    public const string FIELD_CUTOFF = 'order_cutoff';

    public const string FIELD_MIN_TOTAL = 'min_order_total_lira';

    public const string FIELD_DELIVERY_FEE = 'delivery_fee_lira';

    public const string FIELD_PAYMENTS = 'payment_methods';

    public const string FIELD_BUSY = 'busy';

    public const string FIELD_BUSY_MESSAGE = 'busy_message';

    /**
     * Sayfa açıldığı andaki yoğunluk değerini taşıyan gizli alan.
     *
     * Mutfak ekranındaki tuş da `bld_busy`'yi değiştirir. Yönetici sayfayı
     * açık bırakıp yarım saat sonra "kaydet" derse, dokunmadığı bir anahtarı
     * eski değerine geri çevirmiş olur. Bu alan, formun hangi değerle
     * çizildiğini geri getirir; kaydetmede yalnızca yöneticinin BİLİNÇLİ
     * olarak değiştirdiği anahtar yazılır (bkz. `save()`).
     */
    public const string FIELD_BUSY_SNAPSHOT = 'busy_snapshot';

    public const string FIELD_PREP_MINUTES = 'prep_minutes';

    public const string FIELD_DELIVERY_MINUTES = 'delivery_minutes';

    public const string FIELD_BUSY_EXTRA_MINUTES = 'busy_extra_minutes';

    /** Bugünden kaç gün sonrasına sipariş alınır (`docs/control/settings.md`). */
    public const string FIELD_LOOKAHEAD = 'max_lookahead_days';

    /** Abonelik siparişlerinin KDS'e düşme saati. */
    public const string FIELD_SUBSCRIPTION_RELEASE = 'subscription_release_time';

    /**
     * İleri sipariş penceresinin TAVANI — iş kararı 3, en fazla 7 gün.
     *
     * `LocationGate::DEFAULT_LOOKAHEAD_DAYS` bugün 30 ve o sabit başka bir
     * kulvarda. Bu sınıf sözleşmenin dediğini uyguluyor: 7'nin üstü kabul
     * edilmiyor ve panele varsayılan olarak 7 bildiriliyor. Daha büyük bir
     * değerin panelden girilebilmesi, kararın sessizce delinmesi olurdu.
     */
    public const int MAX_LOOKAHEAD_DAYS = 7;

    /** Sözleşmedeki varsayılan abonelik düşme saati. */
    public const string DEFAULT_SUBSCRIPTION_RELEASE_TIME = '07:00';

    /** Sözleşmedeki varsayılan: teslimde belge kendiliğinden üretilmez. */
    public const bool DEFAULT_AUTO_INVOICE = false;

    public function __construct(private readonly LocationGate $gate) {}

    /**
     * Ayarların ait olduğu vitrin.
     *
     * Faz 1'de tek vitrin vardır; `is_default` olan öne alınır. Diğer
     * yüzeyler (API denetleyicileri) de aynı sırayı kullanıyor, sayfanın
     * onlardan farklı bir vitrini düzenlemesi sessiz bir tuzak olurdu.
     */
    public function location(): ?Location
    {
        return Location::query()
            ->where('location_status', true)
            ->orderByDesc('is_default')
            ->first();
    }

    /**
     * Gate'teki değerleri form alanlarına çevirir.
     *
     * @return array<string, mixed>
     */
    public function toFormData(Location $location): array
    {
        $busy = $this->gate->isBusy($location);

        return [
            self::FIELD_ORDERING => (int) $this->gate->orderingEnabled($location),
            self::FIELD_CUTOFF => $this->gate->orderCutoff($location) ?? '',
            self::FIELD_MIN_TOTAL => LiraField::toInput($this->gate->minOrderTotal($location)),
            self::FIELD_DELIVERY_FEE => LiraField::toInput($this->gate->deliveryFee($location)),
            self::FIELD_PAYMENTS => $this->gate->paymentMethods($location),
            self::FIELD_BUSY => (int) $busy,
            self::FIELD_BUSY_SNAPSHOT => (int) $busy,
            // Kutuda müşterinin GÖRDÜĞÜ metin durur. Yönetici özel bir metin
            // yazmadıysa bu varsayılandır; kutuyu boşaltmak varsayılana döner
            // (`save()` bunu `null` olarak yazar).
            self::FIELD_BUSY_MESSAGE => $this->gate->busyMessage($location),
            // Dakika alanları gate'ten HER ZAMAN dolu döner (kayıt yoksa
            // varsayılan). Boş kutu göstermiyoruz: yönetici boş bir alanı
            // "tahmin kapalı" sanır, oysa tahmin her koşulda üretiliyor.
            self::FIELD_PREP_MINUTES => $this->gate->prepMinutes($location),
            self::FIELD_DELIVERY_MINUTES => $this->gate->deliveryMinutes($location),
            self::FIELD_BUSY_EXTRA_MINUTES => $this->gate->busyExtraMinutes($location),
            // Kontrol Merkezi'nden yönetilen iki alan panelde de görünür
            // (görev: "TI admin de görebilsin"). Aynı gate'ten okunuyorlar,
            // yani iki yüzeyde tek gerçek var.
            self::FIELD_LOOKAHEAD => $this->gate->maxLookaheadDays($location),
            self::FIELD_SUBSCRIPTION_RELEASE => $this->subscriptionReleaseTime($location),
        ];
    }

    /**
     * Form verisini gate'e yazar.
     *
     * @param  array<string, mixed>  $data
     */
    public function save(Location $location, array $data): void
    {
        $this->gate->setOrderingEnabled(
            $location,
            (bool) (int) ($data[self::FIELD_ORDERING] ?? 0),
        );

        $cutoff = trim((string) ($data[self::FIELD_CUTOFF] ?? ''));
        $this->gate->setOrderCutoff($location, $cutoff === '' ? null : $cutoff);

        $this->gate->setMinOrderTotal(
            $location,
            LiraField::toKurus($data[self::FIELD_MIN_TOTAL] ?? 0),
        );

        $this->gate->setDeliveryFee(
            $location,
            LiraField::toKurus($data[self::FIELD_DELIVERY_FEE] ?? 0),
        );

        $methods = $data[self::FIELD_PAYMENTS] ?? [];
        $this->gate->setPaymentMethods($location, is_array($methods) ? $methods : []);

        // Sıfır veya eksik değer gate'te varsayılana dönüyor
        // (`LocationGate::positiveMinutes`), üst sınır da orada. Burada ikinci
        // bir sınır koymuyoruz: iki yerde yaşayan bir kural, biri
        // değiştiğinde sessizce ayrışır.
        $this->gate->setPrepMinutes($location, (int) ($data[self::FIELD_PREP_MINUTES] ?? 0));
        $this->gate->setDeliveryMinutes($location, (int) ($data[self::FIELD_DELIVERY_MINUTES] ?? 0));
        $this->gate->setBusyExtraMinutes($location, (int) ($data[self::FIELD_BUSY_EXTRA_MINUTES] ?? 0));

        // Tavan burada da uygulanıyor: form kuralı yöneticiye hata gösterir,
        // buradaki `min()` ise elle POST edilen bir değeri keser. İkisi aynı
        // sabitten okuyor, yani ayrışamazlar.
        $this->gate->setMaxLookaheadDays(
            $location,
            min(self::MAX_LOOKAHEAD_DAYS, max(0, (int) ($data[self::FIELD_LOOKAHEAD] ?? 0))),
        );

        $this->saveSubscriptionReleaseTime($location, $data);
        $this->saveBusy($location, $data);
        $this->saveBusyMessage($location, $data);
    }

    /**
     * Yoğunluk anahtarı yalnızca yönetici onu gerçekten çevirdiyse yazılır.
     *
     * Aksi hâlde sayfa açıkken mutfağın bastığı tuş, yöneticinin ilgisiz bir
     * alanı kaydetmesiyle geri alınırdı. Bu, mutfakta "tuş çalışmıyor"
     * şikâyetine dönüşen ve sebebi görünmeyen bir hatadır.
     *
     * @param  array<string, mixed>  $data
     */
    private function saveBusy(Location $location, array $data): void
    {
        $submitted = (bool) (int) ($data[self::FIELD_BUSY] ?? 0);
        $rendered = (bool) (int) ($data[self::FIELD_BUSY_SNAPSHOT] ?? 0);

        if ($submitted !== $rendered) {
            $this->gate->setBusy($location, $submitted);
        }
    }

    /**
     * Boş kutu ve varsayılanın aynen geri gönderilmesi "özel metin yok"
     * demektir; ikisi de `null` yazar. Varsayılan metni kalıcı bir değer
     * olarak saklasaydık, metni ileride değiştirmek imkânsızlaşırdı.
     *
     * @param  array<string, mixed>  $data
     */
    private function saveBusyMessage(Location $location, array $data): void
    {
        $message = trim((string) ($data[self::FIELD_BUSY_MESSAGE] ?? ''));

        $this->gate->setBusyMessage(
            $location,
            ($message === '' || $message === LocationGate::DEFAULT_BUSY_MESSAGE)
                ? null
                : $message,
        );
    }

    /**
     * Abonelik düşme saati — gate henüz bu anahtarı tanımıyorsa yazılmaz.
     *
     * Gerekçe `pendingGateFields()` içindedir. Sessiz düşürme bilinçli
     * DEĞİL: form alanı da aynı listeye bakıp devre dışı çiziliyor, yani
     * yönetici yazamadığı bir kutuya bir şey yazmıyor.
     *
     * @param  array<string, mixed>  $data
     */
    private function saveSubscriptionReleaseTime(Location $location, array $data): void
    {
        if (!array_key_exists(self::FIELD_SUBSCRIPTION_RELEASE, $data)) {
            return;
        }

        if (!method_exists($this->gate, 'setSubscriptionReleaseTime')) {
            return;
        }

        $value = trim((string) $data[self::FIELD_SUBSCRIPTION_RELEASE]);

        $this->gate->setSubscriptionReleaseTime(
            $location,
            $value === '' ? self::DEFAULT_SUBSCRIPTION_RELEASE_TIME : $value,
        );
    }

    // ── Kontrol Merkezi yüzeyi (`docs/control/settings.md`) ────────────────
    //
    // AYNI SINIF, İKİNCİ BİR YÜZ. Kontrol ucunun kendi çeviri katmanını
    // yazması, `location_options` için ikinci bir doğruluk kaynağı açmak
    // olurdu: bir gün admin paneli kuruşa yuvarlarken uç yuvarlamaz ve iki
    // yüzey aynı ayarı farklı gösterir. Form yüzü TL metniyle, kontrol yüzü
    // tam sayı kuruşla konuşuyor; ortak olan şey gate çağrıları.

    /**
     * `GET /api/control/settings/sales` gövdesindeki `data` bloğu.
     *
     * @return array<string, mixed>
     */
    public function toControlData(Location $location): array
    {
        /*
         * SIRA ÖNEMLİ: `orderingEnabled()` süresi dolmuş bir durdurmayı
         * OKUMA ANINDA temizliyor (`LocationGate::resumeOrdering`). Önce
         * `pauseEndsAt()` okunsaydı yanıt "kapalı ama süre dolmuş" gibi
         * çelişkili bir çift taşırdı.
         */
        $enabled = $this->gate->orderingEnabled($location);
        $pausedUntil = $this->gate->pauseEndsAt($location);

        return [
            'location_id' => (int) $location->location_id,
            'location_name' => (string) $location->location_name,

            'ordering_enabled' => $enabled,
            'paused_until' => $pausedUntil?->toIso8601ZuluString(),
            'pause_reason' => $this->gate->pauseReason($location),
            // Çalışma saatlerinden TÜRETİLİR, yazılamaz.
            'is_open' => $this->gate->isOpen($location),

            'order_cutoff' => $this->gate->orderCutoff($location),
            // Gate'in bugünkü varsayılanı 30; sözleşme tavanı 7. Okunan
            // değer OLDUĞU GİBİ bildiriliyor — panelin "şu an ne yazıyor"
            // sorusuna verilecek doğru cevap kayıttaki değerdir, bizim
            // istediğimiz değer değil. Tavan yazma yolunda uygulanıyor.
            'max_lookahead_days' => $this->gate->maxLookaheadDays($location),
            'subscription_release_time' => $this->subscriptionReleaseTime($location),

            'min_order_total_kurus' => $this->gate->minOrderTotal($location),
            'delivery_fee_kurus' => $this->gate->deliveryFee($location),
            'payment_methods' => $this->canonicalPaymentMethods(
                $this->gate->paymentMethods($location),
            ),

            'busy' => $this->gate->isBusy($location),
            'busy_message' => $this->gate->busyMessage($location),

            'prep_minutes' => $this->gate->prepMinutes($location),
            'delivery_minutes' => $this->gate->deliveryMinutes($location),
            'busy_extra_minutes' => $this->gate->busyExtraMinutes($location),

            'daily_menu_enabled' => $this->gate->dailyMenuEnabled($location),
            // SALT OKUNUR: kimliği göç yazar ve yanlış bir kimlik günün
            // menüsünü sıfır liraya sattırır.
            'daily_package_menu_id' => $this->gate->dailyPackageMenuId($location),
            'auto_invoice' => $this->autoInvoice($location),
        ];
    }

    /**
     * `meta.defaults` — alan boşaltıldığında hangi değerin geçerli olacağı.
     *
     * PANELE SUNUCUDAN SÖYLENİR. İstemcinin kendi varsayılanını gömmesi,
     * sunucu varsayılanı değiştiğinde iki farklı gerçek üretirdi.
     *
     * @return array<string, mixed>
     */
    public function controlDefaults(): array
    {
        return [
            'busy_message' => LocationGate::DEFAULT_BUSY_MESSAGE,
            'max_lookahead_days' => self::MAX_LOOKAHEAD_DAYS,
            'prep_minutes' => 40,
            'delivery_minutes' => 20,
            'busy_extra_minutes' => 15,
            'subscription_release_time' => self::DEFAULT_SUBSCRIPTION_RELEASE_TIME,
        ];
    }

    /**
     * `PUT /sales` ile yazılabilen alanlar.
     *
     * `ordering_enabled` BİLEREK YOK — kendi uçları var (`/ordering/pause`,
     * `/ordering/resume`). `is_open` türetiliyor, `daily_package_menu_id`
     * göçün işi. Denetleyici bu listeyi hem doğrulama hem de "yazılamaz
     * alan gönderildi" kontrolü için kullanır.
     *
     * @return list<string>
     */
    public function controlWritableFields(): array
    {
        return [
            'order_cutoff',
            'max_lookahead_days',
            'subscription_release_time',
            'min_order_total_kurus',
            'delivery_fee_kurus',
            'payment_methods',
            'busy',
            'busy_message',
            'prep_minutes',
            'delivery_minutes',
            'busy_extra_minutes',
            'daily_menu_enabled',
            'auto_invoice',
        ];
    }

    /**
     * Sunucu tarafı henüz hazır olmayan sözleşme alanları.
     *
     * `bld_subscription_release_time` ve `bld_auto_invoice` anahtarlarının
     * `LocationGate` erişimcileri BAŞKA BİR KULVARDA yazılıyor
     * (`docs/control/settings.md` — "BAŞKA AJANIN KULVARI"). Erişimci
     * gelene kadar bu alanlar OKUNABİLİR (sözleşmedeki varsayılanla) ama
     * YAZILAMAZ: yazmayı sessizce yutmak, yöneticinin kaydettiğini sandığı
     * bir saatin hiç uygulanmaması demekti — panel `422` ile açıkça
     * öğrenir.
     *
     * Erişimciler eklendiği gün bu metot boş liste döner ve tek satır bile
     * değişmeden kendiliğinden devreden çıkar.
     *
     * @return list<string>
     */
    public function pendingGateFields(): array
    {
        $pending = [];

        if (!method_exists($this->gate, 'setSubscriptionReleaseTime')) {
            $pending[] = 'subscription_release_time';
        }

        if (!method_exists($this->gate, 'setAutoInvoice')) {
            $pending[] = 'auto_invoice';
        }

        return $pending;
    }

    /**
     * İsteği "ne değişecek" listesine çevirir — HİÇBİR ŞEY YAZMAZ.
     *
     * Kuru prova ve gerçek yazma AYNI listeyi kullanır; bu yüzden
     * "kuru prova geçti ama gönderim başka şey yaptı" hâli oluşamaz.
     * Listede yalnız GERÇEKTEN DEĞİŞEN alanlar bulunur: aynı değeri
     * yeniden yazmak denetim izine "değişiklik yok" olarak düşer.
     *
     * @param  array<string, mixed>  $input
     * @return list<array{field:string, from:mixed, to:mixed}>
     */
    public function planControl(Location $location, array $input): array
    {
        $current = $this->toControlData($location);
        $changes = [];

        foreach ($this->controlWritableFields() as $field) {
            if (!array_key_exists($field, $input)) {
                continue;
            }

            $to = $this->normalizeControl($field, $input[$field]);
            $from = $current[$field] ?? null;

            if ($from === $to) {
                continue;
            }

            $changes[] = ['field' => $field, 'from' => $from, 'to' => $to];
        }

        return $changes;
    }

    /**
     * `planControl()` çıktısını gate'e yazar.
     *
     * YOĞUNLUK YARIŞI BURADA DA KORUNUYOR. Form yüzünde çözüm
     * `busy_snapshot`'tı (bkz. `saveBusy()`); kontrol yüzünde çözüm iki
     * katmanlı: (1) `PUT /sales` KISMİ yazar, yani panel yalnız
     * yöneticinin dokunduğu alanı gönderir, (2) gönderse bile değer
     * kayıttakiyle aynıysa `planControl()` onu listeye hiç koymaz ve
     * `setBusy()` ÇAĞRILMAZ. Mutfağın aradaki tuşu, ilgisiz bir ayarı
     * kaydeden yönetici tarafından geri alınamaz — form yüzündeki kuralın
     * aynısı, farklı mekanizmayla.
     *
     * @param  list<array{field:string, from:mixed, to:mixed}>  $changes
     */
    public function applyControl(Location $location, array $changes): void
    {
        foreach ($changes as $change) {
            $value = $change['to'];

            match ($change['field']) {
                'order_cutoff' => $this->gate->setOrderCutoff($location, $value),
                'max_lookahead_days' => $this->gate->setMaxLookaheadDays($location, (int) $value),
                'subscription_release_time' => $this->writeSubscriptionReleaseTime($location, (string) $value),
                'min_order_total_kurus' => $this->gate->setMinOrderTotal($location, (int) $value),
                'delivery_fee_kurus' => $this->gate->setDeliveryFee($location, (int) $value),
                'payment_methods' => $this->gate->setPaymentMethods($location, (array) $value),
                'busy' => $this->gate->setBusy($location, (bool) $value),
                // Varsayılan metnin kendisi geldiyse `null` yazılır: metni
                // kalıcı bir değer olarak saklasaydık ileride değiştirmek
                // imkânsızlaşırdı (`saveBusyMessage()` ile aynı kural).
                'busy_message' => $this->gate->setBusyMessage(
                    $location,
                    $value === LocationGate::DEFAULT_BUSY_MESSAGE ? null : (string) $value,
                ),
                'prep_minutes' => $this->gate->setPrepMinutes($location, (int) $value),
                'delivery_minutes' => $this->gate->setDeliveryMinutes($location, (int) $value),
                'busy_extra_minutes' => $this->gate->setBusyExtraMinutes($location, (int) $value),
                'daily_menu_enabled' => $this->gate->setDailyMenuEnabled($location, (bool) $value),
                'auto_invoice' => $this->writeAutoInvoice($location, (bool) $value),
                default => null,
            };
        }
    }

    /** Satışı durdurur — `POST /ordering/pause`. */
    public function pauseOrdering(Location $location, ?Carbon $until, ?string $customerMessage): void
    {
        $this->gate->pauseOrdering($location, $until, $customerMessage);
    }

    /** Satışı açar ve durdurma izlerini temizler — `POST /ordering/resume`. */
    public function resumeOrdering(Location $location): void
    {
        $this->gate->resumeOrdering($location);
    }

    /**
     * Gelen değeri kayıttaki biçime çevirir.
     *
     * DOĞRULAMA BURADA DEĞİL, denetleyicide: bu metot "geçerli bir değer"
     * varsayar ve yalnız karşılaştırılabilir hâle getirir. İkisini
     * birleştirmek, aynı kuralın hem 422 mesajını hem yazma biçimini
     * üretmesi demekti ve biri değiştiğinde diğeri sessizce ayrışırdı.
     */
    private function normalizeControl(string $field, mixed $value): mixed
    {
        return match ($field) {
            'order_cutoff' => is_string($value) && trim($value) !== '' ? trim($value) : null,
            'subscription_release_time' => trim((string) $value),
            'max_lookahead_days', 'prep_minutes', 'delivery_minutes', 'busy_extra_minutes' => (int) $value,
            'min_order_total_kurus', 'delivery_fee_kurus' => max(0, (int) $value),
            'payment_methods' => $this->canonicalPaymentMethods(is_array($value) ? $value : []),
            'busy', 'daily_menu_enabled', 'auto_invoice' => (bool) $value,
            // Boş kutu "özel metin yok" demektir ve kayıttaki karşılığı
            // varsayılan metindir; `changed` listesinin doğru olması için
            // karşılaştırma da o metin üzerinden yapılır.
            'busy_message' => trim((string) $value) === ''
                ? LocationGate::DEFAULT_BUSY_MESSAGE
                : trim((string) $value),
            default => $value,
        };
    }

    /**
     * Ödeme yöntemi listesini karşılaştırılabilir tek bir sıraya çeker.
     *
     * SIRA SABİTLENMEZSE `["cash","online"]` ile `["online","cash"]` farklı
     * görünür ve `changed` listesi hiç değişmemiş bir ayarı değişmiş
     * gösterirdi. Tekrarlar da burada eleniyor.
     *
     * @param  array<int|string, mixed>  $methods
     * @return list<string>
     */
    private function canonicalPaymentMethods(array $methods): array
    {
        return array_values(array_intersect(
            LocationGate::ALL_PAYMENT_METHODS,
            array_map(strval(...), $methods),
        ));
    }

    /**
     * Abonelik düşme saati — gate erişimcisi yoksa sözleşme varsayılanı.
     *
     * Gerekçe `pendingGateFields()` içinde.
     */
    private function subscriptionReleaseTime(Location $location): string
    {
        if (!method_exists($this->gate, 'subscriptionReleaseTime')) {
            return self::DEFAULT_SUBSCRIPTION_RELEASE_TIME;
        }

        $value = $this->gate->subscriptionReleaseTime($location);

        return is_string($value) && trim($value) !== ''
            ? trim($value)
            : self::DEFAULT_SUBSCRIPTION_RELEASE_TIME;
    }

    private function autoInvoice(Location $location): bool
    {
        return method_exists($this->gate, 'autoInvoice')
            ? (bool) $this->gate->autoInvoice($location)
            : self::DEFAULT_AUTO_INVOICE;
    }

    private function writeSubscriptionReleaseTime(Location $location, string $value): void
    {
        if (!method_exists($this->gate, 'setSubscriptionReleaseTime')) {
            return;
        }

        $this->gate->setSubscriptionReleaseTime($location, $value);
    }

    private function writeAutoInvoice(Location $location, bool $value): void
    {
        if (!method_exists($this->gate, 'setAutoInvoice')) {
            return;
        }

        $this->gate->setAutoInvoice($location, $value);
    }
}
