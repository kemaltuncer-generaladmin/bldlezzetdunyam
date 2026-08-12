{{--
    Liste sütunu: cari borç limiti (B-14).

    Üç durum üç ayrı ifade — sayı göstermek yetmiyor, çünkü "0" ile "boş"
    tamamen zıt anlamlara geliyor:
      NULL → sınırsız (göç öncesinden gelen müşteriler)
      0    → cari hesap kapalı; `account` ödeme yöntemi hiç görünmez
      n    → tavan
--}}
@php
    $limit = $record->bld_credit_limit_kurus;
@endphp
@if ($limit === null)
    <span class="text-muted">@lang('veykemtu.bridgeapi::accountledger.limit_none')</span>
@elseif ((int) $limit === 0)
    <span class="badge bg-secondary">@lang('veykemtu.bridgeapi::accountledger.limit_closed')</span>
@else
    <span class="bld-money">{{ number_format((int) $limit / 100, 2, ',', '.') }} ₺</span>
@endif
