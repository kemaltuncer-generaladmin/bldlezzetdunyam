{{--
    Liste sütunu: takip durumu.

    Rozet, düz metin yerine kullanılıyor çünkü bu listenin tarama biçimi
    okumak değil, göz gezdirmektir: "yeni" olanlar renkleriyle ayrışmazsa
    yönetici otuz satırın her birini okumak zorunda kalır.
--}}
<span class="badge text-bg-{{ $record->statusCssClass() }}">
    {{ lang('veykemtu.bridgeapi::quoterequest.status_'.$record->status) }}
</span>
