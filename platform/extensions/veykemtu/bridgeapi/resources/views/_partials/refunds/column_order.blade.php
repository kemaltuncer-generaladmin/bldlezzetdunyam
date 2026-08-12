{{-- Sipariş numarası, siparişin kendisine bağlantılı. İade satırına bakan
     kişinin ilk sorusu "hangi sipariş, ne olmuştu" — numarayı kopyalayıp
     arama kutusuna yapıştırmak zorunda kalmasın. --}}
<a href="{{ admin_url('orders/edit/'.$record->order_id) }}">
    S-{{ $record->order_id }}
</a>
@if ($record->revision_id)
    <span class="text-muted small d-block">
        @lang('veykemtu.bridgeapi::refund.revision') #{{ $record->revision_id }}
    </span>
@endif
