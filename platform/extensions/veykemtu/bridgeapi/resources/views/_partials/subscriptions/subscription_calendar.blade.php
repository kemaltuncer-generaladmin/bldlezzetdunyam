{{--
    Abonelik takvimi — B-16.

    İki soruyu birden yanıtlıyor:
      * ÖNÜMÜZDEKİ 30 GÜN: hangi günler, kaç porsiyon, hangisi tatile denk
        geliyor. Kaynak `Subscription::upcomingServiceDays()`, o da gece
        üretim işiyle AYNI `runsOnDate()`/`quantityForDate()` metotlarını
        kullanıyor — ekranda görünen ile üretilen ayrışamaz.
      * SON ÜRETİLENLER: `veykemtu_subscription_runs` üzerinden gerçekten
        doğmuş siparişler. Plan ile gerçeğin yan yana durması, "dün üretim
        koştu mu" sorusunu tek bakışta kapatıyor.

    Salt okunur. Gün atlamak ya da porsiyon değiştirmek için istisna kaydı
    girilir (Telefon siparişi ekranındaki ek porsiyon bölümü, ya da
    müşterinin kendi uygulaması).
--}}
@php
    $bugun = \Veykemtu\BridgeApi\Support\BusinessTime::now();
    $gunler = $model->exists ? $model->upcomingServiceDays($bugun, 30) : [];

    $kosumlar = $model->exists
        ? \Illuminate\Support\Facades\DB::table('veykemtu_subscription_runs')
            ->where('subscription_id', $model->id)
            ->orderByDesc('service_date')
            ->limit(10)
            ->get()
        : collect();
@endphp

<div class="row g-4">
    <div class="col-lg-7">
        <div class="text-muted small mb-2">
            @lang('veykemtu.bridgeapi::subscription.calendar_upcoming')
        </div>

        @if ($gunler === [])
            <div class="alert alert-secondary mb-0">
                @lang('veykemtu.bridgeapi::subscription.calendar_none')
            </div>
        @else
            <div class="table-responsive">
                <table class="table table-sm align-middle mb-0">
                    <thead>
                        <tr>
                            <th scope="col">@lang('veykemtu.bridgeapi::subscription.calendar_day')</th>
                            <th scope="col" class="text-end">@lang('veykemtu.bridgeapi::subscription.calendar_portions')</th>
                            <th scope="col">@lang('veykemtu.bridgeapi::subscription.calendar_state')</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($gunler as $gun)
                            <tr @class(['table-warning' => $gun['closed']])>
                                <td class="text-nowrap">
                                    {{ $gun['date']->format('d.m.Y') }}
                                    <span class="text-muted">
                                        {{ lang('veykemtu.bridgeapi::subscription.day_'.$gun['date']->dayOfWeekIso) }}
                                    </span>
                                </td>
                                <td class="text-end bld-money">{{ $gun['quantity'] }}</td>
                                <td>
                                    @if ($gun['closed'])
                                        {{-- Kapalı gün üretimi durdurur; planda görünüp
                                             üretilmemesi sürpriz olmasın diye ayrıca
                                             işaretleniyor. --}}
                                        <span class="badge bg-warning text-dark">
                                            @lang('veykemtu.bridgeapi::subscription.calendar_closed')
                                        </span>
                                        @if ($gun['note'])
                                            <span class="small text-muted">{{ $gun['note'] }}</span>
                                        @endif
                                    @elseif ($model->quantityOverrideFor($gun['date']) !== null)
                                        <span class="badge bg-info">
                                            @lang('veykemtu.bridgeapi::subscription.calendar_override')
                                        </span>
                                    @else
                                        <span class="text-muted small">
                                            @lang('veykemtu.bridgeapi::subscription.calendar_normal')
                                        </span>
                                    @endif
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        @endif
    </div>

    <div class="col-lg-5">
        <div class="text-muted small mb-2">
            @lang('veykemtu.bridgeapi::subscription.calendar_generated')
        </div>

        @if ($kosumlar->isEmpty())
            <div class="alert alert-secondary mb-0">
                @lang('veykemtu.bridgeapi::subscription.calendar_no_runs')
            </div>
        @else
            <ul class="list-unstyled mb-0">
                @foreach ($kosumlar as $kosum)
                    <li class="d-flex justify-content-between border-bottom py-1">
                        <span>{{ \Illuminate\Support\Carbon::parse($kosum->service_date)->format('d.m.Y') }}</span>
                        <span>
                            @if ($kosum->order_id)
                                <a href="{{ admin_url('orders/edit/'.$kosum->order_id) }}">
                                    S-{{ $kosum->order_id }}
                                </a>
                            @else
                                {{-- Koşum kaydı var ama sipariş yok: üretim o gün
                                     bilerek atlandı (tatil/duraklatma) ya da
                                     hata aldı. İkisi de görünmeli. --}}
                                <span class="text-muted">
                                    @lang('veykemtu.bridgeapi::subscription.calendar_no_order')
                                </span>
                            @endif
                        </span>
                    </li>
                @endforeach
            </ul>
        @endif
    </div>
</div>
