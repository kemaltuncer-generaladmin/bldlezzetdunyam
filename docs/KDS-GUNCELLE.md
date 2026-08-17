# KDS güncellemesi yayınlama

Mutfak kasasındaki (`mutfakapp`) yeni bir sürümün sahadaki kasalara ulaşmasının
tam prosedürü. **Otomasyon yok** — adımlar elle koşulur ve sırası bağlayıcıdır.

Kapsam dışı: yeni bir kasa kurmak (→ [`infra/kasa/README.md`](../infra/kasa/README.md)),
cari arşivi gibi tek seferlik dağıtım adımları (→ [`RUNBOOK.md`](RUNBOOK.md)).

> Bu belge 17.08.2026'da 1.0.2 yayınlanırken uçtan uca koşularak yazıldı.
> Aşağıdaki her tuzak o koşumda gerçekten yaşandı.

---

## 0. Önce karar: değişiklik nereye dokunuyor?

Bir KDS düzeltmesi çoğu zaman **iki tarafa birden** dokunur. K-23 (test fişi
döngüsü) böyleydi: dört hatanın ikisi kasada, ikisi sunucudaydı.

| Değişiklik | Sıra |
|---|---|
| Yalnız kasa | Doğrudan §1'den başla |
| Kasa + sunucu | **Önce sunucu dağıtılır**, sonra kasa yayınlanır |

Tersini yaparsan yarım düzeltme yayınlarsın: kasa yeni, sunucu eski davranır ve
şikâyet devam eder. Sunucu tarafı `main`'e push edilip Coolify dağıtımı inince
§4'e geçilir.

Sunucunun gerçekten dağıtıldığını **dosya varlığıyla** doğrula, API yanıtına
bakarak değil — boş bir günün menü yanıtı yeni alanları zaten taşımaz ve seni
"dağıtılmamış" sanmaya iter:

```bash
ssh root@62.238.102.197 'APP=$(docker ps --format "{{.Names}}" | grep "^app-" | head -1); docker exec "$APP" ls /var/www/platform/extensions/veykemtu/bridgeapi/src/Services/<YeniSinif>.php'
```

Göçlerin koştuğunu da veritabanından doğrula (`information_schema` üzerinden
kolon/tablo varlığı) — `php artisan migrate:status` yalnız Laravel çekirdek
göçlerini gösterir, TastyIgniter eklenti göçlerini **göstermez**.

---

## 1. Kapılar

Paket üretmeden önce ikisi de temiz olmalı:

```bash
cd BLD/mutfakapp && flutter analyze && flutter test
```

`flutter analyze` sıfır uyarı, testlerin tamamı yeşil. Kırık bir kasa sürümü
sahada geri almak zordur: kasa güncellemeyi kendi indirir ve kurar.

---

## 2. Sürüm numarasını üç yerde birden yükselt

`paketle.sh` üçü ayrışırsa **bilerek reddeder**. Bu iyi bir denetim: sürüm
ayrışırsa kasa kendi sürümünü yanlış bildirir ve `min_supported` kapısı yanlış
kasayı engeller — sessiz bir arıza olurdu.

| Yer | Örnek |
|---|---|
| `mutfakapp/pubspec.yaml` | `version: 1.0.2+2` |
| `mutfakapp/lib/src/config/app_config.dart` | `static const String appVersion = '1.0.2';` |
| `paketle.sh` argümanı | `./infra/kasa/paketle.sh 1.0.2` |

Sürüm numarası semver: saf hata düzeltmesi → yama (`1.0.1` → `1.0.2`), yeni
davranış → minör.

---

## 3. Paketi üret

```bash
cd BLD && ./infra/kasa/paketle.sh 1.0.2
```

**`derle.sh` ile karıştırma.** `derle.sh` TEK BİR kasa için derler, sunucu
adresini ve o kasanın mutfak token'ını ikiliye gömer ve o makineye kurar.
`paketle.sh` ise sahadaki TÜM kasalara dağıtılacak paketi üretir ve token
gömmez — paket GitHub'da durduğu için gömmek onu yayınlamak olurdu, ayrıca
paketi kuran her kasa aynı cihaz kimliğine bürünürdü.

Gereken araçlar: `flutter`, `ninja`, `cmake`, `dpkg-deb`. Çıktı:

```
build/paket/mutfakapp_1.0.2_amd64.deb   +  sha256
```

sha256'yı not al, §5'te gerekecek.

---

## 4. GitHub Releases'e yükle

`gh` gerekiyor. Kurulu değilse ve `sudo` parola istiyorsa sudosuz kur:

