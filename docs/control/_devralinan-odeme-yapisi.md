# Devralınan ödeme yapısı — cari ödeme akışından kurtarılanlar

> **Bu dosya bir arşivdir, bir tasarım belgesi değildir.** Cari hesap
> altyapısı 20.08.2026'da tamamen kaldırıldı (Ajan 0-B). Kaldırılan
> kodun içinde, sonraki fazda **abonelik ödemesi** için birebir gereken
> bir iskelet vardı: "sipariş olmadan para tahsil etmek". Silmeden önce
> o iskelet buraya çıkarıldı.
>
> Yapı dört adımdır ve her adımın varlık sebebi bir arıza senaryosudur.
> Abonelik ödemesi yazılırken **adımlar değil, gerekçeler** taşınmalıdır:
> nesne (cari bakiye) değişecek, arıza senaryoları aynı kalacak.

Silinen dosyalar (git geçmişinde `2026_08_20` öncesinde durur):

| Dosya | Rolü |
|---|---|
| `platform/extensions/veykemtu/bridgeapi/src/Models/AccountPaymentIntent.php` | Niyet modeli |
| `platform/extensions/veykemtu/bridgeapi/database/migrations/2026_08_13_000002_create_veykemtu_account_payments_table.php` | Niyet tablosu |
| `platform/extensions/veykemtu/bridgeapi/src/Http/Controllers/AccountController.php` | `startPayment()` — niyeti açan uç |
| `platform/extensions/veykemtu/payment/src/Http/Controllers/AccountSimulationController.php` | Sağlayıcı sayfası + dönüş |
| `platform/extensions/veykemtu/payment/resources/views/account_simulation.blade.php` | Simülasyon formu |
| `platform/extensions/veykemtu/payment/src/Payments/AccountPayment.php` | `OfflinePayment` alt sınıfı, `CODE = 'account'` |
| `platform/extensions/veykemtu/payment/src/Refunds/AccountRefund.php` | Para hareketi olmayan iade geçidi |

---

## 1. Neden ayrı bir "niyet" tablosu gerekti

Mevcut simülasyon POS'u (`SimulationController`) **siparişe** bağlıdır:
`Order::where('hash', ...)`. Müşteri "birikmiş borcumun 2.500 TL'sini
ödeyeyim" dediğinde ortada sipariş yoktur — ödenen şey bir siparişin
bedeli değil, bir **bakiyedir**.

Abonelikte durum aynıdır: "ağustos ayı abonelik bedelini öde" isteğinin
karşılığı tek bir sipariş değildir.

Niyet tablosunun taşıdığı alanlar ve her birinin sebebi:

```php
$table->bigIncrements('id');
$table->unsignedBigInteger('customer_id')->index();

// Kuruş. Her zaman pozitif.
$table->unsignedBigInteger('amount_kurus');

// Niyet oluşturulduğu ANDAKİ bakiye. Denetim için: "2.500 TL ödedim ama
// borcum 3.000 TL çıktı" tartışmasında, o an ekranda ne yazdığını
// gösteren tek kayıt bu.
$table->bigInteger('balance_at_start');

// pending | succeeded | failed
$table->string('status', 16)->default('pending')->index();

// Dışarıya verilen TEK tanımlayıcı.
$table->string('hash', 64)->unique();

// Gerçek POS bağlandığında sağlayıcının işlem numarası buraya.
$table->string('provider_ref', 128)->nullable();
$table->string('gateway', 32)->nullable();

$table->timestamp('created_at')->nullable();
$table->timestamp('settled_at')->nullable();
```

**Niyet neden doğrudan deftere yazılmadı:** ödeme sağlayıcısına gidip
dönmek gerekiyor ve dönüş güvenilmez. Kullanıcı sekmeyi kapatabilir,
sağlayıcı callback'i iki kez gönderebilir, ağ kopabilir. Niyeti önce
`pending` yazıp dönüşte `succeeded`'a çevirmek, "ödeme başladı ama
bitmedi" durumunu **temsil edilebilir** kılar.

## 2. Tutar sunucuda doğrulanır — iki mod, tek uç

