{{--
    Ziyaretçinin gönderdiği talebin künyesi — SALT OKUNUR.

    Form alanı değil, tek bir `partial`: gerekçe `resources/models/quoterequest.php`
    başındadır. Boş gelen satır HİÇ ÇİZİLMİYOR; "Sıklık: —" gibi on tane boş
    satır, dolu olan üç satırı görünmez kılardı.

    Telefon ve e-posta tıklanabilir: bu ekranın varlık sebebi firmanın talebe
    dönmesi ve numarayı elle kopyalamak o yolun en yavaş adımı.
--}}
@php
    $digits = preg_replace('/\D/', '', (string) $model->telephone);
    /*
     * Site numarayı başında sıfır olmadan 10 hane gönderiyor; `tel:` bağlantısı
     * ülke kodu olmadan yalnızca yurt içinden çalışır. Tam 10 haneli değerlere
     * +90 ekleniyor, diğerleri (dahili no, uluslararası numara) olduğu gibi
     * bırakılıyor — tahmin edip yanlış ülkeye çevirmektense ham hâli doğru.
     */
    $telHref = $digits === '' ? null : (strlen($digits) === 10 ? '+90'.$digits : $digits);

    $lines = [
        'organization' => $model->organization,
        'service_type' => $model->service_type,
        'headcount' => $model->headcount,
        'frequency' => $model->frequency,
        'start_date' => $model->start_date?->format('d.m.Y'),
        'location' => $model->location,
        'menu_preference' => $model->menu_preference,
        'kitchen_note' => $model->kitchen_note,
        'message' => $model->message,
    ];
@endphp

<div class="p-3">
    <h5 class="mb-3">{{ $model->full_name }}</h5>

    <div class="mb-3">
        @if($telHref)
            <a class="btn btn-sm btn-outline-primary me-2" href="tel:{{ $telHref }}">
                <i class="fa fa-phone"></i> {{ $model->telephone }}
            </a>
        @endif
        @if($model->email)
            <a class="btn btn-sm btn-outline-primary" href="mailto:{{ $model->email }}">
                <i class="fa fa-envelope"></i> {{ $model->email }}
            </a>
        @endif
    </div>

    <dl class="row mb-0">
        @foreach($lines as $key => $value)
            @if(filled($value))
                <dt class="col-sm-3 text-muted fw-normal">
                    {{ lang('veykemtu.bridgeapi::quoterequest.label_'.$key) }}
                </dt>
                <dd class="col-sm-9" style="white-space: pre-line">{{ $value }}</dd>
            @endif
        @endforeach

        <dt class="col-sm-3 text-muted fw-normal">
            {{ lang('veykemtu.bridgeapi::quoterequest.label_submitted_at') }}
        </dt>
        <dd class="col-sm-9">
            {{ ($model->submitted_at ?? $model->created_at)?->format('d.m.Y H:i') }}
        </dd>

        {{--
            KVKK onayı ekranda GÖRÜNÜR. Onaysız kayıt zaten oluşmuyor, ama
            "ne zaman onayladı" sorusunun cevabı bir denetimde panelden
            okunabilmeli; veritabanına bakmak gerekseydi kayıt pratikte yok
            sayılırdı.
        --}}
        <dt class="col-sm-3 text-muted fw-normal">
            {{ lang('veykemtu.bridgeapi::quoterequest.label_kvkk') }}
        </dt>
        <dd class="col-sm-9">
            <i class="fa fa-check text-success"></i>
            {{ $model->kvkk_accepted_at?->format('d.m.Y H:i') }}
        </dd>
    </dl>
</div>
