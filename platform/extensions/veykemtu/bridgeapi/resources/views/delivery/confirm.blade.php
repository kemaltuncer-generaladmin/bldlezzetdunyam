<!doctype html>
{{-- Kuryenin fişteki QR'ı okutunca gördüğü onay sayfası (K-20). --}}
{{-- TEK DÜĞME, KAYDIRMASIZ: kurye dışarıda, tek eli dolu, telefonu --}}
{{-- güneşin altında. İkinci bir seçenek her defasında bir duraksama. --}}
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>Teslim onayı — Benim Lezzet Dünyam</title>
<style>
  :root { --turuncu:#c2410c; --nötr:#57534e; --zemin:#fafaf9; --kart:#fff; --kenar:#e7e5e4; }
  * { box-sizing: border-box; }
  body { margin:0; font:16px/1.5 system-ui,-apple-system,"Segoe UI",sans-serif;
         background:var(--zemin); color:#1c1917; display:flex; justify-content:center;
         padding:24px 16px; }
  .kutu { width:100%; max-width:440px; }
  .kart { background:var(--kart); border:1px solid var(--kenar); border-radius:16px;
          padding:24px; }
  h1 { margin:0 0 4px; font-size:28px; letter-spacing:-.01em; }
  .alt { color:var(--nötr); font-size:14px; margin:0 0 20px; }
  .ad { font-size:20px; font-weight:600; margin:0 0 2px; }
  .adres { color:var(--nötr); font-size:15px; margin:0 0 20px; }
  .tahsil { display:flex; justify-content:space-between; align-items:baseline;
            padding:16px; background:#fff7ed; border:1px solid #fdba74;
            border-radius:12px; margin-bottom:22px; }
  .tahsil b { font-size:28px; color:var(--turuncu); }
  .yok { padding:14px 16px; background:var(--zemin); border-radius:12px;
         margin-bottom:22px; color:var(--nötr); font-size:15px; }
  button { width:100%; padding:20px; font-size:19px; font-weight:700;
           color:#fff; background:var(--turuncu); border:0; border-radius:14px;
           cursor:pointer; }
  button:hover { background:#9a3412; }
  .durum { text-align:center; padding:12px 0 4px; }
  .durum .isaret { font-size:44px; line-height:1; display:block; margin-bottom:10px; }
  .durum p { margin:0; color:var(--nötr); }
  .durum h1 { font-size:22px; margin-bottom:8px; }
</style>
</head>
<body>
<div class="kutu">
  <div class="kart">
    @if ($state === 'confirm')
      <p class="alt">Sipariş</p>
      <h1>{{ $orderNumber }}</h1>

      @if ($customerName !== null)
        <p class="ad" style="margin-top:16px">{{ $customerName }}</p>
      @endif
      @if ($address !== null)
        <p class="adres">
          {{ $address['line1'] }}<br>
          {{ $address['district'] }} / {{ $address['city'] }}
        </p>
      @endif

      {{-- TAHSİLAT SATIRI DÜĞMENİN ÜSTÜNDE: para alınmadan basılan bir --}}
      {{-- "teslim ettim", kuryenin cebinden çıkan paradır. --}}
      @if ($collectKurus > 0)
        <div class="tahsil">
          <span>Tahsil edilecek</span>
          <b>{{ number_format($collectKurus / 100, 2, ',', '.') }} ₺</b>
        </div>
      @else
        <div class="yok">Bu sipariş ödenmiş — kapıda tahsilat yok.</div>
      @endif

      <form method="post">
        @csrf
        <input type="hidden" name="e" value="{{ $expires }}">
        <input type="hidden" name="s" value="{{ $signature }}">
        <button type="submit">TESLİM ETTİM</button>
      </form>

    @elseif ($state === 'done')
      <div class="durum">
        <span class="isaret">✓</span>
        <h1>Teslim alındı</h1>
        <p>{{ $orderNumber }} numaralı sipariş kapatıldı. Teşekkürler.</p>
      </div>

    @elseif ($state === 'already')
      {{-- HATA EKRANI DEĞİL. Çift dokunan ya da bağlantıyı ikinci kez --}}
      {{-- okutan kurye kırmızı bir ekran görmemeli: iş zaten olmuş. --}}
      <div class="durum">
        <span class="isaret">✓</span>
        <h1>Bu sipariş zaten teslim edildi</h1>
        <p>Yapmanız gereken bir şey yok.</p>
      </div>

    @elseif ($state === 'cancelled')
      <div class="durum">
        <span class="isaret">⨯</span>
        <h1>Bu sipariş iptal edilmiş</h1>
        <p>Teslim etmeyin, mutfakla görüşün.</p>
      </div>

    @elseif ($state === 'too_early')
      <div class="durum">
        <span class="isaret">⏳</span>
        <h1>Sipariş henüz hazır değil</h1>
        <p>Mutfak siparişi hazır işaretlemeden teslim onayı alınamaz.</p>
      </div>

    @elseif ($state === 'expired')
      <div class="durum">
        <span class="isaret">⏳</span>
        <h1>Bağlantının süresi doldu</h1>
        <p>Kasadan yeni bir fiş bastırın.</p>
      </div>

    @else
      {{-- BOZUK İMZA İLE BULUNAMAYAN SİPARİŞ AYNI EKRANI GÖRÜR: --}}
      {{-- ayrım, elinde imza olmayan birine sipariş numaralarını taratırdı. --}}
      <div class="durum">
        <span class="isaret">⨯</span>
        <h1>Bağlantı geçersiz</h1>
        <p>Fişteki kareyi tekrar okutun ya da mutfakla görüşün.</p>
      </div>
    @endif
  </div>
</div>
</body>
</html>
