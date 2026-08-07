{{--
    Liste sütunu: cari bakiye.

    Kaydedilmez; her satırda defterden runtime hesaplanır. Borç (bize borçlu)
    kırmızı, alacak (fazla ödeme) yeşil, sıfır soluk — otuz satırda kimin
    borcu olduğu tek bakışta ayrışsın.
--}}
@php
    $bakiye = app(\Veykemtu\BridgeApi\Services\AccountLedger::class)->balance((int) $record->customer_id);
    $tl = number_format(abs($bakiye) / 100, 2, ',', '.');
    $renk = $bakiye > 0 ? 'text-danger' : ($bakiye < 0 ? 'text-success' : 'text-muted');
@endphp
<span class="{{ $renk }} fw-bold">{{ $bakiye < 0 ? '-' : '' }}{{ $tl }} ₺</span>
