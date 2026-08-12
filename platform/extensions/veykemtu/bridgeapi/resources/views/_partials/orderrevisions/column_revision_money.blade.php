{{--
    Para tarafı: toplam değişimi, doğan iade ve ek tahsilat.

    Üçü ayrı sütun olsaydı liste okunmaz hâle gelirdi; üçü de aynı soruya
    ("bu düzenleme kasada ne yaptı") hizmet ettiği için tek hücrede.
--}}
@php
    $tl = static fn (int $kurus): string => number_format(abs($kurus) / 100, 2, ',', '.') . ' ₺';
    $delta = $record->totalDelta();
@endphp
<span class="bld-money {{ $delta > 0 ? 'text-danger' : ($delta < 0 ? 'text-success' : 'text-muted') }}">
    {{ $delta > 0 ? '+' : ($delta < 0 ? '-' : '') }}{{ $tl($delta) }}
</span>
@if ((int) $record->refund_kurus > 0)
    <span class="d-block small text-success">
        @lang('veykemtu.bridgeapi::monitor.refund'): {{ $tl((int) $record->refund_kurus) }}
    </span>
@endif
@if ((int) $record->extra_charge_kurus > 0)
    <span class="d-block small text-danger">
        @lang('veykemtu.bridgeapi::monitor.extra_charge'): {{ $tl((int) $record->extra_charge_kurus) }}
    </span>
@endif