```php
// POST /api/account/payments
//   {"amount": 250000} → istenen tutar
//   {"full": true}     → o anki borcun tamamı
$data = $request->validate([
    'amount' => ['sometimes', 'nullable', 'integer', 'min:1'],
    'full' => ['sometimes', 'boolean'],
]);

$balance = $this->ledger->balance((int) $customer->customer_id);

// `full` modunda istemcinin gönderdiği bir rakam HİÇ OKUNMAZ; tutar
// burada yeniden hesaplanır. Aksi hâlde istemcinin ekranındaki eski
// bakiye ile gerçek borç ayrıştığında (arada bir sipariş geçmişse)
// müşteri eksik ödeyip "kapattım" sanırdı.
$full = (bool) ($data['full'] ?? false);
$amount = $full ? $balance : (int) ($data['amount'] ?? 0);

// BORCU AŞAN ÖDEME REDDEDİLİR: fazla ödeme negatif bakiye (alacaklı
// müşteri) yaratır ve iadesi elle iş demektir.
if ($amount > $balance) {
    throw ApiException::validationFailed('Tutar borcunuzdan büyük olamaz.', [
        'amount' => $amount,
        'balance' => $balance,
    ]);
}
```

Abonelik karşılığı: "bu ayın bedeli" sunucuda abonelik satırlarından
hesaplanmalı, istemciden gelen bir tutar okunmamalıdır.

## 3. Dışa kimlik `hash` ile verilir, `id` ile değil

```php
$intent = new AccountPaymentIntent;
$intent->customer_id = (int) $customer->customer_id;
$intent->amount_kurus = $amount;
$intent->balance_at_start = $balance;
$intent->status = AccountPaymentIntent::STATUS_PENDING;
// 32 bayt rastgele: adres tahmin edilerek başkasının ödeme sayfası
// açılamamalı. Sıralı `id` bu yüzden dışarı verilmiyor.
$intent->hash = bin2hex(random_bytes(16));
$intent->created_at = BusinessTime::forStorage(BusinessTime::now());
$intent->save();

return $this->json([
    'payment_id' => (int) $intent->id,
    'amount' => $amount,
    'balance' => $balance,
    'currency' => 'TRY',
    'status' => $intent->status,
    'redirect_url' => url('/cari-odeme-simulasyon/'.$intent->hash),
], 201);
```

**Ödeme burada tamamlanmaz.** Uç yalnızca niyeti `pending` yazar ve
sağlayıcının sayfasına yönlendirme adresi döner.

## 4. Dönüş adresi — açık yönlendirme (open redirect) kapısı

Dönüş adresi kullanıcıdan gelen bir sorgu parametresidir; doğrulanmazsa
ödeme sayfamız üçüncü bir siteye yönlendirme aracına dönüşür.

```php
private function returnUrl(Request $request): string
{
    $varsayilan = rtrim((string) config('app.frontend_url', env('FRONTEND_URL', '')), '/');
    $istenen = (string) $request->query('return', '');

    if ($varsayilan === '') {
        return url('/');
    }

    // YALNIZCA yapılandırılmış ön yüzün HOST'u kabul edilir.
    if ($istenen !== '') {
        $izinliHost = parse_url($varsayilan, PHP_URL_HOST);
        $istenenHost = parse_url($istenen, PHP_URL_HOST);

        if ($izinliHost !== null && $izinliHost === $istenenHost) {
            return $istenen;
        }
    }

    return $varsayilan.'/hesabim/cari';
}

/**
 * Dönüş adresine `durum` parametresini ekler.
 *
 * K-20'de sahada çıktı: dönüş adresi artık sorgu parametresi
 * taşıyabiliyor ve düz birleştirme ikinci bir `?` üretip `durum`u
 * okunamaz kılıyordu.
 */
private static function withStatus(string $url, string $durum): string
{
    return $url.(str_contains($url, '?') ? '&' : '?').'durum='.$durum;
}
```

## 5. Çift geri-arama koruması — iki katman

Bu, yapının **en pahalı öğrenilmiş dersidir** ve abonelik ödemesinde
birebir gerekir.

