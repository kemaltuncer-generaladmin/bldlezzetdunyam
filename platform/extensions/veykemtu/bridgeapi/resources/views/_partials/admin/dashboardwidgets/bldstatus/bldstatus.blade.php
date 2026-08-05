{{--
    BLD işletme durumu parçacığı.

    TASARIM: en üstte iki şalter, çünkü sayfayı açan yöneticinin ilk sorusu
    "sipariş alıyor muyum" ve "mutfak yetişiyor mu"dur. Yoğunluk rozeti
    bilinçli olarak SARI, kapalı sipariş alımı KIRMIZIDIR — ikisi aynı renkte
    olsaydı yönetici yanlış şalteri arardı. Rozetlerin altındaki küçük not
    farkı yazıyla da söyler.
--}}
<div class="dashboard-widget widget-bldstatus">
    <h6 class="widget-title">
        @lang('veykemtu.bridgeapi::default.dashboard.text_title')
        <a class="float-end small" href="{{ $settingsUrl }}">
            @lang('veykemtu.bridgeapi::default.dashboard.text_open_settings')
        </a>
    </h6>

    @unless($bld['has_location'])
        <p class="text-danger mb-0">
            @lang('veykemtu.bridgeapi::default.dashboard.text_no_location')
        </p>
    @else
        <div class="d-flex flex-wrap gap-2 mb-3">
            <span @class([
                'badge',
                'text-bg-success' => $bld['ordering_enabled'],
                'text-bg-danger' => !$bld['ordering_enabled'],
            ])>
                <i class="fa {{ $bld['ordering_enabled'] ? 'fa-circle-check' : 'fa-circle-xmark' }}"></i>
                @lang($bld['ordering_enabled']
                    ? 'veykemtu.bridgeapi::default.dashboard.text_ordering_on'
                    : 'veykemtu.bridgeapi::default.dashboard.text_ordering_off')
            </span>

            <span @class([
                'badge',
                'text-bg-warning' => $bld['busy'],
                'text-bg-secondary' => !$bld['busy'],
            ])>
                <i class="fa {{ $bld['busy'] ? 'fa-fire-burner' : 'fa-kitchen-set' }}"></i>
                @lang($bld['busy']
                    ? 'veykemtu.bridgeapi::default.dashboard.text_busy_on'
                    : 'veykemtu.bridgeapi::default.dashboard.text_busy_off')
            </span>

            <span class="badge text-bg-light">
                <i class="fa fa-clock"></i>
                @if($bld['order_cutoff'])
                    @lang('veykemtu.bridgeapi::default.dashboard.text_cutoff'): {{ $bld['order_cutoff'] }}
                @else
                    @lang('veykemtu.bridgeapi::default.dashboard.text_no_cutoff')
                @endif
            </span>
        </div>

        <div class="row row-cols-2 row-cols-lg-3 g-3">
            <div class="col">
                <div class="fs-4 fw-bold">{{ $bld['orders_today'] }}</div>
                <div class="text-muted small">
                    @lang('veykemtu.bridgeapi::default.dashboard.text_orders_today')
                </div>
            </div>
            <div class="col">
                <div class="fs-4 fw-bold">{{ currency_format($revenueToday) }}</div>
                <div class="text-muted small">
                    @lang('veykemtu.bridgeapi::default.dashboard.text_revenue_today')
                </div>
            </div>
            <div class="col">
                <div @class(['fs-4 fw-bold', 'text-warning' => $bld['pending_orders'] > 0])>
                    {{ $bld['pending_orders'] }}
                </div>
                <div class="text-muted small">
                    @lang('veykemtu.bridgeapi::default.dashboard.text_pending')
                </div>
            </div>
            <div class="col">
                <div @class(['fs-4 fw-bold', 'text-danger' => $bld['unprinted_orders'] > 0])>
                    {{ $bld['unprinted_orders'] }}
                </div>
                <div class="text-muted small">
                    @lang('veykemtu.bridgeapi::default.dashboard.text_unprinted')
                </div>
            </div>
            <div class="col">
                <div @class([
                    'fs-4 fw-bold',
                    'text-danger' => $bld['devices_total'] > 0 && $bld['devices_online'] === 0,
                ])>
                    {{ $bld['devices_online'] }}
                    <small class="text-muted fw-normal">
                        / {{ $bld['devices_total'] }} @lang('veykemtu.bridgeapi::default.dashboard.text_devices_total')
                    </small>
                </div>
                <div class="text-muted small">
                    @lang('veykemtu.bridgeapi::default.dashboard.text_devices_online')
                </div>
            </div>
        </div>
    @endunless
</div>
