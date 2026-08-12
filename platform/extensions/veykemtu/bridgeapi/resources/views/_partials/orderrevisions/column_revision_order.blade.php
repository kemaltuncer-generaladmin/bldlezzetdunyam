{{-- Sipariş numarası + kaçıncı revizyon. Aynı siparişin iki kez
     düzenlenmesi sık; hangisine baktığı numarayla ayrılıyor. --}}
<a href="{{ admin_url('orders/edit/'.$record->order_id) }}">S-{{ $record->order_id }}</a>
<span class="text-muted small d-block">
    @lang('veykemtu.bridgeapi::monitor.revision_no', ['no' => (int) $record->revision_no])
</span>
