@php
    /**
     * İÇERİK YALNIZ `snapshot_json`'DAN OKUNUR — canlı tablolara HİÇ
     * bakılmaz. Sipariş sonradan düzenlense, müşteri unvanı değişse,
     * ürün fiyatı artsa bile basılmış belge aynı kâğıdı üretmeli.
     * Canlı okuyan bir şablon, aynı belgeyi iki zamanda iki farklı
     * biçimde basar ve müşterinin elindeki kopya "yanlış" görünür.
     *
     * SINIF ADLARI TAM NİTELİKLİ, `use` YOK: Blade `@php` bloğunu
     * derlenmiş şablonun içine gömüyor ve oradaki bir `use` ifadesi
     * şablonun nereye derlendiğine bağlı olarak kırılgan. Bir belge
     * şablonunda üç sınıf adı için ödenecek bedel bu kadar.
     */
    /** @var \Veykemtu\BridgeApi\Models\Invoice $invoice */
    $snapshot = $invoice->snapshot();

    $issuer = is_array($snapshot['issuer'] ?? null) ? $snapshot['issuer'] : [];
    $customer = is_array($snapshot['customer'] ?? null) ? $snapshot['customer'] : [];
    $document = is_array($snapshot['document'] ?? null) ? $snapshot['document'] : [];
    $lines = is_array($snapshot['lines'] ?? null) ? $snapshot['lines'] : [];
    $totals = is_array($snapshot['totals'] ?? null) ? $snapshot['totals'] : [];
    $payment = is_array($snapshot['payment'] ?? null) ? $snapshot['payment'] : [];

    $isPeriod = ($document['kind'] ?? null) === \Veykemtu\BridgeApi\Models\Invoice::TYPE_SUBSCRIPTION;

    // Kuruş → TL yalnız GÖRÜNTÜLEME katmanında. Türkçe biçim: 1.234,56.
    $lira = static fn(mixed $kurus): string => number_format(((int) $kurus) / 100, 2, ',', '.');

    // Tarihler işletme duvar saatinde basılır; depolama UTC ama kâğıdın
    // üstündeki gün müşterinin gördüğü gündür.
    $gun = static function (mixed $value): string {
        if (!is_string($value) || trim($value) === '') {
            return '—';
        }

        return \Illuminate\Support\Carbon::parse($value)->format('d.m.Y');
    };

    $an = static function (mixed $value): string {
        if ($value === null) {
            return '—';
        }

        return \Veykemtu\BridgeApi\Support\BusinessTime::at(\Illuminate\Support\Carbon::parse($value))->format('d.m.Y H:i');
    };

    $odemeYontemi = [
        'cash' => 'Nakit',
        'online' => 'Online ödeme',
        'prepaid_monthly' => 'Aylık peşin ödeme',
    ][$payment['method'] ?? ''] ?? ($payment['method'] ?? '—');

    $odemeDurumu = ['paid' => 'Ödendi', 'pending' => 'Bekliyor'][$payment['status'] ?? ''] ?? '—';
