# mutfakapp — Mutfak Ekranı (KDS)

Spesifikasyon: [`docs/05-mutfakapp.md`](../docs/05-mutfakapp.md)

## Değişmez kısıtlar

- **Hedef platform yalnızca Linux desktop.** `flutter create --platforms=linux`
  ile oluşturuldu. `mutfakapp/android/` **yoktur**, Android'e özgü hiçbir paket
  eklenmez (ADR-04). `.gitignore` ve `.github/workflows/mutfakapp.yml` bunu
  ayrıca denetler.
- Tüm ağ çağrıları `packages/api_client` üzerinden. Doğrudan `dio`/`http`
  çağrısı bulunmaz.
- Veri katmanı `OrderSource` arayüzünü uygular; Faz 1
  [`PollingOrderSource`](lib/src/data/polling_order_source.dart),
  Faz 1.5 `WebSocketOrderSource`.
- Sabit metinler [`lib/src/l10n/app_tr.arb`](lib/src/l10n/app_tr.arb) içindedir.
  Değiştirdikten sonra `flutter gen-l10n` koşun; üretilen dosyalar commitlenir.

## Çalıştırma

Kök dizin bir pub workspace'tir; bağımlılıklar oradan çözülür.

```bash
flutter pub get                 # kökte ya da mutfakapp içinde, fark etmez
flutter run -d linux
```

Varsayılan sunucu mock'tur (`http://localhost:4010/api`, eşleme kodu
`BLD1-MOCK`, bkz. [`infra/mock/README.md`](../infra/mock/README.md)).
Gerçek backend'e bağlanmak için:

```bash
flutter run -d linux \
  --dart-define=BLD_API_BASE_URL=http://localhost:8080/api \
  --dart-define="BLD_KITCHEN_TOKEN=<pair ile alınan token>"
```

## Derleme zamanı ayarları

| `--dart-define` | Varsayılan | Ne işe yarar |
|---|---|---|
| `BLD_API_BASE_URL` | `http://localhost:4010/api` | `/api` dahil taban adres |
| `BLD_PRINTER_DEVICE` | `/dev/thermal0` | Termal yazıcının cihaz dosyası |
| `BLD_PRINTER_CODEPAGE` | `29` | `ESC t n` kod sayfası — aşağıya bakın |
| `BLD_POLL_SECONDS` | `5` | Sipariş çekme aralığı |
| `BLD_KITCHEN_TOKEN` | *(boş)* | Kurulumda önceden verilen cihaz token'ı |

`BLD_API_BASE_URL` yalnızca **ilk açılış** varsayılanıdır; eşleme ekranından
girilen adres `shared_preferences`'a yazılır ve sonraki açılışlarda o kullanılır.

## Eşleme

İlk açılışta sunucu adresi + eşleme kodu istenir (`docs/05` §7). Kod yönetici
panelinden alınır:

```bash
docker compose -f infra/docker-compose.dev.yml exec -T -e HOME=/tmp app \
  php artisan veykemtu:kds --new="Mutfak Kasası"
```

Token iptal edilirse (`403 DEVICE_REVOKED`) uygulama kendiliğinden eşleme
ekranına döner.

## Yazdırma kuyruğu

Her fiş önce **diske** yazılır (`print_queue` tablosu, SQLite), sonra basılır.
Kuyruk dosyası `~/.local/share/tr.com.benimlezzetdunyam.mutfakapp/print_queue.sqlite`.

- İş kimliği `(order_id, type)` çiftidir ve tabloda `UNIQUE` kısıtıyla
  korunur — aynı fiş iki kez basılmaz, uygulama yeniden başlasa bile.
- Basım başarısızsa `attempts++` ve geri çekilmeli tekrar: 2s → 5s → 15s → 60s.
- Yazıcı yoksa işler kuyrukta bekler; durum çubuğunda sayaç ve kalıcı uyarı.
- Basımdan sonra `POST /api/kitchen/print-jobs/{id}/ack` gönderilir;
  başarısız olursa sessizce yutulur.

`sqlite3` paketi **2.9.x'e sabitlenmiştir**: 3.3+ kütüphaneyi deneysel native
assets ile yüklüyor. Sistem kütüphanesi kullanılır, bu yüzden `.deb`
paketlenirken **`libsqlite3-0` bağımlılık olarak yazılmalıdır**.

## Yazıcı

Donanım doğrulandı: `0483:5720` "aaaait Printer", `/dev/usb/lp1`, udev kuralı
`/dev/thermal0` bağını kuruyor
([`infra/kasa/99-thermal-printer.rules`](../infra/kasa/99-thermal-printer.rules)).

**Kod sayfası numarası standart değildir.** Bu yazıcıda Türkçe glifler
`ESC t 29` ile basar, dokümanın başta söylediği `ESC t 13` (PC857) ile **boş**
basar. Yazıcı değişirse doğru numarayı
[`infra/kasa/kodsayfasi-tara.sh`](../infra/kasa/kodsayfasi-tara.sh) bulur,
sonuç `BLD_PRINTER_CODEPAGE` ile verilir — kod değişmez.

ESC/POS motoru bu pakette değil, `packages/core/lib/src/escpos/` altındadır ve
yalnızca **bayt üretir**; golden testleri `packages/core/test/golden/`.

## Testler

```bash
flutter analyze     # sıfır uyarı
flutter test        # pano, polling, fiş eşleme, ekran testleri
```
