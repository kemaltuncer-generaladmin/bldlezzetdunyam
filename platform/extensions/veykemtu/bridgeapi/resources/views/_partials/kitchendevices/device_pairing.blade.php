{{--
    Eşleme paneli.

    Kod BÜYÜK ve tek satırda: mutfakta, çoğu zaman kötü ışıkta ve telefondan
    okunarak giriliyor (`KitchenDevice::generatePairingCode` gerekçesi).

    İptal düğmesi kırmızı ve onaylı; geri alınamaz bir işlem.
--}}
<div class="row-fluid mt-3">
    <div class="card shadow-sm mx-3">
        <div class="card-header">
            <strong>@lang('veykemtu.bridgeapi::default.kds.panel_pairing')</strong>
        </div>
        <div class="card-body">
            <p class="text-muted small">
                @lang('veykemtu.bridgeapi::default.kds.panel_pairing_comment')
            </p>

            @if($pairingMinutesLeft !== null)
                <div class="mb-3">
                    <div class="text-muted small">@lang('veykemtu.bridgeapi::default.kds.text_pairing_code')</div>
                    <div class="fs-2 fw-bold font-monospace">{{ $device->pairing_code }}</div>
                    <div class="small text-warning">
                        {{ __('veykemtu.bridgeapi::default.kds.text_pairing_minutes_left', [
                            'minutes' => $pairingMinutesLeft,
                        ]) }}
                    </div>
                </div>
            @else
                <p class="mb-3">
                    @lang('veykemtu.bridgeapi::default.kds.text_pairing_none')
                    @if($device->last_seen_at !== null)
                        @lang('veykemtu.bridgeapi::default.kds.text_pairing_paired')
                    @endif
                </p>
            @endif

            @unless($device->isRevoked())
                <div class="d-flex flex-wrap gap-2">
                    <button
                        type="button"
                        class="btn btn-primary"
                        data-request="onRefreshPairingCode"
                    >@lang('veykemtu.bridgeapi::default.kds.button_pairing_code')</button>

                    <button
                        type="button"
                        class="btn btn-danger"
                        data-request="onRevokeDevice"
                        data-request-confirm="{{ __('veykemtu.bridgeapi::default.kds.confirm_revoke') }}"
                    >@lang('veykemtu.bridgeapi::default.kds.button_revoke')</button>
                </div>
            @endunless
        </div>
    </div>
</div>
