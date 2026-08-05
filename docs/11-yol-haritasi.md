# 11 — Yol Haritası (Faz 2)

Bu dosya **planı** tutar, kararı değil. Buradaki bir madde kodlanmadan önce
`docs/openapi.yaml` ve ilgili spesifikasyon güncellenir; sözleşme her zaman
önce gelir (`AGENTS.md` §2.3).

Hedef, kullanıcının cümlesiyle: *"bir nevi kendi yemeksepeti uygulamamızı
yazıyoruz."* Bu, Faz 1'in "tek vitrin, sabit ücret, kuponsuz" varsayımlarının
tamamının değişeceği anlamına geliyor. Aşağıdaki sıra bunu **kırmadan**
yapmanın sırasıdır.

---

## 0. Değişmeyen kurallar

Faz 2'de de geçerli, tartışmaya kapalı:

- **Para her yerde `int` kuruştur.** Hiçbir katmanda `float` para
  tutulmaz — kampanya ve kupon hesapları ondalık hataya en açık yerdir ve
  bir kuruşluk sapma raporları tutmaz hâle getirir.
- **Fiyatı sunucu hesaplar.** İstemcinin gönderdiği tutar yok sayılır
  (`docs/03` §4). Kupon ve kampanya bunu değiştirmez: indirim de sunucuda
  hesaplanır, istemci yalnızca **gösterir**.
- **Tek kaynak veritabanıdır.** Ürün, fiyat, görsel, stok, kampanya —
  hepsi admin panelden girilir, API'den okunur. Hiçbir istemci kendi
  kopyasını gömmez.
- **Şema kırılmaz.** Yalnızca ekleme yapılır.

---

## 1. Sıra ve bağımlılıklar

```
F2-01 Adres modeli + Maps
   └─ F2-02 Teslimat bölgeleri (poligon)
        ├─ F2-03 Bölgeye göre asgari sepet + teslimat ücreti
        └─ F2-04 Gel-al noktaları ve saatleri
F2-05 Fiyat motoru (tek yerde hesap)
   ├─ F2-06 Kampanyalar
   └─ F2-07 Kupon kodları
F2-08 Admin: yoğunluk ve şalterler tek ekranda
```

`F2-05` **kritik yol üzerindedir**: kampanya ve kuponu ayrı ayrı, her biri
kendi indirim mantığıyla yazmak, iki indirimin çakıştığı gün toplamın
yanlış çıkmasıyla biter. Önce tek bir hesap motoru, sonra kuralları ona
takmak.

---

## 2. F2-01 — Adres modeli ve Google Maps

**Bugün:** adres serbest metin (`line1`, `district`, `city`). Koordinat yok.

**Hedef:** her adresin `lat`/`lng`'si olacak; bölge, ücret ve asgari tutar
buradan türeyecek.

| Parça | Karar |
|---|---|
| Adres tamamlama | Places Autocomplete (müşteri yazarken) |
| Koordinat | Geocoding — **sunucuda**, istemcide değil |
| Harita gösterimi | Maps JavaScript API (web), `google_maps_flutter` (mobil) |

> **Geocoding neden sunucuda:** anahtar istemciye gömülürse kotayı
> yabancılar harcar. Ayrıca teslimat ücretini belirleyen koordinatı
> istemcinin göndermesi, istemcinin ücreti seçmesi demektir — sunucu
> adresi kendisi çözmeli.

**Anahtar yönetimi:** `GOOGLE_MAPS_SERVER_KEY` (IP kısıtlı, sunucu) ve
`GOOGLE_MAPS_BROWSER_KEY` (HTTP referer kısıtlı, yalnızca Autocomplete).
İkisi de `.env`, repoya girmez.

**Maliyet tuzağı:** Autocomplete oturum başına ücretlendirilir. `sessiontoken`
kullanılmazsa her tuş vuruşu ayrı istek sayılır ve fatura 10-20 katına çıkar.
Bu, plan aşamasında not edilmezse sahada fark edilmez.

**Sözleşme etkisi (additive):**
- `Address` şemasına `lat`, `lng`, `place_id` (hepsi opsiyonel)
- Yeni uç: `POST /addresses/resolve` → serbest metni koordinata çevirir,
  bölge ve ücret önizlemesi döner

---

## 3. F2-02 / F2-03 — Teslimat bölgeleri ve bölgeye göre kurallar

**Bugün:** tek `delivery_fee`, tek `min_order_total` — tüm şehir için aynı.

**Hedef:** bölge bazlı. TastyIgniter'ın **kendi `location_areas` tablosu
bunu zaten yapıyor** (poligon ya da mesafe tabanlı) — yeni tablo açmıyoruz.

| Bölge alanı | Ne |
|---|---|
| poligon / yarıçap | Sınır |
| `min_order_total` | O bölgenin asgari sepeti |
| `delivery_fee` | O bölgenin ücreti |
| `eta_minutes` | Tahmini süre |

**Sözleşme etkisi:**
- `Location.min_order_total` ve `delivery_fee` **kalır** (kırmıyoruz) ama
  artık "varsayılan bölge" değeri anlamına gelir
- Yeni: `GET /locations/{id}/zones` ve `POST /addresses/resolve` yanıtında
  `zone` nesnesi

> **Kırılma riski:** istemciler bugün `Location.delivery_fee`'yi ekranda
> gösteriyor. Bölge geldiğinde bu değer "adres girilene kadar geçerli
> tahmin" olur. İstemcilerin adres seçilince **yeniden hesaplatması**
> şart; yoksa müşteriye 40 ₺ gösterip 60 ₺ tahsil ederiz.

