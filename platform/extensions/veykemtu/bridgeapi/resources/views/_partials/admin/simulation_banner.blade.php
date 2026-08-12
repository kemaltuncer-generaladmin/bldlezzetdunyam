{{--
    Sanal POS simülasyon şeridi — B-12.

    Simülasyon modunda kartla ödenen sipariş gerçekten tahsil EDİLMİYOR;
    sipariş "ödendi" görünür ama kasaya para girmez (docs/11 §10). Bu, bilerek
    verilmiş bir karardır — gerçek POS sözleşmesi yapılana kadar sürecek.

    Şerit her admin ekranının tepesinde duruyor çünkü tehlike unutulmakta:
    bir ayar sayfasının içine yazılsaydı, aylar sonra paneli devralan kişi
    kart ödemelerinin gerçek olduğunu varsayardı.

    Yalnızca simülasyon açıkken çizilir (`SimulatedPos::isAllowed()`),
    yani gerçek POS bağlandığı gün kendiliğinden kaybolur.
--}}
<div class="bld-sim-banner" role="status">
    <i class="fa fa-triangle-exclamation fa-fw" aria-hidden="true"></i>
    <span>@lang('veykemtu.bridgeapi::default.simulation.banner_title')</span>
    <span class="bld-sim-banner__detail">@lang('veykemtu.bridgeapi::default.simulation.banner_detail')</span>
</div>
