{{--
    Mutfak kasası düzenleme sayfası.

    Çekirdeğin `igniter.admin::edit` görünümünün yerine geçer. Fark: formun
    ALTINA üç panel ekler.

    NEDEN PANELLER FORMUN İÇİNDE DEĞİL: HTML'de form iç içe geçemez ve komut
    panelinin kendi alanları (sipariş no, fiş tipi) var. Ayrıca panellerin
    hiçbiri "kaydedilmez" — biri salt okunur bir rapor, ikisi tek seferlik
    eylemdir. Kaydet düğmesinin altında durmaları yöneticiye yanlış söz verirdi.
--}}
<div class="d-flex p-3">
    @if($previousUrl = AdminMenu::getPreviousUrl())
        <a
            class="btn shadow-none border-none ps-0"
            href="{{ $previousUrl }}"
        ><i class="fa fa-angle-left fs-4 align-bottom"></i></a>
    @endif
    <h4 class="page-title mb-0 lh-base">
        <span>{!! Template::getHeading() !!}</span>
    </h4>
</div>

@if($device->isRevoked())
    <div class="mx-3 mb-3 alert alert-danger">
        {{ __('veykemtu.bridgeapi::default.kds.text_revoked_banner', [
            'when' => \Veykemtu\BridgeApi\Admin\KitchenDevicePanel::since($device->revoked_at),
        ]) }}
    </div>
@endif

<div class="row-fluid">
    <div class="card shadow-sm mx-3">
        {!! form_open([
            'id'     => 'edit-form',
            'role'   => 'form',
            'method' => 'PATCH',
        ]) !!}

        <div class="border-bottom">
            {!! $this->renderFormToolbar() !!}
        </div>

        {!! $this->renderForm([], true) !!}

        {!! form_close() !!}
    </div>
</div>

{!! $this->makePartial('device_health') !!}
{!! $this->makePartial('device_pairing') !!}
{!! $this->makePartial('device_commands') !!}