```php
// KATMAN 1 — durum kontrolü.
// Kesinleşmiş niyet ikinci kez işlenmez. Gerçek POS'ta callback iki kez
// gelebiliyor (docs/04 §5); simülasyon aynı davranışı TAKLİT ETMELİ,
// yoksa istemciler bu duruma karşı yazılmaz.
if (!$intent->isPending()) {
    return redirect()->away(self::withStatus($returnUrl, 'zaten_odendi'));
}

/*
 * NİYET VE PARA KAYDI TEK TRANSACTION'DA.
 *
 * İkisi ayrılsaydı ve arada süreç düşseydi iki bozuk sonuçtan biri
 * çıkardı: kayıt yazılıp niyet `pending` kalır (müşteri ikinci kez
 * ödemeye çalışır) ya da niyet `succeeded` olup kayıt boş kalır (para
 * alınmış görünür, borç durur). İkisi de elle onarım demek.
 *
 * KATMAN 2 — hedef tarafındaki tekil indeks: ikinci kayıt satırı bir
 * yarışta bile yazılamaz.
 */
DB::transaction(function () use ($intent): void {
    // … para hareketinin hedefe yazılması (eskiden: cari defter alacağı)

    $intent->status = AccountPaymentIntent::STATUS_SUCCEEDED;
    $intent->gateway = SimulatedPos::CODE;
    $intent->settled_at = BusinessTime::forStorage(BusinessTime::now());
    $intent->save();
});

Log::warning('SİMÜLASYON: ödeme işlendi, para tahsil edilmedi.', [
    'intent_id' => $intent->id,
    'customer_id' => $intent->customer_id,
    'amount_kurus' => $intent->amount_kurus,
]);
```

## 6. Kart verisi ve rota kaydı

- Kart alanları yalnızca **biçim** doğrulanır (`kart_no`, `ad_soyad`,
  `son_kullanma` `AA/YY`, `cvv` 3-4 hane) ve **hiçbir yere yazılmaz**.
- Sayfa `web` middleware grubundadır — bir HTML formudur ve CSRF
  koruması gerekir. API rotalarımız (durumsuz, token'lı) ayrı dünyada.
- Simülasyon kapalıysa rotalar **hiç kaydedilmez**: kapalı bir geçide
  giden adres bırakmak, ileride yanlışlıkla açılmasının en kolay yolu.

```php
if (!SimulatedPos::isAllowed()) {
    return;
}

Route::middleware('web')->group(function (): void {
    Route::get('/cari-odeme-simulasyon/{hash}', [AccountSimulationController::class, 'show'])
        ->name('veykemtu.payment.account_simulation');
    Route::post('/cari-odeme-simulasyon/{hash}', [AccountSimulationController::class, 'process']);
});
```

**Neden sipariş ödemesiyle aynı rotaya konmadı:** sipariş akışı bir
siparişin bedelini tahsil eder ve siparişi `processed` işaretler; bu akışta
sipariş yoktur. Aynı rotaya iki anlam yüklemek, dönüş adresinden yazıcı
tetiğine kadar her adımda "bu hangisiydi" dallanması demekti. Abonelik
ödemesi de **üçüncü bir rota** olmalıdır.

## 7. Ödeme geçidi sınıfı — `payments` satırı neden şart

`AccountPayment` yalnızca bir kod taşıyordu:

```php
class AccountPayment extends OfflinePayment
{
    public const string CODE = 'account';
}
```

Sebep `OfflinePayment` docblock'unda: TastyIgniter `orders.payment`
alanını `payments.code` ile eşleştirir. Kod karşılığı olmayan bir sipariş
için `Order::$payment_method` ilişkisi `null` döner ve ödeme günlüğü
"property on null" ile patlar. Yeni bir ödeme yöntemi (ör. abonelik
peşin ödemesi) eklenecekse **önce `payments` satırı** açılmalıdır.

`markAsPaymentProcessed()` çağrılmaz: alınmamış bir parayı alınmış
göstermek raporları yalancı yapar.

## 8. İade geçidi — "para hareketi yok" da bir sonuçtur

```php
class AccountRefund implements RefundGateway
{
    public const string CODE = 'account';

    public function refund(Order $order, int $amountKurus, string $reason): RefundResult
    {
        return RefundResult::succeeded('cari-defter');
    }
}
```

**Neden yine de bir geçit:** iade kayıtları tek tabloda toplansın ve "bu
siparişin iadesi ne oldu" sorusu ödeme yöntemine bakmadan
cevaplanabilsin diye. Abonelikte de aynı ihtiyaç doğacak — iade
edilecek para olmadığı durumda bile bir `RefundResult` üretilmelidir.
