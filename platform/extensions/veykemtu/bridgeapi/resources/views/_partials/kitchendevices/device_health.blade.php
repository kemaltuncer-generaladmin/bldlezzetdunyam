{{--
    Kasanın bildirdiği durum — salt okunur.

    "Ayarların durumu" satırı bu panelin en çok işe yarayan parçası:
    `settings_updated_at` ile `health_reported_at` karşılaştırması,
    yöneticinin kaydettikten sonra sorduğu tek soruyu ("gitti mi?")
    cevaplar. Onsuz kaydet düğmesi sessiz bir kuyuya benzerdi.
--}}
<div class="row-fluid mt-3">
    <div class="card shadow-sm mx-3">
        <div class="card-header">
            <strong>@lang('veykemtu.bridgeapi::default.kds.panel_health')</strong>
        </div>
        <div class="card-body">
            <p class="text-muted small">
                @lang('veykemtu.bridgeapi::default.kds.panel_health_comment')
            </p>

            <div class="row row-cols-1 row-cols-md-3 g-3">
                <div class="col">
                    <div class="text-muted small">@lang('veykemtu.bridgeapi::default.kds.column_connection')</div>
                    <span class="badge text-bg-{{ $connection['css'] }}">{{ $connection['label'] }}</span>
                    <div class="small mt-1">
                        @lang('veykemtu.bridgeapi::default.kds.text_last_seen'):
                        {{ $lastSeen ?? __('veykemtu.bridgeapi::default.kds.text_never') }}
                    </div>
                </div>

                <div class="col">
                    <div class="text-muted small">@lang('veykemtu.bridgeapi::default.kds.column_printer')</div>
                    <span class="badge text-bg-{{ $printer['css'] }}">{{ $printer['label'] }}</span>
                    @if($printer['state'] === \Veykemtu\BridgeApi\Admin\KitchenDevicePanel::PRINTER_UNKNOWN)
                        <div class="text-muted small mt-1">
                            @lang('veykemtu.bridgeapi::default.kds.printer_unknown_hint')
                        </div>
                    @endif
                </div>

                <div class="col">
                    <div class="text-muted small">@lang('veykemtu.bridgeapi::default.kds.text_settings_sync')</div>
                    <span class="badge text-bg-{{ $settingsSync['css'] }}">{{ $settingsSync['label'] }}</span>
                    <div class="small mt-1">
                        @lang('veykemtu.bridgeapi::default.kds.text_settings_changed_at'):
                        {{ \Veykemtu\BridgeApi\Admin\KitchenDevicePanel::since($device->settings_updated_at)
                            ?? __('veykemtu.bridgeapi::default.kds.text_never') }}
                    </div>
                </div>

                <div class="col">
                    <div class="text-muted small">@lang('veykemtu.bridgeapi::default.kds.text_queue_pending')</div>
                    <div class="fs-5 fw-bold">
                        {{ $device->print_queue_pending ?? __('veykemtu.bridgeapi::default.kds.text_unknown') }}
                    </div>
                </div>

                <div class="col">
                    <div class="text-muted small">@lang('veykemtu.bridgeapi::default.kds.text_queue_failed')</div>
                    <div @class(['fs-5 fw-bold', 'text-danger' => (int) $device->print_queue_failed > 0])>
                        {{ $device->print_queue_failed ?? __('veykemtu.bridgeapi::default.kds.text_unknown') }}
                    </div>
                </div>

                <div class="col">
                    <div class="text-muted small">@lang('veykemtu.bridgeapi::default.kds.text_app_version')</div>
                    <div class="fs-5 fw-bold">
                        {{ $device->app_version ?: __('veykemtu.bridgeapi::default.kds.text_unknown') }}
                    </div>
                    <div class="small mt-1">
                        @lang('veykemtu.bridgeapi::default.kds.text_last_health'):
                        {{ $lastHealth ?? __('veykemtu.bridgeapi::default.kds.text_never') }}
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
