{{--
    Liste sütunu: son sağlık bildirimi ve uygulama sürümü.

    Sürüm kasanın BEYANIDIR ve doğrulanmaz; bu yüzden kaçışlı basılıyor.
--}}
@php
    $reported = \Veykemtu\BridgeApi\Admin\KitchenDevicePanel::since($record->health_reported_at);
@endphp
<div class="small">{{ $reported ?? __('veykemtu.bridgeapi::default.kds.text_never') }}</div>
<div class="text-muted small">
    @lang('veykemtu.bridgeapi::default.kds.text_app_version'):
    {{ $record->app_version ?: __('veykemtu.bridgeapi::default.kds.text_unknown') }}
</div>
