{{--
    Liste sütunu: hareket tipi rozeti. Borç kırmızı, alacak yeşil.
--}}
@php
    $isDebit = $record->entry_type === \Veykemtu\BridgeApi\Models\AccountLedgerEntry::TYPE_DEBIT;
@endphp
<span class="badge text-bg-{{ $isDebit ? 'danger' : 'success' }}">
    {{ lang('veykemtu.bridgeapi::accountledger.type_'.$record->entry_type) }}
</span>
