<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Console;

use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Veykemtu\BridgeApi\Admin\LiraField;
use Veykemtu\BridgeApi\Models\AccountLedgerEntry;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Services\AccountLedger;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Cari deftere elle borç/alacak (tahsilat) girişi.
 *
 * `account` ödeme geçidi tahsilat yapmaz (sipariş `pending` kalır); para elden
 * alındığında yönetici bu komutla bir **alacak** hareketi girer. Sunucuya
 * erişimi olan yönetici zaten artisan komutlarını kullanıyor (RUNBOOK).
 */
class AccountEntryCommand extends Command
{
    protected $signature = 'veykemtu:cari-hareket
        {customer : Müşteri ID veya e-posta}
        {type : debit (borç) | credit (alacak/tahsilat)}
        {amount : TL tutar — 1500, 1.500,50, 1500.50}
        {--desc= : Açıklama}
        {--date= : İşletme günü YYYY-AA-GG (varsayılan bugün)}';

    protected $description = 'Cari hesap defterine elle borç/alacak hareketi girer.';

    public function handle(AccountLedger $ledger): int
    {
        $type = (string) $this->argument('type');
        if (!in_array($type, [AccountLedgerEntry::TYPE_DEBIT, AccountLedgerEntry::TYPE_CREDIT], true)) {
            $this->components->error("type yalnızca 'debit' veya 'credit' olabilir.");

            return self::FAILURE;
        }

        $customer = $this->resolveCustomer((string) $this->argument('customer'));
        if ($customer === null) {
            $this->components->error('Müşteri bulunamadı.');

            return self::FAILURE;
        }

        $kurus = LiraField::toKurus($this->argument('amount'));
        if ($kurus <= 0) {
            $this->components->error('Tutar 0 TL üzerinde olmalı.');

            return self::FAILURE;
        }

        $date = $this->option('date') !== null
            ? Carbon::parse((string) $this->option('date'))
            : BusinessTime::now();

        $ledger->record(
            customerId: (int) $customer->customer_id,
            type: $type,
            amountKurus: $kurus,
            source: AccountLedgerEntry::SOURCE_MANUAL,
            referenceType: null,
            referenceId: null,
            description: (string) ($this->option('desc') ?: 'Elle giriş'),
            effectiveDate: $date,
        );

        $this->components->twoColumnDetail(
            $customer->email,
            LiraField::toInput($kurus).' TL '
                .($type === AccountLedgerEntry::TYPE_DEBIT ? 'borç' : 'alacak'),
        );
        $this->components->info(
            'Güncel bakiye: '
            .LiraField::toInput($ledger->balance((int) $customer->customer_id)).' TL',
        );

        return self::SUCCESS;
    }

    private function resolveCustomer(string $ref): ?ApiCustomer
    {
        if (ctype_digit($ref)) {
            return ApiCustomer::query()->where('customer_id', (int) $ref)->first();
        }

        return ApiCustomer::query()->where('email', $ref)->first();
    }
}
