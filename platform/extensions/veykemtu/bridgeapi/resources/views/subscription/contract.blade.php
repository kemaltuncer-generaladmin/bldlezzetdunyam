<!doctype html>
{{-- Abonenin SMS'teki bağlantıyla açtığı sözleşme sayfası (iş kararı 9). --}}
{{-- TEK EKRAN, TEK AKIŞ: oku → kod iste → onayla. Sayfayı açan kişi çoğu --}}
{{-- zaman uygulamayı hiç kurmamış satın alma yetkilisi; ikinci bir adım --}}
{{-- ya da giriş ekranı onayı kaybettirir. --}}
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
{{-- Sözleşme metni müşteriye özel; arama motorunda yeri yok. --}}
<meta name="robots" content="noindex, nofollow">
<title>Abonelik sözleşmesi — Benim Lezzet Dünyam</title>
<style>
  :root { --turuncu:#c2410c; --nötr:#57534e; --zemin:#fafaf9; --kart:#fff; --kenar:#e7e5e4; }
  * { box-sizing: border-box; }
  body { margin:0; font:16px/1.6 system-ui,-apple-system,"Segoe UI",sans-serif;
         background:var(--zemin); color:#1c1917; display:flex; justify-content:center;
         padding:24px 16px 48px; }
  .kutu { width:100%; max-width:620px; }
  .kart { background:var(--kart); border:1px solid var(--kenar); border-radius:16px;
          padding:24px; margin-bottom:16px; }
  h1 { margin:0 0 4px; font-size:26px; letter-spacing:-.01em; }
  .alt { color:var(--nötr); font-size:14px; margin:0 0 20px; }
  .metin h2 { font-size:22px; margin:0 0 12px; }
  .metin h3 { font-size:17px; margin:22px 0 6px; }
  .metin p { margin:0 0 12px; }
  .metin table { width:100%; border-collapse:collapse; margin:12px 0 4px; }
  .metin th { text-align:left; font-weight:600; color:var(--nötr); padding:7px 0;
              border-bottom:1px solid var(--kenar); width:45%; }
  .metin td { text-align:right; padding:7px 0; border-bottom:1px solid var(--kenar); }
  .ozet { display:flex; justify-content:space-between; align-items:baseline;
          padding:16px; background:#fff7ed; border:1px solid #fdba74;
          border-radius:12px; margin:0 0 20px; }
  .ozet b { font-size:26px; color:var(--turuncu); }
  label { display:block; font-size:14px; color:var(--nötr); margin:0 0 6px; }
  input { width:100%; padding:16px; font-size:22px; letter-spacing:.35em;
          text-align:center; border:1px solid var(--kenar); border-radius:12px;
          font-family:inherit; }
  button { width:100%; padding:18px; font-size:18px; font-weight:700; margin-top:14px;
           color:#fff; background:var(--turuncu); border:0; border-radius:14px;
           cursor:pointer; }
  button:hover:enabled { background:#9a3412; }
  button:disabled { background:#d6d3d1; cursor:default; }
  .ikincil { background:#fff; color:var(--turuncu); border:1px solid var(--turuncu); }
  .ikincil:hover:enabled { background:#fff7ed; }
  .uyari { margin:14px 0 0; padding:12px 14px; border-radius:10px; font-size:15px;
           background:#fef2f2; color:#991b1b; }
  .bilgi { margin:14px 0 0; padding:12px 14px; border-radius:10px; font-size:15px;
           background:#f0fdf4; color:#166534; }
  .gizli { display:none; }
  .durum { text-align:center; padding:12px 0 4px; }
  .durum .isaret { font-size:44px; line-height:1; display:block; margin-bottom:10px; }
  .durum h1 { font-size:22px; margin-bottom:8px; }
  .durum p { margin:0; color:var(--nötr); }
</style>
</head>
<body>
<div class="kutu">

@if ($state === 'invalid')
  <div class="kart durum">
    <span class="isaret">⚠️</span>
    <h1>Bağlantı geçersiz</h1>
    <p>Bu sözleşme bağlantısı okunamadı. SMS'teki adresi eksiksiz açtığınızdan
       emin olun ya da yeni bağlantı isteyin.</p>
  </div>

@elseif ($state === 'expired')
  <div class="kart durum">
    <span class="isaret">⏳</span>
    <h1>Bağlantının süresi doldu</h1>
    <p>Sözleşme bağlantıları güvenlik gereği sınırlı süre yaşar.
       Bizimle iletişime geçip yeni bir bağlantı isteyebilirsiniz.</p>
  </div>

@elseif ($state === 'cancelled')
  <div class="kart durum">
    <span class="isaret">🚫</span>
    <h1>Sözleşme iptal edilmiş</h1>
    <p>Koşullar değişmiş olabilir. Yeni sözleşme için bizimle iletişime geçin.</p>
  </div>

@else
  <div class="kart">
    <p class="alt">{{ $contract['customer_label'] ?: 'Abonelik' }}</p>
    <h1>{{ $contract['title'] ?: 'Abonelik Sözleşmesi' }}</h1>

    <div class="ozet">
      <span>Porsiyon fiyatı</span>
      <b>{{ number_format($contract['unit_price'] / 100, 2, ',', '.') }} TL</b>
    </div>

    {{-- METİN HAM BASILIR VE BU GÜVENLİDİR: `body_html`, `ContractService` --}}
    {{-- tarafından üretiliyor ve içindeki her dinamik değer `e()` ile --}}
    {{-- kaçırılmış durumda. Panelden yapıştırılan serbest HTML buraya --}}
    {{-- girmiyor; girseydi kaçırmak değil `HtmlSanitizer` gerekirdi. --}}
    <div class="metin">{!! $bodyHtml !!}</div>
  </div>
@endif

@if ($state === 'approved')
  <div class="kart durum">
    <span class="isaret">✅</span>
    <h1>Sözleşme onaylandı</h1>
    <p>
      @if ($approvedName)
        {{ $approvedName }} tarafından onaylandı.
      @endif
      Ödeme adımı için sizinle iletişime geçeceğiz.
    </p>
  </div>

@elseif ($state === 'sign')
  <div class="kart" id="onay">
    <h2 style="margin:0 0 4px; font-size:19px;">Onay</h2>
    <p class="alt">
      Onaylamak için <strong>{{ $contract['masked_phone'] }}</strong> numarasına
      göndereceğimiz 6 haneli kodu girin.
    </p>

    <button type="button" id="kodIste">Onay kodu gönder</button>

    <div id="kodAlani" class="gizli" style="margin-top:18px">
      <label for="kod">SMS ile gelen kod</label>
      <input id="kod" inputmode="numeric" autocomplete="one-time-code"
             maxlength="6" pattern="[0-9]{6}" placeholder="000000">
      <label for="ad" style="margin-top:14px">Ad soyad (isteğe bağlı)</label>
      <input id="ad" type="text" maxlength="120" style="font-size:16px;
             letter-spacing:normal; text-align:left" placeholder="Onaylayan kişi">
      <button type="button" id="onayla">Sözleşmeyi onayla</button>
      <button type="button" id="tekrar" class="ikincil">Kodu tekrar gönder</button>
    </div>

    <p id="hata" class="uyari gizli"></p>
    <p id="bilgi" class="bilgi gizli"></p>
  </div>

  <script>
  (function () {
    // YAZMA ADIMLARI DONMUŞ SÖZLEŞMEDEKİ UÇLARA GİDER (docs/openapi.yaml).
    // Sayfanın kendi POST rotası yok; olsaydı oran sınırı ve OTP deneme
    // sayacı ikiye bölünürdü.
    // ADRES GÖRELİ: sayfa hangi alan adından açıldıysa API çağrısı da oraya
    // gider. Mutlak adres yazsaydık, ters vekilin gördüğü iç sunucu adı
    // tarayıcıya sızabilir ve istek hiç ulaşmazdı.
    var taban = '/api/contracts/' + @json($token);
    var basliklar = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-App-Id': 'website',
      'X-App-Version': '1.0.0'
    };

    var kodIste = document.getElementById('kodIste');
    var tekrar = document.getElementById('tekrar');
    var onayla = document.getElementById('onayla');
    var kodAlani = document.getElementById('kodAlani');
    var kod = document.getElementById('kod');
    var ad = document.getElementById('ad');
    var hata = document.getElementById('hata');
    var bilgi = document.getElementById('bilgi');

    function goster(kutu, metin) {
      kutu.textContent = metin;
      kutu.classList.remove('gizli');
    }

    function temizle() {
      hata.classList.add('gizli');
      bilgi.classList.add('gizli');
    }

    function mesaj(veri, yedek) {
      if (veri && veri.error && veri.error.message) { return veri.error.message; }
      if (veri && veri.message) { return veri.message; }
      return yedek;
    }

    function istek(yol, govde, dugme, tamam) {
      temizle();
      dugme.disabled = true;
      fetch(taban + yol, {
        method: 'POST',
        headers: basliklar,
        body: JSON.stringify(govde)
      }).then(function (yanit) {
        return yanit.json().catch(function () { return {}; }).then(function (veri) {
          return { ok: yanit.ok, veri: veri };
        });
      }).then(function (sonuc) {
        dugme.disabled = false;
        if (sonuc.ok) { tamam(sonuc.veri); return; }
        goster(hata, mesaj(sonuc.veri, 'İşlem tamamlanamadı, tekrar deneyin.'));
      }).catch(function () {
        dugme.disabled = false;
        goster(hata, 'Bağlantı kurulamadı. İnternetinizi kontrol edip tekrar deneyin.');
      });
    }

    function kodGonder(dugme) {
      istek('/otp', {}, dugme, function (veri) {
        kodAlani.classList.remove('gizli');
        kodIste.classList.add('gizli');
        goster(bilgi, mesaj(veri, 'Kod gönderildi.'));
        kod.focus();
      });
    }

    kodIste.addEventListener('click', function () { kodGonder(kodIste); });
    tekrar.addEventListener('click', function () { kodGonder(tekrar); });

    onayla.addEventListener('click', function () {
      var deger = (kod.value || '').replace(/\D+/g, '');
      if (deger.length !== 6) {
        goster(hata, 'Kod 6 haneli olmalı.');
        return;
      }

      var govde = { code: deger };
      if ((ad.value || '').trim() !== '') { govde.full_name = ad.value.trim(); }

      istek('/approve', govde, onayla, function () {
        // Sayfa yeniden çiziliyor: onaylanmış hâli sunucudan gelsin ki
        // ekrandaki durum ile kayıttaki durum ayrışmasın.
        window.location.reload();
      });
    });
  })();
  </script>
@endif

</div>
</body>
</html>
