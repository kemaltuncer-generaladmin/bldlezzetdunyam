<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
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
}