```bash
VER=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | grep -m1 '"tag_name"' | cut -d'"' -f4 | sed 's/^v//')
curl -fsSL -o /tmp/gh.tar.gz "https://github.com/cli/cli/releases/download/v${VER}/gh_${VER}_linux_amd64.tar.gz"
tar xzf /tmp/gh.tar.gz -C /tmp && cp "/tmp/gh_${VER}_linux_amd64/bin/gh" ~/.local/bin/
```

Sonra `gh auth login` (bu adımı **insan** yapar; token girilmesi gereken bir iş).

`paketle.sh 1.0.2 --yayinla` yüklemeyi kendisi yapar. Elle yapılacaksa:

```bash
cd BLD
gh release create "mutfakapp-v1.0.2" build/paket/mutfakapp_1.0.2_amd64.deb \
  --title "mutfakapp 1.0.2" --notes "K-23: test fişi döngüsü düzeltmesi"
```

> **Tuzak.** `gh` depoyu bulunduğun dizinin git remote'undan çözer. BLD deposu
> dışından çağırırsan `release not found` der ve sürümü yayınlamamışsın
> sanırsın. Emin olmak için `--repo kemaltuncer-generaladmin/bldlezzetdunyam`
> ver.

İndirme adresini al:

```bash
gh release view mutfakapp-v1.0.2 --repo kemaltuncer-generaladmin/bldlezzetdunyam \
  --json assets --jq '.assets[] | select(.name | endswith(".deb")) | .url'
```

---

## 5. Sürümü sunucuya kaydet — **kasaların gördüğü adım budur**

§3 ve §4 bittiğinde kasa hâlâ hiçbir şey görmez. Kasa `GET /api/app-version`
sorar ve o uç `veykemtu_app_releases` tablosunu okur. Kayıt yapılmadan
"güncellemeleri denetle" **yok** der.

Komut üretimde koşar:

```bash
ssh root@62.238.102.197 'APP=$(docker ps --format "{{.Names}}" | grep "^app-" | head -1); docker exec -w /var/www/platform "$APP" php artisan veykemtu:surum --publish --app=mutfakapp --surum=1.0.2 --url="<gh release adresi>" --sha256=<sha256> --notes="<not>"'
```

> **`--min-supported` VERME.** Alt sınırı yeni sürüme eşitlemek, güncellemeyi
> henüz almamış her kasayı anında engelleyici ekrana düşürür — ve güncellemenin
> kendisi o ekranın arkasında kalır. Alt sınır ancak eski bir sürümün sunucuyla
> gerçekten uyumsuz olduğu, bilinçli bir kararla yükseltilir.

Seçenek adı `--surum`, `--version` **değil**: `--version` Symfony Console'un
ayrılmış seçeneği.

---

## 6. Doğrula

```bash
curl -s -H "X-App-Id: website" -H "X-App-Version: 1.0.0" -H "Accept-Language: tr" \
  "https://api.benimlezzetdunyam.com.tr/api/app-version?app_id=mutfakapp&app_version=1.0.1"
```

`latest` yeni sürümü, `min_supported` **eski** değeri göstermeli.

---

## 7. Kasaya indir

Kasa saatlik denetimde kendi görür. Hemen istiyorsan Kontrol Merkezi →
**KDS Yönetimi** → ilgili cihaz → `update` komutu.

> Komut kuyruğu K-23'ten beri sınırlı: teslim edilemeyen bir komut 3 denemeden
> ve 30 dakikadan sonra kesin sonuca bağlanır, sonsuza dönmez. Aynı komutu iki
> kez göndermek de tek satır üretir (`REPRINT` hariç — aynı fişi ikinci kez
> basmak meşru).

Kurulumdan sonra kasanın ayarlar ekranında sürümün yeni değeri gösterdiğini
gör; `veykemtu_kitchen_devices.app_version` de bir sonraki sağlık atımında
güncellenir.

---

## Geri alma

Yayınlanmış bir sürümü geri almanın yolu **eski sürümü yeniden yayınlamak
değil** (kasa sürüm karşılaştırması yapar, geriye gitmez). Bozuk bir sürüm
çıktıysa:

1. Düzeltmeyi içeren **yeni** bir yama sürümü çıkar (`1.0.3`) ve §1-6'yı koş.
2. Acil durumda tek kasayı elle kurtar: `infra/kasa/derle.sh` ile o makinede
   yerel derleme yap ve kur.

---

## Bu belgeyi güncelleyen değişiklikler

| Tarih | Ne değişti |
|---|---|
| 17.08.2026 | İlk sürüm; 1.0.2 yayını sırasında uçtan uca koşularak yazıldı |
