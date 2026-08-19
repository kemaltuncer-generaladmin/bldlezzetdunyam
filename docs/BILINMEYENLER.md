# BİLİNMEYENLER

> Ajanlar tahminle ilerlemez. Emin olunmayan her şey buraya yazılır ve TODO bırakılarak devam edilir.
> Format: `- [KOL-X][GG.AA] Soru | Etkilenen: <dosya> | Geçici çözüm: <ne yapıldı>`
> Gün 7'de bu dosya boşaltılır: her satır ya çözülür ya Faz 2 backlog'una taşınır.

## Açık

### Kol A — Platform

_(Kol A'nın açık maddesi kalmadı — B-02'nin iki mimari sorusu da karara bağlandı, aşağıya bakın.)_

### Kol C — Mobil (`musteriapp`)

- [KOL-C-Mobil][04.08] `musteriapp` kök `pubspec.yaml`'daki pub workspace'e eklenmeli mi? Kök dosya bu ajanın dosya alanı dışında (`mutfakapp` ajanı da aynı dosyayı düzenleyecek). | Etkilenen: `pubspec.yaml`, `musteriapp/pubspec.yaml` | Geçici çözüm: workspace'e **eklenmedi**; `packages/*` path bağımlılığı olarak kullanılıyor. `packages/*` birbirine `^0.1.0` (hosted) diye baktığı için `musteriapp/pubspec.yaml`'a üç satırlık `dependency_overrides` konuldu. Workspace'e katılırsa bu blok silinir, başka değişiklik gerekmez.
- [KOL-C-Mobil][04.08] `docs/07` §1 sepet için `sqflite` diyor; sepet tek bir küçük JSON belgesi, ilişkisel sorgu/göç ihtiyacı yok. | Etkilenen: `musteriapp/lib/src/data/local_cache.dart`, `docs/07-musteriapp.md` §1 | Geçici çözüm: sepet ve menü önbelleği `shared_preferences` içinde JSON olarak tutuluyor. Bir bağımlılık ve bir şema göç mekanizması eksildi. Sepet büyür veya sorgulanır hale gelirse `sqflite`'a geçilir; arayüz (`LocalCache`) tek yerde.
- [KOL-C-Mobil][04.08] `packages/core`'daki `TurkishTime` yalnızca UTC → Türkiye yönünü kapsıyor; kullanıcının seçtiği duvar saatini UTC'ye çevirmek gerekiyor (istenen teslim zamanı). | Etkilenen: `packages/core/lib/src/turkish_time.dart`, `musteriapp/lib/src/core/time_input.dart` | Geçici çözüm: ters çevirim `musteriapp` içinde `istanbulWallClockToUtc` olarak yazıldı. `packages/` ajanının alanı olduğu için oraya taşınmadı — `TurkishTime.fromIstanbul` eklenirse yerel kopya silinmeli.
- [KOL-C-Mobil][04.08] Ödeme WebView'i (`docs/07` §2 "Ödeme web görünümü") uygulanmadı; `webview_flutter` yeni bir bağımlılık ve Faz 1'de `online` hiçbir vitrinin `payment_methods` listesinde yok. | Etkilenen: `musteriapp/lib/src/features/checkout/checkout_screen.dart` | Geçici çözüm: sunucu `redirect_url` dönerse kullanıcı bilgilendiriliyor ama yönlendirme yapılmıyor. Kuveyt Türk entegrasyonu netleşince (bkz. Kol A'nın sanal POS maddesi) ekran eklenecek.
- [KOL-C-Mobil][04.08] Geliştirme makinesinde **Android SDK kurulu değil** (`flutter doctor`: "Unable to locate Android SDK"), bu yüzden APK/AAB derlemesi doğrulanamadı. | Etkilenen: `musteriapp/android/`, `I-06` | Geçici çözüm: Dart tarafı `flutter build bundle` ile derlendi (başarılı), `flutter analyze` sıfır uyarı, testler yeşil. Paket adı `com.veykemtu.catering` olarak `namespace` + `applicationId` + `MainActivity.kt` üçünde birden ayarlandı ama Gradle derlemesi **hiç koşmadı**. Play kanalı açılmadan önce bir kez `flutter build appbundle` çalıştırılmalı.
- [KOL-C-Mobil][04.08] Çevrimdışılık nasıl anlaşılacak? `connectivity_plus` yeni bağımlılık ve "ağ arayüzü var" ile "sunucuya ulaşılıyor" aynı şey değil. | Etkilenen: `musteriapp/lib/src/providers/infra_providers.dart` | Geçici çözüm: durum son API çağrısının sonucundan türetiliyor — `ApiException.code == UNKNOWN && statusCode == null` çevrimdışı sayılıyor. Eklenti gerekirse `ConnectivityNotifier` tek değişim noktası.
- [KOL-C-Mobil][04.08] `X-App-Version` başlığı ile `pubspec.yaml`'daki `version:` iki ayrı yerde duruyor; ikisinin ayrışmasını engelleyen bir kontrol yok. | Etkilenen: `musteriapp/lib/src/config/app_config.dart`, `musteriapp/pubspec.yaml`, CI | Geçici çözüm: varsayılan `1.0.0`, `--dart-define=BLD_APP_VERSION` ile geçilebiliyor. `package_info_plus` bağımlılığı eklenmedi. CI'da tek satırlık bir karşılaştırma adımı önerilir.
- [KOL-C-Mobil][04.08] Token `shared_preferences` içinde **şifresiz** duruyor (`docs/07` §1 böyle diyor). Rootlu cihazda okunabilir. | Etkilenen: `musteriapp/lib/src/data/token_store.dart` | Geçici çözüm: dokümana uyuldu. Token `customer` kapsamlı ve sunucudan iptal edilebilir. `flutter_secure_storage`'a geçiş kararı Faz 2'ye bırakıldı; `TokenStore` arayüzü tek değişim noktası.
- [KOL-C-Mobil][04.08] `MenuOption.type` kapalı enum değil (Kol A'nın açık maddesi). İstemci bilinmeyen tipi nasıl çizsin? | Etkilenen: `musteriapp/lib/src/features/menu/product_detail_screen.dart` | Geçici çözüm: `MenuOption.isMultiSelect` (`type == 'checkbox'`) kullanılıyor; bilinmeyen tip **tek seçim** gibi çiziliyor, sözleşmenin açıklamasıyla aynı. Zorunlu tek seçimli grupta ilk değer önceden işaretleniyor.
- [KOL-C-Mobil][04.08] "Hesabım → adresler" (`docs/07` §2) uygulanamadı: sözleşmede adres ucu yok, adres sipariş gövdesiyle gidiyor. | Etkilenen: `musteriapp/lib/src/features/account/account_screen.dart`, `docs/openapi.yaml` | Geçici çözüm: hesap ekranı profil + çıkış gösteriyor; adres her siparişte ödeme ekranında giriliyor. Adres defteri istenirse önce `GET/POST /api/me/addresses` sözleşmeye eklenmeli.
- [KOL-C-Mobil][04.08] `GET /orders` sayfalı; kaç sayfa gösterilecek? | Etkilenen: `musteriapp/lib/src/providers/order_providers.dart` | Geçici çözüm: yalnızca ilk sayfa (25 kayıt) çekiliyor, aşağı çekip yenileme var, sonsuz kaydırma yok. `PaginationMeta.hasNextPage` hazır duruyor.

## Çözülenler — B-02 doğrulaması (04.08, gerçek kurulumdan okundu)

Kurulan sürümler: **TastyIgniter core 4.3.4**, Laravel 12.64.0, PHP 8.3.33, `laravel/sanctum` 4.3.3, `ti-ext-api` 4.2.3, MySQL 8.4.11.

| Soru | Gerçek cevap |
|---|---|
| Sipariş **durum güncelleme** servisinin imzası | `Igniter\Cart\Models\Order::updateOrderStatus($id, array $options = []): StatusHistory\|false` — `Order.php:311`. Ayrı bir "sipariş oluşturma servisi" yoktur; sipariş `Order` modeli üzerinden kaydedilir. |
| Durum değişimine nasıl bağlanılır | `Igniter\Admin\EventSubscribers\StatusUpdatedSubscriber` var — çekirdeğe dokunmadan olay dinleyicisiyle bağlanılabilir (`veykemtu/push` bunu kullanacak). |
| Hangi API uçları hazır geliyor | `ti-ext-api` ile 82 rota: addresses, categories, coupons, currencies, customers, locations, location_settings, menus, menu_options, menu_item_options, orders, reservations, reviews, status, tables, users + `POST /api/token`, `GET /api/token/user`. |
| Teslimat tipi alanı | `orders.order_type`; sabitler `Igniter\Cart\Models\Order::DELIVERY = 'delivery'` ve `::COLLECTION = 'collection'`. **Bizim `pickup` değerimiz TastyIgniter'da `collection`'dır** — `bridgeapi` çevirmek zorunda. |
| Tek vitrin desteği | `.env`'de `IGNITER_LOCATION_MODE=single\|multiple` var. `single` seçildi. |
| Kurulum komutu | `php artisan igniter:install` **`--no-interaction` destekliyor** ama bu modda **admin kullanıcısı ve vitrin oluşturmuyor** — ikisi de ayrıca yapılmalı (`B-01` kalanı). |
| Alpine uyumluluğu | **Çalışmıyor.** Çekirdek `ExtensionManager.php:99` `GLOB_BRACE` kullanıyor; glibc'ye özgü, musl sağlamıyor. Taban imaj Debian'a çevrildi (`infra/platform/Dockerfile`). |

### ŞEMA UYUŞMAZLIĞI — `status_code` diye bir kolon yok

`statuses` tablosunun gerçek kolonları: `status_id`, `status_name`, `status_comment`, `notify_customer`, `status_for`, `status_color`, zaman damgaları. **Kod alanı yoktur.** `orders.status_id` bir tamsayı FK'dir.

Sonuç: `docs/02-veri-modeli.md` §4'teki üretim listesi sorgusu (`o.status_code IN (...)`) bu şemada **çalışmaz** ve düzeltildi.

Varsayılan durumlar da bizimkiler değil: `Received, Pending, Preparation, Delivery, Completed, Canceled`.

### B-02'nin iki mimari sorusu — karara bağlandı (04.08, işletme onayı)

| Soru | Karar | Uygulama |
|---|---|---|
| `ti-ext-api` 82 rotayla `/api` önekini işgal ediyor | **Devre dışı bırakıldı**, sözleşme `bridgeapi`'de sıfırdan uygulanacak | Paket çekirdeğin **zorunlu bağımlılığı** olduğu için composer'dan kaldırılamadı. Kapatma `platform/bootstrap/cache/disabled-addons.json` içindedir ve `.gitignore` istisnasıyla **commitlenir** — yoksa klonlayan ajanda geri açılırdı. Doğrulandı: `/api` rotası 0, `/admin` rotası 47 (panel sağlam). `laravel/sanctum` 4.3.3 duruyor. |
| 7 durum kodu nerede saklanacak | **`statuses` tablosuna `status_code` kolonu eklendi** | `bridgeapi` migration'ı (eklemeli, çekirdek dosyaya dokunmaz — ADR-02 ihlali değil). `veykemtu:setup` komutu 7 satırı yazar, `default_order_status`'u `yeni`ye ayarlar, vitrini ve müşteri grubunu açar. İdempotenttir. Admin panelde "Hazırlanıyor" görünür, API `hazirlaniyor` döner. |

### B-02 sırasında düzeltilen varsayımlarım

| Varsaydığım | Gerçek |
|---|---|
| `locations.location_slug` | **`permalink_slug`** |
| `setting()->set()` + `->save()` | `set()` kendisi kaydeder; ek `save()` boş satır insert edip `1062` verir |
| Eklenti meta verisi `extension.json`'da | **`composer.json` → `extra.tastyigniter-extension`** (`docs/04` §3 düzeltildi) |
| Alpine tabanlı PHP imajı yeterli | **Yetersiz** — `GLOB_BRACE` musl'da yok, Debian'a geçildi |

- [KOL-A][04.08] `igniter:install` sonrası TastyIgniter'ın kendi "Default" vitrini (#1) ve "Default group" (#1) kaydı duruyor. | Etkilenen: admin paneli görünümü | Geçici çözüm: `veykemtu:setup` bunları **silmiyor**, uyarı veriyor — silme geri alınamaz ve bağlı veri olup olmadığını komut bilemez. Yönetici admin panelden temizlemeli. API zaten yalnızca `catering` vitrinini döndürecek.
- [KOL-A][04.08] `ordering_enabled` TastyIgniter'da hangi katmana yazılacak? Vitrin (`locations`) ayarı mı, ayrı `settings` kaydı mı? | Etkilenen: `docs/03-api-sozlesmesi.md` §3, `bridgeapi` | Geçici çözüm: sözleşmede vitrin alanı olarak tanımlandı. Kurulu sürümün `locations` şeması okununca saklama yeri kesinleşir; **API sözleşmesi değişmez.**
- [KOL-A][04.08] `order_cutoff`, TastyIgniter'ın kendi çalışma saati (`working_hours`) mekanizmasıyla çakışıyor mu? `is_open` bundan mı türetilecek? | Etkilenen: `bridgeapi`, `docs/03` §3 | Geçici çözüm: `is_open` = çalışma saatinden türetilir, `ordering_enabled` = elle şalter, `order_cutoff` = ayrı alan. Üçü bağımsız tanımlandı; kod okununca sadeleşebilir.
- [KOL-A][04.08] `MenuOption.type` alanının gerçek değer kümesi nedir? Sözleşmede yalnızca `radio` örneği vardı. | Etkilenen: `docs/openapi.yaml` `MenuOption`, `website/`, `musteriapp/` | Geçici çözüm: kapalı enum **yazılmadı**, serbest string bırakıldı; bilinen değerler açıklamada. TastyIgniter'ın gerçek kümesi `B-02`'de okunup enum'a çevrilecek (ekleme değil daraltma olacağı için sözleşme değişikliği sayılır, önce burada karara bağlanmalı).
- [KOL-A][04.08] Kuveyt Türk sanal POS'un teknik dokümanı ve test hesabı elimizde yok. Entegrasyon biçimi ne (3D Secure host-to-host / hosted page)? | Etkilenen: `platform/extensions/veykemtu/payment/` | Geçici çözüm: Faz 1'de `online` hiçbir vitrinin `payment_methods` listesinde yok. Eklenti arayüzü yazılır, sağlayıcı sınıfı boş kalır.

### Kol B — Mutfak / KDS

- [KOL-B][04.08] Fişin satır genişliği kaç karakter? `docs/05` §1 "80 mm" diyor (Font A'da 48 karakter) ama §5.3'teki örnek fişlerin ayraç çizgisi 32 karakter (58 mm karşılığı). | Etkilenen: `packages/core/lib/src/escpos/receipt_templates.dart`, `packages/core/test/golden/*.hex` | Geçici çözüm: donanım tablosu kazandı, varsayılan **48**. `ReceiptStyle.columns` ile değiştirilebilir; değişirse golden dosyaları `BLD_UPDATE_GOLDEN=1` ile yenilenir. Gerçek yazıcıdan çıkan fişte satır taşıyorsa 32'ye çekilecek.
- [KOL-B][04.08] Fiş başlığındaki tarih siparişin oluşturma zamanı mı, basım zamanı mı? Sözleşmedeki `KitchenReceipt`/`CustomerReceipt` şemalarında `created_at` **yok**. | Etkilenen: `packages/core/lib/src/escpos/receipt_data.dart` | Geçici çözüm: **basım zamanı** (`printedAt`) basılıyor ve şablona dışarıdan veriliyor (saf fonksiyon kalsın diye). Fiş sipariş düştüğü anda basıldığı için ikisi pratikte aynı. Sözleşmeye `created_at` eklenirse doğrusuna geçilir — bu ekleme, kırıcı değişiklik değil.
- [KOL-B][04.08] Doküman üç sütun adı veriyor (YENİ / HAZIRLANIYOR / HAZIR) ama beş aktif durum var; `onaylandi` ve `yolda` hangi sütuna düşer yazmıyor. | Etkilenen: `mutfakapp/lib/src/kds/board.dart` | Geçici çözüm: `yeni` → YENİ, `onaylandi`+`hazirlaniyor` → HAZIRLANIYOR, `hazir`+`yolda` → HAZIR. Gerekçe: "YENİ" mutfağın **henüz görmediği iş** demek olmalı, 3 saniye kuralı ve sesli uyarı ona bağlı; ONAYLA'ya basılınca kart sütun değiştirmezse personel neyi hallettiğini göremez. Tek satırlık `columnOf` değişimiyle döner.
- [KOL-B][04.08] `assets/new_order.wav` deposunda yok ve ses çalmak için paket (`audioplayers` vb.) eklemek yeni bağımlılık kararıdır — `AGENTS.md` §6.3 gereği sormadan eklenmedi. | Etkilenen: `mutfakapp/lib/src/kds/new_order_highlights.dart` | Geçici çözüm: görsel kural tam uygulandı (kart 3 sn yanıp söner); ses için bağımlılıksız `SystemSound.play(SystemSoundType.alert)` çağrılıyor, Linux masaüstünde sessiz kalabilir. Ses dosyası + paket onayı gelince tek fonksiyon değişecek.
- [KOL-B][04.08] **Oran sınırı çelişkisi:** `docs/05` §4 "her 5 saniyede bir çek" diyor = 720 istek/saat; `docs/openapi.yaml` `/kitchen/*` için **600 istek/saat/cihaz** koyuyor. Heartbeat'le birlikte 780/saat. | Etkilenen: `mutfakapp/lib/src/data/polling_order_source.dart`, `docs/openapi.yaml` §Oran sınırları | Geçici çözüm: mutfak spesifikasyonu kazandı, 5 sn kaldı (`BLD_POLL_SECONDS` ile değiştirilebilir). Üretim listesi ayrı uçtan çekilmiyor, yerelde hesaplanıyor — yoksa 1440/saat olurdu. Gerçek sunucuda sınır 900/saate çıkarılmalı ya da aralık 7 sn yapılmalı; karar verilmedi.
- [KOL-B][04.08] `GET /kitchen/orders?since=...` varsayılan olarak tamamlananları filtreliyor; bir sipariş `teslim_edildi` olunca artımlı yanıtta **hiç görünmüyor** ve kart ekranda kalıcı oluyor. | Etkilenen: `mutfakapp/lib/src/data/polling_order_source.dart` | Geçici çözüm: artımlı isteklerde `include_completed=true` gönderiliyor, terminal durumdakiler yerelde eleniyor. Tam yenilemede `false`. Sözleşmeye aykırı değil ama dokümanda bu kullanım yazmıyor — `docs/05` §4'e eklenmeli.
- [KOL-B][04.08] `docs/09` §K-03 "üç fiş şablonu" diyor; `docs/05` §5.3 ve BILINMEYENLER #1 iki şablon diyor (teslim fişi iptal). | Etkilenen: `docs/09-gorev-plani.md` | Geçici çözüm: **iki** şablon yapıldı (mutfak, musteri). `docs/09` satırı güncellenmeli, kod doğru.
- [KOL-B][05.08] `sqlite3` paketinin 3.3+ sürümleri kütüphaneyi Dart'ın **deneysel** native assets mekanizmasıyla yüklüyor (`@DefaultAsset`) ve `open.dart`'ı kaldırmış; `sqlite3_flutter_libs` ise `0.6.0+eol`. | Etkilenen: `mutfakapp/pubspec.yaml`, `.deb` paketleme | Geçici çözüm: `sqlite3` **2.9.x**'e sabitlendi; sistemdeki `libsqlite3`'ü açıyor. Ubuntu'da `libsqlite3-0` zaten kurulu ama **`.deb` bağımlılıklarına yazılmalı** — kasada eksikse uygulama kuyruğu açamaz. Kod sürümlü adı da deniyor (`libsqlite3.so`, `.so.0`, `.so.3`).
- [KOL-B][05.08] `docs/05` §5.4 kuyruk kolonlarını sayıyor ama `payload`'ın boş olabilirliğini ve tekrar zamanının nerede tutulacağını söylemiyor. | Etkilenen: `mutfakapp/lib/src/printing/print_queue.dart` | Geçici çözüm: `payload` **nullable** — iş önce diske yazılıyor, fiş verisi sonra çekiliyor; sipariş düştüğü an ağ giderse "basılacaktı" bilgisi kaybolmuyor. Tekrar zamanı için kolon eklenmedi (`attempts` yeterli): geri çekilme bellekte tutuluyor, yeniden başlatmada iş hemen deneniyor — ki doğrusu da budur.
- [KOL-B][05.08] `docs/05` §5.4'teki "Ayarlarda **Yeniden bas** butonu" ayarlar ekranına ait; ayarlar ekranı `K-08`'de. | Etkilenen: `mutfakapp` ayarlar | Geçici çözüm: kuyruk tarafı hazır (`markPrinted` geri alınabilir bir güncelleme), buton `K-08`'de eklenecek. **Uyarı:** basılmış satırı silmek ya da `printed_at`'i boşaltmak tekillik kısıtını gevşetir; yeniden basma bilinçli bir insan eylemi olarak ele alınmalı.
- [KOL-B][05.08] Gerçek kasada uygulama **on koşuda bir kapanışta `SIGSEGV`** verdi (açılışta değil; 6 ardışık koşuda tekrarlamadı, core dump üretilmedi). | Etkilenen: `mutfakapp`, `infra/kasa/mutfakapp.service` | Geçici çözüm: yok — sebebi bulunamadı, Flutter Linux gömücüsünün GTK/Wayland kapanışından şüpheleniliyor. Zararsız kabul edildi: kuyruk diskte ve idempotent, servis `Restart=always`. Sahada tekrarlarsa `flutter run --verbose` ile izlenmeli.
- [KOL-B][05.08] Eşleme ekranındaki "Cihaz adı" alanının varsayılanı dokümanda yok. | Etkilenen: `mutfakapp/lib/src/pairing/pairing_screen.dart` | Geçici çözüm: `Mutfak Kasası` yazılı geliyor, personel değiştirebilir. Admin panelde cihaz bu adla görünür.
- [KOL-B][04.08] Fişteki sabit metinler (`Bu belge bilgi fişidir...`, `GEL-AL`, `Ara Toplam`) `l10n` üzerinden gelmiyor — `packages/core` saf Dart, Flutter `l10n` altyapısı yok. | Etkilenen: `packages/core/lib/src/escpos/receipt_templates.dart` | Geçici çözüm: `ReceiptStyle` alanı olarak dışarıdan verilebilir hâle getirildi, varsayılanlar dokümandaki metinler. Termal fiş tek dilli bir işletme çıktısıdır, arayüz metni değildir.

### Kol C — Website

- [KOL-C-Web][04.08] Sözleşmede `MenuItem.slug` **yok**, ama `/urun/[slug]` rotası SEO gereği zorunlu (`docs/06` §2). | Etkilenen: `website/lib/slug.ts`, `website/app/urun/[slug]/page.tsx`, `docs/openapi.yaml` `MenuItem` | Geçici çözüm: slug istemcide türetiliyor — `slugify(ad) + "-" + id` (örn. `tavuk-sote-101`). Sondaki kimlik çözümlemeyi tek anlamlı yapıyor; ad değişse bile eski bağlantı çalışıyor ve kanonik slug'a `307` ile taşınıyor. Sözleşmeye `slug` alanı **eklenirse** (kırıcı değil) bu dosya sadeleşir ve slug sunucu kaynaklı olur.
- [KOL-C-Web][04.08] **Teslimat ücreti sipariş oluşturulmadan bilinmiyor.** `Location` şemasında teslimat ücreti alanı yok; ücret yalnızca `OrderDetail.delivery_fee` ile geliyor. | Etkilenen: `website/app/sepet/page.tsx`, `website/app/odeme/page.tsx` | Geçici çözüm: sepet ve ödeme ekranında yalnızca **ara toplam** gösteriliyor, teslimat satırında "Adrese teslimde eklenir / sipariş adımında hesaplanır" yazıyor; kesin toplam sipariş takip ekranında görünüyor. Kullanıcı onaylamadan önce toplamı görmek isteyecektir — sözleşmeye `Location.delivery_fee` veya bir "sepet önizleme" ucu eklenmesi Faz 1.5'te değerlendirilmeli (işletme sorusu #10 ile bağlantılı).
- [KOL-C-Web][04.08] `Error.details` biçimi sözleşmede serbest (`additionalProperties: true`); mock hem mesaj metni hem izinli değer listesi döndürüyor (`{"payment_method":["cash","account"]}`). | Etkilenen: `website/lib/api/client.ts` `ApiError.fieldErrors()` | Geçici çözüm: yalnızca boşluk içeren (cümle gibi görünen) değerler alan hatası olarak gösteriliyor; tek kelimelik değerler atlanıyor, üst düzey `message` gösteriliyor. `details` için sözleşmede bir biçim sabitlenmesi gerekiyor.
- [KOL-C-Web][04.08] Profil güncelleme ve kayıtlı adres defteri için sözleşmede uç yok (`Customer` salt okunur, `Address` yalnızca sipariş içinde). | Etkilenen: `website/app/hesabim/page.tsx` (`docs/06` §2 "Profil, adresler") | Geçici çözüm: `/hesabim` yalnızca görüntüleme yapıyor; adres her siparişte ödeme adımında giriliyor ve ekranda bunun Faz 1 kapsamı olduğu yazıyor.
- [KOL-C-Web][04.08 → 19.08 **BÜYÜK ÖLÇÜDE ÇÖZÜLDÜ**] Yasal metinlerdeki **işletme kimlik bilgileri** verilmedi. | Etkilenen: `website/app/kvkk/page.tsx`, `website/app/mesafeli-satis/page.tsx`, `website/app/gizlilik/page.tsx` | **Durum:** sözleşmeye `SiteContent.legal` bloğu eklendi (`docs/openapi.yaml`), panelde "Yasal kimlik" bölümü açıldı ve değerler girildi: ticari unvan, işletme türü, merkez adresi, vergi dairesi/no. Kaynak 2024 vergi levhası (GİB onay kodu WVVA0KN3E20) — BLD, BBD ile aynı gerçek kişi işletmesi altında. MERSİS ve KEP **kalıcı olarak yok** (ticaret siciline kayıtlı tüzel kişi değil); bu satırlar artık "eksik" sayılmıyor, hiç gösterilmiyor. | **Kalan:** BLD'ye ait telefon ve e-posta hâlâ panelde boş — uydurulmuyor, sayfalarda "girilmesi gerekiyor" olarak görünüyor.
- [KOL-C-Web][19.08] Gizlilik metninin üç açık maddesi duruyor: **ödeme hizmeti sağlayıcısının ticari adı** (kodda gerçek sanal POS yok — `veykemtu/payment` altında nakit, havale ve SİMÜLASYON geçidi var, bkz. `docs/03` §"Faz 1 notu"), **barındırma sağlayıcısı ve sunucu konumu**, **sunucu erişim kayıtlarının saklama süresi**. | Etkilenen: `website/components/site/legal-identity.tsx` `openLegalItems()` | Geçici çözüm: üçü de "yayın öncesi tamamlanacak" listesinde; ödeme maddesi panelde sağlayıcı adı girildiği anda listeden kendiliğinden düşüyor.
- [KOL-C-Web][04.08] `next-intl` kuruldu (tek dil `tr`, locale öneki yok) ama sözlük yalnızca ortak metinleri (başlık, alt bilgi, 404) kapsıyor; sayfa içi uzun kopya hâlâ bileşenlerin içinde. | Etkilenen: `website/messages/tr.json` | Geçici çözüm: altyapı hazır, ikinci dil eklenirse kalan metinler taşınacak. Faz 1'de tek dil olduğu için tam taşıma yapılmadı.
- [KOL-C-Web][04.08] `route`'ta `loading.tsx` bulunması, `notFound()`/`redirect()` çağrılarının HTTP durumunu `200`'e düşürüyor (akış/streaming). | Etkilenen: `website/app/urun/[slug]/`, `website/app/siparis/[id]/`, `website/app/siparislerim/` | Geçici çözüm: durum kodu SEO/doğruluk açısından önemli olan rotalardan `loading.tsx` kaldırıldı; iskelet yalnızca `/menu` ve `/sepet` üzerinde duruyor. Doğrulandı: `/urun/bogus-99999` → `404`, `/urun/yanlis-101` → `307 /urun/tavuk-sote-101`.

### Kol D — Altyapı

- [KOL-D][04.08] **DNS henüz sunucuya bakmıyor.** `benimlezzetdunyam.com.tr`, `www` ve `api` adlarının hiçbiri çözülmüyor. | Etkilenen: TLS, `I-03` | Geçici çözüm: yok — Caddy sertifika alamaz. Gereken A kayıtları: `@`, `www`, `api` → `62.238.102.197`. Kayıtlar yayılmadan üretim yığını başlatılırsa Caddy sonsuz yeniden dener.
- [KOL-D][04.08] Sunucu **Ubuntu 26.04 LTS**, dokümanlar 24.04 varsayıyor (`docs/08` §1). | Etkilenen: `docs/08-kurulum-deploy.md`, `infra/docker-compose.yml` | Geçici çözüm: yığın tamamen Docker içinde çalıştığı için fark büyük ihtimalle zararsız. `I-03`'te doğrulanacak: `get.docker.com` betiği 26.04'ü tanıyor mu, `ufw`/`unattended-upgrades` paket adları aynı mı. **Kasa (MSI) ayrı bir makinedir ve orada 24.04 kararı geçerlidir** (`docs/08` §2.1) — sunucu sürümü kasayı bağlamaz.
## Çözüldü — donanım doğrulaması (04.08, gerçek yazıcıda)

`docs/09-gorev-plani.md` §8 "projenin en büyük tek donanım riski" ilan
ettiği madde **kapandı**. MSI kasada, bağlı yazıcıyla fiziksel olarak
doğrulandı:

| Soru | Cevap |
|---|---|
| Yazıcı kimliği | `0483:5720` — `aaaait Printer`, seri `11101800002` |
| Cihaz dosyası | `/dev/usb/lp1` (**`lp0` değil** — takılma sırasına bağlı, bu yüzden `/dev/thermal0` sembolik bağı şart) |
| Çekirdek modülü | `usblp`, yüklü |
| udev kuralı | Yazıldı ve kuruldu; `/dev/thermal0` → `usb/lp1`, mod `0666`, yazılabilir |
| Fiş basıyor mu | **Evet** |
| Türkçe kod sayfası | **`ESC t 29`** (`1B 74 1D`) |

### Dokümanın yanlış olduğu nokta

`docs/05-mutfakapp.md` §5.2 kod sayfası için `ESC t 13` (PC857) diyordu.
**Bu yazıcıda çalışmıyor** — Türkçe baytlar boşluk basılıyor, o kod
sayfasında glif yok. `n = 0..47` taraması yapıldı, yalnızca `n = 29`
doğru sonuç verdi. Doküman düzeltildi.

Bayt karşılıkları PC857 düzeniyle aynı; farklı olan yalnızca **seçim
numarası**. Gerçek yazıcıda doğrulanan 12 harf: ç ğ ı ö ş ü Ç Ğ İ Ö Ş Ü.

**Ders:** ESC/POS kod sayfası numaraları standart değildir, üreticiye göre
değişir. Yazıcı değişirse tarama tekrarlanmalı —
`infra/kasa/kodsayfasi-tara.sh` tek komutla yapar.
- [KOL-D][04.08] Geliştirme makinesinde araç zinciri kurulu değildi (git/docker/node/dart/php yok, apt indeksi boş). | Etkilenen: tüm hatlar | Geçici çözüm: Node 22 ve Dart SDK `~/.local/sdk` altına sudo'suz kuruldu; git + docker + Flutter Linux masaüstü bağımlılıkları için sudo gerekti, kullanıcı elle koştu.

## Karara bağlanmayı bekleyen iş soruları

Bunlar teknik değil, **işletmenin cevaplaması gereken** sorular. Cevapsız kalırsa varsayılan uygulanır.

| # | Soru | Varsayılan (cevap gelmezse) |
|---|---|---|
| 7 | Abonelik modeli nasıl işleyecek? (haftalık/aylık paket, kaç öğün, iptal kuralı, faturalama dönemi) | **Faz 2.** Faz 1'de yok. Dokümanlarda tanımı bulunmadığı için tasarlanmadı. |
| 8 | Toplu fiyatlama nasıl hesaplanacak? (adet kırılımlı kademe mi, müşteriye özel fiyat listesi mi, sözleşme fiyatı mı) | **Faz 2.** Faz 1'de ürün fiyatı tekildir. |
| 9 | Cari hesap (`account`) ödemesi kimlere açık? Her müşteri seçebilir mi, yönetici tek tek mi yetkilendirir? | Her giriş yapmış müşteri seçebilir; tahsilat sistem dışında takip edilir. |
| 10 | Teslimat ücreti nasıl belirlenir? Sabit mi, bölge bazlı mı, tutar üstü ücretsiz mi? | TastyIgniter'ın kendi teslimat ücreti mekanizması, sabit ücret. |
| 11 | Logo ve nihai renk paleti | Yer tutucu turuncu palet (`#F97316`) ile devam, Gün 6'da değiştirilir. |

## Çözüldü

| # | Soru | Karar | Tarih | Etki |
|---|---|---|---|---|
| 1 | Öğrenci ödemesi: online / tezgahta / bakiye-cüzdan? | **Öğrenci kanalı tamamen iptal** — hiçbir sürümde olmayacak. | 04.08 | `docs/00` §3-4-6-7, `docs/02` §1-2-3-6, `docs/03` (`channel`/`pickup_code`/`group` alanları ve `teslim` fiş tipi silindi), `docs/05` §3/§5.3/§5.5/§10, `docs/06`, `docs/07`, `docs/09`, `docs/10` S2 |
| 2 | Catering tahsilatı: online POS / cari hesap + fatura? | **Online POS alınacak (Kuveyt Türk)**, sağlayıcı sözleşmesi bitene kadar kapalı. Faz 1'de `cash` (kapıda) + `account` (cari) çalışır. | 04.08 | `docs/03` §3'e `payment_methods` alanı eklendi, `docs/04` §5, `docs/06` §3, `docs/10` S1 |
| 3 | Kurum içi sipariş girişi: günlük toplu mu, haftalık şablon mu? | **Kurum içi kanal tamamen iptal.** Yönetici gerekirse admin panelden normal sipariş açar. | 04.08 | `veykemtu/channels` eklentisi ve `veykemtu_order_meta` tablosu iptal edildi (`docs/02` §2, `docs/04` §4) |
| 4 | Öğrenci bildirimi veliye SMS gidecek mi? | Konusuz — öğrenci kanalı iptal. | 04.08 | — |
| 5 | Sipariş kesim saati var mı? | **Var ve yönetilebilir.** Admin panelden sipariş alımı açılıp kapatılabilir (`ordering_enabled`) + günlük kesim saati (`order_cutoff`). | 04.08 | `docs/03` §3, `docs/04` §4.1, `docs/06` §3, `docs/10` S3 |
| 6 | Firma/marka adı, logo, renk paleti | **Ad: "Benim Lezzet Dünyam" (BLD).** Palet turuncu. Logo sonra yapılacak → soru #11'e taşındı. | 04.08 | `README.md`, `docs/04` §2, `docs/05` §5.3, `packages/design_system` |
| — | Alan adı ne olacak? | **`benimlezzetdunyam.com.tr`** — site `www.` ile, API `api.` alt alan adında. Sunucu: `62.238.102.197` (`bldmain`, Ubuntu 26.04 LTS). | 04.08 | `infra/.env.example`, `docs/openapi.yaml` servers, `platform/.env.example`, `website/.env.example` |

## Master prompt ↔ doküman çelişkileri (Oturum 0'da karara bağlandı)

| Konu | Master prompt | Doküman | Karar |
|---|---|---|---|
| KDS veri arayüzü adı | `SiparisKaynagi`, "`docs/05` §5'teki imza" | `OrderSource`, **§4**'te | `OrderSource` — `AGENTS.md` §4 "Türkçe değişken adı kullanma" kuralı gereği. §5 yazdırma bölümüdür, arayüz §4'tedir. |
| Mock sunucu klasörü | `infra/mock-api/` | `infra/mock/` | `infra/mock/` — doküman kazanır (`00-INDEX.md` çelişki kuralı). Compose **servis** adı `mock-api` kaldı, verilen komut aynen çalışır. |
| Kasa betikleri | `infra/ubuntu/kur.sh`, `99-termal-yazici.rules` | `infra/kasa/setup.sh`, `99-thermal-printer.rules` | Doküman kazanır |
| Dev compose | `infra/docker-compose.dev.yml` | `infra/docker-compose.yml` | Çelişki değil, ikisi de var: `.dev.yml` = dev (mysql + platform + mock), `.yml` = prod (`docs/08` §1.2) |
| api_client kaynağı | `openapi.yaml`'dan üretilsin | `platform/openapi.json`'dan (`docs/03` §9) | `docs/openapi.yaml` normatif tohumdur; `platform`'un ürettiği `openapi.json` buna uymak zorunda, CI fark kontrolü yapar (`E-01`) |
| Boş gövde | "`UnimplementedError` olabilir" | `AGENTS.md` §2.5 "placeholder bırakma" | Çelişki değil: Oturum 0 çıktısı **iskelettir**, "bitti" değildir. `X-03` gövdeleri boş bırakılmadı, gerçekten uygulandı — kalan `UnimplementedError` yok. |
| Katalog ucunun adı | Bitirme ölçütünde `GET /api/catalog` | Sözleşmede böyle bir uç yok: `GET /api/locations` + `GET /api/locations/{id}/menu` (`docs/03` §3) | Doküman kazanır. Ölçüt "mock örnek katalog verisi dönüyor" olarak yorumlandı ve iki uçla da doğrulandı. |
