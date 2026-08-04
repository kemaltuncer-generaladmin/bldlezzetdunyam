<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Igniter\User\Models\CustomerGroup;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ApiCustomer;

/**
 * Kimlik uçları — `docs/openapi.yaml` §Kimlik.
 *
 * Token'lar Sanctum'dur ve `customer` yeteneğiyle üretilir; mutfak uçlarına
 * geçemezler (ADR-08, `docs/10-test-kabul.md` S5).
 */
class AuthController extends ApiController
{
    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'first_name' => ['required', 'string', 'max:64'],
            'last_name' => ['required', 'string', 'max:64'],
            'email' => ['required', 'email', 'max:96', Rule::unique('customers', 'email')],
            'telephone' => ['required', 'string', 'regex:/^[1-9][0-9]{9}$/'],
            'password' => ['required', 'string', 'min:8', 'max:128'],
            'kvkk_accepted' => ['required', 'accepted'],
        ], [
            'kvkk_accepted.accepted' => 'KVKK aydınlatma metnini onaylamanız gerekiyor.',
            'telephone.regex' => 'Telefon 10 haneli olmalı (başında 0 veya +90 olmadan).',
            'email.unique' => 'Bu e-posta zaten kayıtlı.',
        ]);

        $customer = new ApiCustomer;
        $customer->first_name = $data['first_name'];
        $customer->last_name = $data['last_name'];
        $customer->email = $data['email'];
        $customer->telephone = $data['telephone'];
        $customer->password = $data['password'];
        $customer->customer_group_id = $this->defaultGroupId();
        $customer->status = true;
        // KVKK onayı zaman damgasıyla saklanır (docs/02 §6).
        $customer->is_activated = true;
        $customer->activated_at = now();
        $customer->save();

        return $this->json($this->authPayload($customer), 201);
    }

    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $customer = ApiCustomer::where('email', $data['email'])->first();

        // Kullanıcı yok ile şifre yanlış aynı mesajı döner: hangi e-postaların
        // kayıtlı olduğunu sızdırmamak için.
        if ($customer === null || !Hash::check($data['password'], (string) $customer->password)) {
            throw ApiException::validationFailed('E-posta veya şifre hatalı.', [
                'email' => 'Doğrulanamadı.',
            ]);
        }

        if ((bool) $customer->status !== true) {
            throw ApiException::forbidden('Hesabınız devre dışı. Bizimle iletişime geçin.');
        }

        return $this->json($this->authPayload($customer));
    }

    public function logout(Request $request): JsonResponse
    {
        // Yalnızca bu isteği yapan token silinir; kullanıcının diğer
        // cihazlardaki oturumları etkilenmez.
        $request->user()?->currentAccessToken()?->delete();

        return $this->noContent();
    }

    public function me(Request $request): JsonResponse
    {
        /** @var ApiCustomer $customer */
        $customer = $request->user();

        return $this->json([
            'id' => (int) $customer->customer_id,
            'first_name' => (string) $customer->first_name,
            'last_name' => (string) $customer->last_name,
            'email' => (string) $customer->email,
            'telephone' => (string) ($customer->telephone ?? ''),
            'default_location_id' => $this->defaultLocationId(),
        ]);
    }

    public function pushToken(Request $request): JsonResponse
    {
        $data = $request->validate([
            'fcm_token' => ['required', 'string', 'max:512'],
            'platform' => ['sometimes', Rule::in(['android'])],
        ]);

        /** @var ApiCustomer $customer */
        $customer = $request->user();

        // Tablo `veykemtu/push` eklentisine aittir ama uç sözleşmede müşteri
        // tarafındadır. Eklenti henüz yoksa istek sessizce başarılı sayılır:
        // istemcinin push kaydı yüzünden hata alması, siparişten daha
        // önemsiz bir işin ana akışı bozması demek olurdu.
        if (!$this->pushTableExists()) {
            return $this->noContent();
        }

        DB::table('veykemtu_device_tokens')->updateOrInsert(
            ['customer_id' => $customer->customer_id, 'fcm_token' => $data['fcm_token']],
            ['platform' => $data['platform'] ?? 'android', 'updated_at' => now()],
        );

        return $this->noContent();
    }

    /** @return array<string, mixed> */
    private function authPayload(ApiCustomer $customer): array
    {
        // Aynı hesabın birden çok cihazda açık kalması normaldir (web + mobil),
        // bu yüzden eski token'lar silinmez.
        $token = $customer->createToken('istemci', [ApiCustomer::SCOPE]);

        return [
            'token' => $token->plainTextToken,
            'customer' => [
                'id' => (int) $customer->customer_id,
                'first_name' => (string) $customer->first_name,
            ],
        ];
    }

    private function defaultGroupId(): ?int
    {
        $id = CustomerGroup::where('group_name', 'Catering Müşterisi')->value('customer_group_id');

        return $id !== null ? (int) $id : null;
    }

    private function defaultLocationId(): ?int
    {
        $id = DB::table('locations')
            ->where('location_status', true)
            ->orderByDesc('is_default')
            ->value('location_id');

        return $id !== null ? (int) $id : null;
    }

    private function pushTableExists(): bool
    {
        return DB::getSchemaBuilder()->hasTable('veykemtu_device_tokens');
    }
}
