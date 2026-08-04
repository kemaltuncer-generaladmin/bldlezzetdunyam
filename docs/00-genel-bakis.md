# 00 — Genel Bakış

## 1. Problem

Catering şirketi bugün siparişleri telefon, WhatsApp ve kağıt üzerinden alıyor. Sorunlar: sipariş kaybı, mutfağa geç ulaşma, üretim miktarının son dakikada belirsiz kalması, müşterinin "siparişim ne durumda" sorusuna cevap verecek bir yer olmaması.

## 2. Çözümün sınırı

Sistem üç kanaldan sipariş toplar, tek mutfağa düşürür, mutfağı bir ekranla yönetir ve müşteriyi bilgilendirir. **Sistem bir muhasebe, İK veya lojistik yazılımı değildir.** Fatura kesmez (bkz. §6), kurye rotası çizmez, personel vardiyası yönetmez.

## 3. Kullanıcı rolleri

| Rol | Kim | Nereden kullanır | Ne yapar |
|---|---|---|---|
| **Müşteri** | Dış catering müşterisi (kurum veya birey) | `website/` veya `musteriapp/` | Menü görür, sipariş verir, siparişini takip eder |
| **Mutfak personeli** | Aşçı / mutfak sorumlusu | `mutfakapp/` (Ubuntu kasa) | Siparişleri görür, durum ilerletir, fiş basar |
| **Yönetici** | İşletme sahibi / müdür | Admin panel (Mac, tarayıcı) | Menü/fiyat yönetir, sipariş alımını açıp kapatır, rapor alır |

## 4. Tek sipariş kanalı — catering

**Karar (04.08, işletme sahibi):** Sistemde **tek** sipariş türü vardır: dış catering müşterisinin web veya mobilden verdiği sipariş. Öğrenci kanalı ve kurum içi sipariş kanalı **iptal edilmiştir; hiçbir sürümde bulunmayacaktır.**

| Nasıl gelir | Teslimat | Fiş |
|---|---|---|
| Web/mobil, catering müşterisi | Adrese gönderim (`delivery`) veya gel-al (`pickup`) | Mutfak fişi + müşteri fişi |

Bunun sözleşmeye yansıması: API'de `channel`, `channel_label`, `pickup_code` alanları ve `teslim` fiş tipi **yoktur**. Sipariş çeşitliliği yalnızca `delivery_type` (`delivery` \| `pickup`) üzerinden ifade edilir.

> **Neden alan tamamen silindi de tek değerli enum bırakılmadı?** ADR-09 alan **eklemeye** izin verir, silmeye vermez. İleride yeni bir kanal gerekirse `channel` alanını *eklemek* geriye uyumludur; bugün tek değerli enum bırakıp yarın değer eklemek ise istemcilerdeki exhaustive `switch` bloklarını kırar. Düşük riskli yön silmektir.

## 5. Uçtan uca akış

```
Müşteri sipariş verir (web/mobil)
        │
        ▼
Backend: sipariş kaydı oluşur (durum = yeni)
        │
        ├──► Mutfak ekranına düşer (WebSocket/polling)
        │         │
        │         ▼
        │    Mutfak fişi otomatik basılır
        │         │
        │         ▼
        │    Personel: onayla → hazırlanıyor → hazır
        │         │
        │         ▼
        │    Müşteri fişi basılır
        │
        └──► Müşteriye push/bildirim gider (her durum değişiminde)
                  │
                  ▼
             yolda → teslim edildi
```

## 6. Kapsam dışı (bilinçli olarak)

| Konu | Neden | Ne zaman |
|---|---|---|
| Fiziksel POS / ÖKC entegrasyonu | Yalnızca sanal POS kullanılacak | Hiç |
| e-Arşiv fatura | Mali entegrasyon ayrı proje; termal fiş **bilgi fişidir, mali belge değildir** | Faz 3 |
| Stok / mal kabul | Sipariş akışı önce oturmalı | Faz 2 |
| **Öğrenci siparişi / kantin vitrini** | İşletme kararı: kapsam dışı | **Hiç** |
| **Kurum içi sipariş girişi (ayrı kanal)** | İşletme kararı: kapsam dışı. Yönetici gerekirse admin panelden normal sipariş açar | **Hiç** |
| Öğrenci cüzdan/bakiye | Öğrenci kanalı iptal edildi | Hiç |
| Reçete / porsiyon maliyeti | Stok modülüne bağımlı | Faz 3 |
| iOS uygulaması | Aynı Flutter kodundan derlenir | Faz 3 |
| Kurye takip / rota | Tek araçlı operasyon, ihtiyaç yok | — |

## 7. Sözlük

| Terim | Anlam |
|---|---|
| **KDS** | Kitchen Display System — mutfak ekranı uygulaması (`mutfakapp/`) |
| **Vitrin (location)** | TastyIgniter'ın çoklu şube kavramı. Faz 1'de **tek vitrin** vardır: catering. Çoklu vitrin yeteneği platformdan bedava gelir, kullanılmaz. |
| **ESC/POS** | Termal yazıcı komut protokolü |
| **Üretim listesi** | Aktif siparişlerin ürün bazında toplamı ("40 tavuk sote") |
| **Eklenti (extension)** | TastyIgniter'ın modül birimi; tüm özel kodumuz burada yaşar |
| **Kasa** | Mutfaktaki MSI bilgisayar (Ubuntu 24.04) |

## 8. Kalite hedefleri

- Sipariş verildikten sonra mutfak ekranında görünme süresi: **< 3 saniye** (WebSocket ile < 1 sn)
- Mutfak fişi basımı: sipariş düştükten sonra **otomatik, insan müdahalesi olmadan**
- Fiş kaybı: **sıfır** — yazıcı kapalı/kağıtsız olsa bile kuyrukta bekler
- Web sitesi ilk yükleme: **< 2 saniye** (SSR)
- Kasa uygulaması: elektrik gelince **otomatik açılır**, kimse müdahale etmez
