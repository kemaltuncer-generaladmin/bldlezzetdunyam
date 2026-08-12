{{--
    "Elle iade edildi" işareti.

    Yalnızca iş bekleyen satırlarda çıkıyor; kapanmış iadede düğme
    göstermek, ikinci kez para gönderilmesine açık bir davet olurdu.
    Onay metni tutarı içeriyor: yönetici neyi onayladığını görmeden
    tıklamamalı.
--}}
@if ($record->needsAction())
    <button
        type="button"
        class="btn btn-sm btn-outline-success"
        data-request="onMarkSettled"
        data-request-data="recordId: {{ $record->id }}"
        data-request-confirm="{{ sprintf(
            lang('veykemtu.bridgeapi::refund.confirm_settle'),
            number_format((int) $record->amount_kurus / 100, 2, ',', '.'),
            $record->order_id,
        ) }}"
        data-progress-indicator="{{ lang('admin::lang.text_saving') }}"
    >@lang('veykemtu.bridgeapi::refund.button_settle')</button>
@elseif ($record->settled_at)
    <span class="text-muted small">
        {{ $record->settled_at->format('d.m.Y H:i') }}
        @if ($record->provider_ref)
            <span class="d-block">{{ $record->provider_ref }}</span>
        @endif
    </span>
@else
    <span class="text-muted">—</span>
@endif
