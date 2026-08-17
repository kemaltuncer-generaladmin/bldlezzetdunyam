import { API_BASE_URL, APP_ID, APP_VERSION } from '@/lib/api/client';

/**
 * İstemci hata raportörü — `POST /client-errors` (`docs/openapi.yaml` §Teşhis).
 *
 * Üç yüzeyden çağrılır: `app/error.tsx` (rota hata sınırı),
 * `app/global-error.tsx` (kök yerleşim hatası) ve `instrumentation.ts`
 * (`onRequestError` — Server Component, Route Handler ve Server Action
 * hataları). Modül hem tarayıcıda hem sunucuda çalışır.
 *
 * ## `apiFetch`'ten GEÇMEZ
 *
 * Raportör izlenen yoldan gitmemeli. `apiFetch` hata durumunda `ApiError`
 * fırlatıyor, `AbortError`'ı yeniden atıyor ve ileride bir yeniden deneme ya
 * da oturum yenileme katmanı kazanabilir. Hata bildirme yolunda atılan bir
 * istisna, çağıranı yakalama bloğunun içinde ikinci bir hataya sokar; kendini
 * besleyen döngü tam olarak böyle başlar. Buradaki istek çıplak `fetch`,
 * sonucu okunmuyor ve gövdesi baştan sona `try/catch` içinde.
 *
 * ## `source` GÖVDEDE YOK
 *
 * Sunucu raporun hangi uygulamadan geldiğini `X-App-Id` başlığından türetir.
 * Gövdeye bırakılsaydı site `mutfakapp` yazan bir rapor üretebilir ve
 * mutfağın güvendiği hata monitörüne sahte KDS alarmı düşürebilirdi.
 *
 * ## `navigator.sendBeacon` KULLANILMIYOR — bilinçli
 *
 * Beacon özel başlık taşıyamaz. `X-App-Id` ve `X-App-Version` ise ZORUNLU
 * (`RequireAppHeaders` ara katmanı, `docs/03` §1.1): başlıksız istek uca hiç
 * ulaşmadan `422` alır. Yani beacon ile gönderilen her rapor sessizce
 * kaybolurdu ve bunu fark etmenin yolu yok — istek "gitti" görünür.
 * `fetch(..., { keepalive: true })` beacon'ın verdiği garantiyi (sayfa
 * kapanırken de tamamlanma) başlıklarla birlikte veriyor; beacon'ın tek
 * üstünlüğü olan çok eski tarayıcı desteği, başlığı taşıyamadığı için
 * burada bir üstünlük değil.
 */

/** `ClientErrorReport.kind` — sözleşmedeki bilinen türler. Kapalı enum DEĞİL. */
export type ClientErrorKind = 'unhandled' | 'network' | 'render' | 'parse' | 'manual';

export interface ReportInput {
  /** Hatanın kendisi ya da hazır bir özet metin. */
  readonly error: unknown;
  readonly kind: ClientErrorKind;
  /** Hatanın oluştuğu ekran/rota. Sorgu dizesi BURADA temizlenir. */
  readonly route?: string | null;
  /** Ek bağlam. Kişisel veri ve sır KONMAZ. */
  readonly context?: Record<string, unknown> | null;
}

/* ══════════════════════════════════════════════════════════════════════════
   1. Parmak izi

   `packages/core/lib/src/error_fingerprint.dart` ile BİREBİR aynı tarif.
   İkisi ayrışırsa "web'de tek satır, mobilde altmış satır" gibi kıyaslanamaz
   iki tablo çıkar ve hangi platformun daha çok hata ürettiği sorusunun cevabı
   bozulur. DEĞİŞTİRİLECEKSE İKİSİ BİRLİKTE DEĞİŞİR.
   ══════════════════════════════════════════════════════════════════════════ */

/** Parmak izine giren yığın çerçevesi sayısı — Dart tarafıyla aynı. */
const FRAME_COUNT = 3;

const WHITESPACE_RUN = /\s+/g;
/** `\d` yerine açık aralık: Dart karşılığı da aynı kümeyi siliyor. */
const DIGITS = /[0-9]/g;

const FNV_OFFSET_BASIS = 0xcbf29ce484222325n;
const FNV_PRIME = 0x100000001b3n;
const U64_MASK = 0xffffffffffffffffn;

