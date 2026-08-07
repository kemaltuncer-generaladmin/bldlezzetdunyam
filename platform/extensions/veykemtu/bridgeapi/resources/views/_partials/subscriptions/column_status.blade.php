{{-- Liste sütunu: abonelik durumu rozeti. --}}
<span class="badge text-bg-{{ $record->statusCssClass() }}">
    {{ lang('veykemtu.bridgeapi::subscription.status_'.$record->status) }}
</span>
