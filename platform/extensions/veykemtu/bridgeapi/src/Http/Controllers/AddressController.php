<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Igniter\User\Models\Address;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ApiCustomer;

/**
 * Müşterinin adres defteri — `docs/openapi.yaml` §Adresler.
 *
 * NEDEN VAR: bugün her sipariş adresi sıfırdan yazdırıyor. Haftada üç
 * kez sipariş veren bir ofis müşterisi aynı adresi haftada üç kez
 * yazıyor ve bir harf hatası kuryeyi yanlış kapıya götürüyor.
 *
 * SİPARİŞ ADRESİ BURADAN **KOPYALANIR, BAĞLANMAZ.**
 * `OrderFactory::storeAddress()` her siparişte yeni bir satır açar ve
 * öyle kalmalıdır. Sipariş kayıtlı adrese *işaret etseydi*, müşteri
 * adresini düzelttiğinde geçmiş siparişlerin teslimat adresi de
 * geçmişe dönük değişirdi — teslim edilmiş bir siparişin nereye
 * gittiği artık okunamazdı. Teslimat adresi değişmez bir kayıttır.
 *
 * Bu yüzden defter satırları `bld_is_saved = true`, sipariş anlık
 * görüntüleri `false` ile işaretlenir; liste yalnızca defteri gösterir.
 */
class AddressController extends ApiController
{
    public function index(Request $request): JsonResponse
    {
        $rows = $this->query($request)
            ->orderByDesc('bld_is_default')
            ->orderByDesc('address_id')
            ->get();

        return $this->json([
            'data' => $rows->map($this->payload(...))->values()->all(),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validated($request);

        $address = new Address;
        $address->customer_id = $this->customer($request)->customer_id;
        $this->fill($address, $data);
        $address->bld_is_saved = true;
        $address->save();

        // İlk adres kendiliğinden varsayılan olur. Müşteriyi tek adresi
        // için ayrıca "varsayılan yap" demeye zorlamak anlamsız.
        if ($this->countSaved($request) === 1) {
            $this->makeDefault($request, (int) $address->address_id);
            $address->refresh();
        } elseif (($data['is_default'] ?? false) === true) {
            $this->makeDefault($request, (int) $address->address_id);
            $address->refresh();
        }

        return $this->json($this->payload($address), 201);
    }

    public function update(Request $request, int $address): JsonResponse
    {
        $model = $this->find($request, $address);
        $data = $this->validated($request);

        $this->fill($model, $data);
        $model->save();

        if (($data['is_default'] ?? false) === true) {
            $this->makeDefault($request, (int) $model->address_id);
            $model->refresh();
        }

        return $this->json($this->payload($model));
    }

    /**
     * Defterden siler.
     *
     * Bu GERÇEK bir silmedir ve güvenlidir: sipariş adresleri ayrı
     * satırlardır, defter satırına bağlı değildir. Geçmiş siparişlerin
     * adresi olduğu yerde kalır.
     */
    public function destroy(Request $request, int $address): JsonResponse
    {
        $model = $this->find($request, $address);
        $wasDefault = (bool) $model->bld_is_default;
        $model->delete();

        // Varsayılan silindiyse boşta bırakmıyoruz: müşteri ödeme
        // ekranında hiçbir adres seçili görmemeli.
        if ($wasDefault) {
            $next = $this->query($request)->orderByDesc('address_id')->first();

            if ($next !== null) {
                $this->makeDefault($request, (int) $next->address_id);
            }
        }

        return $this->noContent();
    }

    /** @return array<string, mixed> */
    private function validated(Request $request): array
    {
        return $request->validate([
            'label' => ['sometimes', 'nullable', 'string', 'max:64'],
            'line1' => ['required', 'string', 'max:255'],
            'district' => ['required', 'string', 'max:96'],
            'city' => ['required', 'string', 'max:96'],
            'note' => ['sometimes', 'nullable', 'string', 'max:255'],
            'is_default' => ['sometimes', 'boolean'],
        ]);
    }

    /** @param array<string, mixed> $data */
    private function fill(Address $address, array $data): void
    {
        // Sipariş adresiyle AYNI eşleme kullanılıyor
        // (`OrderPresenter::address`): `state` sütunu ilçeyi, `address_2`
        // kurye notunu taşır. İki farklı eşleme, ikisinin ayrıştığı gün
        // adresin yarısının kaybolması demekti.
        $address->bld_label = $data['label'] ?? null;
        $address->address_1 = (string) $data['line1'];
        $address->state = (string) $data['district'];
        $address->city = (string) $data['city'];
        $address->address_2 = $data['note'] ?? null;
    }

    /** @return array<string, mixed> */
    private function payload(Address $address): array
    {
        return [
            'id' => (int) $address->address_id,
            'label' => $address->bld_label !== null && $address->bld_label !== ''
                ? (string) $address->bld_label
                : null,
            'line1' => (string) $address->address_1,
            'district' => (string) ($address->state ?? ''),
            'city' => (string) ($address->city ?? ''),
            'note' => $address->address_2 !== null && $address->address_2 !== ''
                ? (string) $address->address_2
                : null,
            'is_default' => (bool) $address->bld_is_default,
        ];
    }

    /**
     * Varsayılanı taşır.
     *
     * Tek sorguda sıfırlayıp tek sorguda işaretliyoruz: iki adresin
     * birden varsayılan kalması, ödeme ekranının hangisini seçeceğini
     * belirsiz bırakırdı.
     */
    private function makeDefault(Request $request, int $addressId): void
    {
        $customerId = $this->customer($request)->customer_id;

        DB::transaction(static function () use ($customerId, $addressId): void {
            DB::table('addresses')
                ->where('customer_id', $customerId)
                ->where('bld_is_saved', true)
                ->update(['bld_is_default' => false]);

            DB::table('addresses')
                ->where('address_id', $addressId)
                ->update(['bld_is_default' => true]);
        });
    }

    private function countSaved(Request $request): int
    {
        return $this->query($request)->count();
    }

    /** @return \Illuminate\Database\Eloquent\Builder<Address> */
    private function query(Request $request)
    {
        return Address::query()
            ->where('customer_id', $this->customer($request)->customer_id)
            ->where('bld_is_saved', true);
    }

    /** @throws ApiException */
    private function find(Request $request, int $addressId): Address
    {
        $model = $this->query($request)->where('address_id', $addressId)->first();

        // Başkasının adresi de 404 döner, 403 değil: 403, o kimliğin var
        // olduğunu doğrular ve numaraları taramaya davet eder
        // (`docs/03` §5, sipariş uçlarıyla aynı kural).
        if ($model === null) {
            throw ApiException::notFound('Adres bulunamadı.');
        }

        return $model;
    }

    private function customer(Request $request): ApiCustomer
    {
        $customer = $request->user();

        if (!$customer instanceof ApiCustomer) {
            throw ApiException::unauthenticated();
        }

        return $customer;
    }
}
