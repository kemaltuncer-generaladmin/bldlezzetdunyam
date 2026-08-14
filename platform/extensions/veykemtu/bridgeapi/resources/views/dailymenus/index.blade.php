{{--
    Aylık menü takvimi — B-19.

    EKRANIN SIRASI, İŞİN SIRASI. Yönetici önce ayı geziyor, sonra bir güne
    menü kuruyor, en sonunda haftayı çoğaltıp ayı yayına alıyor. Kopyalama ve
    toplu işlemler bu yüzden ızgaranın ALTINDA: takvime bakmadan verilecek
    kararlar değiller.

    Alanlar `form_open` ile değil düz HTML ile yazıldı; buradaki hiçbir alan
    tek bir modele ait değil (gerekçenin tamamı `DailyMenus` sınıf yorumunda).
--}}
@php
    $currency = '₺';

    /**
     * Kuruşu panelde okunacak biçime çevirir: 18000 → "180,00 ₺".
     *
     * Sunucu tarafında biçimlendiriliyor çünkü aynı sayı hem ızgarada hem
     * düzenleyicide görünüyor; iki ayrı yerde biçimlendirmek, birinin
     * binlik ayıracını unuttuğu gün fark edilirdi.
     */
    $formatMoney = static fn(int $kurus): string
        => number_format($kurus / 100, 2, ',', '.').' '.$currency;

    // Tarihler her yerde `gg.aa.yyyy`: yönetici bu biçimi okuyor, sunucu ise
    // `YYYY-AA-GG` alıyor. İkisini karıştırmamak için dönüşüm tek yerde.
    $formatDate = static fn(string $date): string
        => \Illuminate\Support\Carbon::parse($date)->format('d.m.Y');
@endphp

<div class="d-flex p-3">
    <h4 class="page-title mb-0 lh-base">
        <span>@lang('veykemtu.bridgeapi::dailymenu.text_title')</span>
    </h4>
</div>

@if ($location === null)
    <div class="alert alert-danger m-3">
        @lang('veykemtu.bridgeapi::dailymenu.alert_no_location')
    </div>
@else

<div class="px-3">
    <p class="text-muted">@lang('veykemtu.bridgeapi::dailymenu.text_intro')</p>

    {{-- Şalter kapalıyken girilen menü hiçbir yerde görünmüyor. Bunu
         söylemeyen bir ekran, yöneticinin bir ayı boşa girmesine yol açar. --}}
    @unless ($dailyMenuEnabled)
        <div class="alert alert-warning">
            @lang('veykemtu.bridgeapi::dailymenu.alert_regime_off')
        </div>
    @endunless

    @if ($packageMenuId === null)
        <div class="alert alert-warning">
            @lang('veykemtu.bridgeapi::dailymenu.alert_no_package_product')
        </div>
    @endif
</div>

