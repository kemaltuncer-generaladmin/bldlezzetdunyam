{{--
    Tahsilat girişi (B-14).

    ANA FORMDAN AYRI BİR İSTEK: alanlar `onSave`'e değil `onRecordPayment`'a
    gidiyor. Sebep, ikisinin farklı şeyler olması — limit bir AYARDIR
    (değiştirilir, üzerine yazılır), tahsilat ise bir OLAYDIR (deftere
    eklenir, geri alınmaz). Aynı Kaydet düğmesine bağlansaydı, limiti
    düzeltmek için kaydeden yönetici her seferinde tahsilat da yazmış olurdu.

    `data-request-confirm`: defter append-only. Yanlış girilen tahsilat
    silinemez, ancak ters kayıtla düzeltilir — bu yüzden gönderimden önce
    bir kez daha soruluyor.
--}}
@php
    $bugun = \Veykemtu\BridgeApi\Support\BusinessTime::now()->toDateString();
@endphp

<div class="row g-3 align-items-end">
    <div class="col-md-3">
        <label class="form-label" for="bld-payment-amount">
            @lang('veykemtu.bridgeapi::accountledger.label_payment_amount')
        </label>
        <input
            type="text"
            inputmode="decimal"
            class="form-control"
            id="bld-payment-amount"
            name="payment_amount"
            placeholder="0,00"
            autocomplete="off"
        />
    </div>

    <div class="col-md-3">
        <label class="form-label" for="bld-payment-receipt">
            @lang('veykemtu.bridgeapi::accountledger.label_payment_receipt')
        </label>
        <input
            type="text"
            inputmode="numeric"
            class="form-control"
            id="bld-payment-receipt"
            name="payment_receipt"
            autocomplete="off"
        />
    </div>

    <div class="col-md-3">
        <label class="form-label" for="bld-payment-date">
            @lang('veykemtu.bridgeapi::accountledger.label_payment_date')
        </label>
        <input
            type="date"
            class="form-control"
            id="bld-payment-date"
            name="payment_date"
            value="{{ $bugun }}"
        />
    </div>

    <div class="col-md-3">
        <button
            type="button"
            class="btn btn-success w-100"
            data-request="onRecordPayment"
            data-request-form="#edit-form"
            data-request-confirm="{{ lang('veykemtu.bridgeapi::accountledger.confirm_payment') }}"
            data-progress-indicator="{{ lang('admin::lang.text_saving') }}"
        >
            <i class="fa fa-hand-holding-dollar" aria-hidden="true"></i>
            @lang('veykemtu.bridgeapi::accountledger.button_payment')
        </button>
    </div>
</div>

<p class="form-text mt-2 mb-0">
    @lang('veykemtu.bridgeapi::accountledger.help_payment_receipt')
</p>
