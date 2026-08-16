# 07 — Müşteri Mobil Uygulaması

## 1. Teknoloji

- Flutter 3.x → **Android (Google Play) + iOS (App Store)**. Karar
  05.08.2026'da güncellendi; önceki plan yalnızca Android'di.
- Bundle/uygulama kimliği **iki platformda da aynı**: `com.veykemtu.catering`.
  Ayrışırsa push kayıtları ve deep link'ler iki ayrı uygulamaya bölünür.
- State: Riverpod
- Model: freezed + json_serializable
- API: `packages/api_client`
- Push: Firebase Cloud Messaging
- Yerel: `shared_preferences` (token), `sqflite` (sepet)

## 2. Ekranlar

Alt gezinme **5 sekme**: Ana Sayfa (keşif) · Menü · Aboneliklerim · Siparişlerim · Hesabım.

| Ekran | İçerik |
|---|---|
| Açılış | Token kontrolü, sürüm kontrolü (`/api/app-version`) |
| Giriş / Kayıt | **Kurumsal kayıt** (firma bilgileri + giriş bilgileri), KVKK onay kutusu, **"Beni hatırla"** |
| Ana Sayfa (keşif) | Hero + **aktif abonelik** ve **cari bakiye** kısayolu (girişliyken) + son sipariş + kategori/öne çıkan şeritleri |
| Menü | Kategori sekmeleri, ürün listesi, arama |
| Ürün detayı | Görsel, açıklama, seçenekler, adet, not, sepete ekle |
| Sepet | Kalemler, adet düzenleme, tutar özeti |
| Ödeme | Teslimat tipi/adres, istenen saat, ödeme yöntemi |
| Ödeme sayfası | Sanal POS `redirect_url` **sistem tarayıcısında** açılır |
| Sipariş takip | Adım çubuğu, canlı durum |
| Siparişlerim | Geçmiş liste, detay |
| **Aboneliklerim** | Abonelik listesi, detay (duraklat/devam/iptal), yeni talep |
| **Cari hesabım** | Güncel bakiye + hareket ekstresi (Hesabım'dan kısayol) |
| Hesabım | Firma + yetkili profil, kısayollar (Aboneliklerim/Cari/Adres), bildirim ayarı, çıkış |
| Sipariş kapalı | `can_order = false` kullanıcının sepet/ödemeye girişinde bilgi ekranı |
| Zorunlu güncelleme | `min_supported` altındaysa engelleyici ekran |

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

### Neden WebView değil?

Spesifikasyonun ilk hâli uygulama içi WebView diyordu. Üç sebeple sistem
tarayıcısına geçildi: 3-D Secure akışında bankalar uygulama içi WebView'ları
giderek daha çok reddediyor; kullanıcı adres çubuğundaki alan adını görüp
doğrulayamıyor; `webview_flutter` web hedefini desteklemiyor ve tek kod yolu
kalmıyordu.

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
- **Push (FCM):** token kaydı hazır (`POST /api/me/push-token`) ama token'ı
  Firebase üretir; Firebase projesi ve imzalama bilgileri repoda yoktur ve
  uydurulamaz. Bunlar girildiğinde sözleşme değişmeden devreye girer.

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

- Sepet hesaplama (adet, seçenek fiyat farkı, ara toplam) unit test
- API hata durumlarının kullanıcı mesajına çevrilmesi unit test
- Zorunlu güncelleme mantığı (`version < min_supported`) unit test
- Giriş → sipariş akışı widget test (API mock)
- **Stok tavanı** (`bld_core` `maxAddable` → sepet) unit test (`cart_stock_cap_test.dart`)
- **Abonelik/cari sözleşme örnekleri** `packages/api_client` contract test'te ayrıştırılır

> **Sipariş kapısı testi kaldırıldı (Faz 0).** `Session.canOrder` ve
> `session_gating_test.dart` yok; cari hesapla birlikte "yalnız onaylı hesap
> sipariş verir" kuralı düştü ve test adıyla zorunlu kıldığı kod artık
> bulunmuyor. Yerine sepetin stok tavanı denetimi geldi.

## 8. B2B: abonelik ve cari hesap self-servisi (Faz 2 — UYGULANDI)

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
  devam ettir, her durumda iptal (onay diyaloğuyla). "Yeni abonelik talebi" günleri,
  günlük adedi, başlangıcı ve teslimat tipini toplar; **fiyat alanı yoktur** — talep
  `pending` doğar, admin fiyatlandırır.
- **Cari hesabım:** güncel bakiye (pozitif = borç) + hareket ekstresi. Tutarların
  hiçbiri istemcide hesaplanmaz; `Money.format` ile gösterilir.
- Ana sayfada girişliyken aktif abonelik ve cari bakiye kısayolu görünür.
