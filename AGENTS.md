# AGENTS.md — Ajanlar İçin Çalışma Kuralları

Bu dosya repo kökündedir ve **her ajan, her görevden önce bunu okur.** Kurallar tartışmaya açık değildir; bir kuralın yanlış olduğunu düşünüyorsan görevi durdur ve `docs/` altındaki ilgili dokümana itiraz notu bırak, kendi kararınla sapma.

---

## 0. Projenin tek cümlesi

Bir catering şirketi için sipariş altyapısı: müşteri (web veya mobil) sipariş verir → sipariş backend'de tek kaynakta doğar → mutfaktaki Ubuntu kasada çalışan KDS uygulamasına düşer → fiş basılır → mutfak hazırlar → durum güncellenir → müşteri anlık takip eder.

## 1. Değişmez mimari kararlar

| Katman | Teknoloji | Klasör |
|---|---|---|
| Backend + Admin Panel | TastyIgniter (PHP 8.3 / Laravel) + MySQL | `platform/` |
| Müşteri web sitesi | Next.js 15 (App Router, TypeScript) | `website/` |
| Müşteri mobil | Flutter (Android + iOS — Google Play ve App Store) | `musteriapp/` |
| Mutfak ekranı (KDS) | Flutter **Linux desktop** — Ubuntu 24.04 | `mutfakapp/` |
| Ortak Dart paketleri | Dart (pub workspace) | `packages/` |
| Altyapı | Docker Compose, Caddy | `infra/` |

**Android tablet planı iptal edilmiştir.** Mutfak yazılımı yalnızca MSI kasadaki Ubuntu üzerinde çalışır. `mutfakapp/` içinde Android'e dair kod, bağımlılık veya hedef **bulunmayacaktır**.

**Öğrenci ve kurum içi sipariş kanalları iptal edilmiştir.** Tek sipariş türü vardır: catering. Kodda `channel`, `pickup_code`, `ogrenci`, `kurum_ici`, `kantin` geçen hiçbir alan, enum değeri, ekran veya tablo **bulunmayacaktır**. Sipariş çeşitliliği yalnızca `delivery_type` (`delivery` \| `pickup`) ile ifade edilir. Gerekçe ve etkiler: `docs/00-genel-bakis.md` §4.

## 2. Mutlak yasaklar

1. **`platform/vendor/` altına dokunma.** TastyIgniter çekirdeği ve resmî eklentiler asla düzenlenmez. Tüm davranış değişikliği `platform/extensions/veykemtu/` altında kendi eklentimizde olur. Çekirdek dosyada tek satır diff gören review otomatik reddedilir.
2. **Sırları commit etme.** API anahtarı, sanal POS bilgisi, imzalama sertifikası, `.env` gerçek değerleri repoya girmez. Yalnızca `.env.example` şablonları commitlenir.
3. **Şema kırma.** Yayınlanmış bir API alanının adını veya tipini değiştirme, alan silme. Sadece ekleme yapılır (bkz. `docs/03-api-sozlesmesi.md` §1.4). Sözleşmenin normatif biçimi **`docs/openapi.yaml`**'dır; istemci modelleri elle yazılmaz, bu dosyadan üretilir.
4. **Kendi kütüphaneni yazma.** HTTP istemci, tarih işleme, state yönetimi için dokümanda belirtilen paketleri kullan. Alternatif öneriyorsan önce sor.
5. **Placeholder bırakma.** `TODO`, `lorem ipsum`, `throw UnimplementedError()` içeren kod "bitti" sayılmaz. Bitmeyen işi PR'da açıkça belirt.

## 3. Görev alma ve teslim protokolü

1. Görevini `docs/09-gorev-plani.md` içinden al. Her görevin bir kimliği var (`B-01`, `K-03` gibi).
2. Başlamadan önce görevin bağımlılıklarının tamamlandığını doğrula. Bağımlılık bitmemişse başlama, plan sahibine bildir.
3. Dal aç: `feat/<gorev-id>-kisa-aciklama` (örn. `feat/K-03-escpos-yazdirma`).
4. Commit mesajı: `<gorev-id>: ne yapıldı` (örn. `K-03: ESC/POS yazdırma kuyruğu eklendi`).
5. PR açarken şablonu doldur: hangi görev, hangi kabul ölçütleri karşılandı, nasıl test edildi.
6. **Kabul ölçütü `docs/10-test-kabul.md` dosyasındadır.** Kendi ölçütünü uydurma.

