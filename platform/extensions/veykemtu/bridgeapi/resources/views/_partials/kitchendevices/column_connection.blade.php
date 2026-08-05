{{--
    Liste sütunu: bağlantı durumu.

    Rozetin altındaki "x dakika önce" bilinçli olarak duruyor: "Çevrimdışı"
    tek başına kesintinin iki dakika mı iki gün mü sürdüğünü söylemez ve
    yönetici bunu öğrenmek için kaydı açmak zorunda kalırdı.
--}}
@php
    $state = \Veykemtu\BridgeApi\Admin\KitchenDevicePanel::connection($record);
    $since = \Veykemtu\BridgeApi\Admin\KitchenDevicePanel::since($record->last_seen_at);
@endphp
<span class="badge text-bg-{{ $state['css'] }}">{{ $state['label'] }}</span>
@if($since)
    <div class="text-muted small">{{ $since }}</div>
@endif
