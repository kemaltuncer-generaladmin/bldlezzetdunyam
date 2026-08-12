<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\AccountPaymentIntent;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Services\AccountLedger;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Müşteri cari hesap uçları — `docs/openapi.yaml` §Cari hesap.
 *
 * Yalnızca istek sahibinin kendi verisi döner. Fatura kesmez (e-Arşiv Faz 3);
 * bakiye ve ekstre gösterir. Para her yerde kuruş `int`.
 */
class AccountController extends ApiController
{
    public function __construct(
        private readonly AccountLedger $ledger,
    ) {}

    public function summary(Request $request): JsonResponse
    {
        /** @var ApiCustomer $customer */
        $customer = $request->user();

        return $this->json([
            'balance' => $this->ledger->balance((int) $customer->customer_id),
            'currency' => 'TRY',
            'as_of' => self::ts(BusinessTime::now()),
        ]);
    }

    public function statement(Request $request): JsonResponse
    {
        $data = $request->validate([
            'from' => ['sometimes', 'nullable', 'date'],
            'to' => ['sometimes', 'nullable', 'date'],
        ]);

        /** @var ApiCustomer $customer */
        $customer = $request->user();

        // Varsayılan aralık: son 3 ay. İstemci `from`/`to` verirse o kullanılır.
        $to = isset($data['to']) && $data['to'] !== null
            ? Carbon::parse($data['to'])
            : BusinessTime::now();
        $from = isset($data['from']) && $data['from'] !== null
            ? Carbon::parse($data['from'])
            : $to->copy()->subMonths(3);

        $statement = $this->ledger->statement(
            (int) $customer->customer_id,
            $from,
            $to,
        );

        return $this->json([
            'opening_balance' => $statement['opening_balance'],
            'closing_balance' => $statement['closing_balance'],
            'currency' => 'TRY',
            'from' => $from->toDateString(),
            'to' => $to->toDateString(),
            'entries' => $statement['entries'],
        ]);
    }

    /**
     * Cari borç ödemesi başlatır — `POST /api/account/payments` (B-14 / W-12).
     *
     * İKİ MOD, TEK UÇ:
     *   `{"amount": 250000}` → istenen tutar
     *   `{"full": true}`     → o anki borcun tamamı
     * "İstenen ya da toplam tutara göre ödeme" isteği birebir bu.
     *
     * TUTAR SUNUCUDA DOĞRULANIR. `full` modunda istemcinin gönderdiği bir
     * rakam hiç okunmaz; bakiye burada yeniden hesaplanır. Aksi hâlde
     * istemcinin ekranındaki eski bakiye ile gerçek borç ayrıştığında
     * (arada bir sipariş geçmişse) müşteri eksik ödeyip "kapattım" sanırdı.
     *
     * BORCU AŞAN ÖDEME REDDEDİLİR: fazla ödeme defterde negatif bakiye
     * (alacaklı müşteri) yaratır ve iadesi elle iş demektir. Müşteri
     * arayüzünden yanlışlıkla yapılmasına izin vermiyoruz; gerçekten
     * avans alınacaksa yönetici panelden işler.
     *
     * Ödeme burada TAMAMLANMAZ: niyet `pending` yazılır ve sağlayıcının
     * (bugün simülasyon) sayfasına yönlendirme adresi döner. Defter ancak
     * dönüşte, ödeme kesinleşince yazılır.
     */
    public function startPayment(Request $request): JsonResponse
    {
        $data = $request->validate([
            'amount' => ['sometimes', 'nullable', 'integer', 'min:1'],
            'full' => ['sometimes', 'boolean'],
        ]);

        /** @var ApiCustomer $customer */
        $customer = $request->user();

        $balance = $this->ledger->balance((int) $customer->customer_id);

        if ($balance <= 0) {
            throw ApiException::validationFailed('Ödenecek borç bulunmuyor.', [
                'balance' => $balance,
            ]);
        }

        $full = (bool) ($data['full'] ?? false);
        $amount = $full ? $balance : (int) ($data['amount'] ?? 0);

        if ($amount <= 0) {
            throw ApiException::validationFailed(
                'Ödenecek tutar belirtilmeli.',
                ['amount' => 'Tutar girin veya borcun tamamını seçin.'],
            );
        }

        if ($amount > $balance) {
            throw ApiException::validationFailed('Tutar borcunuzdan büyük olamaz.', [
                'amount' => $amount,
                'balance' => $balance,
            ]);
        }

        $intent = new AccountPaymentIntent;
        $intent->customer_id = (int) $customer->customer_id;
        $intent->amount_kurus = $amount;
        $intent->balance_at_start = $balance;
        $intent->status = AccountPaymentIntent::STATUS_PENDING;
        // 32 bayt rastgele: adres tahmin edilerek başkasının ödeme sayfası
        // açılamamalı. Sıralı `id` bu yüzden dışarı verilmiyor.
        $intent->hash = bin2hex(random_bytes(16));
        $intent->created_at = BusinessTime::forStorage(BusinessTime::now());
        $intent->save();

        return $this->json([
            'payment_id' => (int) $intent->id,
            'amount' => $amount,
            'balance' => $balance,
            'currency' => 'TRY',
            'status' => $intent->status,
            'redirect_url' => url('/cari-odeme-simulasyon/'.$intent->hash),
        ], 201);
    }
}