<form id="bld-daily-menus" class="px-3 pb-5">
    @csrf
    <input type="hidden" name="month" value="{{ $monthKey }}">

    <div class="bld-calendar-bar">
        <a
            class="btn btn-sm btn-outline-secondary"
            href="{{ admin_url($baseUri.'?'.$monthParam.'='.$prevMonth) }}"
        >&lsaquo; @lang('veykemtu.bridgeapi::dailymenu.nav_prev')</a>

        <h5 class="bld-calendar-title">{{ $monthLabel }}</h5>

        @if ($monthKey !== $thisMonth)
            <a
                class="btn btn-sm btn-outline-secondary"
                href="{{ admin_url($baseUri.'?'.$monthParam.'='.$thisMonth) }}"
            >@lang('veykemtu.bridgeapi::dailymenu.nav_today')</a>
        @endif

        <a
            class="btn btn-sm btn-outline-secondary"
            href="{{ admin_url($baseUri.'?'.$monthParam.'='.$nextMonth) }}"
        >@lang('veykemtu.bridgeapi::dailymenu.nav_next') &rsaquo;</a>
    </div>

    @include('veykemtu.bridgeapi::_partials.dailymenus.month_grid')

    {{-- ── Kopyalama ───────────────────────────────────────────────────
         Izgaranın ALTINDA ve aynı formun İÇİNDE: "seçili günlere uygula"
         düğmesi ızgaradaki kutucukları gönderiyor. Ayrı bir forma
         konsaydı seçim hiç ulaşmazdı. --}}
    <div class="card mt-4">
        <div class="card-header fw-semibold">
            @lang('veykemtu.bridgeapi::dailymenu.section_copy')
        </div>
        <div class="card-body">
            <p class="bld-field-help">@lang('veykemtu.bridgeapi::dailymenu.help_copy')</p>

            <div class="form-check mb-3">
                <input
                    type="checkbox"
                    class="form-check-input"
                    id="bld-copy-overwrite"
                    name="copy_overwrite"
                    value="1"
                    aria-describedby="bld-copy-overwrite-help"
                >
                <label class="form-check-label" for="bld-copy-overwrite">
                    @lang('veykemtu.bridgeapi::dailymenu.label_copy_overwrite')
                </label>
                <span class="bld-field-help" id="bld-copy-overwrite-help">
                    @lang('veykemtu.bridgeapi::dailymenu.help_copy_overwrite')
                </span>
            </div>

            <div class="row g-3 align-items-start">
                <div class="col-md-3">
                    <label class="form-label" for="bld-copy-week-start">
                        @lang('veykemtu.bridgeapi::dailymenu.label_copy_week_start')
                    </label>
                    <input
                        type="date"
                        class="form-control"
                        id="bld-copy-week-start"
                        name="copy_week_start"
                        value="{{ $month->toDateString() }}"
                        aria-describedby="bld-copy-week-help"
                    >
                    <span class="bld-field-help" id="bld-copy-week-help">
                        @lang('veykemtu.bridgeapi::dailymenu.help_copy_week')
                    </span>
                </div>
                <div class="col-md-3">
                    <label class="form-label d-none d-md-block">&nbsp;</label>
                    <button
                        type="button"
                        class="btn btn-outline-primary w-100"
                        data-request="onCopyWeek"
                        data-request-form="#bld-daily-menus"
                        data-progress-indicator="{{ lang('admin::lang.text_saving') }}"
                    >@lang('veykemtu.bridgeapi::dailymenu.button_copy_week')</button>
                    <span class="bld-field-help"></span>
                </div>

                <div class="col-md-3">
                    <label class="form-label" for="bld-copy-source">
                        @lang('veykemtu.bridgeapi::dailymenu.label_source_day')
                    </label>
                    <input
                        type="date"
                        class="form-control"
                        id="bld-copy-source"
                        name="source_date"
                        value="{{ $month->toDateString() }}"
                        aria-describedby="bld-copy-selected-help"
                    >
                    <span class="bld-field-help" id="bld-copy-selected-help">
                        @lang('veykemtu.bridgeapi::dailymenu.help_copy_selected')
                    </span>
                </div>
                <div class="col-md-3">
                    <label class="form-label d-none d-md-block">&nbsp;</label>
                    <button
                        type="button"
                        class="btn btn-outline-primary w-100"
                        data-request="onCopyDay"
                        data-request-form="#bld-daily-menus"
                        data-progress-indicator="{{ lang('admin::lang.text_saving') }}"
                    >@lang('veykemtu.bridgeapi::dailymenu.button_copy_selected')</button>
                    <span class="bld-field-help"></span>
                </div>
            </div>
        </div>
    </div>

    {{-- ── Ayı toplu işle ──────────────────────────────────────────────── --}}
    <div class="card mt-3">
        <div class="card-header fw-semibold">
            @lang('veykemtu.bridgeapi::dailymenu.section_bulk')
        </div>
        <div class="card-body">
            <p class="bld-field-help">@lang('veykemtu.bridgeapi::dailymenu.help_bulk')</p>

            <div class="d-flex flex-wrap gap-2">
                <button
                    type="button"
                    class="btn btn-outline-primary"
                    data-request="onBulkStatus"
                    data-request-form="#bld-daily-menus"
                    data-request-data="bulk_status:'published'"
                    data-request-confirm="{{ lang('veykemtu.bridgeapi::dailymenu.confirm_bulk_publish') }}"
                    data-progress-indicator="{{ lang('admin::lang.text_saving') }}"
                >@lang('veykemtu.bridgeapi::dailymenu.button_bulk_publish')</button>

                <button
                    type="button"
                    class="btn btn-outline-secondary"
                    data-request="onBulkStatus"
                    data-request-form="#bld-daily-menus"
                    data-request-data="bulk_status:'draft'"
                    data-request-confirm="{{ lang('veykemtu.bridgeapi::dailymenu.confirm_bulk_draft') }}"
                    data-progress-indicator="{{ lang('admin::lang.text_saving') }}"
                >@lang('veykemtu.bridgeapi::dailymenu.button_bulk_draft')</button>
            </div>
        </div>
    </div>
</form>

@include('veykemtu.bridgeapi::_partials.dailymenus.day_editor')