@endphp
<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>{{ $invoice->invoice_no }}</title>
{{-- TEK DOSYA, DIŞ BAĞIMLILIK YOK: CSS gömülü, yazı tipi sistem yazı --}}
{{-- tipi, görsel yok. Panel bu sayfayı gizli bir iframe'de açıp --}}
{{-- `print()` çağırıyor; dışarıdan kaynak çeken bir sayfa, ağ yokken --}}
{{-- ya da yazıcı odasında boş basardı. --}}
<style>
  @page { size: A4; margin: 15mm; }

  :root {
    --murekkep: #1c1917;
    --nötr: #57534e;
    --kenar: #d6d3d1;
    --zebra: #f5f5f4;
    --uyari: #b91c1c;
  }

  * { box-sizing: border-box; }

  body {
    margin: 0;
    font: 12px/1.55 system-ui, -apple-system, "Segoe UI", "Noto Sans", sans-serif;
    color: var(--murekkep);
    background: #fff;
  }

  .sayfa { max-width: 180mm; margin: 0 auto; padding: 8mm 0; position: relative; }

  header { display: flex; justify-content: space-between; gap: 16mm; align-items: flex-start; }
  header h1 { margin: 0 0 2px; font-size: 17px; letter-spacing: -.01em; }
  header .satici p { margin: 0; color: var(--nötr); font-size: 11px; }

  .belge { text-align: right; white-space: nowrap; }
  .belge .no { font-size: 18px; font-weight: 700; letter-spacing: .02em; }
  .belge .tur { color: var(--nötr); font-size: 11px; text-transform: uppercase;
                letter-spacing: .08em; }
  .belge .tarih { color: var(--nötr); font-size: 11px; margin-top: 2px; }

  .ayrac { border: 0; border-top: 2px solid var(--murekkep); margin: 6mm 0 5mm; }

  .taraflar { display: flex; gap: 10mm; margin-bottom: 6mm; }
  .taraflar section { flex: 1; }
  .taraflar h2 { margin: 0 0 3px; font-size: 10px; text-transform: uppercase;
                 letter-spacing: .09em; color: var(--nötr); font-weight: 600; }
  .taraflar .ad { font-size: 13px; font-weight: 600; }
  .taraflar p { margin: 1px 0 0; font-size: 11px; color: var(--nötr); }

  table { width: 100%; border-collapse: collapse; }
  thead th {
    text-align: left; font-size: 10px; text-transform: uppercase;
    letter-spacing: .07em; color: var(--nötr); font-weight: 600;
    border-bottom: 1px solid var(--murekkep); padding: 0 4px 4px;
  }
  tbody td { padding: 5px 4px; border-bottom: 1px solid var(--kenar); vertical-align: top; }
  tbody tr:nth-child(even) td { background: var(--zebra); }
  .sag { text-align: right; white-space: nowrap; }
  .orta { text-align: center; }

  /* BİLEŞEN SATIRI GİRİNTİLİ — şeffaflık. Müşteri "Günün Menüsü ×12"nin */
  /* içinde ne olduğunu görmeli; fiyatları sıfır olduğu için toplam şişmez. */
  .bilesen td { color: var(--nötr); font-size: 11px; }
  .bilesen .ad { padding-left: 14px; }
  .bilesen .ad::before { content: "└ "; color: var(--kenar); }

  .toplamlar { margin-top: 5mm; display: flex; justify-content: flex-end; }
  .toplamlar table { width: 78mm; }
  .toplamlar td { border: 0; padding: 3px 4px; }
  .toplamlar .genel td { border-top: 2px solid var(--murekkep); font-size: 14px;
                         font-weight: 700; padding-top: 6px; }

  .donem { margin-top: 5mm; border: 1px solid var(--kenar); border-radius: 4px; }
  .donem td { border: 0; border-bottom: 1px solid var(--kenar); padding: 5px 8px; font-size: 11px; }
  .donem tr:last-child td { border-bottom: 0; }
  .donem td:first-child { color: var(--nötr); width: 55%; }

  .odeme { margin-top: 5mm; font-size: 11px; color: var(--nötr); }
  .odeme b { color: var(--murekkep); }

  footer { margin-top: 8mm; padding-top: 4mm; border-top: 1px solid var(--kenar);
           font-size: 10.5px; color: var(--nötr); }
  footer .ibare { font-weight: 700; color: var(--murekkep); }

  .iptal-notu { margin-top: 3mm; padding: 6px 8px; border: 1px solid var(--uyari);
                border-radius: 4px; color: var(--uyari); font-size: 11px; }

  /* ÇAPRAZ "İPTAL" FİLİGRANI: iptal edilmiş bir belgenin temiz --------- */
  /* basılabilmesi, elindeki kâğıdın geçerli olduğunu sanan bir müşteri -- */
  /* üretirdi. Filigran `position: fixed` — çok sayfalı belgede her ------ */
  /* sayfaya düşer. --------------------------------------------------- */
  .filigran {
    position: fixed; inset: 0; display: flex; align-items: center;
    justify-content: center; pointer-events: none; z-index: 10;
  }
  .filigran span {
    transform: rotate(-32deg);
    font-size: 92px; font-weight: 800; letter-spacing: .12em;
    color: rgba(185, 28, 28, .18);
    border: 8px solid rgba(185, 28, 28, .18);
    padding: 10px 40px; border-radius: 12px;
  }

  @media print {
    body { background: #fff; }
    .sayfa { padding: 0; max-width: none; }
    tbody tr { break-inside: avoid; }
    /* Zebra ve filigran renkleri yazıcıda da kalmalı; tarayıcı --------- */
    /* varsayılanı arka planları atar ve iptal filigranı kaybolurdu. --- */
    * { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  }
</style>
</head>
<body>
@if ($invoice->isVoid())
  <div class="filigran" aria-hidden="true"><span>İPTAL</span></div>
@endif

<div class="sayfa">
  <header>
    <div class="satici">
      <h1>{{ $issuer['name'] ?? 'BLD Catering' }}</h1>
      @if (($issuer['address'] ?? null) !== null)
        <p>{{ $issuer['address'] }}</p>
      @endif
      @if (($issuer['phone'] ?? null) !== null)
        <p>Tel: {{ $issuer['phone'] }}</p>
      @endif
      @if (($issuer['email'] ?? null) !== null)
        <p>{{ $issuer['email'] }}</p>
      @endif
    </div>

    <div class="belge">
      <div class="tur">{{ $isPeriod ? 'Abonelik dönem belgesi' : 'Sipariş belgesi' }}</div>
      <div class="no">{{ $invoice->invoice_no }}</div>
      <div class="tarih">Düzenlenme: {{ $an($invoice->issued_at) }}</div>
    </div>
  </header>

  <hr class="ayrac">

  <div class="taraflar">
    <section>
      <h2>Alıcı</h2>
      <div class="ad">{{ $customer['label'] ?? '—' }}</div>
      @if (($customer['contact_person'] ?? null) !== null && ($customer['contact_person'] ?? null) !== ($customer['label'] ?? null))
        <p>Yetkili: {{ $customer['contact_person'] }}</p>
      @endif
      @if (($customer['tax_no'] ?? null) !== null)
        <p>Vergi no: {{ $customer['tax_no'] }}@if (($customer['tax_office'] ?? null) !== null) — {{ $customer['tax_office'] }}@endif</p>
      @endif
      @if (($customer['address'] ?? null) !== null)
        <p>{{ $customer['address'] }}</p>
      @endif
      @if (($customer['phone'] ?? null) !== null)
        <p>Tel: {{ $customer['phone'] }}</p>
      @endif
    </section>

    <section>
      <h2>{{ $isPeriod ? 'Dönem' : 'Sipariş' }}</h2>
      @if ($isPeriod)
        <div class="ad">{{ $gun($document['period_start'] ?? null) }} – {{ $gun($document['period_end'] ?? null) }}</div>
        <p>Abonelik no: {{ $document['subscription_id'] ?? '—' }}</p>
      @else
        <div class="ad">{{ $document['order_number'] ?? '—' }}</div>
        <p>Servis günü: {{ $gun($document['service_date'] ?? null) }}</p>
        <p>Teslimat: {{ ($document['delivery_type'] ?? '') === 'pickup' ? 'Gel-al' : 'Adrese teslim' }}</p>
      @endif
    </section>
  </div>

  <table>
    <thead>
      <tr>
        <th>Açıklama</th>
        <th class="orta" style="width:16mm">Adet</th>
        <th class="sag" style="width:26mm">Birim (₺)</th>
        <th class="sag" style="width:28mm">Tutar (₺)</th>
      </tr>
    </thead>
    <tbody>
      @forelse ($lines as $line)
        @php $bilesen = ($line['role'] ?? 'item') === 'component'; @endphp
        <tr class="{{ $bilesen ? 'bilesen' : 'kalem' }}">
          <td class="ad">{{ $line['description'] ?? '' }}</td>
          <td class="orta">{{ (int) ($line['quantity'] ?? 0) }}</td>
          <td class="sag">{{ $lira($line['unit_price_kurus'] ?? 0) }}</td>
          <td class="sag">{{ $lira($line['line_total_kurus'] ?? 0) }}</td>
        </tr>
      @empty
        <tr><td colspan="4">Kalem yok.</td></tr>
      @endforelse
    </tbody>
  </table>

  @if ($isPeriod)
    {{-- DÖNEM DÖKÜMÜ: planlanan ile teslim edilen arasındaki farkı --}}
    {{-- açıklayan tek yer burası. Müşteri "neden bu kadar" sorusunun --}}
    {{-- cevabını kâğıdın üstünde görmeli, bizi aramak zorunda kalmamalı. --}}
    <table class="donem">
      <tr>
        <td>Anlaşılan birim fiyat</td>
        <td class="sag">{{ $lira($document['unit_price_kurus'] ?? 0) }} ₺</td>
      </tr>
      <tr>
        <td>Planlanan porsiyon</td>
        <td class="sag">{{ (int) ($document['planned_portions'] ?? 0) }}</td>
      </tr>
      <tr>
        <td>Teslim edilen porsiyon</td>
        <td class="sag"><b>{{ (int) ($document['delivered_portions'] ?? 0) }}</b></td>
      </tr>
      <tr>
        <td>Atlanan gün</td>
        <td class="sag">
          @php $atlanan = is_array($document['skipped_days'] ?? null) ? $document['skipped_days'] : []; @endphp
          @if ($atlanan === [])
            Yok
          @else
            {{ implode(', ', array_map($gun, $atlanan)) }}
          @endif
        </td>
      </tr>
    </table>
  @endif

  <div class="toplamlar">
    <table>
      <tr>
        <td>Ara toplam</td>
        <td class="sag">{{ $lira($totals['subtotal_kurus'] ?? 0) }} ₺</td>
      </tr>
      @if ((int) ($totals['delivery_fee_kurus'] ?? 0) > 0)
        <tr>
          <td>Teslimat ücreti</td>
          <td class="sag">{{ $lira($totals['delivery_fee_kurus']) }} ₺</td>
        </tr>
      @endif
      <tr class="genel">
        <td>Toplam</td>
        <td class="sag">{{ $lira($totals['total_kurus'] ?? 0) }} ₺</td>
      </tr>
    </table>
  </div>

  <p class="odeme">
    Ödeme yöntemi: <b>{{ $odemeYontemi }}</b> · Durum: <b>{{ $odemeDurumu }}</b>
    @if (($payment['reference'] ?? null) !== null)
      · Ödeme referansı: <b>{{ $payment['reference'] }}</b>
    @endif
    @if (($payment['paid_at'] ?? null) !== null)
      · Ödeme anı: <b>{{ $an($payment['paid_at']) }}</b>
    @endif
  </p>

  @if ($invoice->isVoid())
    <div class="iptal-notu">
      <b>Bu belge {{ $an($invoice->void_at) }} tarihinde iptal edilmiştir.</b>
      @if (($invoice->void_reason ?? null) !== null)
        <br>Gerekçe: {{ $invoice->void_reason }}
      @endif
    </div>
  @endif

  <footer>
    {{-- ZORUNLU İBARE — ŞABLONDAN KALDIRILAMAZ. --}}
    {{-- `docs/control/invoices.md`: belgenin mali değeri yoktur. --}}
    <p class="ibare">{{ \Veykemtu\BridgeApi\Services\InvoiceService::NOTICE }} {{ \Veykemtu\BridgeApi\Services\InvoiceService::NOTICE_EXTRA }}</p>
    <p>{{ $issuer['name'] ?? 'BLD Catering' }} · Belge no {{ $invoice->invoice_no }}</p>
  </footer>
</div>
</body>
</html>
