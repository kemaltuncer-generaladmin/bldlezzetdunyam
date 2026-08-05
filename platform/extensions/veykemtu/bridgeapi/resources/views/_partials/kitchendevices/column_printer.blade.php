{{--
    Liste sütunu: yazıcı durumu — ÜÇ HÂL.

    "Bilinmiyor" gri, "ARIZALI" kırmızıdır. İkisi aynı renkte gösterilseydi
    henüz hiç sağlık bildirimi göndermemiş yeni bir kasa, yöneticiyi var
    olmayan bir yazıcı arızası aramaya gönderirdi.
--}}
@php
    $state = \Veykemtu\BridgeApi\Admin\KitchenDevicePanel::printer($record);
    $unknown = $state['state'] === \Veykemtu\BridgeApi\Admin\KitchenDevicePanel::PRINTER_UNKNOWN;
@endphp
<span class="badge text-bg-{{ $state['css'] }}">{{ $state['label'] }}</span>
@if($unknown)
    <div class="text-muted small">
        @lang('veykemtu.bridgeapi::default.kds.printer_unknown_hint')
    </div>
@endif
