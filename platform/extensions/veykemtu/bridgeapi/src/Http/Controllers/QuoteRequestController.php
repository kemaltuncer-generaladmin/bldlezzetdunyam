<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Throwable;
use Veykemtu\BridgeApi\Models\QuoteRequest;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Teklif talebi ucu — `docs/openapi.yaml` §Teklif.
 *
 * Kimlik GEREKTİRMEZ: formu dolduran kişi henüz müşteri değil, olması da
 * beklenmiyor. Teklif isteyebilmek için önce hesap açtırmak, formun tamamen
 * doldurulup gönderilmemesinin en yaygın sebebidir. Koruma kimlikte değil
 * oran sınırındadır (`bld-quote`, `Extension::registerRateLimiters`).
 *
 * ## DOĞRULAMA NEDEN GEVŞEK
 *
 * Bu ucun başarısızlığı "hatalı istek" değil, **kaybedilmiş iş** demektir.
 * Ziyaretçi formu bir kez doldurur; 422 gördüğünde çoğu zaman tekrar
 * denemez, rakibe gider. Bu yüzden:
 *
 *  - **Bilinmeyen alanlar sessizce yok sayılır.** Aşağıda yalnızca bilinen
 *    anahtarlar okunuyor; gövdeye eklenen fazladan bir alan (sitenin ileride
 *    ekleyeceği `utm_source` gibi) isteği reddettirmez. Sıkı bir "yalnızca bu
 *    alanlar" kuralı, sitenin bir sürüm önde gitmesi hâlinde talep akışını
 *    tamamen durdururdu.
 *  - **Sözleşme dışı DEĞERLER de kabul edilir.** `service_type`, `frequency`
 *    ve `menu_preference` enum ile kısıtlanmıyor: site yeni bir hizmet
 *    eklediğinde slug önce orada doğar, burada sonra tanınır. Enum, o aradaki
 *    her talebi çöpe atardı. Değer metin olarak saklanır; panelde okunur.
 *  - **Uzun metin kesilir, reddedilmez.** 2000 karakteri aşan bir açıklama
 *    için talebi geri çevirmek, 100 karakter fazlalık uğruna müşteri
 *    kaybetmektir.
 *
 * ## SERT OLAN İKİ KURAL
 *
 *  1. **KVKK onayı.** Onaysız kişisel veri saklamak hukuki sorundur; onaysız
 *     gönderim kaydedilmeden 422 döner. Bu tek "kaybetmeyi göze aldığımız"
 *     durumdur ve site zaten onay kutusunu zorunlu tutuyor.
 *  2. **Ulaşılabilir olmak.** Ad ile birlikte telefon VEYA e-postadan en az
 *     biri gerekir. İkisi de yoksa kayıt bir işe yaramaz: firma teklifi
 *     kimseye gönderemez, kayıt yalnızca kişisel veri biriktirir.
 */
class QuoteRequestController extends ApiController
{
    /** Kısa metin alanlarının sütun sınırları — kesme noktaları. */
    private const array LIMITS = [
        'full_name' => 120,
        'organization' => 160,
        'telephone' => 32,
        'email' => 160,
        'service_type' => 64,
        'frequency' => 32,
        'location' => 160,
        'menu_preference' => 32,
        'kitchen_note' => 2000,
        'message' => 5000,
    ];

