<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Models\AccountLedgerEntry;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Cari hesap defteri motoru — tek sorumluluk (`LocationGate` kalıbı).
 *
 * Yürüyen bakiye stratejisi: **runtime toplam** (snapshot değil). Append-only
 * defter + indeks üzerinden `SUM` her zaman doğru; snapshot'ın drift riski
 * yoktur (`docs/02 §5`). Çok satırda performans gerekirse ay-sonu kapanış
 * bakiyesinden ileri-toplama optimizasyonu sonra eklenebilir.
 *
 * SINIR: fatura kesmez (e-Arşiv Faz 3). Yalnızca borç/alacak/bakiye/ekstre.
 */
final class AccountLedger
{
    /**
     * Deftere bir hareket yazar (idempotent).
     *
     * Aynı `(source, reference_type, reference_id, entry_type)` bir kez yazılır
     * — sipariş borcu iki kez düşmez. Manuel girişte `reference_id` null olur
     * ve tekilleştirmeye takılmaz (bilinçli).
     */
    public function record(
        int $customerId,
        string $type,
        int $amountKurus,
        string $source,
        ?string $referenceType = null,
        ?int $referenceId = null,
        ?string $description = null,
        ?Carbon $effectiveDate = null,
        ?int $createdBy = null,
    ): void {
        $when = $effectiveDate ?? BusinessTime::now();

        DB::table('veykemtu_account_ledger')->insertOrIgnore([
            'customer_id' => $customerId,
            'entry_type' => $type,
            'amount_kurus' => $amountKurus,
            'source' => $source,
            'reference_type' => $referenceType,
            'reference_id' => $referenceId,
            'description' => $description,
            'effective_date' => $when->toDateString(),
            'created_by' => $createdBy,
            'created_at' => BusinessTime::forStorage(BusinessTime::now()),
        ]);
    }

    /**
     * Belirli bir kaynak/referans/tip için hareket var mı?
     *
     * İptal ters kaydında kullanılır: yalnızca gerçekten borç düşmüş siparişe
     * alacak yazılır (bu özellikten önce oluşmuş account siparişlerinde borç
     * yoktur; onlara alacak yazmak bakiyeyi yanlış eksiltirdi).
     */
    public function hasEntry(
        string $source,
        ?string $referenceType,
        ?int $referenceId,
        string $type,
    ): bool {
        return DB::table('veykemtu_account_ledger')
            ->where('source', $source)
            ->where('reference_type', $referenceType)
            ->where('reference_id', $referenceId)
            ->where('entry_type', $type)
            ->exists();
    }

    /**
     * Güncel bakiye (kuruş). Pozitif = müşterinin bize borcu var.
     */
    public function balance(int $customerId): int
    {
        return (int) DB::table('veykemtu_account_ledger')
            ->where('customer_id', $customerId)
            ->selectRaw($this->balanceExpression().' AS bakiye')
            ->value('bakiye');
    }

    /**
     * Tarih aralığı ekstresi: açılış bakiyesi + hareketler (yürüyen bakiyeli)
     * + kapanış bakiyesi.
     *
     * @return array{opening_balance: int, closing_balance: int, entries: list<array<string, mixed>>}
     */
    public function statement(int $customerId, Carbon $from, Carbon $to): array
    {
        $opening = (int) DB::table('veykemtu_account_ledger')
            ->where('customer_id', $customerId)
            ->whereDate('effective_date', '<', $from->toDateString())
            ->selectRaw($this->balanceExpression().' AS bakiye')
            ->value('bakiye');

        $rows = AccountLedgerEntry::query()
            ->forCustomer($customerId)
            ->whereBetween('effective_date', [$from->toDateString(), $to->toDateString()])
            ->orderBy('effective_date')
            ->orderBy('id')
            ->get();

        $running = $opening;
        $entries = [];
        foreach ($rows as $row) {
            $delta = $row->entry_type === AccountLedgerEntry::TYPE_DEBIT
                ? $row->amount_kurus
                : -$row->amount_kurus;
            $running += $delta;

            $entries[] = [
                'date' => $row->effective_date->toDateString(),
                'entry_type' => $row->entry_type,
                'amount' => (int) $row->amount_kurus,
                'running_balance' => $running,
                'source' => $row->source,
                'description' => $row->description,
            ];
        }

        return [
            'opening_balance' => $opening,
            'closing_balance' => $running,
            'entries' => $entries,
        ];
    }

    /**
     * Ay-sonu dönem özeti: açılış + dönem borç/alacak + kapanış.
     *
     * @return array{opening: int, debit_total: int, credit_total: int, closing: int}
     */
    public function periodSummary(int $customerId, Carbon $from, Carbon $to): array
    {
        $opening = (int) DB::table('veykemtu_account_ledger')
            ->where('customer_id', $customerId)
            ->whereDate('effective_date', '<', $from->toDateString())
            ->selectRaw($this->balanceExpression().' AS bakiye')
            ->value('bakiye');

        $base = DB::table('veykemtu_account_ledger')
            ->where('customer_id', $customerId)
            ->whereBetween('effective_date', [$from->toDateString(), $to->toDateString()]);

        $debit = (int) (clone $base)
            ->where('entry_type', AccountLedgerEntry::TYPE_DEBIT)
            ->sum('amount_kurus');
        $credit = (int) (clone $base)
            ->where('entry_type', AccountLedgerEntry::TYPE_CREDIT)
            ->sum('amount_kurus');

        return [
            'opening' => $opening,
            'debit_total' => $debit,
            'credit_total' => $credit,
            'closing' => $opening + $debit - $credit,
        ];
    }

    /**
     * Borç pozitif, alacak negatif toplanır — güncel borç bakiyesi.
     */
    private function balanceExpression(): string
    {
        return "COALESCE(SUM(CASE WHEN entry_type = '"
            .AccountLedgerEntry::TYPE_DEBIT
            ."' THEN amount_kurus ELSE -amount_kurus END), 0)";
    }
}
