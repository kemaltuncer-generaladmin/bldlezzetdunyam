{{--
    Gün düzenleyici — B-19.

    TEK DİYALOG, OTUZ BİR GÜN. Her hücre için ayrı bir form çizmek sayfayı
    otuz bir kopyayla şişirirdi ve ürün listesi (yüz küsur `<option>`) her
    birinde tekrarlanırdı. Diyalog boş çiziliyor; içeriğini `index.blade.php`
    içindeki betik, sunucudan gelen gün tablosundan dolduruyor.

    IZGARA FORMUNUN DIŞINDA. İç içe `<form>` geçersiz HTML ve tarayıcı
    içtekini sessizce atıyor; kopyalama formunun içine konsaydı gün
    kaydetme düğmesi hiç çalışmazdı.

    YAPISAL ALANLAR AYRI BİR `<fieldset>` İÇİNDE ve bu tesadüf değil:
    siparişi olan günde o fieldset devre dışı bırakılıyor, devre dışı alanlar
    ise formdan hiç gönderilmiyor. Kilit böylece tek bir özelliğe indirgeniyor
    — her alanı tek tek kapatmayı unutmak mümkün olmuyor.
--}}
<dialog id="bld-day-editor" class="bld-dialog" aria-labelledby="bld-day-editor-title">
    <form id="bld-day-editor-form">
        @csrf
        <input type="hidden" name="day_date" id="bld-day-date" value="">

        <div class="bld-dialog-head">
            <div>
                <h5 class="bld-dialog-title" id="bld-day-editor-title">
                    @lang('veykemtu.bridgeapi::dailymenu.editor_title')
                </h5>
                <span class="bld-dialog-date" id="bld-day-editor-date"></span>
            </div>

            <button
                type="button"
                class="btn btn-sm btn-outline-secondary"
                data-bld-close
            >@lang('veykemtu.bridgeapi::dailymenu.editor_close')</button>
        </div>

        <div class="bld-dialog-body">
            {{-- Üç şerit, üç ton. Metinleri betik dolduruyor: gün sayısı ve
                 kapalı gün notu güne göre değişiyor. --}}
            <div
                class="bld-notice bld-notice--muted"
                id="bld-day-notice-new"
                hidden
            >@lang('veykemtu.bridgeapi::dailymenu.editor_new_notice')</div>

            <div
                class="bld-notice bld-notice--info"
                id="bld-day-notice-locked"
                role="status"
                data-template="{{ lang('veykemtu.bridgeapi::dailymenu.editor_locked_notice') }}"
                hidden
            ></div>

            <div
                class="bld-notice bld-notice--warning"
                id="bld-day-notice-closed"
                role="status"
                data-template="{{ lang('veykemtu.bridgeapi::dailymenu.editor_closed_notice') }}"
                hidden
            ></div>

            {{-- ── Kozmetik alanlar — kilitli günde de düzenlenebilir ──── --}}
            <div class="row g-3">
                <div class="col-md-6">
                    <label class="form-label" for="bld-day-title">
                        @lang('veykemtu.bridgeapi::dailymenu.label_title')
                    </label>
                    <input
                        type="text"
                        class="form-control"
                        id="bld-day-title"
                        name="title"
                        maxlength="120"
                        autocomplete="off"
                        aria-describedby="bld-day-title-help"
                    >
                    <span class="bld-field-help" id="bld-day-title-help">
                        @lang('veykemtu.bridgeapi::dailymenu.help_title')
                    </span>
                </div>

                <div class="col-md-6">
                    <label class="form-label" for="bld-day-description">
                        @lang('veykemtu.bridgeapi::dailymenu.label_description')
                    </label>
                    <input
                        type="text"
                        class="form-control"
                        id="bld-day-description"
                        name="description"
                        maxlength="500"
                        autocomplete="off"
                        aria-describedby="bld-day-description-help"
                    >
                    <span class="bld-field-help" id="bld-day-description-help">
                        @lang('veykemtu.bridgeapi::dailymenu.help_description')
                    </span>
                </div>

                <div class="col-12">
                    <label class="form-label" for="bld-day-internal-note">
                        @lang('veykemtu.bridgeapi::dailymenu.label_internal_note')
                    </label>
                    <input
                        type="text"
                        class="form-control"
                        id="bld-day-internal-note"
                        name="internal_note"
                        maxlength="255"
                        autocomplete="off"
                        aria-describedby="bld-day-internal-note-help"
                    >
                    <span class="bld-field-help" id="bld-day-internal-note-help">
                        @lang('veykemtu.bridgeapi::dailymenu.help_internal_note')
                    </span>
                </div>
            </div>

            {{-- ── Yapısal alanlar — siparişli günde donar ─────────────── --}}
            <fieldset class="bld-day-structural mt-2" id="bld-day-structural">
                <div class="row g-3">
                    <div class="col-md-4">
                        <label class="form-label" for="bld-day-package-price">
                            @lang('veykemtu.bridgeapi::dailymenu.label_package_price')
                        </label>
                        {{-- `type="number"` DEĞİL, `text`. Çekirdeğin form
                             parçacığı number postback'ini `(int)` ile
                             daraltıp kuruşu yiyor (`LiraField` docblock'u);
                             ayrıca `number` alanı tarayıcı diline göre
                             "180,50" girdisini geçersiz sayıp boş
                             gönderebiliyor. --}}
                        <input
                            type="text"
                            inputmode="decimal"
                            class="form-control bld-money-input"
                            id="bld-day-package-price"
                            name="package_price"
                            maxlength="12"
                            autocomplete="off"
                            placeholder="—"
                            aria-describedby="bld-day-package-price-help"
                        >
                        <span class="bld-field-help" id="bld-day-package-price-help">
                            @lang('veykemtu.bridgeapi::dailymenu.help_package_price')
                        </span>
                    </div>

                    <div class="col-md-8">
                        <div class="form-check mt-4">
                            <input
                                type="checkbox"
                                class="form-check-input"
                                id="bld-day-components-sellable"
                                name="components_sellable"
                                value="1"
                                aria-describedby="bld-day-components-sellable-help"
                            >
                            <label class="form-check-label" for="bld-day-components-sellable">
                                @lang('veykemtu.bridgeapi::dailymenu.label_components_sellable')
                            </label>
                        </div>
                        <span class="bld-field-help" id="bld-day-components-sellable-help">
                            @lang('veykemtu.bridgeapi::dailymenu.help_components_sellable')
                        </span>
                    </div>
                </div>

                <h6 class="mt-3 fw-semibold">
                    @lang('veykemtu.bridgeapi::dailymenu.section_items')
                </h6>
                <p class="bld-field-help">@lang('veykemtu.bridgeapi::dailymenu.help_items')</p>

                <div class="table-responsive">
                    <table class="table table-sm bld-items-table">
                        <thead>
                            <tr>
                                <th scope="col" style="width:32%">
                                    @lang('veykemtu.bridgeapi::dailymenu.column_item')
                                </th>
                                <th scope="col" style="width:8%">
                                    @lang('veykemtu.bridgeapi::dailymenu.column_quantity')
                                </th>
                                <th scope="col" style="width:14%">
                                    @lang('veykemtu.bridgeapi::dailymenu.column_price_override')
                                </th>
                                <th scope="col" style="width:20%">
                                    @lang('veykemtu.bridgeapi::dailymenu.column_label')
                                </th>
                                <th scope="col" class="text-center" style="width:8%">
                                    @lang('veykemtu.bridgeapi::dailymenu.column_required')
                                </th>
                                <th scope="col" class="text-center" style="width:8%">
                                    @lang('veykemtu.bridgeapi::dailymenu.column_sellable_alone')
                                </th>
                                <th scope="col" class="text-end" style="width:10%">
                                    @lang('veykemtu.bridgeapi::dailymenu.column_actions')
                                </th>
                            </tr>
                        </thead>
                        <tbody id="bld-day-items"></tbody>
                        <tbody id="bld-day-items-empty" class="bld-items-empty">
                            <tr>
                                <td colspan="7">
                                    @lang('veykemtu.bridgeapi::dailymenu.empty_items')
                                </td>
                            </tr>
                        </tbody>
                    </table>
                </div>

                <button type="button" class="btn btn-sm btn-outline-secondary" id="bld-day-add-item">
                    <i class="fa fa-plus" aria-hidden="true"></i>
                    @lang('veykemtu.bridgeapi::dailymenu.button_add_item')
                </button>
            </fieldset>
        </div>

        <div class="bld-dialog-foot">
            {{-- GÖRÜNÜM BAŞINA TEK PRIMARY: kaydetmek. Yayına alma ayrı bir
                 karar ve `Tonal`/`Outline` seviyesinde duruyor; ikisi de
                 dolu düğme olsaydı yönetici hangisinin "işi bitiren" düğme
                 olduğunu her seferinde okumak zorunda kalırdı. --}}
            <button
                type="button"
                class="btn btn-primary"
                data-request="onSaveDay"
                data-request-form="#bld-day-editor-form"
                data-progress-indicator="{{ lang('admin::lang.text_saving') }}"
            >@lang('veykemtu.bridgeapi::dailymenu.button_save')</button>

            <button
                type="button"
                class="btn btn-outline-primary"
                data-bld-publish="published"
                data-request="onPublish"
                data-request-form="#bld-day-editor-form"
                data-request-data="publish_status:'published'"
                data-progress-indicator="{{ lang('admin::lang.text_saving') }}"
            >@lang('veykemtu.bridgeapi::dailymenu.button_publish')</button>

            <button
                type="button"
                class="btn btn-outline-secondary"
                data-bld-publish="draft"
                data-request="onPublish"
                data-request-form="#bld-day-editor-form"
                data-request-data="publish_status:'draft'"
                data-request-confirm="{{ lang('veykemtu.bridgeapi::dailymenu.confirm_unpublish') }}"
                data-progress-indicator="{{ lang('admin::lang.text_saving') }}"
            >@lang('veykemtu.bridgeapi::dailymenu.button_unpublish')</button>

            <button type="button" class="btn btn-link ms-auto" data-bld-close>
                @lang('veykemtu.bridgeapi::dailymenu.editor_close')
            </button>
        </div>
    </form>
</dialog>

{{--
    Kalem satırı şablonu.

    `<template>` içeriği forma dahil değil, yani buradaki alanlar hiçbir
    zaman gönderilmez. Alan adları da bilerek boş: betik satırı eklerken
    `items[<sıra>][...]` biçiminde adlandırıyor. Düz liste (`item_x[]`)
    kullanılsaydı, işaretlenmemiş bir onay kutusu hiç gönderilmediği için
    satırlar kayardı — üçüncü satırın "zorunlu" değeri dördüncüye yazılırdı.
--}}
<template id="bld-day-item-template">
    <tr>
        <td>
            <select class="form-select form-select-sm" data-name="menu_id" aria-label="{{ lang('veykemtu.bridgeapi::dailymenu.column_item') }}">
                <option value="">@lang('veykemtu.bridgeapi::dailymenu.option_pick_product')</option>
                @foreach ($products as $product)
                    <option value="{{ $product->menu_id }}">
                        {{ $product->menu_name }}
                        ({{ $formatMoney(\Veykemtu\BridgeApi\Support\Money::toKurus($product->menu_price)) }})
                    </option>
                @endforeach
            </select>
        </td>
        <td>
            <input
                type="number"
                class="form-control form-control-sm"
                data-name="quantity"
                min="1"
                max="99"
                value="1"
                aria-label="{{ lang('veykemtu.bridgeapi::dailymenu.column_quantity') }}"
            >
        </td>
        <td>
            {{-- Para alanı `text`: gerekçe paket fiyatındaki yorumda. --}}
            <input
                type="text"
                inputmode="decimal"
                class="form-control form-control-sm bld-money-input"
                data-name="price_override"
                maxlength="12"
                placeholder="—"
                title="{{ lang('veykemtu.bridgeapi::dailymenu.help_price_override') }}"
                aria-label="{{ lang('veykemtu.bridgeapi::dailymenu.column_price_override') }}"
            >
        </td>
        <td>
            <input
                type="text"
                class="form-control form-control-sm"
                data-name="label"
                maxlength="120"
                title="{{ lang('veykemtu.bridgeapi::dailymenu.help_label') }}"
                aria-label="{{ lang('veykemtu.bridgeapi::dailymenu.column_label') }}"
            >
        </td>
        <td class="text-center">
            <input
                type="checkbox"
                class="form-check-input"
                data-name="is_required"
                value="1"
                checked
                title="{{ lang('veykemtu.bridgeapi::dailymenu.help_required') }}"
                aria-label="{{ lang('veykemtu.bridgeapi::dailymenu.column_required') }}"
            >
        </td>
        <td class="text-center">
            <input
                type="checkbox"
                class="form-check-input"
                data-name="sellable_alone"
                value="1"
                checked
                title="{{ lang('veykemtu.bridgeapi::dailymenu.help_sellable_alone') }}"
                aria-label="{{ lang('veykemtu.bridgeapi::dailymenu.column_sellable_alone') }}"
            >
        </td>
        <td class="text-end text-nowrap">
            <button
                type="button"
                class="btn btn-sm btn-link p-1"
                data-bld-row-action="up"
                aria-label="{{ lang('veykemtu.bridgeapi::dailymenu.button_move_up') }}"
                title="{{ lang('veykemtu.bridgeapi::dailymenu.button_move_up') }}"
            ><i class="fa fa-arrow-up" aria-hidden="true"></i></button>
            <button
                type="button"
                class="btn btn-sm btn-link p-1"
                data-bld-row-action="down"
                aria-label="{{ lang('veykemtu.bridgeapi::dailymenu.button_move_down') }}"
                title="{{ lang('veykemtu.bridgeapi::dailymenu.button_move_down') }}"
            ><i class="fa fa-arrow-down" aria-hidden="true"></i></button>
            <button
                type="button"
                class="btn btn-sm btn-link p-1 text-danger"
                data-bld-row-action="remove"
                aria-label="{{ lang('veykemtu.bridgeapi::dailymenu.button_remove_item') }}"
                title="{{ lang('veykemtu.bridgeapi::dailymenu.button_remove_item') }}"
            ><i class="fa fa-times" aria-hidden="true"></i></button>
        </td>
    </tr>
</template>
