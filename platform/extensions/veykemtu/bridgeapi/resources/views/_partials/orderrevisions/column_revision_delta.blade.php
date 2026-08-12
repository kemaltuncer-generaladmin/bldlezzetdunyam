{{--
    Satır farkı: kaç kalem eklendi/çıkarıldı.

    `before_json`/`after_json` tam anlık görüntü tutuyor. Burada yalnızca
    KALEM SAYISI karşılaştırılıyor — tam diff'i göstermek liste sütununa
    sığmaz ve zaten sipariş sayfasında duruyor. Amaç "burada ne oldu"
    sorusuna tek bakışta bir yön vermek.
--}}
@php
    $onceKalem = is_array($record->before_json) ? count($record->before_json['items'] ?? []) : 0;
    $sonraKalem = is_array($record->after_json) ? count($record->after_json['items'] ?? []) : 0;
    $fark = $sonraKalem - $onceKalem;
@endphp
<span class="text-muted">{{ $onceKalem }} → {{ $sonraKalem }}</span>
@if ($fark !== 0)
    <span class="badge {{ $fark > 0 ? 'bg-info' : 'bg-secondary' }}">
        {{ $fark > 0 ? '+' : '' }}{{ $fark }}
    </span>
@endif
