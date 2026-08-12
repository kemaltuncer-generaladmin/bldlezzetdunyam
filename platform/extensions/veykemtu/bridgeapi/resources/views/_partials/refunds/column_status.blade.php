{{--
    İade durumu.

    Renkler önem sırasına göre, "iyi/kötü" ekseninde değil:
      manual  → kehribar, çünkü BİR İŞ BEKLİYOR (asıl mesele bu)
      failed  → kırmızı, sağlayıcı reddetti; müdahale şart
      pending → gri, sağlayıcıda; yapacak bir şey yok
      succeeded → yeşil, kapandı
--}}
@php
    $renk = match ($record->status) {
        \Veykemtu\BridgeApi\Models\PaymentRefund::STATUS_MANUAL => 'bg-warning text-dark',
        \Veykemtu\BridgeApi\Models\PaymentRefund::STATUS_FAILED => 'bg-danger',
        \Veykemtu\BridgeApi\Models\PaymentRefund::STATUS_SUCCEEDED => 'bg-success',
        default => 'bg-secondary',
    };
    $etiket = \Veykemtu\BridgeApi\Models\PaymentRefund::statusOptions()[$record->status] ?? $record->status;
@endphp
<span class="badge {{ $renk }}">{{ $etiket }}</span>
@if ($record->error)
    <span class="d-block small text-danger">{{ \Illuminate\Support\Str::limit($record->error, 80) }}</span>
@endif
