{{-- Gösterge paneli: kurumsal (abonelik + cari) özet. --}}
<div class="card mb-3">
    <div class="card-body">
        <h5 class="card-title mb-3">{{ lang('veykemtu.bridgeapi::subscription.dashboard_label') }}</h5>
        <div class="row text-center g-3">
            <div class="col-4">
                <div class="fs-3 fw-bold text-primary">{{ (int) $bld['active_subscriptions'] }}</div>
                <div class="text-muted small">
                    <a href="{{ $subscriptionsUrl }}">{{ lang('veykemtu.bridgeapi::subscription.dashboard_active') }}</a>
                </div>
            </div>
            <div class="col-4">
                <div class="fs-3 fw-bold">
                    @if($bld['tomorrow_closed'])
                        <span class="text-warning">{{ lang('veykemtu.bridgeapi::subscription.dashboard_closed') }}</span>
                    @else
                        {{ (int) $bld['tomorrow_portions'] }}
                    @endif
                </div>
                <div class="text-muted small">{{ lang('veykemtu.bridgeapi::subscription.dashboard_portions') }}</div>
            </div>
            <div class="col-4">
                <div class="fs-3 fw-bold {{ $openBalance > 0 ? 'text-danger' : 'text-success' }}">
                    {{ number_format($openBalance, 2, ',', '.') }} ₺
                </div>
                <div class="text-muted small">
                    <a href="{{ $accountsUrl }}">{{ lang('veykemtu.bridgeapi::subscription.dashboard_balance') }}</a>
                </div>
            </div>
        </div>
    </div>
</div>
