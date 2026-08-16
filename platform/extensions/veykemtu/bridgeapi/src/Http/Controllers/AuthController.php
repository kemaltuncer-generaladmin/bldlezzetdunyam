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
use Veykemtu\BridgeApi\Services\OtpService;

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

            // Kurum alanları — KALICI OLARAK OPSİYONEL. Kurumsal sipariş
            // kapısı kalktı; bu alanlar artık bir yetki değil, faturaya ve
            // fişe basılan serbest metin etikettir. Zorunlu kılmak, kurumu
            // olmayan bir müşteriyi kayıt olamaz hâle getirirdi.
            'company_name' => ['sometimes', 'nullable', 'string', 'max:160'],
            'tax_office' => ['sometimes', 'nullable', 'string', 'max:120'],
            'tax_number' => ['sometimes', 'nullable', 'string', 'max:32'],
            'contact_person' => ['sometimes', 'nullable', 'string', 'max:120'],
            'company_phone' => ['sometimes', 'nullable', 'string', 'max:32'],
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
        // `bld_account_type` artık bir KAPI DEĞİL, SERBEST METİN ETİKET:
        // kurumsal sipariş kapısı (`CustomerGate`) kaldırıldı ve herkes
        // sipariş verebiliyor. Varsayılan yine 'corporate' — kolonun
        // veritabanı varsayılanıyla ve bugüne kadarki her kayıtla aynı
        // değer; değiştirmek geçmişi ikiye bölerdi.
        // Alanlar tek tek atanır (toplu fill değil) — çekirdek Customer'ın
        // fillable'ı bld_* kolonlarını içermez, AuthController kalıbı budur.
        $customer->bld_account_type = 'corporate';
        $customer->bld_org_name = $data['company_name'] ?? null;
        $customer->bld_tax_office = $data['tax_office'] ?? null;
        $customer->bld_tax_no = $data['tax_number'] ?? null;
        $customer->bld_contact_person = $data['contact_person'] ?? null;
        $customer->bld_org_phone = $data['company_phone'] ?? null;
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

    /**
     * Telefona giriş kodu gönderir — `POST /api/auth/otp/request` (B-18).
     *
     * YANIT HER ZAMAN AYNI: numara kayıtlı olsun olmasın 202 döner ve gövde
     * değişmez. "Bu numara kayıtlı değil" demek, saldırgana müşteri
     * listesini numara numara taratma imkânı verirdi — üstelik kurumsal
     * müşteri listesi ticari olarak da hassas.
     *
     * SMS gönderimi başarısız olursa istisna fırlar ve kullanıcı açık bir
     * hata görür; sessizce 202 dönmek, gelmeyecek bir kodu bekleten bir
     * kullanıcı üretirdi.
     */
    public function requestOtp(Request $request): JsonResponse
    {
        $data = $request->validate([
            // Biçim GEVŞEK tutuluyor: `0555...`, `+90 555...` ve boşluklu
            // yazımların hepsi kabul edilip `OtpService::normalize` ile tek
            // biçime indiriliyor. Katı bir regex, doğru numarayı alışkın
            // olduğu gibi yazan müşteriyi kapıda çevirirdi.
            'phone' => ['required', 'string', 'min:10', 'max:20'],
        ], [
            'phone.required' => 'Telefon numaranızı girin.',
        ]);

        resolve(OtpService::class)->request($data['phone']);

        return $this->json([
            'message' => 'Kod gönderildi. SMS birkaç saniye içinde ulaşır.',
            'expires_in' => OtpService::TTL_SECONDS,
            'resend_after' => OtpService::RESEND_COOLDOWN_SECONDS,
        ], 202);
    }

    /**
     * Kodu doğrular ve oturum açar — `POST /api/auth/otp/verify` (B-18).
     *
     * Şifreli girişle AYNI gövdeyi döndürüyor (`authPayload`): istemci
     * tarafında iki ayrı oturum kurma yolu olmasın, token nereden gelirse
     * gelsin aynı şekilde saklansın.
     */
    public function verifyOtp(Request $request): JsonResponse
    {
        $data = $request->validate([
            'phone' => ['required', 'string', 'min:10', 'max:20'],
            'code' => ['required', 'string', 'size:6'],
        ], [
            'code.size' => 'Kod 6 haneli olmalı.',
        ]);

        $customer = resolve(OtpService::class)->verify($data['phone'], $data['code']);

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

        // Kolon boşsa 'corporate' — grandfather davranışı korunuyor.
        $accountType = (string) ($customer->bld_account_type ?: 'corporate');

        return $this->json([
            'id' => (int) $customer->customer_id,
            'first_name' => (string) $customer->first_name,
            'last_name' => (string) $customer->last_name,
            'email' => (string) $customer->email,
            'telephone' => (string) ($customer->telephone ?? ''),
            'default_location_id' => $this->defaultLocationId(),
            /*
             * `account_type` ve `can_order` YAYINLANMIŞ ALANLARDIR ve
             * kurumsal sipariş kapısı kalksa da SİLİNMEZLER (`docs/03` §1.4:
             * alan silinmez, sadece eklenir). Flutter modellerinde ikisi de
             * nullable değil — silmek, konuşlanmış uygulamada ayrıştırma
             * hatası demekti.
             *
             * `can_order` artık SABİT `true`: herkes sipariş verebiliyor.
             * `account_type` saklanan dizeyi döndürmeye devam ediyor, çünkü
             * kolon serbest metin etiket olarak duruyor.
             */
            'account_type' => $accountType,
            'can_order' => true,
            'company_name' => $customer->bld_org_name,
            'contact_person' => $customer->bld_contact_person,
        ]);
    }

    /**
     * Profil güncelleme.
     *
     * E-POSTA DEĞİŞTİRİLEMEZ. Giriş kimliği odur; değiştirmek doğrulama
     * akışı (yeni adrese onay bağlantısı) ister, o da yoksa hesabı
     * başkasının e-postasına taşımanın yolu olur. Ayrı bir iş.
     */
    public function updateMe(Request $request): JsonResponse
    {
        /** @var ApiCustomer $customer */
        $customer = $request->user();

        $data = $request->validate([
            'first_name' => ['sometimes', 'required', 'string', 'max:64'],
            'last_name' => ['sometimes', 'required', 'string', 'max:64'],
            'telephone' => ['sometimes', 'required', 'string', 'regex:/^[1-9][0-9]{9}$/'],
            // Kurumsal alanlar güncellenebilir; vergi kimliği (tax_no/office)
            // e-posta gibi kilitli — değişimi ayrı doğrulama ister.
            'company_name' => ['sometimes', 'nullable', 'string', 'max:160'],
            'contact_person' => ['sometimes', 'nullable', 'string', 'max:120'],
            'company_phone' => ['sometimes', 'nullable', 'string', 'max:32'],
        ], [
            'telephone.regex' => 'Telefon 10 haneli olmalı (başında 0 veya +90 olmadan).',
        ]);

        foreach (['first_name', 'last_name', 'telephone'] as $alan) {
            if (array_key_exists($alan, $data)) {
                $customer->{$alan} = $data[$alan];
            }
        }

        // Kurumsal alanlar `bld_` önekli kolonlara eşlenir.
        $kurumsalEsleme = [
            'company_name' => 'bld_org_name',
            'contact_person' => 'bld_contact_person',
            'company_phone' => 'bld_org_phone',
        ];
        foreach ($kurumsalEsleme as $gelen => $kolon) {
            if (array_key_exists($gelen, $data)) {
                $customer->{$kolon} = $data[$gelen];
            }
        }

        $customer->save();

        return $this->me($request);
    }

    /**
     * Parola değiştirme.
     *
     * MEVCUT PAROLA ZORUNLU. Token çalınmış bir oturumun parolayı
     * değiştirip hesabı tamamen ele geçirmesini engelleyen tek şey bu.
     *
     * Değişiklikten sonra DİĞER TÜM TOKEN'LAR İPTAL EDİLİR ve çağırana
     * yenisi verilir: parola değiştirmenin amacı zaten "başkası
     * giremesin"dir; eski oturumları açık bırakmak o amacı boşa çıkarır.
     */
    public function changePassword(Request $request): JsonResponse
    {
        /** @var ApiCustomer $customer */
        $customer = $request->user();

        $data = $request->validate([
            'current_password' => ['required', 'string'],
            'password' => ['required', 'string', 'min:8', 'max:128', 'different:current_password'],
        ], [
            'password.different' => 'Yeni parola eskisiyle aynı olamaz.',
        ]);

        if (!Hash::check($data['current_password'], (string) $customer->password)) {
            throw ApiException::validationFailed('Mevcut parola yanlış.', [
                'current_password' => 'Mevcut parola yanlış.',
            ]);
        }

        $customer->password = $data['password'];
        $customer->save();

        $customer->tokens()->delete();

        return $this->json($this->authPayload($customer));
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
