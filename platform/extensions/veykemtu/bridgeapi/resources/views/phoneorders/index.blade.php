{{--
    Telefon siparişi giriş ekranı — B-13.

    TEK SAYFA, TEK EKRAN. Sipariş telefonda alınıyor: müşteri hatta bekliyor
    ve yöneticinin sekme değiştirecek, arayacak, geri gelecek vakti yok.
    Bu yüzden müşteri seçimi, satırlar, adres ve ödeme aynı ekranda ve
    kaydırma sırası konuşmanın sırasıyla aynı.

    Alanlar `form_open` ile değil düz HTML ile yazıldı: çekirdeğin form
    parçacığı model odaklı ve buradaki hiçbir alan tek bir modele ait değil
    (gerekçenin tamamı `PhoneOrders` sınıf yorumunda).
--}}
@php
    $paraBirimi = '₺';
@endphp

<div class="d-flex p-3">
    <h4 class="page-title mb-0 lh-base">
        <span>@lang('veykemtu.bridgeapi::phoneorder.text_title')</span>
    </h4>
</div>

@if ($location === null)
    <div class="alert alert-danger m-3">
        @lang('veykemtu.bridgeapi::phoneorder.alert_no_location')
    </div>
@else

<form id="bld-phone-order" class="px-3 pb-5">
    @csrf

    {{-- ── Müşteri ──────────────────────────────────────────────────── --}}
    <div class="card mb-3">
        <div class="card-header fw-semibold">
            @lang('veykemtu.bridgeapi::phoneorder.section_customer')
        </div>
        <div class="card-body">
            <div class="row g-3">
                <div class="col-md-8">
                    <label class="form-label" for="bld-customer">
                        @lang('veykemtu.bridgeapi::phoneorder.label_customer')
                    </label>
                    {{-- Arama kutusu değil `select`: kurumsal müşteri sayısı
                         onlarla ifade ediliyor ve tarayıcının kendi yazarak
                         bulma davranışı, yazdığımız her AJAX aramasından
                         hızlı ve güvenilir. --}}
                    <select class="form-select" id="bld-customer" name="customer_id">
                        <option value="0">@lang('veykemtu.bridgeapi::phoneorder.option_new_customer')</option>
                        @foreach ($customers as $customer)
                            <option
                                value="{{ $customer->customer_id }}"
                                data-limit="{{ $customer->bld_credit_limit_kurus === null ? '' : (int) $customer->bld_credit_limit_kurus }}"
                            >
                                {{ $customer->bld_org_name ?: trim($customer->first_name.' '.$customer->last_name) }}
                                @if ($customer->telephone) — {{ $customer->telephone }} @endif
                            </option>
                        @endforeach
                    </select>
                </div>
            </div>

            {{-- Yeni müşteri alanları yalnızca "Yeni müşteri" seçiliyken
                 açılır. Her zaman görünür olsalardı, kayıtlı bir müşteri
                 seçen yönetici boş bıraktığı alanların ne işe yaradığını
                 sorardı. --}}
            <div class="row g-3 mt-1" id="bld-new-customer">
                <div class="col-12">
                    <div class="alert alert-info py-2 mb-0 small">
                        @lang('veykemtu.bridgeapi::phoneorder.help_new_customer')
                    </div>
                </div>
                <div class="col-md-4">
                    <label class="form-label" for="bld-org">
                        @lang('veykemtu.bridgeapi::phoneorder.label_org_name')
                    </label>
                    <input type="text" class="form-control" id="bld-org" name="new_org_name" autocomplete="off">
                </div>
                <div class="col-md-4">
                    <label class="form-label" for="bld-contact">
                        @lang('veykemtu.bridgeapi::phoneorder.label_contact')
                    </label>
                    <input type="text" class="form-control" id="bld-contact" name="new_contact" autocomplete="off">
                </div>
                <div class="col-md-4">
                    <label class="form-label" for="bld-phone">
                        @lang('veykemtu.bridgeapi::phoneorder.label_phone')
                    </label>
                    <input type="tel" class="form-control" id="bld-phone" name="new_phone" autocomplete="off">
                </div>
            </div>
        </div>
    </div>

    {{-- ── Ürünler ──────────────────────────────────────────────────── --}}
    <div class="card mb-3">
        <div class="card-header fw-semibold">
            @lang('veykemtu.bridgeapi::phoneorder.section_items')
        </div>
        <div class="card-body">
            <table class="table table-sm align-middle mb-2">
                <thead>
                    <tr>
                        <th scope="col" style="width:45%">@lang('veykemtu.bridgeapi::phoneorder.column_item')</th>
                        <th scope="col" style="width:12%">@lang('veykemtu.bridgeapi::phoneorder.column_quantity')</th>
                        <th scope="col">@lang('veykemtu.bridgeapi::phoneorder.column_line_note')</th>
                    </tr>
                </thead>
                <tbody id="bld-lines">
                    @for ($i = 0; $i < $initialLines; $i++)
                        <tr>
                            <td>
                                <select class="form-select form-select-sm" name="line_menu_id[]">
                                    <option value="0">—</option>
                                    @foreach ($menus as $menu)
                                        <option value="{{ $menu->menu_id }}">
                                            {{ $menu->menu_name }}
                                            ({{ number_format((float) $menu->menu_price, 2, ',', '.') }} {{ $paraBirimi }})
                                        </option>
                                    @endforeach
                                </select>
                            </td>
                            <td>
                                <input
                                    type="number"
                                    class="form-control form-control-sm"
                                    name="line_quantity[]"
                                    min="0"
                                    max="9999"
                                    value="0"
                                >
                            </td>
                            <td>
                                <input type="text" class="form-control form-control-sm" name="line_note[]" maxlength="255">
                            </td>
                        </tr>
                    @endfor
                </tbody>
            </table>

            <button type="button" class="btn btn-sm btn-outline-secondary" id="bld-add-line">
                <i class="fa fa-plus" aria-hidden="true"></i>
                @lang('veykemtu.bridgeapi::phoneorder.button_add_line')
            </button>

            <p class="form-text mb-0">@lang('veykemtu.bridgeapi::phoneorder.help_items')</p>
        </div>
    </div>

    {{-- ── Teslimat ─────────────────────────────────────────────────── --}}
    <div class="card mb-3">
        <div class="card-header fw-semibold">
            @lang('veykemtu.bridgeapi::phoneorder.section_delivery')
        </div>
        <div class="card-body">
            <div class="row g-3">
                <div class="col-md-3">
                    <label class="form-label" for="bld-delivery-type">
                        @lang('veykemtu.bridgeapi::phoneorder.label_delivery_type')
                    </label>
                    <select class="form-select" id="bld-delivery-type" name="delivery_type">
                        <option value="delivery">@lang('veykemtu.bridgeapi::phoneorder.delivery')</option>
                        <option value="collection">@lang('veykemtu.bridgeapi::phoneorder.pickup')</option>
                    </select>
                </div>
                <div class="col-md-3">
                    <label class="form-label" for="bld-date">
                        @lang('veykemtu.bridgeapi::phoneorder.label_date')
                    </label>
                    <input type="date" class="form-control" id="bld-date" name="requested_date" value="{{ $today }}">
                </div>
                <div class="col-md-3">
                    <label class="form-label" for="bld-time">
                        @lang('veykemtu.bridgeapi::phoneorder.label_time')
                    </label>
                    <input type="time" class="form-control" id="bld-time" name="requested_time">
                </div>
                <div class="col-md-3">
                    <label class="form-label" for="bld-payment">
                        @lang('veykemtu.bridgeapi::phoneorder.label_payment')
                    </label>
                    <select class="form-select" id="bld-payment" name="payment_method">
                        @foreach ($paymentMethods as $method)
                            <option value="{{ $method }}">
                                @lang('veykemtu.bridgeapi::phoneorder.payment_'.$method)
                            </option>
                        @endforeach
                    </select>
                </div>
            </div>

            <p class="form-text">@lang('veykemtu.bridgeapi::phoneorder.help_time')</p>

            <div class="row g-3" id="bld-address">
                <div class="col-md-6">
                    <label class="form-label" for="bld-address-line1">
                        @lang('veykemtu.bridgeapi::phoneorder.label_address')
                    </label>
                    <input type="text" class="form-control" id="bld-address-line1" name="address_line1">
                </div>
                <div class="col-md-3">
                    <label class="form-label" for="bld-district">
                        @lang('veykemtu.bridgeapi::phoneorder.label_district')
                    </label>
                    <input type="text" class="form-control" id="bld-district" name="address_district">
                </div>
                <div class="col-md-3">
                    <label class="form-label" for="bld-city">
                        @lang('veykemtu.bridgeapi::phoneorder.label_city')
                    </label>
                    <input type="text" class="form-control" id="bld-city" name="address_city" value="Konya">
                </div>
                <div class="col-12">
                    <label class="form-label" for="bld-address-note">
                        @lang('veykemtu.bridgeapi::phoneorder.label_address_note')
                    </label>
                    <input type="text" class="form-control" id="bld-address-note" name="address_note" maxlength="255">
                </div>
            </div>

            <div class="row g-3 mt-1">
                <div class="col-12">
                    <label class="form-label" for="bld-note">
                        @lang('veykemtu.bridgeapi::phoneorder.label_note')
                    </label>
                    <input type="text" class="form-control" id="bld-note" name="customer_note" maxlength="255">
                </div>
            </div>
        </div>
    </div>

    {{-- ── Abonelik bağı ────────────────────────────────────────────── --}}
    <div class="card mb-3">
        <div class="card-header fw-semibold">
            @lang('veykemtu.bridgeapi::phoneorder.section_subscription')
        </div>
        <div class="card-body">
            <div class="row g-3">
                <div class="col-md-6">
                    <label class="form-label" for="bld-subscription">
                        @lang('veykemtu.bridgeapi::phoneorder.label_subscription')
                    </label>
                    <select class="form-select" id="bld-subscription" name="subscription_id">
                        <option value="0">@lang('veykemtu.bridgeapi::phoneorder.option_no_subscription')</option>
                        @foreach ($subscriptions as $subscription)
                            <option value="{{ $subscription->id }}" data-customer="{{ $subscription->customer_id }}">
                                #{{ $subscription->id }} — {{ $subscription->default_quantity }}
                                @lang('veykemtu.bridgeapi::phoneorder.portion')
                            </option>
                        @endforeach
                    </select>
                </div>
            </div>
            <p class="form-text mb-0">@lang('veykemtu.bridgeapi::phoneorder.help_subscription')</p>
        </div>
    </div>

    <div class="d-flex gap-2">
        <button
            type="button"
            class="btn btn-primary btn-lg"
            data-request="onCreateOrder"
            data-request-form="#bld-phone-order"
            data-request-confirm="{{ lang('veykemtu.bridgeapi::phoneorder.confirm_create') }}"
            data-progress-indicator="{{ lang('admin::lang.text_saving') }}"
        >
            <i class="fa fa-utensils" aria-hidden="true"></i>
            @lang('veykemtu.bridgeapi::phoneorder.button_create')
        </button>
    </div>
