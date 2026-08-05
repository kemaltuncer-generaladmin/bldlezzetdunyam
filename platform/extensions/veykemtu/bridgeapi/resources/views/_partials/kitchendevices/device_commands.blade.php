{{--
    Komut paneli ve komut geçmişi.

    ÜST YAZI GECİKMEYİ SÖYLER. Komut kasanın bir sonraki sağlık bildirimine
    biniyor; "hemen oldu" izlenimi veren bir arayüz yöneticiyi düğmeye ikinci
    kez bastırır ve iki test fişi çıkar.

    Yeniden basma alanları KENDİ FORMUNDA: AJAX çerçevesi düğmenin en yakın
    formunu gönderiyor (`request.js`), formsuz bir düğme yalnızca kendi
    `data-request-data`sını taşır ve sipariş numarası hiç gitmezdi.
--}}
@php
    $panel = \Veykemtu\BridgeApi\Admin\KitchenDevicePanel::class;
    $commandModel = \Veykemtu\BridgeApi\Models\KitchenCommand::class;
@endphp
<div class="row-fluid mt-3">
    <div class="card shadow-sm mx-3">
        <div class="card-header">
            <strong>@lang('veykemtu.bridgeapi::default.kds.panel_commands')</strong>
        </div>
        <div class="card-body">
            <p class="text-muted small">
                {{ __('veykemtu.bridgeapi::default.kds.panel_commands_comment', [
                    'seconds' => $arrivalSeconds,
                ]) }}
            </p>

            @if($device->isRevoked())
                <p class="mb-0 text-danger">
                    @lang('veykemtu.bridgeapi::default.kds.alert_revoked_device')
                </p>
            @else
                <div class="d-flex flex-wrap gap-2 mb-4">
                    <button
                        type="button"
                        class="btn btn-light"
                        data-request="onSendCommand"
                        data-request-data="command:'{{ $commandModel::TEST_RECEIPT }}'"
                    >@lang('veykemtu.bridgeapi::default.kds.command_test_receipt')</button>

                    <button
                        type="button"
                        class="btn btn-light"
                        data-request="onSendCommand"
                        data-request-data="command:'{{ $commandModel::CLEAR_FAILED }}'"
                    >@lang('veykemtu.bridgeapi::default.kds.command_clear_failed')</button>

                    <button
                        type="button"
                        class="btn btn-light"
                        data-request="onSendCommand"
                        data-request-data="command:'{{ $commandModel::SILENCE_ALARM }}'"
                    >@lang('veykemtu.bridgeapi::default.kds.command_silence_alarm')</button>

                    <button
                        type="button"
                        class="btn btn-danger"
                        data-request="onSendCommand"
                        data-request-data="command:'{{ $commandModel::RESTART }}'"
                        data-request-confirm="{{ __('veykemtu.bridgeapi::default.kds.confirm_restart') }}"
                    >@lang('veykemtu.bridgeapi::default.kds.command_restart')</button>
                </div>

                {!! form_open(['id' => 'kds-reprint-form', 'role' => 'form', 'method' => 'POST']) !!}
                <div class="row g-2 align-items-end">
                    <div class="col-12">
                        <label class="form-label mb-0"><strong>
                            @lang('veykemtu.bridgeapi::default.kds.command_reprint')
                        </strong></label>
                        <div class="text-muted small">
                            @lang('veykemtu.bridgeapi::default.kds.help_reprint')
                        </div>
                    </div>
                    <div class="col-sm-4">
                        <label class="form-label" for="kds-order-id">
                            @lang('veykemtu.bridgeapi::default.kds.label_order_id')
                        </label>
                        <input
                            type="number"
                            min="1"
                            step="1"
                            id="kds-order-id"
                            name="order_id"
                            class="form-control"
                        />
                    </div>
                    <div class="col-sm-4">
                        <label class="form-label" for="kds-receipt-type">
                            @lang('veykemtu.bridgeapi::default.kds.label_receipt_type')
                        </label>
                        <select id="kds-receipt-type" name="receipt_type" class="form-control">
                            @foreach($receiptTypes as $type)
                                <option value="{{ $type }}">
                                    @lang('veykemtu.bridgeapi::default.kds.receipt_type_'.$type)
                                </option>
                            @endforeach
                        </select>
                    </div>
                    <div class="col-sm-4">
                        <button
                            type="button"
                            class="btn btn-primary w-100"
                            data-request="onSendCommand"
                            data-request-data="command:'{{ $commandModel::REPRINT }}'"
                        >@lang('veykemtu.bridgeapi::default.kds.command_reprint')</button>
                    </div>
                </div>
                {!! form_close() !!}
            @endif
        </div>
    </div>
</div>

<div class="row-fluid mt-3 mb-3">
    <div class="card shadow-sm mx-3">
        <div class="card-header">
            <strong>@lang('veykemtu.bridgeapi::default.kds.panel_command_log')</strong>
        </div>
        <div class="table-responsive">
            <table class="table mb-0">
                <thead>
                    <tr>
                        <th>@lang('veykemtu.bridgeapi::default.kds.label_command')</th>
                        <th>@lang('veykemtu.bridgeapi::default.kds.column_command_sent')</th>
                        <th>@lang('veykemtu.bridgeapi::default.kds.column_command_state')</th>
                        <th>@lang('veykemtu.bridgeapi::default.kds.column_command_result')</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse($commands as $command)
                        @php $state = $panel::commandState($command); @endphp
                        <tr>
                            <td>
                                {{ $panel::commandLabel($command->command) }}
                                @isset($command->payload['order_id'])
                                    <div class="text-muted small">
                                        #{{ $command->payload['order_id'] }}
                                        @isset($command->payload['type'])
                                            — @lang('veykemtu.bridgeapi::default.kds.receipt_type_'.$command->payload['type'])
                                        @endisset
                                    </div>
                                @endisset
                            </td>
                            {{-- Damga eski kayıtlarda boş olabilir; boş
                                 hücre yerine tire, "bilinmiyor"u söyler. --}}
                            <td class="small">
                                {{ $panel::since($command->created_at)
                                    ?? __('veykemtu.bridgeapi::default.kds.text_command_no_result') }}
                            </td>
                            <td><span class="badge text-bg-{{ $state['css'] }}">{{ $state['label'] }}</span></td>
                            <td class="small">
                                {{ $command->result ?: __('veykemtu.bridgeapi::default.kds.text_command_no_result') }}
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="4" class="text-center text-muted">
                                @lang('veykemtu.bridgeapi::default.kds.text_no_commands')
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
</div>
