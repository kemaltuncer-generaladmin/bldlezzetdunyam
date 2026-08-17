# 07 — Müşteri Mobil Uygulaması

## 1. Teknoloji

- Flutter 3.x → **Android (Google Play) + iOS (App Store)**. Karar
  05.08.2026'da güncellendi; önceki plan yalnızca Android'di.
- Bundle/uygulama kimliği **iki platformda da aynı**: `com.veykemtu.catering`.
  Ayrışırsa push kayıtları ve deep link'ler iki ayrı uygulamaya bölünür.
- State: Riverpod
- Model: freezed + json_serializable
- API: `packages/api_client`
- Push: **YOK.** Firebase Cloud Messaging kapsam dışı — gerekçe §4.
- Yerel: `shared_preferences` (token), `sqflite` (sepet)

## 2. Ekranlar

Alt gezinme **5 sekme**: Ana Sayfa (keşif) · Menü · Aboneliklerim · Siparişlerim · Hesabım.

| Ekran | İçerik |
|---|---|
| Açılış | Token kontrolü, sürüm kontrolü (`/api/app-version`) |
| Giriş / Kayıt | **Kurumsal kayıt** (firma bilgileri + giriş bilgileri), KVKK onay kutusu, **"Beni hatırla"** |
| Ana Sayfa (keşif) | Duyuru bandı + hero + **aktif abonelik** kısayolu (girişliyken) + son sipariş + günün menüsü şeridi |
| Menü | Gün seçici, günün menüsü kartları, kalan porsiyon rozeti, kesim geri sayımı |
| Günün kalemi detayı | Görsel, açıklama, alerjenler, seçenekler, adet, not, sepete ekle |
| Sepet | Kalemler, adet düzenleme (stok tavanı denetimli), tutar özeti |
| Ödeme | Teslimat tipi/adres, istenen saat, ödeme yöntemi |
| Sipariş takip | Adım çubuğu, canlı durum, **ödeme adımı** (§3) |
| Siparişlerim | Geçmiş liste, detay |
| **Aboneliklerim** | Abonelik listesi, detay (duraklat/devam/iptal/gün atlama), yeni talep, **sözleşme onayı ve dönem ödemesi** |
| Hesabım | Firma + yetkili profil, kısayollar (Aboneliklerim/Adres), bildirim ayarı, çıkış |
| Zorunlu güncelleme | `min_supported` altındaysa engelleyici ekran |

> **Değişen ve kaldırılan ekranlar (Faz 0–1).** *Katalog ürün detayı* yerini
> **günün kalemi detayına** bıraktı: kalem artık o GÜNÜN menüsünden çözülüyor,
> çünkü fiyatı o güne özel olabiliyor (`DailyMenuItem.effective_unit_price`) ve
> günden bağımsız açılan bir ekran hangi günün fiyatını gösterdiğini
> söyleyemezdi. *Ayrı ödeme sayfası* kalktı — ödeme uygulama içinde yürüyor
> (§3). *Cari hesabım* kalktı: bakiye/ekstre diye bir kavram yok
> (`docs/02` §7.2). *Sipariş kapalı* bilgi ekranı da kalktı — sipariş kapısı
> yok (§8).

## 3. Sunucu neyi belirler

Uygulamada iş kuralı **kodlanmaz**; şu üçünü sunucu söyler, uygulama yalnızca uygular:
- Hangi vitrin ve menü gösterilecek → `GET /api/locations`, `GET /api/locations/{id}/menu`
- Sipariş alınıyor mu → `is_open` + `ordering_enabled`
- Hangi ödeme yöntemleri açık → `payment_methods`

`delivery_type=pickup` seçilirse teslimat adresi adımı atlanır ve teslimat ücreti eklenmez; bu, sunucunun döndüğü tutarla doğrulanır (istemci kendi hesabına güvenmez).

### "Beni hatırla"

Giriş ekranındaki kutu **işaretliyken** (varsayılan) token `shared_preferences`
içine yazılır ve oturum uygulama kapansa da sürer — bugüne kadarki davranış
budur. İşaretli DEĞİLKEN token yalnızca bellekte tutulur, diske hiç yazılmaz:
uygulama kapandığında oturum biter. Tercihin kendisi diske yazılır, token
yazılmaz.

### Adres alanları ve harita

İl **sabittir** (Konya), ilçe iki seçenekli listeden gelir (Selçuklu, Karatay)
ve harita hizmet alanı kutusunun dışına çıkmaz — `docs/00-genel-bakis.md` §4.1.
Ödeme ekranında kayıtlı bir adres seçiliyken haritadan iğne bırakılırsa iğne
**adres defterine de işlenir**: müşteri kapısını bir kez göstermeli, her
siparişte yeniden değil. Deftere yazılan değerler formdaki metinler değil,
kayıtlı adresin kendi alanlarıdır — o sipariş için yapılan düzeltme deftere
sızmaz.

### Ödeme: ne WebView, ne dış tarayıcı — `next_action` durum makinesi