## 4. Kod standartları

**PHP (platform/):** PSR-12. `composer lint` temiz geçmeli. Eklenti isimlendirme: `veykemtu/<modul>`. Migration'lar geri alınabilir (`down()` yazılacak).

**TypeScript (website/):** `strict: true`. `any` yasak — bilinmeyen tip için `unknown` + tip daraltma. ESLint + Prettier yapılandırması repoda; `npm run lint` temiz geçmeli. Server Component varsayılan; `"use client"` yalnızca gerçekten gerekliyse.

**Dart (musteriapp/, mutfakapp/, packages/):** `flutter analyze` sıfır uyarı. State yönetimi: **Riverpod**. Model sınıfları `freezed` + `json_serializable`. Sabit metinler doğrudan koda yazılmaz, `l10n` üzerinden gelir (Türkçe varsayılan).

Üretilen `*.freezed.dart` / `*.g.dart` dosyaları **commitlenir** — böylece klonlayan ajan `build_runner` koşmadan derleyebilir. Bunlar **elle düzenlenmez**; birleştirme çakışması çıkarsa çözüm `dart run build_runner build --delete-conflicting-outputs` koşup sonucu almaktır, satır satır çakışma çözmek değil.

**Genel:** Fonksiyonlar tek iş yapar. Yorum "ne" değil "neden" açıklar. Türkçe değişken adı kullanma — kod İngilizce, arayüz metinleri Türkçe.

## 5. Test beklentisi

- Backend: her yeni endpoint için en az bir feature test (mutlu yol + bir hata yolu).
- Website: kritik akış (menü → sepet → sipariş) için bir e2e testi (Playwright).
- Flutter: iş mantığı içeren her sınıf için unit test. UI testi zorunlu değil.
- Yazdırma alt sistemi: ESC/POS byte üretimi için golden test (beklenen byte dizisi sabit dosyada tutulur).

## 6. Belirsizlikte ne yapılır

Doküman bir konuyu kapsamıyorsa: **uydurma.** Şu sırayı izle:
1. `docs/` altındaki diğer dosyalarda cevap var mı bak.
2. Yoksa, en küçük ve en geri alınabilir varsayımı yap, kodda `// VARSAYIM:` yorumu bırak ve PR açıklamasında listele.
3. Karar mimariyi etkiliyorsa (yeni bağımlılık, yeni servis, şema değişikliği) **kod yazma**, önce sor.

## 7. Doküman haritası

| Dosya | İçerik |
|---|---|
| `docs/00-genel-bakis.md` | Ürün kapsamı, roller, sözlük |
| `docs/01-mimari.md` | Sistem mimarisi, ADR'ler, bileşen sınırları |
| `docs/02-veri-modeli.md` | Şema, sipariş durum makinesi |
| `docs/03-api-sozlesmesi.md` | Tüm endpoint'ler, istek/yanıt örnekleri (insan için) |
| `docs/openapi.yaml` | **Normatif sözleşme** (OpenAPI 3.1) — istemciler bundan üretilir |
| `docs/04-platform.md` | TastyIgniter kurulumu, eklenti geliştirme |
| `docs/05-mutfakapp.md` | KDS spesifikasyonu, ESC/POS, kiosk |
| `docs/06-website.md` | Next.js site spesifikasyonu |
| `docs/07-musteriapp.md` | Flutter mobil spesifikasyonu |
| `docs/08-kurulum-deploy.md` | Ubuntu kurulumu, Docker, CI/CD |
| `docs/09-gorev-plani.md` | 1 haftalık görev dağılımı, bağımlılık grafiği |
| `docs/10-test-kabul.md` | Kabul ölçütleri, uçtan uca senaryolar |
| `docs/11-yol-haritasi.md` | Faz 2 planı: Maps, bölgeler, kampanya, kupon |
