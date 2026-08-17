/**
 * BUGÜNE SİPARİŞ VERİLEBİLİR OLMASINI KURAR — varsaymaz.
 *
 * ## Neden var
 *
 * Satış akışını sınayan testler ("Sepete ekle" düğmesine basanlar) tek bir
 * yazısız varsayıma dayanıyordu: *bugün sipariş alınıyor*. Seed'deki vitrinin
 * kesim saati `08:00`, servis günleri Pazartesi–Cuma. Yani süit, İstanbul'da
 * saat 08:00'i geçtikten sonra ya da hafta sonu koşulduğunda KESİN olarak
 * kırmızıya dönüyordu: günün menüsü `is_orderable: false` geliyor, bütün
 * "Sepete ekle" düğmeleri kapanıp etiketleri sebebe dönüşüyor ("Bugüne
 * sipariş alınmıyor") ve testler düğmeyi hiç bulamıyordu.
 *
 * Hata da tam olarak orada göstermiyordu kendini: `getByRole('button',
 * {name: /Sepete ekle/})` "görünür değil" diyordu, "kesim saati geçti"
 * demiyordu — hatanın gösterdiği yer ile sebebi arasında bağ yoktu.
 *
 * ## Neden `.mjs` ve neden iki çağıranı var
 *
 * Aynı tarif İKİ AYRI ANDA gerekiyor:
 *
 *   1. `npm run build`'DEN ÖNCE — ana sayfa statik/ISR üretiliyor, yani
 *      derleme anındaki menü durumu HTML'e gömülüyor. Mock o an kapalıysa
 *      ana sayfanın bandı "Bugüne sipariş alınmıyor" diye üretiliyor ve
 *      önbellek penceresi boyunca öyle servis ediliyor; testin sonradan
 *      mock'u açması bu HTML'i değiştirmiyor.
 *   2. HER TESTTE — `/__mock/reset` vitrini seed'e geri alıyor
 *      (`state.reset()` içinde `structuredClone(LOCATION)`), yani kesim saati
 *      her sıfırlamada geri geliyor.
 *
 * Birincisi düz `node` ile (`e2e/prepare-mock.mjs`), ikincisi Playwright'ın
 * TypeScript koşucusundan çağrılıyor. Tarif TEK yerde dursun diye dosya sade
 * ESM JavaScript: `node` da içe aktarabiliyor, `e2e/mock.ts` de. İki kopya
 * yazmak, birinin sessizce sapması demekti.
 *
 * ÇALIŞTIRILABİLİR GİRİŞ AYRI DOSYADA (`prepare-mock.mjs`): Playwright bu
 * modülü kendi koşucusunda CommonJS'e çeviriyor ve `import.meta` orada
 * sözdizimi hatası veriyor — "doğrudan mı çalıştırıldım" kontrolü bu yüzden
 * burada duramıyor.
 */

/** Sözleşme uçlarının kökü (`/api` dahil). */
const API_URL = (process.env.NEXT_PUBLIC_API_URL ?? 'http://127.0.0.1:4010/api').replace(
  /\/+$/,
  '',
);

/** Sunucunun kökü. `/__mock/*` kancaları `/api` ALTINDA DEĞİL, kökte duruyor. */
const API_BASE = API_URL.replace(/\/api$/, '');

const HEADERS = {
  'X-App-Id': 'website',
  'X-App-Version': '1.0.0',
  'Accept-Language': 'tr',
  'Content-Type': 'application/json',
};

/** İşletme saatindeki bugün (`YYYY-AA-GG`). */
export function businessToday() {
  /*
   * Saat dilimi AÇIKÇA veriliyor: koşucunun kendi saat dilimi mock'unkinden
   * farklı olabilir ve gece yarısına yakın koşumda iki taraf başka gün
   * seçerdi. `sv-SE` zaten `2026-08-17` biçimi veriyor.
   */
  return new Intl.DateTimeFormat('sv-SE', {
    timeZone: 'Europe/Istanbul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
}

async function post(path, body) {
  const response = await fetch(`${API_BASE}${path}`, {
    method: 'POST',
    headers: HEADERS,
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`Mock kancası ${path} başarısız (HTTP ${response.status}).`);
  }
  return response.json();
}

/**
 * Ortamı mock'un KENDİ kancalarıyla bilinen bir hâle getirir:
 *   * kesim saatini kaldırır (`order_cutoff: null` sözleşmede geçerli bir
 *     değer — kesimi olmayan vitrinde gün hiç kapanmaz),
 *   * bütün haftayı servis günü yapar,
 *   * bugünün menüsünü yayına alır (seed hafta sonuna menü koymuyor).
 *
 * Sonra SONUCU DOĞRULAR. Kurulum sessizce tutmazsa hata burada, sebebiyle
 * birlikte çıksın; yirmi satır sonra "düğme yok" diye değil.
 *
 * Kesim saati kuralının kendisi burada sınanmıyor; onu sözleşme ve arka uç
 * testleri doğruluyor. Buradaki testlerin konusu SİTENİN akışı.
 */
export async function openOrdering() {
  const today = businessToday();

  /*
   * Vitrin kimliği yanıttan okunuyor: sabit `1` yazmak, seed değiştiğinde
   * testi sessizce başka bir vitrini doğrular hâle getirirdi. `/__mock/*`
   * yanıtları sözleşmenin `{data: …}` sarmalayıcısını kullanmıyor, vitrin
   * nesnesi doğrudan dönüyor.
   */
  const location = await post('/__mock/location', {
    order_cutoff: null,
    service_weekdays: [1, 2, 3, 4, 5, 6, 7],
  });

  await post(`/__mock/daily-menu/${today}`, { published: true });

  const check = await fetch(`${API_URL}/locations/${location.id}/daily-menu?date=${today}`, {
    headers: HEADERS,
  });
  if (!check.ok) {
    throw new Error(`Günün menüsü okunamadı (HTTP ${check.status}).`);
  }

  const { data } = await check.json();
  if (data.is_orderable !== true) {
    throw new Error(`${today} gününe sipariş alınmıyor (sebep: ${data.unavailable_reason}).`);
  }

  return today;
}
