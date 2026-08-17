<!doctype html>
{{-- Sanal POS'un aboneyi geri bıraktığı sayfa: sonuç ve iptal. --}}
{{-- TEK EKRAN, DÜĞMESİZ: burada yapılacak bir iş yok. Sayfanın tamamı --}}
{{-- okumadır; para hareketini sağlayıcının geri-araması kesinleştirir. --}}
{{-- Bir düğme koysaydık, dönüş adresini yenileyen her abone ikinci bir --}}
{{-- tahsilat denemesi başlatabileceğini sanırdı. --}}
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
{{-- Ödeme sonucu müşteriye özel; arama motorunda yeri yok. --}}
<meta name="robots" content="noindex, nofollow">
<title>Abonelik ödemesi — Benim Lezzet Dünyam</title>
<style>
  :root { --turuncu:#c2410c; --nötr:#57534e; --zemin:#fafaf9; --kart:#fff; --kenar:#e7e5e4; }
  * { box-sizing: border-box; }
  body { margin:0; font:16px/1.6 system-ui,-apple-system,"Segoe UI",sans-serif;
         background:var(--zemin); color:#1c1917; display:flex; justify-content:center;
         padding:24px 16px 48px; }
  .kutu { width:100%; max-width:460px; }
  .kart { background:var(--kart); border:1px solid var(--kenar); border-radius:16px;
          padding:24px; margin-bottom:16px; }
  .durum { text-align:center; }
  .durum .isaret { font-size:44px; line-height:1; display:block; margin-bottom:10px; }
  h1 { margin:0 0 8px; font-size:23px; letter-spacing:-.01em; }
  .durum p { margin:0; color:var(--nötr); }
  .baslik { font-size:14px; color:var(--nötr); margin:0 0 12px; font-weight:600;
            letter-spacing:.02em; text-transform:uppercase; }
  table { width:100%; border-collapse:collapse; }
  th { text-align:left; font-weight:400; color:var(--nötr); padding:9px 0;
       border-bottom:1px solid var(--kenar); }
  td { text-align:right; padding:9px 0; border-bottom:1px solid var(--kenar);
       font-weight:600; }
  tr:last-child th, tr:last-child td { border-bottom:0; }
  .tutar { display:flex; justify-content:space-between; align-items:baseline;
           padding:16px; background:#fff7ed; border:1px solid #fdba74;
           border-radius:12px; margin:0 0 18px; }
  .tutar b { font-size:26px; color:var(--turuncu); }
  .yapilacak { margin:16px 0 0; padding:13px 15px; border-radius:10px; font-size:15px;
               background:var(--zemin); color:var(--nötr); }
  .yenile { display:block; text-align:center; margin:16px 0 0; padding:15px;
            border:1px solid var(--turuncu); border-radius:12px; color:var(--turuncu);
            text-decoration:none; font-weight:600; }
</style>
</head>
<body>
<div class="kutu">

{{-- BİLİNMEYEN HASH: ödeme hakkında TEK KELİME yok. Dönem ya da tutar --}}
{{-- sızdırsaydı, adres tahmin ederek abonelik taramanın önü açılırdı. --}}
@if ($state === 'unknown')
  <div class="kart durum">
    <span class="isaret">⚠️</span>
    <h1>Ödeme kaydı bulunamadı</h1>
    <p>Bu bağlantı okunamadı ya da artık geçerli değil. Ödemenizi
       uygulamadan veya siteden tekrar başlatabilirsiniz.</p>
  </div>

@else
  <div class="kart durum">
    @if ($state === 'succeeded')
      <span class="isaret">✅</span>
      <h1>Ödemeniz alındı</h1>
      <p>Dönem bedeliniz tahsil edildi. Aboneliğiniz bu dönem boyunca
         aralıksız devam eder.</p>

    @elseif ($state === 'pending')
      {{-- HATA EKRANI DEĞİL. Sağlayıcı kullanıcıyı geri bırakmış olsa da --}}
      {{-- sonucu ayrı bir kanaldan bildiriyor ve o bildirim gecikebilir. --}}
      {{-- "Başarısız" demek, saniyeler sonra kesinleşecek bir ödemeyi --}}
      {{-- abonenin ikinci kez yapmasına yol açardı. --}}
      <span class="isaret">⏳</span>
      <h1>Ödemeniz sonuçlanmadı</h1>
      <p>Bankanızdan sonuç henüz ulaşmadı. Kart bilgileriniz bizde tutulmaz;
         yapmanız gereken bir şey yok.</p>

    @elseif ($state === 'failed')
      <span class="isaret">⨯</span>
      <h1>Ödeme tamamlanamadı</h1>
      <p>Bankanız işlemi onaylamadı. Kartınızdan para çekilmedi.</p>

    @elseif ($state === 'refunded')
      <span class="isaret">↩</span>
      <h1>Bu dönem iade edildi</h1>
      <p>Ödediğiniz tutar iade edildi; bu dönem artık aboneliğinize dâhil
         değil.</p>

    @else
      {{-- `cancelled` — vazgeçme. Kırmızı bir hata ekranı GÖSTERİLMEZ: --}}
      {{-- kullanıcı bilerek geri döndü, ortada arıza yok. --}}
      <span class="isaret">↩</span>
      <h1>Ödemeden vazgeçtiniz</h1>
      <p>Herhangi bir tahsilat yapılmadı. Bu dönemin ödemesi açık kaldı,
         dilediğiniz zaman kaldığınız yerden devam edebilirsiniz.</p>
    @endif
  </div>

  <div class="kart">
    <p class="baslik">Dönem özeti</p>

    <div class="tutar">
      <span>Dönem bedeli</span>
      <b>{{ $amount }} ₺</b>
    </div>

    <table>
      <tr>
        <th>Dönem</th>
        <td>{{ $period }}</td>
      </tr>
      <tr>
        {{-- ÇARPANLAR EKRANDA: "neden bu tutar" sorusu sayfayı --}}
        {{-- kapatmadan cevaplanabilmeli (devralınan yapı §1). --}}
        <th>Porsiyon</th>
        <td>{{ $portions }} × {{ $unitPrice }} ₺</td>
      </tr>
      <tr>
        <th>Abonelik durumu</th>
        <td>
          @php
            $etiket = match ($subscriptionState) {
                'active' => 'Aktif',
                'paused' => 'Duraklatıldı',
                'cancelled' => 'İptal edildi',
                'pending' => 'Ödeme bekliyor',
                default => 'Bilinmiyor',
            };
          @endphp
          {{ $etiket }}
        </td>
      </tr>
    </table>

    {{-- NE YAPILACAĞI HER HÂLDE YAZILI: sayfayı açan kişi uygulamayı hiç --}}
    {{-- kurmamış olabilir (ödeme SMS'teki sözleşme bağlantısından da --}}
    {{-- başlayabiliyor), yani "uygulamaya dön" tek başına yol göstermez. --}}
    @if ($state === 'succeeded')
      <p class="yapilacak">Bu sayfayı kapatabilirsiniz. Teslimatlarınız
         planlandığı gibi sürecek.</p>

    @elseif ($state === 'pending')
      <p class="yapilacak">Sonuç birkaç dakika içinde netleşir. Bu sayfayı
         yenileyerek durumu görebilirsiniz; tekrar ödeme başlatmanıza gerek
         yok.</p>
      <a class="yenile" href="{{ $refreshUrl }}">Durumu yenile</a>

    @elseif ($state === 'failed')
      <p class="yapilacak">Uygulamadan ya da siteden yeni bir ödeme
         başlatabilirsiniz. Sorun sürerse bizimle iletişime geçin.</p>

    @elseif ($state === 'refunded')
      <p class="yapilacak">Aboneliğinizi sürdürmek isterseniz uygulamadan
         veya siteden yeni bir ödeme başlatabilirsiniz.</p>

    @else
      <p class="yapilacak">Ödemeyi uygulamadan ya da siteden kaldığınız
         yerden tekrar başlatabilirsiniz; bu dönem için ikinci bir ücret
         çıkmaz.</p>
    @endif
  </div>
@endif

</div>
</body>
</html>
