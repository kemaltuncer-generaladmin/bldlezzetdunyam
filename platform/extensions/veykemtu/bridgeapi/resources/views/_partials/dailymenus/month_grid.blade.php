{{--
    Ay ızgarası — B-19.

    Bir gün kutusu ÜÇ SORUYU aynı anda cevaplamak zorunda: o gün ne var
    (başlık + kalem sayısı), kaça satılıyor (paket fiyatı) ve satılabilir mi
    (rozet). Üçünden biri eksik olduğunda yönetici kutuyu açmak zorunda
    kalıyor; otuz bir kutuyu tek tek açmak takvimin bütün anlamını
    ortadan kaldırırdı.

    ROZET SIRASI = KURAL SIRASI. `DailyMenuService::verdict()` "kapalı gün her
    zaman kazanır" diyor; rozet de öyle diziliyor. İki yüzeyin farklı sıra
    kullanması, panelde "yayında" görünen bir günün müşteride kapalı çıkması
    demekti.
--}}
<div class="bld-calendar" role="group" aria-label="{{ $monthLabel }}">
    @for ($weekday = 1; $weekday <= 7; $weekday++)
        <div class="bld-calendar-weekday" aria-hidden="true">
            {{ lang('veykemtu.bridgeapi::dailymenu.weekday_'.$weekday) }}
        </div>
    @endfor

    @foreach ($weeks as $week)
        @foreach ($week as $cell)
            @php
                /** @var \Veykemtu\BridgeApi\Models\DailyMenu|null $dayMenu */
                $dayMenu = $cell['menu'];
                $isPublished = $dayMenu !== null
                    && $dayMenu->status === \Veykemtu\BridgeApi\Models\DailyMenu::STATUS_PUBLISHED;
            @endphp

            <div
                class="bld-day
                    @if (!$cell['in_month']) bld-day--outside @endif
                    @if ($cell['is_today']) bld-day--today @endif
                    @if ($cell['closed'] !== null) bld-day--closed @endif
                    @if ($cell['locked']) bld-day--locked @endif"
            >
                <div class="bld-day-head">
                    <span class="bld-day-number">{{ $cell['day_number'] }}</span>

                    {{-- Kopyalama hedefi seçici. Izgaranın içinde duruyor
                         çünkü "bu günü şu günlere uygula" işi takvime
                         bakarken veriliyor; ayrı bir tarih listesi, seçimi
                         takvimden koparırdı. --}}
                    <label class="bld-day-pick" title="{{ lang('veykemtu.bridgeapi::dailymenu.cell_select') }}">
                        <input
                            type="checkbox"
                            class="form-check-input"
                            name="target_dates[]"
                            value="{{ $cell['date'] }}"
                        >
                        <span class="visually-hidden">
                            {{ lang('veykemtu.bridgeapi::dailymenu.cell_select') }}
                            — {{ $formatDate($cell['date']) }}
                        </span>
                    </label>
                </div>

                <button
                    type="button"
                    class="bld-day-open"
                    data-bld-open="{{ $cell['date'] }}"
                    aria-label="{{ lang('veykemtu.bridgeapi::dailymenu.cell_open') }} — {{ $formatDate($cell['date']) }}"
                >
                    <span class="bld-day-title">
                        @if ($dayMenu !== null && trim((string) $dayMenu->title) !== '')
                            {{ $dayMenu->title }}
                        @elseif ($dayMenu !== null)
                            {{ sprintf(lang('veykemtu.bridgeapi::dailymenu.cell_items'), $cell['item_count']) }}
                        @else
                            <span class="text-muted">@lang('veykemtu.bridgeapi::dailymenu.cell_empty')</span>
                        @endif
                    </span>

                    @if ($dayMenu !== null)
                        <span class="bld-day-meta">
                            {{ sprintf(lang('veykemtu.bridgeapi::dailymenu.cell_items'), $cell['item_count']) }}
                        </span>

                        <span class="bld-day-price">
                            @if ($dayMenu->sellsPackage())
                                {{ sprintf(
                                    lang('veykemtu.bridgeapi::dailymenu.cell_package'),
                                    $formatMoney((int) $dayMenu->package_price_kurus),
                                ) }}
                            @else
                                <span class="bld-day-meta">
                                    @lang('veykemtu.bridgeapi::dailymenu.cell_no_package')
                                </span>
                            @endif
                        </span>
                    @endif

                    <span class="bld-day-badges">
                        @if ($cell['closed'] !== null)
                            <span class="bld-badge bld-badge--closed">
                                @lang('veykemtu.bridgeapi::dailymenu.badge_closed')
                            </span>
                        @endif

                        @if ($cell['locked'])
                            {{-- Rozet SAYIYI gösteriyor, DURUMU okutuyor.
                                 "3 sipariş" tek başına kilidi anlatmıyor;
                                 "Siparişli — kilitli" ise kaç sipariş
                                 olduğunu söylemiyor ve yönetici kutuyu
                                 açmadan riski tartamıyor. Görünen metin
                                 sayı, erişilebilir ad ise durum. --}}
                            <span
                                class="bld-badge bld-badge--locked"
                                title="{{ lang('veykemtu.bridgeapi::dailymenu.badge_locked') }}"
                            >
                                {{ sprintf(
                                    lang('veykemtu.bridgeapi::dailymenu.cell_orders'),
                                    $cell['order_count'],
                                ) }}
                                <span class="visually-hidden">
                                    — @lang('veykemtu.bridgeapi::dailymenu.badge_locked')
                                </span>
                            </span>
                        @endif

                        @if ($dayMenu === null)
                            <span class="bld-badge bld-badge--empty">
                                @lang('veykemtu.bridgeapi::dailymenu.cell_empty')
                            </span>
                        @elseif ($isPublished)
                            <span class="bld-badge bld-badge--published">
                                @lang('veykemtu.bridgeapi::dailymenu.badge_published')
                            </span>
                        @else
                            <span class="bld-badge bld-badge--draft">
                                @lang('veykemtu.bridgeapi::dailymenu.badge_draft')
                            </span>
                        @endif
                    </span>
                </button>
            </div>
        @endforeach
    @endforeach
</div>