function normalize(value: string): string {
  return value.replace(WHITESPACE_RUN, ' ').trim();
}

/**
 * FNV-1a, 64 bit.
 *
 * `BigInt` ZORUNLU: `number` 2^53'ten sonra basamak kaybeder ve iki platform
 * ayrışır. Maske her adımda uygulanıyor — Dart'ın 64 bitlik tam sayıları
 * taşmayı kendiliğinden sarmalıyor, JavaScript'te sarmalamayı biz yazıyoruz.
 */
function fnv1a64(bytes: Uint8Array): bigint {
  let hash = FNV_OFFSET_BASIS;
  for (const byte of bytes) {
    hash = (hash ^ BigInt(byte)) & U64_MASK;
    hash = (hash * FNV_PRIME) & U64_MASK;
  }
  return hash;
}

/**
 * [kind], [message] ve [frames]'in ilk üç çerçevesinden 16 haneli onaltılık
 * bir iz üretir.
 *
 * Tarif (Dart karşılığıyla birebir):
 *
 * 1. `kind`, `message` ve ilk üç çerçeve alınır; çerçeve azsa boş dizeyle
 *    tamamlanır — anahtar HER ZAMAN beş alandır. Tamamlanmasaydı iki
 *    çerçeveli bir hata ile üç çerçeveli başka bir hata aynı metne
 *    katlanabilirdi.
 * 2. Her alanda boşluk dizileri tek boşluğa iner, kenarlar kırpılır.
 * 3. Alanlar `|` ile birleşir.
 * 4. **Bütün anahtardan rakamlar silinir.** "Sipariş 8421 basılamadı" ile
 *    "Sipariş 8422 basılamadı" tek hatanın iki tekrarıdır; çerçevelerdeki
 *    satır/sütun numaraları da her yapıda kayar.
 * 5. UTF-8 baytları üzerinde FNV-1a (64 bit), sıfırla doldurulmuş küçük harf
 *    onaltılık.
 *
 * İz bir GÜVENLİK değeri değildir; çakışma direnci değil, ucuzluk ve iki
 * dilde aynı sonucu vermek arandığı için kriptografik özet kullanılmıyor.
 */
export function fingerprint(kind: string, message: string, frames: readonly string[]): string {
  const fields = [
    normalize(kind),
    normalize(message),
    ...Array.from({ length: FRAME_COUNT }, (_, index) => normalize(frames[index] ?? '')),
  ];

  const key = fields.join('|').replace(DIGITS, '');

  return fnv1a64(new TextEncoder().encode(key)).toString(16).padStart(16, '0');
}

/* ══════════════════════════════════════════════════════════════════════════
   2. Çökme döngüsü koruması

   ASIL İŞ BU. Bir hata tek başına zararsız; döngüye giren bir ekran saniyede
   onlarca rapor üretiyor ve kurulu taban, hata monitörünü kendi kendine
   DDoS'a çeviriyor. Dört ayrı kemer var ve hepsi gerekli:

     * tekilleştirme  → aynı iz oturum içinde bir kez, sonrası sayaç
     * jeton kovası   → oturum başına 5 istek, aralarında ≥10 sn
     * soğuma         → aynı iz 6 saat içinde ikinci kez gönderilmez
     * örnekleme      → `CLIENT_ERROR_SAMPLE_RATE` ile üstten kısma
   ══════════════════════════════════════════════════════════════════════════ */

/**
 * Oturum içi tekilleştirme penceresi: aynı parmak izi bir kez gider, sonrası
 * sayaca yazılır ve sayaç en sık bu aralıkla tahliye edilir.
 */
const DEDUPE_WINDOW_MS = 60_000;

/** Oturum başına gönderilebilecek rapor sayısı. */
const BUCKET_CAPACITY = 5;

/** İki rapor arasındaki en kısa süre. */
const MIN_INTERVAL_MS = 10_000;

/** Aynı parmak izinin açılışlar/sekmeler arası soğuma süresi. */
const COOLDOWN_MS = 6 * 60 * 60 * 1000;