</form>

{{-- ── Aboneliğe ek porsiyon ────────────────────────────────────────────
     SİPARİŞ FORMUNUN DIŞINDA VE AYRI BİR FORMDA. İkisi zıt işler yapıyor:
     yukarıdaki bugün teslim edilecek bir sipariş açar, buradaki gelecekteki
     bir günün üretim adedini büyütür ve siparişi o gece üretim işi açar.
     Aynı düğmeye bağlanmaları aynı porsiyonun iki kez pişmesi demekti
     (gerekçenin tamamı `PhoneOrders::onAddSubscriptionPortions`). --}}
<form id="bld-extra-portions" class="px-3 pb-5">
    @csrf
    <div class="card">
        <div class="card-header fw-semibold">
            @lang('veykemtu.bridgeapi::phoneorder.section_extra')
        </div>
        <div class="card-body">
            <p class="text-muted small">@lang('veykemtu.bridgeapi::phoneorder.help_extra')</p>

            <div class="row g-3 align-items-end">
                <div class="col-md-4">
                    <label class="form-label" for="bld-extra-subscription">
                        @lang('veykemtu.bridgeapi::phoneorder.label_subscription')
                    </label>
                    <select class="form-select" id="bld-extra-subscription" name="extra_subscription_id">
                        <option value="0">—</option>
                        @foreach ($subscriptions as $subscription)
                            <option value="{{ $subscription->id }}">
                                #{{ $subscription->id }} — {{ $subscription->default_quantity }}
                                @lang('veykemtu.bridgeapi::phoneorder.portion')
                            </option>
                        @endforeach
                    </select>
                </div>
                <div class="col-md-3">
                    <label class="form-label" for="bld-extra-date">
                        @lang('veykemtu.bridgeapi::phoneorder.label_extra_date')
                    </label>
                    <input type="date" class="form-control" id="bld-extra-date" name="extra_date">
                </div>
                <div class="col-md-2">
                    <label class="form-label" for="bld-extra-quantity">
                        @lang('veykemtu.bridgeapi::phoneorder.label_extra_quantity')
                    </label>
                    <input type="number" class="form-control" id="bld-extra-quantity" name="extra_quantity" min="1" max="9999">
                </div>
                <div class="col-md-3">
                    <button
                        type="button"
                        class="btn btn-outline-primary w-100"
                        data-request="onAddSubscriptionPortions"
                        data-request-form="#bld-extra-portions"
                        data-progress-indicator="{{ lang('admin::lang.text_saving') }}"
                    >
                        @lang('veykemtu.bridgeapi::phoneorder.button_extra')
                    </button>
                </div>
            </div>
        </div>
    </div>
