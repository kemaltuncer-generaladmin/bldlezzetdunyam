{{--
    Form künyesi: müşterinin belirlediği takvim ve ürün satırları SALT-OKUNUR.
    Admin bunları değiştirmez; yalnız fiyat/durum/adet düzenler. Alt çizgili
    alan adı (`_details`) getSaveData'dan çıkar — kayda hiç girmez.
--}}
@php
    $dayNames = collect($model->service_days ?? [])
        ->map(fn($d) => lang('veykemtu.bridgeapi::subscription.day_'.(int) $d))
        ->implode(', ');
    $timeFrom = $model->delivery_time_from ? substr((string) $model->delivery_time_from, 0, 5) : '—';
@endphp
<div class="row g-3">
    <div class="col-md-6">
        <dl class="row mb-0">
            <dt class="col-5 text-muted">{{ lang('veykemtu.bridgeapi::subscription.column_customer') }}</dt>
            <dd class="col-7">{{ optional($model->customer)->email ?? '—' }}</dd>
            <dt class="col-5 text-muted">{{ lang('veykemtu.bridgeapi::subscription.detail_period') }}</dt>
            <dd class="col-7">
                {{ optional($model->start_date)->format('d.m.Y') ?? '—' }}
                – {{ optional($model->end_date)->format('d.m.Y') ?? lang('veykemtu.bridgeapi::subscription.detail_open_ended') }}
            </dd>
            <dt class="col-5 text-muted">{{ lang('veykemtu.bridgeapi::subscription.detail_days') }}</dt>
            <dd class="col-7">{{ $dayNames ?: '—' }}</dd>
            <dt class="col-5 text-muted">{{ lang('veykemtu.bridgeapi::subscription.detail_delivery') }}</dt>
            <dd class="col-7">{{ $model->delivery_type }} · {{ $timeFrom }}</dd>
        </dl>
    </div>
    <div class="col-md-6">
        <div class="text-muted mb-1">{{ lang('veykemtu.bridgeapi::subscription.detail_lines') }}</div>
        <ul class="list-unstyled mb-0">
            @forelse($model->lines as $line)
                @php($menuName = \Igniter\Cart\Models\Menu::where('menu_id', $line->menu_id)->value('menu_name'))
                <li>{{ (int) $line->quantity }} × {{ $menuName ?? ('#'.$line->menu_id) }}@if($line->label) <span class="text-muted">({{ $line->label }})</span>@endif</li>
            @empty
                <li class="text-muted">{{ lang('veykemtu.bridgeapi::subscription.detail_no_lines') }}</li>
            @endforelse
        </ul>
    </div>
</div>