<script>
(function () {
    'use strict';

    /*
     * Ayın bütün günleri tek bir tabloda. Sunucu bunu `buildDayPayload()`
     * ile üretiyor; düzenleyici açılırken hiçbir istek atılmıyor.
     *
     * NEDEN AJAX DEĞİL: yönetici bir ayı doldururken otuz kutuya arka arkaya
     * giriyor. Her açılışta bir istek, hem yavaş hem de ağ kesildiğinde
     * ekranın yarısını çalışmaz hâle getirirdi. Verinin tamamı zaten
     * sayfayla birlikte okunmuş durumda.
     */
    var days = @json($days, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT);

    var dialog = document.getElementById('bld-day-editor');
    var form = document.getElementById('bld-day-editor-form');
    var template = document.getElementById('bld-day-item-template');
    var itemsBody = document.getElementById('bld-day-items');
    var emptyBody = document.getElementById('bld-day-items-empty');
    var structural = document.getElementById('bld-day-structural');
    var dateField = document.getElementById('bld-day-date');
    var dateLabel = document.getElementById('bld-day-editor-date');
    var noticeNew = document.getElementById('bld-day-notice-new');
    var noticeLocked = document.getElementById('bld-day-notice-locked');
    var noticeClosed = document.getElementById('bld-day-notice-closed');

    if (!dialog || !form || !template) {
        return;
    }

    // Satır indisleri ARTAN ve boşluklu olabilir. Sunucu dizinin anahtarına
    // değil, sırasına bakıyor; tarayıcı formu DOM sırasıyla gönderiyor.
    var nextIndex = 0;

    function field(name) {
        return form.querySelector('[name="' + name + '"]');
    }

    function refreshEmptyState() {
        emptyBody.hidden = itemsBody.rows.length > 0;
    }

    function addRow(item) {
        var row = template.content.firstElementChild.cloneNode(true);
        var index = nextIndex++;

        Array.prototype.forEach.call(row.querySelectorAll('[data-name]'), function (input) {
            input.name = 'items[' + index + '][' + input.dataset.name + ']';
        });

        if (item) {
            row.querySelector('[data-name="menu_id"]').value = String(item.menu_id);
            row.querySelector('[data-name="quantity"]').value = String(item.quantity);
            row.querySelector('[data-name="price_override"]').value = item.price_override;
            row.querySelector('[data-name="label"]').value = item.label;
            row.querySelector('[data-name="is_required"]').checked = item.is_required;
            row.querySelector('[data-name="sellable_alone"]').checked = item.sellable_alone;
        }

        itemsBody.appendChild(row);
        refreshEmptyState();
    }

    function fillNotice(element, value) {
        var text = element.getAttribute('data-template') || '';

        element.textContent = text.replace(/%[ds]/, String(value));
    }

    function openDay(date) {
        var day = days[date];

        if (!day) {
            return;
        }

        dateField.value = day.date;
        dateLabel.textContent = day.label;

        field('title').value = day.title;
        field('description').value = day.description;
        field('internal_note').value = day.internal_note;
        field('package_price').value = day.package_price;
        field('components_sellable').checked = day.components_sellable;

        itemsBody.innerHTML = '';
        nextIndex = 0;
        day.items.forEach(addRow);
        refreshEmptyState();

        /*
         * KİLİT TEK BİR ÖZELLİĞE İNDİRGENDİ. `fieldset.disabled` hem alanları
         * kullanılamaz yapıyor hem de formdan düşürüyor (jQuery `serialize()`
         * devre dışı alanı atlar). Alanları tek tek kapatmak, yarın eklenen
         * bir alanın unutulması demekti — ve unutulduğunda hata vermez,
         * sessizce siparişli bir günün fiyatını değiştirirdi.
         */
        structural.disabled = day.locked;

        noticeNew.hidden = day.exists;
        noticeLocked.hidden = !day.locked;
        noticeClosed.hidden = !day.closed;

        if (day.locked) {
            fillNotice(noticeLocked, day.order_count);
        }

        if (day.closed) {
            fillNotice(noticeClosed, day.closed_note || '—');
        }

        Array.prototype.forEach.call(form.querySelectorAll('[data-bld-publish]'), function (button) {
            // Devre dışı düğme HER ZAMAN bir sebep metniyle birlikte: üstteki
            // şeritler hangi sebebin geçerli olduğunu yazıyor.
            button.disabled = day.locked || !day.exists || day.status === button.dataset.bldPublish;
        });

        dialog.showModal();
    }

    document.getElementById('bld-daily-menus').addEventListener('click', function (event) {
        var opener = event.target.closest('[data-bld-open]');

        if (opener) {
            openDay(opener.dataset.bldOpen);
        }
    });

    document.getElementById('bld-day-add-item').addEventListener('click', function () {
        addRow(null);
    });

    itemsBody.addEventListener('click', function (event) {
        var button = event.target.closest('[data-bld-row-action]');

        if (!button) {
            return;
        }

        var row = button.closest('tr');
        var action = button.dataset.bldRowAction;

        if (action === 'remove') {
            row.remove();
        } else if (action === 'up' && row.previousElementSibling) {
            itemsBody.insertBefore(row, row.previousElementSibling);
        } else if (action === 'down' && row.nextElementSibling) {
            itemsBody.insertBefore(row.nextElementSibling, row);
        }

        refreshEmptyState();
    });

    Array.prototype.forEach.call(dialog.querySelectorAll('[data-bld-close]'), function (button) {
        button.addEventListener('click', function () {
            dialog.close();
        });
    });
})();
</script>

@endif