</form>

<script>
(function () {
    'use strict';

    var musteri = document.getElementById('bld-customer');
    var yeniAlanlar = document.getElementById('bld-new-customer');
    var teslimTipi = document.getElementById('bld-delivery-type');
    var adres = document.getElementById('bld-address');
    var abonelik = document.getElementById('bld-subscription');

    function gorunurluk() {
        yeniAlanlar.hidden = musteri.value !== '0';
        adres.hidden = teslimTipi.value !== 'delivery';

        // Abonelik listesi seçili müşteriye daraltılır: A firmasının siparişi
        // B firmasının sözleşmesine yazılamasın. Sunucu tarafında da
        // kontrol ediliyor (`collectSubscriptionId`); buradaki yalnızca
        // yanlış seçimi baştan imkânsız kılmak için.
        var secili = musteri.value;
        Array.prototype.forEach.call(abonelik.options, function (secenek) {
            if (!secenek.dataset.customer) return;
            var uygun = secenek.dataset.customer === secili;
            secenek.hidden = !uygun;
            if (!uygun && secenek.selected) abonelik.value = '0';
        });
    }

    musteri.addEventListener('change', gorunurluk);
    teslimTipi.addEventListener('change', gorunurluk);
    gorunurluk();

    document.getElementById('bld-add-line').addEventListener('click', function () {
        var govde = document.getElementById('bld-lines');
        var kopya = govde.rows[0].cloneNode(true);
        Array.prototype.forEach.call(kopya.querySelectorAll('select'), function (s) { s.value = '0'; });
        Array.prototype.forEach.call(kopya.querySelectorAll('input[type=number]'), function (i) { i.value = '0'; });
        Array.prototype.forEach.call(kopya.querySelectorAll('input[type=text]'), function (i) { i.value = ''; });
        govde.appendChild(kopya);
    });
})();
</script>

@endif
