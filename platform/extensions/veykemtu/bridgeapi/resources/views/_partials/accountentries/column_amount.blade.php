{{--
    Liste sütunu: tutar (işaretli). Borç +, alacak −; renk tiple aynı.
    Tutar defterde POZİTİF kuruş; işaret ve renk `entry_type`'tan gelir.
--}}
@php
    $isDebit = $record->entry_type === \Veykemtu\BridgeApi\Models\AccountLedgerEntry::TYPE_DEBIT;
    $tl = number_format($record->amount_kurus / 100, 2, ',', '.');
@endphp
<span class="{{ $isDebit ? 'text-danger' : 'text-success' }} fw-bold">{{ $isDebit ? '+' : '-' }}{{ $tl }} ₺</span>
