{{--
    Müşteri ekstresi (B-14).

    `AccountLedger::statement()` yeniden kullanılıyor — müşteri uygulamasının
    `GET /api/account/statement` ucu da aynı metodu çağırıyor. İki ayrı sorgu
    yazılsaydı, panelde görünen bakiye ile müşterinin telefonunda gördüğü
    bakiye zamanla ayrışırdı; tartışmanın kazananı belirsiz olurdu.

    SON 90 GÜN: ekstre sayfalama istemeyecek kadar kısa, geçmişi görmek için
    yeterince uzun. Daha eskisi ay-sonu özetlerinde
    (`veykemtu_account_periods`) duruyor.
--}}
@php
    $customerId = (int) $formModel->customer_id;
    $to = \Veykemtu\BridgeApi\Support\BusinessTime::now();
    $from = $to->copy()->subDays(90);

    $statement = app(\Veykemtu\BridgeApi\Services\AccountLedger::class)
        ->statement($customerId, $from, $to);

    $tl = static fn (int $kurus): string => number_format(abs($kurus) / 100, 2, ',', '.') . ' ₺';
    $signed = static fn (int $kurus): string
        => ($kurus < 0 ? '-' : '') . number_format(abs($kurus) / 100, 2, ',', '.') . ' ₺';
@endphp

<div class="d-flex justify-content-between align-items-baseline mb-2 small text-muted">
    <span>{{ $from->format('d.m.Y') }} – {{ $to->format('d.m.Y') }}</span>
    <span>
        @lang('veykemtu.bridgeapi::accountledger.statement_opening'):
        <strong class="bld-money">{{ $signed($statement['opening_balance']) }}</strong>
    </span>
</div>

<div class="table-responsive">
    <table class="table table-sm align-middle mb-0">
        <thead>
            <tr>
                <th scope="col">@lang('veykemtu.bridgeapi::accountledger.column_date')</th>
                <th scope="col">@lang('veykemtu.bridgeapi::accountledger.column_description')</th>
                <th scope="col" class="text-end">@lang('veykemtu.bridgeapi::accountledger.column_debit')</th>
                <th scope="col" class="text-end">@lang('veykemtu.bridgeapi::accountledger.column_credit')</th>
                <th scope="col" class="text-end">@lang('veykemtu.bridgeapi::accountledger.column_running')</th>
            </tr>
        </thead>
        <tbody>
            @forelse ($statement['entries'] as $entry)
                @php
                    $isDebit = ($entry['entry_type'] ?? '') === \Veykemtu\BridgeApi\Models\AccountLedgerEntry::TYPE_DEBIT;
                @endphp
                <tr>
                    <td class="text-nowrap">
                        {{ \Illuminate\Support\Carbon::parse($entry['date'])->format('d.m.Y') }}
                    </td>
                    <td>{{ $entry['description'] ?: '—' }}</td>
                    <td class="text-end">{{ $isDebit ? $tl((int) $entry['amount']) : '' }}</td>
                    <td class="text-end">{{ $isDebit ? '' : $tl((int) $entry['amount']) }}</td>
                    <td class="text-end bld-money">{{ $signed((int) $entry['running_balance']) }}</td>
                </tr>
            @empty
                <tr>
                    <td colspan="5" class="text-center text-muted py-4">
                        @lang('veykemtu.bridgeapi::accountledger.statement_empty')
                    </td>
                </tr>
            @endforelse
        </tbody>
        <tfoot>
            <tr>
                <th colspan="4" class="text-end">
                    @lang('veykemtu.bridgeapi::accountledger.statement_closing')
                </th>
                <th class="text-end bld-money">{{ $signed($statement['closing_balance']) }}</th>
            </tr>
        </tfoot>
    </table>
</div>
