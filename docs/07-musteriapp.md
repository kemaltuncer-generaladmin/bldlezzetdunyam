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

| Ekran | İçerik |
|---|---|
| Açılış | Token kontrolü, sürüm kontrolü (`/api/app-version`) |
| Giriş / Kayıt | E-posta + şifre, KVKK onay kutusu |
| Menü | Kategori sekmeleri, ürün listesi, arama |
| Ürün detayı | Görsel, açıklama, seçenekler, adet, not, sepete ekle |
| Sepet | Kalemler, adet düzenleme, tutar özeti |
| Ödeme | Teslimat tipi/adres, istenen saat, ödeme yöntemi |
| Ödeme web görünümü | Sanal POS `redirect_url` (WebView), dönüşte sonuç |
| Sipariş takip | Adım çubuğu, canlı durum |
| Siparişlerim | Geçmiş liste, detay |
| Hesabım | Profil, adresler, çıkış |
| Zorunlu güncelleme | `min_supported` altındaysa engelleyici ekran |

## 3. Sunucu neyi belirler

Uygulamada iş kuralı **kodlanmaz**; şu üçünü sunucu söyler, uygulama yalnızca uygular:
- Hangi vitrin ve menü gösterilecek → `GET /api/locations`, `GET /api/locations/{id}/menu`
- Sipariş alınıyor mu → `is_open` + `ordering_enabled`
- Hangi ödeme yöntemleri açık → `payment_methods`

`delivery_type=pickup` seçilirse teslimat adresi adımı atlanır ve teslimat ücreti eklenmez; bu, sunucunun döndüğü tutarla doğrulanır (istemci kendi hesabına güvenmez).

## 4. Push bildirimleri

- İlk girişten sonra izin istenir; token `POST /api/me/push-token` ile gönderilir.
- Bildirime tıklanınca ilgili sipariş takip ekranı açılır (deep link).
- Uygulama açıkken bildirim in-app banner olarak gösterilir, ekrandaki veri anında yenilenir.

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
