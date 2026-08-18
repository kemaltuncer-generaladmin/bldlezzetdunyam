import 'server-only';

/**
 * TAZE OKUMALAR İÇİN MİKRO-ÖNBELLEK (süreç içi) + TEK-UÇUŞ.
 *
 * ## Çözdüğü sorun
 *
 * Sipariş kararı veren her yol vitrin ve günün menüsünü `'fresh'`
 * (`cache: 'no-store'`) okuyor — gerekçesi `lib/api/catalog.ts`'te ve doğru:
 * yönetici şalteri kapattığında altmış saniye boyunca sipariş alınamaz.
 *
 * Ama `no-store`, Next.js'in İKİ ayrı önbelleğini birden kapatıyordu:
 *
 *  1. **Data Cache** — kapanması İSTENEN şey.
 *  2. **Request Memoization** — aynı render içinde aynı GET'in tekrarını
 *     eleyen React katmanı. Bu katman zaten Route Handler'larda ve Server
 *     Action'larda HİÇ ÇALIŞMIYOR (Next.js: "memoization only applies to the
 *     React Component tree ... it doesn't apply to fetch requests in Route
 *     Handlers").
 *
 * Sonuç ölçüldü: menüde tek bir "Sepete ekle" tıklaması platforma **on iki**
 * ayrı HTTP isteği doğuruyordu —
 *
 * | Kaynak | `/locations` | `/daily-menu` | `/menu-calendar` |
 * |---|---|---|---|
 * | `addToCartAction` | 1 | 1 | — |
 * | eylemin RSC yeniden çizimi (`revalidatePath`) | 1 | 1 | 1 |
 * | `router.refresh()` (kaldırıldı) | 1 | 1 | 1 |
 * | `CartSummaryPanel` → `/api/sepet-ozeti` | 1 | 1 | — |
 * | `CartSummaryBar` → `/api/sepet-ozeti` | 1 | 1 | — |
 *
 * Hepsi aynı saniyenin içinde, hepsi aynı iki cevabı istiyor. Kullanıcının
 * hissettiği "kasma" bu.
 *
 * ## Neden 2 saniye ve neden bu güvenli
 *
 * Buradaki pencere ISR'nin 60 saniyesiyle aynı şey DEĞİL. `'fresh'`in
 * koruduğu iş kuralı "şalter kapandıktan sonra sipariş alınmasın"; iki
 * saniyelik bir pencere o kuralı ölçülebilir biçimde delmiyor — yöneticinin
 * tuşa bastığı an ile müşterinin tıkladığı anın iki saniyeden yakın olması
 * hâlinde bile karar SUNUCUDA bir kez daha veriliyor
 * (`LocationGate::assertAcceptsOrder`, `DailyMenuService::assertOrderable`).
 * Yani bu katman en kötü ihtimalle EKRANI iki saniye eskitir, sipariş
 * kabulünü değil.
 *
 * `CATALOG_FRESH_TTL_MS=0` ile tamamen kapatılabilir; o zaman davranış
 * eskisiyle birebir aynı olur.
 *
 * ## Tek-uçuş (single flight)
 *
 * TTL'den bağımsız olarak, aynı anahtar için uçuşta bir istek varsa ikinci
 * çağıran onu BEKLER, ikinci bir HTTP isteği açmaz. Sepet çubuğu ile sepet
 * kutusunun aynı anda attığı iki `/api/sepet-ozeti` isteği bu yüzden tek bir
 * platform isteğine iniyor — TTL sıfır olsa bile.
 *
 * ## Kapsam
 *
 * YALNIZCA KİMLİKSİZ KATALOG OKUMALARI. Anahtar üreten tek yer
 * `lib/api/catalog.ts` ve `lib/api/daily-menu.ts`; token taşıyan hiçbir
 * yanıt buraya girmiyor ve girmemeli — süreç içi bir harita, oturumlar arası
 * paylaşılır.
 */

/** Yönetici panelden kaydettiğinde pencere sıfırlanır (`/api/icerik-tazele`). */
const DEFAULT_TTL_MS = 2000;

