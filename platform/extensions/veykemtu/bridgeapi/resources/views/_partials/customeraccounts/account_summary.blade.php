{{--
    Müşteri kartının tepesindeki özet (B-14).

    Üç sayı: bakiye, limit, kalan. "Kalan" hesaplanmış olarak duruyor çünkü
    telefondaki asıl soru o: "bu müşteri daha ne kadar sipariş verebilir?"
    Yöneticinin bakiyeyi limitten kafadan çıkarması, yoğun bir öğle
    servisinde hata üretiyor.

    Kimlik bilgileri (unvan, yetkili, telefon) burada SALT-OKUNUR: kartın
    doğru müşteride olduğunu doğrulamak için gerekli, ama düzenleme yeri
    çekirdeğin Müşteriler ekranı.
--}}
@php
    $customerId = (int) $formModel->customer_id;
    $balance = app(\Veykemtu\BridgeApi\Services\AccountLedger::class)->balance($customerId);
    $remaining = app(\Veykemtu\BridgeApi\Services\CreditLimit::class)->remaining($formModel);
    $limit = $formModel->bld_credit_limit_kurus;

    $tl = static fn (int $kurus): string => number_format(abs($kurus) / 100, 2, ',', '.') . ' ₺';
    $balanceClass = $balance > 0 ? 'bld-balance--debt' : ($balance < 0 ? 'bld-balance--credit' : 'bld-balance--settled');
@endphp

<div class="row g-3 mb-3">
    <div class="col-md-4">
        <div class="border rounded p-3 h-100">
            <div class="text-muted small">@lang('veykemtu.bridgeapi::accountledger.summary_balance')</div>
            <div class="fs-4 bld-balance {{ $balanceClass }}">
                {{ $balance < 0 ? '-' : '' }}{{ $tl($balance) }}
            </div>
            <div class="small text-muted">
                @if ($balance > 0)
                    @lang('veykemtu.bridgeapi::accountledger.summary_balance_debt')
                @elseif ($balance < 0)
                    @lang('veykemtu.bridgeapi::accountledger.summary_balance_credit')
                @else
                    @lang('veykemtu.bridgeapi::accountledger.summary_balance_zero')
                @endif
            </div>
        </div>
    </div>

    <div class="col-md-4">
        <div class="border rounded p-3 h-100">
            <div class="text-muted small">@lang('veykemtu.bridgeapi::accountledger.summary_limit')</div>
            <div class="fs-4 bld-money">
                @if ($limit === null)
                    <span class="text-muted fs-6">@lang('veykemtu.bridgeapi::accountledger.limit_none')</span>
                @elseif ((int) $limit === 0)
                    <span class="text-muted fs-6">@lang('veykemtu.bridgeapi::accountledger.limit_closed')</span>
                @else
                    {{ $tl((int) $limit) }}
                @endif
            </div>
        </div>
    </div>

    <div class="col-md-4">
        <div class="border rounded p-3 h-100">
            <div class="text-muted small">@lang('veykemtu.bridgeapi::accountledger.summary_remaining')</div>
            <div class="fs-4 bld-money">
                @if ($remaining === null)
                    <span class="text-muted fs-6">@lang('veykemtu.bridgeapi::accountledger.limit_none')</span>
                @else
                    {{ $tl($remaining) }}
                @endif
            </div>
            @if ($remaining !== null && $remaining === 0)
                <div class="small text-danger">
                    @lang('veykemtu.bridgeapi::accountledger.summary_remaining_blocked')
                </div>
            @endif
        </div>
    </div>
</div>

<dl class="row mb-0 small">
    <dt class="col-sm-3">@lang('veykemtu.bridgeapi::accountledger.column_org')</dt>
    <dd class="col-sm-9">{{ $formModel->bld_org_name ?: '—' }}</dd>

    <dt class="col-sm-3">@lang('veykemtu.bridgeapi::accountledger.column_contact')</dt>
    <dd class="col-sm-9">{{ $formModel->bld_contact_person ?: '—' }}</dd>

    <dt class="col-sm-3">@lang('veykemtu.bridgeapi::accountledger.column_telephone')</dt>
    <dd class="col-sm-9">{{ $formModel->telephone ?: '—' }}</dd>

    <dt class="col-sm-3">@lang('veykemtu.bridgeapi::accountledger.column_email')</dt>
    <dd class="col-sm-9">{{ $formModel->email ?: '—' }}</dd>
</dl>