---

## 4. F2-04 — Gel-al noktaları

**Bugün:** `delivery_type=pickup` var ama nereden alınacağı sabit (tek vitrin).

**Hedef:** birden fazla gel-al noktası, her birinin kendi saatleri ve
hazırlık süresi. Poligon gerekmez; nokta + çalışma takvimi yeter.

---

## 5. F2-05 — Fiyat motoru

**Bunu önce yazmadan kampanya/kupon yazılmaz.**

Tek bir sınıf, tek bir sıra:

```
1. Kalem ara toplamı        (adet × birim fiyat + seçenek farkları)
2. Ürün/kategori kampanyaları
3. Sepet kampanyaları        (X al Y öde, kademeli indirim)
4. Kupon                     (en fazla BİR tane)
5. Teslimat ücreti           (bölgeden; kampanya bunu sıfırlayabilir)
6. Yuvarlama                 (kuruş, tek yerde)
```

Çıktı **döküm** olmalı, tek bir toplam değil: müşteri "neden bu fiyat"
sorusunu ekranda görebilmeli ve destek çağrısı gelmemeli.

**Sözleşme etkisi:** `OrderDetail`'e `discounts: [{code, label, amount}]`
ve `discount_total`. `total` alanının **anlamı değişmez** (ödenecek tutar);
bu yüzden eski istemciler kırılmaz.

---

## 6. F2-06 — Kampanyalar

| Tür | Örnek |
|---|---|
| Yüzde / tutar indirimi | Çorbalarda %20 |
| X al Y öde | 3 al 2 öde |
| Kademeli | 500 ₺ üstü ücretsiz teslimat |
| Zaman kısıtlı | Hafta içi 14:00-16:00 |
| Kanal kısıtlı | Yalnızca mobil uygulama |

Her kampanyanın: başlangıç/bitiş, öncelik, **birleşebilir mi** bayrağı.

> **En sık hata:** iki kampanyanın üst üste binmesi ve toplamın eksiye
> düşmesi. Motor, indirim toplamını ara toplamla sınırlamalı ve bunun
> testi olmalı.

---

## 7. F2-07 — Kupon kodları

TastyIgniter'da **`ti-ext-coupons` zaten kurulu** (`platform/vendor/`).
Kendi kupon tablomuzu açmadan önce onun karşılayıp karşılamadığına
bakılacak — `AGENTS.md` §2.4.

Karşılaması gerekenler: tek kullanımlık / çok kullanımlık, müşteri başına
limit, asgari sepet, ürün-kategori kısıtı, son kullanma, ilk sipariş
kuponu.

**Sözleşme etkisi:** `POST /orders` gövdesine `coupon_code` (opsiyonel),
ve doğrulama için `POST /coupons/validate` — müşteri kodu ödeme ekranında
girer girmez geçerliliğini görmeli, siparişi gönderdiğinde değil.

> **Güvenlik:** kupon doğrulama ucu kaba kuvvete açıktır (geçerli kod
> aramak). `bld-auth` benzeri sıkı bir oran sınırı ve müşteri başına
> deneme limiti gerekir.

---

## 8. F2-08 — Admin: yoğunluk ve şalterler tek ekranda

**Bugün:** yoğunluk şalteri mutfak ekranından açılıp kapanıyor ve API'de
görünüyor (`Location.busy`), **ama admin panelde bir yüzü yok.**

Aynı durum diğer şalterler için de geçerli: `ordering_enabled`,
`order_cutoff`, `min_order_total`, `delivery_fee`, `payment_methods` —
hepsi `location_options` tablosunda yaşıyor ve bugün yalnızca
`veykemtu:setup` komutuyla veya doğrudan veritabanından değişiyor.

**Plan:** eklentiye tek bir "BLD Ayarları" admin sayfası. Değerler
`LocationGate` üzerinden okunup yazılır — ikinci bir kaynak açılmaz.

> **Neden TastyIgniter'ın Location formuna eklemiyoruz:** değerler
> `location_options`'ta duruyor ve çekirdek formun kaydetme akışına
> girmek, çekirdek davranışını uzaktan değiştirmek demek. Kendi
> sayfamız `extensions/veykemtu/` sınırının içinde kalıyor (ADR-02).

---

## 9. Bu plan tamamlanınca değişecek belgeler

| Dosya | Ne değişecek |
|---|---|
| `docs/openapi.yaml` | Adres koordinatları, bölge, indirim, kupon uçları |
| `docs/02-veri-modeli.md` | `location_areas` kullanımı, indirim tabloları |
| `docs/03-api-sozlesmesi.md` | Yeni uçların insan tarafı |
| `docs/06/07` | Adres seçimi ve harita ekranları |
| `docs/10-test-kabul.md` | Bölge/kampanya/kupon kabul ölçütleri |

---

## 10. Faz 2'ye girmeden kapatılacaklar

Bunlar Faz 1'in açık uçlarıdır ve yeni özellik eklemeden önce kapanmalı:

- [ ] `POS_ALLOW_SIMULATION` kaldırılacak, gerçek sanal POS bağlanacak —
      **açık kaldığı sürece her sipariş bedava**
- [ ] GitHub Actions hesap düzeyinde çalışmıyor (18 koşu, hiçbiri
      runner'a atanmadı) — Faz 2'ye CI'sız girilmez
- [ ] `BACKUP_REMOTE` tanımsız; yedekler yalnızca aynı sunucuda
- [ ] iOS derlemesi için Mac + Apple Developer Program