Bu bölüm iki kez değişti ve ikisinin de gerekçesi duruyor.

**Önce WebView bırakıldı.** Spesifikasyonun ilk hâli uygulama içi WebView
diyordu. Üç sebeple vazgeçildi: 3-D Secure akışında bankalar uygulama içi
WebView'ları giderek daha çok reddediyor; kullanıcı adres çubuğundaki alan
adını görüp doğrulayamıyor; `webview_flutter` web hedefini desteklemiyor ve
tek kod yolu kalmıyordu.

**Sonra dış tarayıcı da bırakıldı** ve ödeme uygulamanın içine alındı. Bu
turun kararı bu:

- **Müşteri uygulamadan ÇIKIYOR ve dönmüyordu.** `redirect_url`
  `url_launcher` ile sistem tarayıcısına gönderiliyordu; sayfa bittiğinde
  uygulamaya geri dönecek bir yol yoktu. Müşteri ödemesinin ne olduğunu ancak
  siparişlerim ekranını kendisi açarsa görüyordu.
- **Karar noktası yanlış alandaydı.** `redirect_url` bir ARAÇ, `next_action`
  ise sunucunun KARARI. Sıradaki adım artık tek yerden okunuyor ve tekil
  sipariş ile abonelik ödemesi aynı sözlüğü paylaşıyor.

Sözlük gevşek bir enum'dur (`docs/03` §15.2): `none` \| `otp` \| `three_ds` ve
tanınmayan her değer `unknown`. **`unknown` bilerek `none` sayılmıyor:**
atlanmış bir doğrulamayı "bitti" göstermek, ödenmemiş bir siparişi ödenmiş
saymaktır. Sunucu yeni bir adım eklediğinde eski uygulama onu sessizce
yutmuyor, açıkça "bu sürüm bu adımı yürütemiyor" diyor.

**Tekil siparişte adımın GÖVDESİ henüz yok:** sözleşmede siparişe ait bir
kod-onay ya da ödeme-yoklama ucu bulunmuyor (yalnız
`/subscriptions/{id}/payments…` var). Bu yüzden uygulama adımı kullanıcıya
AÇIKÇA söylüyor ve onu, ödeme durumunu beş saniyede bir tazeleyen takip
ekranına bırakıyor. Abonelik ödemesinde ise akış tam: kod ekranı, doğrulama ve
sonuç aynı ekranda yürüyor.

## 4. Bildirimler

İki ayrı iş var ve karıştırılmamalı:

| Ne | Nasıl | Uygulama kapalıyken |
|---|---|---|
| **Günlük menü hatırlatması** | Cihazda zamanlanır, her gün seçilen saatte (varsayılan 10:30) | **Çalışır** |
| **Sipariş durumu** | Takip yoklaması durum değişimini görünce bildirir | Çalışmaz — push gerekir |

- Günlük hatırlatma sunucuya bağlı değildir; çevrimdışı da çalışır ve bataryayı
  yoklamaya harcamaz. Ayar Hesabım ekranında, varsayılan **kapalı**.
- İzin reddedilirse ayar açılmaz. "Açık" görünen ama hiç bildirim atmayan bir
  anahtar, kullanıcının uygulamaya güvenini bozan sessiz arızalardan biridir.
- Aynı durum iki kez bildirilmez: hangi durumun bildirildiği cihazda tutulur
  (yoklama beş saniyede bir çalışıyor).
- Bildirime dokunulunca ilgili sipariş takip ekranı açılır.
- **Push (FCM) KAPSAM DIŞI.** `POST /api/me/push-token` sözleşmede duruyor ve
  silinmedi (uyum kuralı §1.4), ama **hiçbir bildirim göndermiyor**: token'ı
  Firebase üretir, Firebase projesi ve imzalama bilgileri repoda yoktur ve
  uydurulamaz. Müşteriye ulaşmanın bugünkü iki yolu **SMS** ve **uygulama-içi
  duyuru**'dur. Duyuru yalnız uygulama açıkken çekilir; "teslim edildi" diye
  bir kavram yoktur, "ekranda çizildi" vardır — kapatma işareti sunucuda
  tutuluyor ki aynı bant her açılışta, her cihazda yeniden çıkmasın
  (`docs/02` §10.8).

Zaman dilimi veritabanı yüklenmez: Türkiye sabit UTC+3 ve `packages/core`
aynı kararı zaten vermiş durumda (~1 MB IANA verisi taşımaya değmiyor).

## 5. Çevrimdışı davranış

Sipariş vermek internet gerektirir. İnternet yoksa:
- Son çekilen menü önbellekten **salt okunur** gösterilir, "Çevrimdışı" rozeti
- Sepet yerelde korunur
- Sipariş gönderimi engellenir, açık mesaj verilir

## 6. Google Play