/**
 * En fazla kaç ayrı anahtar tutulur.
 *
 * Anahtar sayısı doğal olarak küçük: bir vitrin + ileri görüş penceresi kadar
 * gün (bugün 7) + takvim aralığı. Tavan yine de var, çünkü `?gun=` adresten
 * geliyor ve geçerli biçimdeki her tarih ayrı bir anahtar üretebilir — sınırsız
 * bir harita, adres uydurarak belleği şişirmeye açık olurdu.
 */
const MAX_ENTRIES = 128;

function readTtl(): number {
  const raw = process.env.CATALOG_FRESH_TTL_MS;
  if (raw === undefined || raw.trim() === '') return DEFAULT_TTL_MS;

  const parsed = Number.parseInt(raw, 10);
  // Negatif ya da sayı olmayan değer "kapalı" değil, YAPILANDIRMA HATASI.
  // Varsayılana düşmek, yazım hatasını sessizce yutmaktan iyi: kapatmak
  // isteyen açıkça `0` yazar.
  if (!Number.isFinite(parsed) || parsed < 0) return DEFAULT_TTL_MS;
  return parsed;
}

export const FRESH_TTL_MS = readTtl();

type Entry = { value: unknown; expiresAt: number };

const entries = new Map<string, Entry>();
const inflight = new Map<string, Promise<unknown>>();

/**
 * Süresi dolmuşları at; hâlâ taşıyorsa en eski eklenenden başlayarak kırp.
 *
 * `Map` ekleme sırasını koruduğu için ilk anahtarlar en eskileridir; ayrı bir
 * LRU tutmak bu boyuttaki bir haritada kazandığından çok karmaşıklık getirirdi.
 */
function prune(now: number): void {
  if (entries.size <= MAX_ENTRIES) return;

  for (const [key, entry] of entries) {
    if (entry.expiresAt <= now) entries.delete(key);
  }

  while (entries.size > MAX_ENTRIES) {
    const oldest = entries.keys().next();
    if (oldest.done) break;
    entries.delete(oldest.value);
  }
}

/**
 * `load`'u anahtar başına en fazla `FRESH_TTL_MS`'de bir çalıştırır ve eş
 * zamanlı çağrıları tek bir uçuşta birleştirir.
 *
 * HATA ÖNBELLEĞE ALINMAZ: reddedilen bir istek `entries`'e yazılmıyor, yalnız
 * uçuş kaydı siliniyor. Aksi hâlde tek bir ağ hatası iki saniye boyunca
 * herkese aynı hatayı verirdi — geçici bir kesintiyi kalıcılaştırmak.
 */
export function freshRead<T>(key: string, load: () => Promise<T>): Promise<T> {
  const now = Date.now();

  if (FRESH_TTL_MS > 0) {
    const hit = entries.get(key);
    if (hit !== undefined && hit.expiresAt > now) return Promise.resolve(hit.value as T);
  }

  // Tek-uçuş TTL'den bağımsız: pencere sıfır olsa bile aynı anda açılmış iki
  // istek tek cevabı paylaşmalı.
  const pending = inflight.get(key);
  if (pending !== undefined) return pending as Promise<T>;

  const promise = load()
    .then((value) => {
      if (FRESH_TTL_MS > 0) {
        const settledAt = Date.now();
        entries.set(key, { value, expiresAt: settledAt + FRESH_TTL_MS });
        prune(settledAt);
      }
      return value;
    })
    .finally(() => {
      inflight.delete(key);
    });

  inflight.set(key, promise);
  return promise;
}

/**
 * Pencereyi elle sıfırlar — yönetici panelde "kaydet"e bastığında
 * (`/api/icerik-tazele`) çağrılır.
 *
 * Uçuştaki istekler İPTAL EDİLMİYOR: onlar zaten sunucudan yeni cevap
 * bekliyor ve iptal etmek, bekleyen çağıranlara hata döndürmek olurdu.
 */
export function dropFreshCache(): void {
  entries.clear();
}
