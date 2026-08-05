<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Admin;

use Igniter\Local\Models\Location;
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
}
