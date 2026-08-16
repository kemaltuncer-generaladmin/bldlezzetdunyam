{{-- Gösterge paneli: abonelik özeti. --}}
{{-- Üçüncü sütun (toplam açık cari bakiye) cari hesapla birlikte kalktı;
     kalan iki rakam yarıya bölünmüş satırda duruyor. --}}
<div class="card mb-3">
    <div class="card-body">
        <h5 class="card-title mb-3">{{ lang('veykemtu.bridgeapi::subscription.dashboard_label') }}</h5>
        <div class="row text-center g-3">
            <div class="col-6">
                <div class="fs-3 fw-bold text-primary">{{ (int) $bld['active_subscriptions'] }}</div>
                <div class="text-muted small">
                    <a href="{{ $subscriptionsUrl }}">{{ lang('veykemtu.bridgeapi::subscription.dashboard_active') }}</a>
                </div>
            </div>
            <div class="col-6">
                <div class="fs-3 fw-bold">
                    @if($bld['tomorrow_closed'])
                        <span class="text-warning">{{ lang('veykemtu.bridgeapi::subscription.dashboard_closed') }}</span>
                    @else
                        {{ (int) $bld['tomorrow_portions'] }}
                    @endif
                </div>
                <div class="text-muted small">{{ lang('veykemtu.bridgeapi::subscription.dashboard_portions') }}</div>
            </div>
        </div>
    </div>
</div>
