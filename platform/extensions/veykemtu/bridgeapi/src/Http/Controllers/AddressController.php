<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Igniter\User\Models\Address;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Services\Geocoding\AddressLookup;
use Veykemtu\BridgeApi\Services\ServiceArea;
use Veykemtu\BridgeApi\Services\StructuredAddress;

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
    public function __construct(private readonly AddressLookup $lookup) {}

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
     * Adres önerisi — `GET /api/addresses/suggest?q=&limit=`.
     *
     * SAĞLAYICI ÇÖKERSE `200` + BOŞ LİSTE. Bu ucun `5xx` dönmesi, dışarıdaki
     * bir servisin kendi sipariş akışımızı durdurabilmesi demek olurdu; oysa
     * öneri bir KOLAYLIK — adres alanları elle de doldurulabiliyor ve harita
     * iğnesi isteğe bağlı. Arıza `AddressLookup` içinde yutulup günlüğe
     * yazılıyor.
     *
     * Boş liste iki şeyi birden anlatır ("uyan adres yok" / "şu an öneri
     * veremiyoruz") ve istemci ikisini AYIRT ETMEZ: doğru davranış ikisinde
     * de aynı, alanları elle doldurtmak.
     *
     * `422` yalnızca isteğin KENDİSİ bozuksa: `q` yok ya da 3 karakterden
     * kısa. Bu bir istemci hatasıdır (debounce kapısı sızdırmış demektir) ve
     * sağlayıcı arızasıyla aynı yanıta karışmasın diye ayrı tutuluyor.
     */
    public function suggest(Request $request): JsonResponse
    {
        $data = $request->validate([
            'q' => [
                'required',
                'string',
                'min:'.AddressLookup::MIN_QUERY_LENGTH,
                'max:'.AddressLookup::MAX_QUERY_LENGTH,
            ],
            // Üst sınır 10: liste bir metin alanının altında açılan bir
            // katman ve telefonda onuncu satır zaten klavyenin altında
            // kalıyor. Ayrıca her satır sağlayıcıdan gelen bir yük.
            'limit' => ['sometimes', 'integer', 'min:1', 'max:'.AddressLookup::MAX_LIMIT],
        ]);

        return $this->noStore([
            'data' => $this->lookup->suggest(
                (string) $data['q'],
                (int) ($data['limit'] ?? AddressLookup::DEFAULT_LIMIT),
            ),
        ]);
    }

    /**
     * Ters geocoding — `GET /api/addresses/reverse?lat=&lng=`.
     *
     * Haritaya iğne bırakıldığında adres metnini kendiliğinden doldurur.
     *
     * KUTU DIŞI NOKTA `422`, boş yanıt değil. Öneri ucunda sessiz boş liste
     * doğruydu çünkü orada söylenecek net bir şey yok; burada var: kullanıcı
     * haritayı GÖRDÜ ve teslimat yapmadığımız bir yeri kasten seçti. Sessiz
     * bir boş yanıt "arıza var" gibi okunurdu.
     *
     * Sağlayıcı o noktayı bilmiyorsa ya da erişilemiyorsa `200` + `data:
     * null` — istemci iğneyi KORUR ve alanları elle doldurtur.
     */
    public function reverse(Request $request): JsonResponse
    {
        $data = $request->validate([
            // `lat`/`lng` ÇİFT hâlinde zorunlu. Kayıtlı adreste yarım
            // koordinat sessizce `null`'a düşüyor; burada çifti tamamlamanın
            // yolu yok — sorulacak bir nokta yoksa soru da yoktur.
            'lat' => ['required', 'numeric', 'between:-90,90'],
            'lng' => ['required', 'numeric', 'between:-180,180'],
        ]);

        $latitude = (float) $data['lat'];
        $longitude = (float) $data['lng'];

        if (!ServiceArea::containsPoint($latitude, $longitude)) {
            throw ApiException::validationFailed(
                'Seçilen konum hizmet alanımızın dışında.',
                // Sözleşme bu gerekçeyi ADIYLA istiyor: istemci "kutu dışı"
                // durumunu diğer doğrulama hatalarından ayırıp haritada
                // bölgeyi gösterebiliyor.
                ['reason' => 'out_of_service_area'],
            );
        }

        return $this->noStore([
            'data' => $this->lookup->reverse($latitude, $longitude),
        ]);
    }

    /**
     * Ara katmanların paylaşımlı önbelleğine GİRMEYEN yanıt.
     *
     * `/suggest` ve `/reverse` yanıtı giriş yapmış bir müşterinin yazdığı
     * metne bağlı ve yazılan adres kişisel veridir (`docs/02` §6). Bir vekil
     * ya da CDN bunu paylaşımlı önbelleğe alsaydı bir müşterinin aradığı
     * adres başkasına dönebilirdi.
     *
     * @param array<string, mixed> $data
     */
    private function noStore(array $data): JsonResponse
    {
        return $this->json($data)
            ->header('Cache-Control', 'private, no-store');
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
        $data = $request->validate([
            'label' => ['sometimes', 'nullable', 'string', 'max:64'],

            /*
             * `line1` ZORUNLU KALIR — sözleşme (`SavedAddressInput`) onu
             * `required` listesinde tutuyor ve tutmaya devam edecek: sahadaki
             * istemci sürümleri yalnız bu alanı gönderiyor, fiş ve kurye
             * ekranı yalnız bunu basıyor.
             *
             * Tek gevşeme, yapılandırılmış alanlarla dolduran YENİ istemci
             * için: mahalle/sokak/bina gönderip `line1` göndermezse sunucu
             * cümleyi kurar. Kural `required` yerine `required_without_all`
             * yazılmasa türetme HİÇ ÇALIŞAMAZDI — istek doğrulamadan
             * geçemeden reddedilirdi.
             *
             * Gönderilen `line1` AYNEN KORUNUR (bkz. `fill()`): müşteri
             * kendi yazdığını görebilmeli.
             */
            'line1' => [
                'required_without_all:'.implode(',', StructuredAddress::LINE_SOURCES),
                'nullable', 'string', 'max:255',
            ],

            // Hizmet alanı denetimi sipariş ucundakiyle aynı (`ServiceArea`).
            // Defter gevşek bırakılsaydı müşteri teslimat yapmadığımız bir
            // adresi kaydeder, ödeme ekranında seçer ve reddedilirdi.
            'district' => ['required', 'string', 'max:96', ServiceArea::districtRule()],
            'city' => ['required', 'string', 'max:96', ServiceArea::cityRule()],
            'note' => ['sometimes', 'nullable', 'string', 'max:255'],
            'is_default' => ['sometimes', 'boolean'],

            // Koordinat isteğe bağlı: haritayı kullanmayan müşteri adresi
            // elle yazıp sipariş verebilmeli. Ama GELDİYSE aralık dışı
            // olamaz — sınır denetimi yoksa istemcinin ters çevirdiği
            // enlem/boylam sessizce kaydedilir ve kurye okyanusa gönderilir.
            'latitude' => ['sometimes', 'nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['sometimes', 'nullable', 'numeric', 'between:-180,180'],

            // Yapılandırılmış beş alan (B-21). Kurallar `StructuredAddress`
            // içinde: aynı beş alan sipariş ucunda da doğrulanıyor ve iki
            // listenin ayrışması, defterde kabul edilen bir adresin siparişte
            // reddedilmesi demek olurdu.
            ...StructuredAddress::rules(),
        ]);

        // Çift tamsa kutunun içinde olmalı. Aralık denetimi (`between`)
        // yalnızca "dünya üzerinde bir yer mi" diye sorar; hizmet alanı
        // denetimi "bizim gittiğimiz yer mi" diye sorar.
        $lat = $data['latitude'] ?? null;
        $lng = $data['longitude'] ?? null;

        if ($lat !== null && $lng !== null
            && !ServiceArea::containsPoint((float) $lat, (float) $lng)) {
            throw ApiException::validationFailed('Seçilen konum hizmet alanımızın dışında.', [
                'latitude' => 'Haritadan seçilen nokta teslimat bölgemizin dışında.',
            ]);
        }

        return $data;
    }

    /** @param array<string, mixed> $data */
    private function fill(Address $address, array $data): void
    {
        // Sipariş adresiyle AYNI eşleme kullanılıyor
        // (`OrderPresenter::address`): `state` sütunu ilçeyi, `address_2`
        // kurye notunu taşır. İki farklı eşleme, ikisinin ayrıştığı gün
        // adresin yarısının kaybolması demekti.
        $address->bld_label = $data['label'] ?? null;
        $address->state = (string) $data['district'];
        $address->city = (string) $data['city'];
        $address->address_2 = $data['note'] ?? null;

        // Parçalar ÖNCE yazılıyor: `line1` türetilecekse cümle, isteğin
        // getirdiği YENİ değerlerden kurulmalı. Sıra ters olsaydı bir
        // güncellemede eski daire numarası cümlede kalırdı.
        StructuredAddress::write($address, $data);

        /*
         * Müşterinin yazdığı `line1` AYNEN korunur; türetme yalnızca boş
         * geldiğinde çalışır. Her zaman türetilseydi "Sanayi sitesi, mavi
         * kepenkli dükkân" gibi kuryenin gerçekten kullandığı tarifler
         * sessizce silinir ve yerine parçalardan kurulmuş yavan bir cümle
         * yazılırdı.
         */
        $line1 = trim((string) ($data['line1'] ?? ''));
        $address->address_1 = $line1 !== ''
            ? $line1
            : StructuredAddress::lineFor($address);

        // `array_key_exists`, `??` DEĞİL: `null` göndermek "koordinatı sil"
        // demek ve saygı görmeli. `??` ile yazılsaydı iğnesini kaldıran
        // müşterinin eski koordinatı kayıtta kalırdı.
        $touchesLat = array_key_exists('latitude', $data);
        $touchesLng = array_key_exists('longitude', $data);

        if (!$touchesLat && !$touchesLng) {
            return;
        }

        // Yarım çift SAKLANMAZ. Koruma yalnızca okumada olsaydı veritabanında
        // "enlem var, boylam yok" satırları birikirdi: API doğru şekilde
        // null gösterir ama panelden bakan yönetici ya da ileride yazılacak
        // bir rapor bunu geçerli bir nokta sanar. Tutarsızlığı kaynağında
        // kesiyoruz.
        $lat = $touchesLat ? $data['latitude'] : $address->bld_latitude;
        $lng = $touchesLng ? $data['longitude'] : $address->bld_longitude;

        $complete = $lat !== null && $lng !== null;
        $address->bld_latitude = $complete ? $lat : null;
        $address->bld_longitude = $complete ? $lng : null;
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

            // Yapılandırılmış alanlar (B-21). Eski kayıtlarda hepsi `null`
            // ve öyle kalıyor: geçmiş adresleri geriye dönük ayrıştırmak,
            // ayrıştırmanın yanlış olduğu her satırda kuryeyi yanlış kapıya
            // götürürdü.
            ...StructuredAddress::read($address),

            'district' => (string) ($address->state ?? ''),
            'city' => (string) ($address->city ?? ''),
            'note' => $address->address_2 !== null && $address->address_2 !== ''
                ? (string) $address->address_2
                : null,
            'is_default' => (bool) $address->bld_is_default,

            // Koordinat ÇİFT olarak anlamlı. Yarısı dolu bir kayıt haritada
            // gösterilemez ama istemci "koordinat var" sanıp iğneyi
            // ekvatora koyar. Eksikse ikisi de null döner.
            ...self::coordinates($address),
        ];
    }

    /**
     * Enlem/boylam çifti — yalnızca ikisi de doluysa.
     *
     * @return array{latitude: float|null, longitude: float|null}
     */
    private static function coordinates(Address $address): array
    {
        $lat = $address->bld_latitude;
        $lng = $address->bld_longitude;

        if ($lat === null || $lng === null) {
            return ['latitude' => null, 'longitude' => null];
        }

        return ['latitude' => (float) $lat, 'longitude' => (float) $lng];
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
