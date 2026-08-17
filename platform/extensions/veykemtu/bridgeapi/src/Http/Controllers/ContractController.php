<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\SubscriptionContract;
use Veykemtu\BridgeApi\Services\ContractService;
use Veykemtu\BridgeApi\Services\OtpService;

/**
 * Abonelik sözleşmesinin açık uçları — `docs/openapi.yaml` §Sözleşme.
 *
 * SINIF ADI `routes/api.php`'DEN GELİR ve metot adları da öyle
 * (`show`/`requestOtp`/`approve`). Rota dosyası sabittir; ayrışma ne
 * açılışta ne `route:list`'te hata verir, yalnız uç çağrılınca patlar —
 * üstelik `class_exists()` nöbetçisi yüzünden sınıf adı tutmazsa rotalar hiç
 * kaydedilmez ve uçlar sessizce 404 döner.
 *
 * KİMLİK GEREKTİRMEZ. Bağlantı aboneye SMS ile gidiyor ve onaylayan kişi
 * çoğu zaman uygulamada oturum açmış kişi değil, satın almayı onaylayan
 * yetkilidir; oturum istemek onayı imkânsız hâle getirirdi. Koruma
 * bağlantının kendisinde (imzalı, süreli, kayıt kimliği taşımayan belirteç)
 * ve SMS kodunda.
 *
 * NEDEN AYRI DENETLEYİCİ: `SubscriptionController` tümüyle `bld.auth` +
 * `bld.scope:customer` grubunun içinde yaşıyor. Kimliksiz bir eylemi o
 * sınıfın içine katmak, ileride birinin ortak bir yardımcıya
 * `$request->user()` eklemesiyle null başvurusuna dönerdi
 * (`PublicTrackingController` ile aynı gerekçe).
 */
class ContractController extends ApiController
{
    public function __construct(private readonly ContractService $contracts) {}

    /**
     * `GET /api/contracts/{token}` — sözleşmeyi oku.
     *
     * SÜRESİ DOLMUŞ BAĞLANTI `410` DEĞİL, `200` + `status: expired` DÖNER:
     * istemci "bu bağlantının süresi doldu, yenisini isteyin" cümlesini
     * kurabilmeli, boş bir hata sayfası görmemelidir. `404` yalnız belirteç
     * hiç tanınmadığında — kurcalanmış imza da tanınmayan bir belirteçtir.
     */
    public function show(string $token): JsonResponse
    {
        return $this->json(['data' => $this->contracts->apiPayload($this->resolve($token))]);
    }

    /**
     * `POST /api/contracts/{token}/otp` — onay kodu iste.
     *
     * Yanıt, kod gerçekten gönderilmiş olsun olmasın aynı biçimdedir
     * (`OtpService` kayıtlı olmayan numarada sessizce çıkıyor).
     */
    public function requestOtp(string $token): JsonResponse
    {
        $this->contracts->requestOtp($this->resolve($token));

        return $this->json([
            'message' => 'Kod gönderildi. SMS birkaç saniye içinde ulaşır.',
            'expires_in' => OtpService::TTL_SECONDS,
            'resend_after' => OtpService::RESEND_COOLDOWN_SECONDS,
        ], 202);
    }

    /**
     * `POST /api/contracts/{token}/approve` — sözleşmeyi onayla.
     *
     * ONAYIN DELİLİ BURADA TOPLANIR: `$request->ip()` ve `User-Agent`. IP'nin
     * gerçek istemciyi göstermesi `TrustProxies` ayarına bağlı; bu depoda
     * özel ağ aralıklarıyla ayarlı, yani Caddy'nin iç adresi değil müşterinin
     * adresi kaydediliyor.
     */
    public function approve(Request $request, string $token): JsonResponse
    {
        $data = $request->validate([
            'code' => ['required', 'string', 'size:6'],
            'full_name' => ['nullable', 'string', 'max:120'],
        ], [
            'code.required' => 'Telefonunuza gelen kodu girin.',
            'code.size' => 'Kod 6 haneli olmalı.',
        ]);

        $contract = $this->contracts->approve(
            $this->resolve($token),
            (string) $data['code'],
            isset($data['full_name']) ? (string) $data['full_name'] : null,
            $request->ip(),
            $request->userAgent(),
        );

        return $this->json(['data' => $this->contracts->apiPayload($contract)]);
    }

    /**
     * Belirteci sözleşmeye çözer.
     *
     * SÜRE BURADA DENETLENMEZ — üç ucun üçü de süresi dolmuş bağlantıyı
     * görmeli: `show` onu `expired` diye yayınlıyor, öbür ikisi
     * `ContractService` içinde `422` ile reddediyor. Burada `410` atsaydık
     * `show`'un sözleşmedeki davranışını kırardık.
     *
     * @throws ApiException
     */
    private function resolve(string $token): SubscriptionContract
    {
        $contract = $this->contracts->find($token);

        if (!$contract instanceof SubscriptionContract) {
            throw ApiException::notFound('Sözleşme bulunamadı.');
        }

        return $contract;
    }
}