/**
 * Yürürlükteki bastırma penceresi.
 *
 * İki kural aynı şeyi farklı ölçekte söylüyor ve BÜYÜK OLAN geçerli:
 * altmış saniyelik tekilleştirme oturum içindeki taban, altı saatlik soğuma
 * ise açılışlar arası tavan. `Math.max` ikisini tek karşılaştırmada
 * birleştiriyor; ayrı ayrı yazılsaydı biri gevşetildiğinde öteki sessizce
 * devre dışı kalırdı.
 */
const SUPPRESS_WINDOW_MS = Math.max(DEDUPE_WINDOW_MS, COOLDOWN_MS);

/** Kalıcı tutulan en fazla kayıt. */
const MAX_RECORDS = 20;

/** Sekme ömrü boyunca kayıtların tutulduğu anahtar. */
const STORAGE_KEY = 'bld.hata.izler';

/** Sunucudaki istek zaman aşımı — hata yolunda beklemek yok. */
const SERVER_TIMEOUT_MS = 2000;

interface SeenRecord {
  /** Son gönderim anı (epoch ms). */
  lastSentEpoch: number;
  /** Bu izin toplam görülme sayısı — bir sonraki raporda bağlama yazılır. */
  count: number;
}

/**
 * Örnekleme oranı (0–1). Tanımsızsa 1: teşhis bilgisini varsayılan olarak
 * kısmıyoruz, kısma kararı sahada verilir.
 *
 * `NEXT_PUBLIC_` ÖNEKİ ZORUNLU. Next.js yalnızca o önekli değişkenleri
 * istemci paketine gömüyor; öneksiz yazılsaydı ayar sunucuda çalışır,
 * tarayıcıda sessizce `undefined` olurdu — yani "örneklemeyi %10'a çektim"
 * diyen biri hâlâ tarayıcıdan %100 rapor alırdı. Öneksiz karşılığı yalnızca
 * sunucu tarafı için yedek olarak okunuyor.
 */
const SAMPLE_RATE = parseRate(
  process.env.NEXT_PUBLIC_CLIENT_ERROR_SAMPLE_RATE ?? process.env.CLIENT_ERROR_SAMPLE_RATE,
);

function parseRate(raw: string | undefined): number {
  if (raw === undefined) return 1;
  const value = Number.parseFloat(raw);
  if (!Number.isFinite(value)) return 1;
  return Math.min(Math.max(value, 0), 1);
}

/** Sunucuda (ve depolama yokken) kullanılan bellek içi kayıt defteri. */
const memoryRecords = new Map<string, SeenRecord>();

let tokensLeft = BUCKET_CAPACITY;
let lastSentAt = 0;

/**
 * Çevrimdışıyken bekleyen TEK rapor.
 *
 * Kuyruk YOK ve olmayacak: çevrimdışı bir cihazda döngüye giren bir ekran
 * sınırsız kuyruğu dakikalar içinde şişirir, sonra bağlantı gelince hepsini
 * birden yollar. Elde tutulacak tek şey en son hata; öncekiler zaten aynı
 * parmak izini taşıyor.
 */
let pending: object | null = null;

function isBrowser(): boolean {
  return typeof window !== 'undefined';
}

/**
 * Kayıt defterini okur.
 *
 * Tarayıcıda `sessionStorage`: sekme ömrü boyunca yaşıyor ve **sayfa
 * yenilenmesinden sağ çıkıyor**. Açılışta çöken bir sayfa yeniden yükleniyor
 * ve bellekteki kova sıfırlanıyor; kayıt kalıcı olmasaydı her yenileme yeni
 * bir kova açar ve koruma hiç devreye girmezdi — Flutter tarafındaki
 * "açılışlar arası soğuma" ile aynı sorun, aynı çözüm.
 */
function readRecords(): Map<string, SeenRecord> {
  if (!isBrowser()) return memoryRecords;

  try {
    const raw = window.sessionStorage.getItem(STORAGE_KEY);
    if (raw === null) return new Map();

    const decoded: unknown = JSON.parse(raw);
    if (typeof decoded !== 'object' || decoded === null) return new Map();

    const records = new Map<string, SeenRecord>();
    for (const [key, value] of Object.entries(decoded as Record<string, unknown>)) {
      if (typeof value !== 'object' || value === null) continue;
      const { lastSentEpoch, count } = value as Partial<SeenRecord>;
      if (typeof lastSentEpoch !== 'number' || typeof count !== 'number') continue;
      records.set(key, { lastSentEpoch, count });
    }
    return records;
  } catch {
    // Depolama kapalı olabilir (gizli sekme, kota). Bellek defteri yeterli.
    return new Map();
  }
}

