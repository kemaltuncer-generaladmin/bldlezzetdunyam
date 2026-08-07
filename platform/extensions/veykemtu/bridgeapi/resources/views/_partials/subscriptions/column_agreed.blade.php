{{-- Liste sütunu: anlaşmalı porsiyon fiyatı (talepte henüz yoksa "—"). --}}
@php($kurus = $record->agreed_unit_price_kurus)
@if($kurus === null)
    <span class="text-muted">{{ lang('veykemtu.bridgeapi::subscription.no_price') }}</span>
@else
    <span class="fw-bold">{{ number_format($kurus / 100, 2, ',', '.') }} ₺</span>
@endif
