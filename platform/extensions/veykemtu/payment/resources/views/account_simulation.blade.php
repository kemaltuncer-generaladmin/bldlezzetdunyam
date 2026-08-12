<!doctype html>
{{-- Cari borç ödeme simülasyonu (B-14 / W-12). --}}
{{-- `simulation.blade.php` ile aynı görsel dil, farklı nesne: burada ödenen --}}
{{-- bir sipariş değil, birikmiş cari bakiyedir. --}}
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>Cari hesap ödemesi — Benim Lezzet Dünyam</title>
<style>
  :root { --turuncu:#c2410c; --nötr:#57534e; --zemin:#fafaf9; --kart:#fff; --kenar:#e7e5e4; }
  * { box-sizing: border-box; }
  body { margin:0; font:16px/1.5 system-ui,-apple-system,"Segoe UI",sans-serif;
         background:var(--zemin); color:#1c1917; display:flex; justify-content:center;
         padding:24px 16px; }
  .kutu { width:100%; max-width:440px; }
  .uyari { background:#fef3c7; border:1px solid #f59e0b; border-radius:12px;
           padding:12px 16px; margin-bottom:16px; font-size:14px; color:#78350f; }
  .kart { background:var(--kart); border:1px solid var(--kenar); border-radius:16px;
          padding:24px; }
  h1 { margin:0 0 4px; font-size:20px; }
  .alt { color:var(--nötr); font-size:14px; margin:0 0 20px; }
  .tutar { display:flex; justify-content:space-between; align-items:baseline;
           padding:14px 16px; background:var(--zemin); border-radius:12px; margin-bottom:8px; }
  .tutar b { font-size:24px; }
  .kalan { display:flex; justify-content:space-between; font-size:14px;
           color:var(--nötr); padding:0 16px; margin-bottom:20px; }
  label { display:block; font-size:14px; font-weight:600; margin:14px 0 6px; }
  input { width:100%; padding:12px 14px; font-size:16px; border:1px solid var(--kenar);
          border-radius:10px; font-family:inherit; }
  input:focus { outline:3px solid #fdba74; outline-offset:1px; border-color:var(--turuncu); }
  .satir { display:flex; gap:12px; }
  .satir > div { flex:1; }
  button { width:100%; margin-top:22px; padding:14px; font-size:16px; font-weight:600;
           color:#fff; background:var(--turuncu); border:0; border-radius:12px; cursor:pointer; }
  button:hover { background:#9a3412; }
  .hata { background:#fee2e2; border:1px solid #dc2626; color:#7f1d1d; padding:10px 14px;
          border-radius:10px; font-size:14px; margin-bottom:14px; }
  .ipucu { margin-top:16px; font-size:13px; color:var(--nötr); }
  .ipucu code { background:var(--zemin); padding:2px 6px; border-radius:6px; }
</style>
</head>
<body>
<div class="kutu">

  <div class="uyari">
    <strong>Bu bir simülasyondur.</strong> Gerçek tahsilat yapılmaz, kart bilgisi
    hiçbir yere kaydedilmez. Ödeme onaylandığında cari hesabınıza alacak olarak
    işlenir.
  </div>

  <div class="kart">
    <h1>Cari hesap ödemesi</h1>
    <p class="alt">İşlem no: {{ $intent->id }}</p>

    <div class="tutar">
      <span>Ödenecek tutar</span>
      <b>{{ $total }} ₺</b>
    </div>

    {{-- Ödeme başlatıldığı ANDAKİ borç gösteriliyor, güncel borç değil.
         Aradan bir sipariş geçmişse müşteri "eksik ödedim" diye şaşırmasın
         diye kaynak açıkça yazılıyor. --}}
    <div class="kalan">
      <span>İşlem başlatıldığında borç</span>
      <span>{{ number_format($intent->balance_at_start / 100, 2, ',', '.') }} ₺</span>
    </div>

    @if ($alreadySettled)
      <div class="hata">Bu ödeme zaten tamamlanmış. Tekrar tahsilat yapılmaz.</div>
      <a href="{{ $returnUrl }}"><button type="button">Cari hesabıma dön</button></a>
    @else

      @if ($errors->any())
        <div class="hata">{{ $errors->first() }}</div>
      @endif

      <form method="post" action="{{ url('/cari-odeme-simulasyon/'.$hash) }}?return={{ urlencode($returnUrl) }}">
        @csrf

        <label for="kart_no">Kart numarası</label>
        <input id="kart_no" name="kart_no" inputmode="numeric" autocomplete="off"
               placeholder="4111 1111 1111 1111" value="4111 1111 1111 1111" required>

        <label for="ad_soyad">Kart üzerindeki ad</label>
        <input id="ad_soyad" name="ad_soyad" autocomplete="off"
               placeholder="AD SOYAD" value="TEST KULLANICI" required>

        <div class="satir">
          <div>
            <label for="son_kullanma">Son kullanma</label>
            <input id="son_kullanma" name="son_kullanma" inputmode="numeric"
                   placeholder="12/30" value="12/30" required>
          </div>
          <div>
            <label for="cvv">CVV</label>
            <input id="cvv" name="cvv" inputmode="numeric" autocomplete="off"
                   placeholder="123" value="123" required>
          </div>
        </div>

        <button type="submit">Ödemeyi tamamla</button>
      </form>

      <p class="ipucu">
        Alanlar test değeriyle dolu geliyor. <strong>Her kart onaylanır</strong> —
        biçim doğru olduğu sürece hangi numarayı girdiğiniz fark etmez.
        Biçim hatasını denemek için <code>cvv</code> alanına harf yazın.
      </p>
    @endif
  </div>
</div>
</body>
</html>