/** Defteri yazar; en eski kayıtlar atılarak [MAX_RECORDS] ile sınırlanır. */
function writeRecords(records: Map<string, SeenRecord>): void {
  if (records.size > MAX_RECORDS) {
    const oldestFirst = [...records.entries()].sort(
      (a, b) => a[1].lastSentEpoch - b[1].lastSentEpoch,
    );
    for (const [key] of oldestFirst.slice(0, records.size - MAX_RECORDS)) records.delete(key);
  }

  if (!isBrowser()) return;

  try {
    window.sessionStorage.setItem(STORAGE_KEY, JSON.stringify(Object.fromEntries(records)));
  } catch {
    // Kota dolmuş olabilir; kayıt kaybı kabul edilmiş bir kayıp.
  }
}

/* ══════════════════════════════════════════════════════════════════════════
   3. Hatadan rapor çıkarma
   ══════════════════════════════════════════════════════════════════════════ */

function messageOf(error: unknown): string {
  if (error instanceof Error) return error.message || error.name;
  if (typeof error === 'string') return error;
  try {
    return JSON.stringify(error) ?? 'Bilinmeyen hata';
  } catch {
    return 'Bilinmeyen hata';
  }
}

function stackOf(error: unknown): string | null {
  return error instanceof Error && typeof error.stack === 'string' ? error.stack : null;
}

/** Yığın izinin ilk satırları — parmak izi bunlardan hesaplanıyor. */
function framesOf(stack: string | null): string[] {
  if (stack === null) return [];
  return stack
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.startsWith('at ') || line.includes('@'))
    .slice(0, FRAME_COUNT);
}

/**
 * Rotadan sorgu dizesini ve çıpayı atar.
 *
 * Sözleşme bunu açıkça istiyor: adres çubuğundaki parametreler zaman zaman
 * kişisel veri taşır (`?telefon=…`, `?token=…`) ve hata kaydı onları saklamak
 * için yanlış yer.
 */
