{{--
    Liste sütunu: fiş kuyruğu.

    Sayılar `null` iken sıfır YAZILMAZ. Kasa hiç bildirim göndermediyse
    "0 bekleyen" yazmak, kuyruğun boş olduğu güvencesini verirdi; oysa
    bilinen tek şey kuyruk hakkında hiçbir şey bilinmediğidir.
--}}
@php
    $pending = $record->print_queue_pending;
    $failed = $record->print_queue_failed;
@endphp
@if($pending === null && $failed === null)
    <span class="text-muted">@lang('veykemtu.bridgeapi::default.kds.text_unknown')</span>
@else
    <div class="small">
        @lang('veykemtu.bridgeapi::default.kds.text_queue_pending'):
        <strong>{{ $pending ?? 0 }}</strong>
    </div>
    <div @class(['small', 'text-danger fw-bold' => (int) $failed > 0])>
        @lang('veykemtu.bridgeapi::default.kds.text_queue_failed'):
        <strong>{{ $failed ?? 0 }}</strong>
    </div>
@endif