    /**
     * Kişi sayısı tavanı.
     *
     * Aşan değer reddedilmez, tavana çekilir ve gerçek sayı zaten
     * açıklamaya yazılır (sitedeki form da böyle yönlendiriyor). Sütun
     * `unsignedInteger`; tavansız bırakmak taşma hatasıyla talebi
     * kaybettirirdi.
     */
    private const int MAX_HEADCOUNT = 1000000;

    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'full_name' => ['required', 'string'],
            // `required_without` çifti: ikisinden en az biri dolu olmalı.
            // `nullable` ile birlikte, boş gelen alanın "biçim hatası"
            // vermesi de engelleniyor — e-posta yoksa telefon yeter.
            'telephone' => ['nullable', 'required_without:email'],
            'email' => ['nullable', 'required_without:telephone'],
            // `accepted` alan yokken de başarısız olur; ayrıca `required`
            // yazmak gereksiz.
            'kvkk_accepted' => ['accepted'],
        ], [
            'full_name.required' => 'Ad ve soyad gerekiyor.',
            'telephone.required_without' => 'Size ulaşabilmemiz için telefon veya e-posta girin.',
            'email.required_without' => 'Size ulaşabilmemiz için telefon veya e-posta girin.',
            'kvkk_accepted.accepted' => 'KVKK aydınlatma metnini onaylamadan talebinizi kaydedemiyoruz.',
        ]);

        $quote = new QuoteRequest;
        $quote->fill($this->attributesFrom($request));
        $quote->save();

        /*
         * YANIT KAYDIN KENDİSİNİ DÖNMEZ, `id` DE DÖNMEZ.
         *
         * Uç herkese açık; artan bir kimlik döndürmek, formu iki kez
         * dolduran herkese "bu firmaya ayda kaç teklif talebi geliyor"
         * bilgisini verirdi. Site zaten yanıt gövdesini kullanmıyor,
         * yalnızca başarıya bakıyor.
         */
        return $this->json([
            'status' => (string) $quote->status,
            'received_at' => self::ts($quote->created_at),
        ], 201);
    }

    /**
     * Gövdeden yalnızca BİLİNEN alanları alır ve sütunlara uydurur.
     *
     * Beyaz liste burada: `$request->all()` ile doldurmak, gövdeye konan
     * herhangi bir anahtarın (`status`, `admin_note`) modele geçmesi
     * demekti — herkese açık bir uçta talebin durumunu ziyaretçinin
     * belirlemesi olurdu.
     *
     * @return array<string, mixed>
     */
    private function attributesFrom(Request $request): array
    {
        return [
            'full_name' => self::text($request->input('full_name'), self::LIMITS['full_name']),
            'organization' => self::text($request->input('organization'), self::LIMITS['organization']),
            'telephone' => self::text($request->input('telephone'), self::LIMITS['telephone']),
            'email' => self::text($request->input('email'), self::LIMITS['email']),
            'service_type' => self::text($request->input('service_type'), self::LIMITS['service_type']),
            'headcount' => self::count($request->input('headcount')),
            'frequency' => self::text($request->input('frequency'), self::LIMITS['frequency']),
            'start_date' => self::date($request->input('start_date')),
            'location' => self::text($request->input('location'), self::LIMITS['location']),
            'menu_preference' => self::text($request->input('menu_preference'), self::LIMITS['menu_preference']),
            'kitchen_note' => self::text($request->input('kitchen_note'), self::LIMITS['kitchen_note']),
            'message' => self::text($request->input('message'), self::LIMITS['message']),
            // Onay anı SUNUCUDA damgalanıyor, gövdeden alınmıyor: istemcinin
            // bildirdiği bir zaman, hukuki bir kayıt için delil değildir.
            'kvkk_accepted_at' => Carbon::now(),
            'submitted_at' => self::date($request->input('submitted_at')),
            'status' => QuoteRequest::STATUS_NEW,
        ];
    }

    /**
     * Metin alanı: kırpar, boşu `null` yapar, sütun sınırında keser.
     *
     * Dizi veya nesne gelirse `null` döner — düzleştirmeye çalışmak
     * "Array to string conversion" ile 500 üretirdi ve talep yine kaybolurdu.
     */
    private static function text(mixed $value, int $limit): ?string
    {
        if (is_bool($value) || (! is_string($value) && ! is_numeric($value))) {
            return null;
        }

        $trimmed = trim((string) $value);

        return $trimmed === '' ? null : mb_substr($trimmed, 0, $limit);
    }

    private static function count(mixed $value): ?int
    {
        if (! is_numeric($value)) {
            return null;
        }

        $number = (int) $value;

        return $number > 0 ? min($number, self::MAX_HEADCOUNT) : null;
    }

    /**
     * Tarih alanı: çözümlenemeyen değer talebi düşürmez, boş bırakılır.
     *
     * `Carbon::parse` geçersiz metinde istisna atar. Onu yakalamamak,
     * ziyaretçinin tarih kutusuna elle yazdığı "yazın" kelimesi yüzünden
     * tüm talebin kaybolması demekti.
     *
     * `BusinessTime::forStorage` ŞART. Site `submitted_at`'i `Z` sonekli UTC
     * gönderiyor ve Eloquent bir Carbon'u YAZARKEN nesnenin kendi zaman
     * dilimini, OKURKEN PHP varsayılanını (Europe/Istanbul) kullanıyor;
     * dönüştürmeden kaydedilen değer panelde üç saat geride görünürdü.
     * Gerekçenin tamamı o metodun üzerinde.
     */
    private static function date(mixed $value): ?Carbon
    {
        if (! is_string($value) || trim($value) === '') {
            return null;
        }

        try {
            return BusinessTime::forStorage(Carbon::parse($value));
        } catch (Throwable) {
            return null;
        }
    }
}