function cleanRoute(route: string | null | undefined): string | null {
  if (!route) return null;
  const cut = route.split(/[?#]/)[0] ?? '';
  return cut.slice(0, 200);
}

/** Tarayıcı/çalışma ortamı özeti — serbest metin, en fazla 120 karakter. */
function deviceSummary(): string | null {
  if (isBrowser()) {
    const agent = window.navigator.userAgent;
    return agent ? agent.slice(0, 120) : null;
  }
  if (typeof process !== 'undefined' && process.versions?.node) {
    return `node/${process.versions.node} ${process.platform ?? ''}`.trim().slice(0, 120);
  }
  return null;
}

/* ══════════════════════════════════════════════════════════════════════════
   4. Gönderim
   ══════════════════════════════════════════════════════════════════════════ */

function post(body: object): void {
  const url = `${API_BASE_URL}/client-errors`;
  const headers = {
    'Content-Type': 'application/json',
    // İkisi de ZORUNLU (`RequireAppHeaders`): eksikse uç talebi almadan 422
    // döner. `source` bu başlıktan türetiliyor, gövdeden değil.
    'X-App-Id': APP_ID,
    'X-App-Version': APP_VERSION,
    'Accept-Language': 'tr',
  };

  const init: RequestInit = {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
    cache: 'no-store',
    // Kimlik göndermiyoruz: uçta token opsiyonel ve raportörün oturum
    // çerezine hiç dokunmaması, hata yolunu oturum durumundan bağımsız kılar.
    credentials: 'omit',
    ...(isBrowser()
      ? // Sayfa kapanırken de tamamlansın diye. Beacon'ın yerini tutan şey bu.
        { keepalive: true }
      : // Sunucuda beklemek yok: hata yolu istek ömrünü uzatmamalı.
        { signal: AbortSignal.timeout(SERVER_TIMEOUT_MS) }),
  };

  /*
   * Yanıt OKUNMUYOR ve tekrar denenmiyor. Uç her koşulda `204` dönmeye söz
   * veriyor; `429` alındığında sözleşme "sessizce düş" diyor — tekrar
   * denemek oran sınırını doldurur ve asıl teşhisi kaybettirir.
   */
  void fetch(url, init).catch(() => {
    // Ağ yok. Rapor kaybı kabul edilmiş bir kayıp; bekleyen tek rapor
    // yuvasında duruyor ve bir sonraki başarılı denemede gidiyor.
    pending = body;
  });
}

/** Çevrimdışıyken tutulan tek raporu boşaltır. */
function flushPending(): void {
  if (pending === null) return;
  const body = pending;
  pending = null;
  post(body);
}

/* ══════════════════════════════════════════════════════════════════════════
   5. Genel arayüz
   ══════════════════════════════════════════════════════════════════════════ */

/**
 * Hatayı bildirir. **Asla fırlatmaz, `void` döner.**
 *
 * Raportör kendini raporlamaz: gövdenin tamamı `try/catch` içinde ve
 * yakalanan hata yutuluyor. Buradan çıkan bir istisna, hata sınırını ikinci
 * kez tetikleyip sonsuz döngü açardı.
 */
export function reportClientError(input: ReportInput): void {
  try {
    const now = Date.now();

    const message = messageOf(input.error);
    const stack = stackOf(input.error);
    const print = fingerprint(input.kind, message, framesOf(stack));

    const records = readRecords();
    const seen = records.get(print);
    const count = (seen?.count ?? 0) + 1;

    /*
     * TEKİLLEŞTİRME + SOĞUMA tek karşılaştırmada (bkz. `SUPPRESS_WINDOW_MS`).
     *
     * Aynı iz, pencere dolmadan GÖNDERİLMEZ; yalnızca sayacı artar ve bir
     * sonraki gerçek gönderimde `context.occurrence` olarak gider.
     */
    if (seen && now - seen.lastSentEpoch < SUPPRESS_WINDOW_MS) {
      records.set(print, { lastSentEpoch: seen.lastSentEpoch, count });
      writeRecords(records);
      return;
    }

    // Örnekleme: sayaç yine de işleniyor, yalnızca tel trafiği kısılıyor.
    if (SAMPLE_RATE < 1 && Math.random() >= SAMPLE_RATE) return;

    // Jeton kovası. Dolduğunda SESSİZCE DÜŞÜLÜR — kuyruğa alınmaz.
    if (tokensLeft <= 0) return;
    if (lastSentAt > 0 && now - lastSentAt < MIN_INTERVAL_MS) return;

    tokensLeft -= 1;
    lastSentAt = now;
    records.set(print, { lastSentEpoch: now, count });
    writeRecords(records);

    const route = cleanRoute(
      input.route ?? (isBrowser() ? window.location.pathname : null),
    );

    /*
     * Gövde sözleşmedeki `ClientErrorReport`. `source` YOK — sunucu onu
     * `X-App-Id`'den türetiyor. Uzunluk sınırları burada uygulanıyor:
     * sunucu kesiyor ama sekiz bin karakterlik bir izi tele koymak, hata
     * yolunda olan bir istemcinin bir de bant genişliğini yakmasıdır.
     */
    const body = {
      message: message.slice(0, 500),
      kind: input.kind,
      stack: stack === null ? null : stack.slice(0, 8000),
      route,
      occurred_at: new Date(now).toISOString(),
      device: deviceSummary(),
      context: {
        ...(input.context ?? {}),
        /*
         * Bastırılan tekrarların sayısı: tek satır gönderiyoruz ama kaç kez
         * olduğunu monitörün bilmesi gerekiyor.
         *
         * PARMAK İZİ GÖVDEYE KONMUYOR. Sözleşmede karşılığı yok
         * (`ClientErrorReport` içinde `fingerprint` alanı bulunmaz) ve
         * sunucunun kendi birleştirme anahtarı ayrı hesaplanıyor
         * (`docs/control/monitor.md` §Tekilleştirme). İki anahtarı aynı
         * satıra koymak, hangisinin doğru olduğu sorusunu doğururdu.
         */
        occurrence: count,
      },
    };

    flushPending();
    post(body);
  } catch {
    // RAPORTÖR KENDİNİ RAPORLAMAZ. Buradan bir şey fırlatmak, hata sınırını
    // ikinci kez tetikler ve döngüyü başlatır.
  }
}
