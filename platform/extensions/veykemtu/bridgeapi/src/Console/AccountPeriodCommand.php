<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Console;

use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Admin\LiraField;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Services\AccountLedger;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Cari hesap ay-sonu özeti — `veykemtu_account_periods`'a dönemi dondurur.
 *
 * FATURA DEĞİLDİR (e-Arşiv Faz 3). Açılış/borç/alacak/kapanış tek satırda;
 * ekstre ve ay-sonu mutabakatı içindir. İdempotent (`UNIQUE(customer, period)`
 * üzerinden `updateOrInsert`): iki kez koşarsa dönem satırı güncellenir.
 * Zamanlanmış çalıştırma FAZ 4'te (`registerSchedule`, ayın 1'i).
 */
class AccountPeriodCommand extends Command
{
    protected $signature = 'veykemtu:cari-donem-ozeti
        {--month= : YYYY-AA (varsayılan: geçen ay)}
        {--customer= : Yalnız bu müşteri ID}
        {--dry-run : Yazmadan yalnızca göster}';

    protected $description = 'Cari hesap ay-sonu özetini üretir (fatura değil; mutabakat verisi).';

    public function handle(AccountLedger $ledger): int
    {
        $monthOpt = $this->option('month');
        $from = $monthOpt !== null
            ? Carbon::createFromFormat('Y-m-d', $monthOpt.'-01')->startOfMonth()
            : BusinessTime::now()->startOfMonth()->subMonth();
        $to = $from->copy()->endOfMonth();
        $period = $from->format('Y-m');
        $dryRun = (bool) $this->option('dry-run');

        $query = ApiCustomer::query()->where('bld_account_type', 'corporate');
        if ($this->option('customer') !== null) {
            $query->where('customer_id', (int) $this->option('customer'));
        }
        $customers = $query->get();

        $this->components->info(sprintf(
            'Dönem %s — %d kurumsal müşteri%s',
            $period,
            $customers->count(),
            $dryRun ? ' (kuru koşum)' : '',
        ));

        $written = 0;
        $skipped = 0;
        foreach ($customers as $customer) {
            $s = $ledger->periodSummary((int) $customer->customer_id, $from, $to);

            // Hiç hareketi ve açılış bakiyesi olmayan müşteriyi yazma.
            if ($s['opening'] === 0 && $s['debit_total'] === 0 && $s['credit_total'] === 0) {
                $skipped++;

                continue;
            }

            $this->components->twoColumnDetail(
                $customer->bld_org_name ?: $customer->email,
                sprintf(
                    'açılış %s | borç %s | alacak %s | kapanış %s',
                    LiraField::toInput($s['opening']),
                    LiraField::toInput($s['debit_total']),
                    LiraField::toInput($s['credit_total']),
                    LiraField::toInput($s['closing']),
                ),
            );

            if (!$dryRun) {
                DB::table('veykemtu_account_periods')->updateOrInsert(
                    ['customer_id' => (int) $customer->customer_id, 'period' => $period],
                    [
                        'opening_kurus' => $s['opening'],
                        'debit_total_kurus' => $s['debit_total'],
                        'credit_total_kurus' => $s['credit_total'],
                        'closing_kurus' => $s['closing'],
                        'generated_at' => BusinessTime::forStorage(BusinessTime::now()),
                    ],
                );
                $written++;
            }
        }

        $this->components->info($dryRun
            ? 'Kuru koşum — hiçbir şey yazılmadı.'
            : sprintf('%d dönem yazıldı, %d boş müşteri atlandı.', $written, $skipped));

        return self::SUCCESS;
    }
}