- Paket adı: `com.veykemtu.catering` (nihai ad yönetici onayıyla)
- Hedef API seviyesi Play'in güncel zorunluluğuna uygun
- Veri güvenliği formu: toplanan veriler (ad, e-posta, telefon, adres, konum yok) beyan edilir
- Gizlilik politikası URL'i `website/` üzerinde yayında olmalı
- **Kapalı test kanalı ilk günden açılır** — inceleme süresi geliştirmeyle paralel işlesin
- İmzalama anahtarı CI gizli değişkenlerinde; repoda yok

## 7. Testler

Bu liste **bir zorunluluk listesidir**, dosya envanteri değil: bir davranışın
testi varsa adı burada geçer, çünkü test adıyla zorunlu kılınan şey silindiğinde
doküman yalan söylemeye başlar (aşağıdaki kutuya bakın).

- Sepet hesaplama (adet, seçenek fiyat farkı, ara toplam) unit test
  (`cart_calculation_test.dart`)
- **Stok tavanı** (`bld_core` `maxAddable` → sepet) unit test
  (`cart_stock_cap_test.dart`) — altın veri kümesi
  `docs/contract/sales-rules.cases.json`
- API hata durumlarının kullanıcı mesajına çevrilmesi unit test
  (`api_error_message_test.dart`)
- Zorunlu güncelleme mantığı (`version < min_supported`) unit test
  (`version_check_test.dart`)
- Günün menüsü ekranı: gün seçici, kesim geri sayımı, tükenmiş kalem
  (`daily_menu_screen_test.dart`)
- **Abonelik dönem ödemesi**: `next_action` sözlüğü, `unknown` adımın "bitti"
  sayılmaması, yoklama (`subscription_payment_test.dart`)
- Abonelikte gün atlama (`subscription_skip_day_test.dart`)
- Uygulama-içi duyuru: gösterim, kapatma, eylem düğmesi
  (`announcement_test.dart`)
- Bildirim zamanlaması ve izin reddi (`notifications_test.dart`)
- Çevrimdışı önbellek (`local_cache_test.dart`)
- Abonelik/sözleşme yanıt örnekleri `packages/api_client` contract test'inde
  ayrıştırılır

> **Sipariş kapısı testi kaldırıldı (Faz 0).** `Session.canOrder` ve
> `session_gating_test.dart` **yok**; cari hesapla birlikte "yalnız onaylı
> hesap sipariş verir" kuralı düştü ve testin adıyla zorunlu kıldığı kod artık
> bulunmuyor. Bu satır silinmiyor: adı geçen bir testi arayıp bulamayan kişi,
> testin mi yoksa dokümanın mı eskidiğini bilemez. Yerine sepetin stok tavanı
> denetimi geldi.

## 8. B2B: abonelik self-servisi (Faz 2 — UYGULANDI, cari kısmı kaldırıldı)

Sistem tamamen kurumsal. İş kuralı istemcide değil sunucuda; uygulama yalnız
sunucu bayraklarını uygular.

- ~~**Sipariş kapısı:**~~ **KALDIRILDI (Faz 0).** Cari hesapla birlikte
  "yalnız onaylı kurumsal hesap sipariş verir" kuralı da düştü; ödeme
  yöntemleri `online` ve `cash` ve ikisi de herkese açık. `Session.canOrder`,
  `_requiresOrdering` kapısı ve "Sipariş kapalı" bilgi ekranı yok. Sepet/ödeme
  yolları yalnızca OTURUM istiyor; bir hesap yine de kapatılırsa bunu
  `POST /orders` söyler ve ekran hata metnini gösterir.
- **Kurumsal kayıt:** form iki bölüm — "Firma bilgileri" (ticari unvan + yetkili
  **zorunlu**, vergi opsiyonel) ve "Giriş bilgileri". `account_type` gönderilmez;
  sunucu `corporate` yazar.
- **Aboneliklerim:** liste + detay. Detayda `active` iken duraklat, `paused` iken
  devam ettir, ileri bir günü atla, her durumda iptal (onay diyaloğuyla).
  "Yeni abonelik talebi" günleri, günlük adedi, başlangıcı ve teslimat tipini
  toplar; **fiyat alanı yoktur** — talep `pending` doğar, admin fiyatlandırır.
- **Sözleşme onayı:** abonelik `awaiting_contract` durumundayken uygulama
  sözleşme metnini **kayıttan** çizer (şablondan değil — metin onay anında
  donmuştur) ve SMS koduyla onaylatır. Onaylanmış bir sözleşme daha sonra
  açıldığında **aynı metni** gösterir.
- **Dönem ödemesi:** `awaiting_payment` durumunda 30 günlük peşin dönem
  ödeniyor. Adım `next_action` ile yürüyor (§3) ve tutar **istemcide
  hesaplanmaz** — `porsiyon × birim fiyat` çarpımını sunucu yapar, uygulama
  `Money.format` ile yalnız gösterir.
- ~~**Cari hesabım:**~~ **KALDIRILDI.** Bakiye/ekstre diye bir kavram yok;
  `/api/account/*` uçları da kalktı (`docs/03` §12.2).
- Ana sayfada girişliyken aktif abonelik kısayolu ve **duyuru bandı** görünür.
