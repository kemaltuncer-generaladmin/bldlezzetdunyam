import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright yapılandırması — W-14.
 *
 * `package.json` içinde `test:e2e` betiği aylardır vardı ama ne bu dosya ne
 * de `e2e/` klasörü vardı: CI adımı "Playwright henüz kurulmadı" yazıp
 * geçiyordu ve kimse fark etmiyordu. Bu dosyanın varlığı o adımı açıyor.
 *
 * MOCK API'YE KARŞI KOŞAR, gerçek backend'e değil (`infra/mock`). Gerekçe
 * CI iş akışında yazılı: PHP + MySQL ayağa kaldırmak e2e turunu dakikalar
 * uzatıyor ve testleri backend'in sağlığına bağlıyor. Sözleşme uyumu ayrı
 * bir adımda (`infra/e2e.sh`) doğrulanıyor, yani mock'un yalan söylemesi
 * mümkün değil.
 */
const PORT = 3100;
const BASE_URL = `http://127.0.0.1:${PORT}`;

export default defineConfig({
  testDir: './e2e',
  // Sipariş akışı sepet çerezini paylaşıyor; paralel koşumda iki test aynı
  // sepeti bozardı. `workers: 1` yavaş ama doğru.
  workers: 1,
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['github'], ['list']] : [['list']],

  use: {
    baseURL: BASE_URL,
    // İlk başarısızlıkta iz alınıyor: CI'da hatayı yeniden üretmek zor ve
    // ekran görüntüsü olmadan "buton bulunamadı" hatası hiçbir şey anlatmıyor.
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    locale: 'tr-TR',
    timezoneId: 'Europe/Istanbul',
  },

  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    // Mobil menünün kapanma davranışı (W-07) yalnızca dar ekranda görünür.
    { name: 'mobile', use: { ...devices['Pixel 7'] } },
  ],

  /*
   * ÜRETİM DERLEMESİ KOŞULUYOR, `next dev` DEĞİL.
   *
   * Geliştirme sunucusu ISR'ı, `revalidate` sürelerini ve yönlendirmeleri
   * üretimden farklı ele alıyor; W-08'in 308 yönlendirmelerini `dev`'de
   * test etmek yanlış güven verirdi.
   */
  /*
   * MOCK, DERLEMEDEN ÖNCE AÇILIYOR.
   *
   * Ana sayfa statik/ISR üretiliyor: "bugün mutfakta" bandı derleme anındaki
   * menü durumuyla HTML'e gömülüyor. Seed'deki vitrinin kesim saati 08:00,
   * yani o saatten sonra (ya da hafta sonu) yapılan bir derleme, bandı
   * "Bugüne sipariş alınmıyor" diye üretiyor ve önbellek penceresi boyunca
   * öyle servis ediyor. Testin sonradan mock'u açması o HTML'i geri
   * getirmiyordu — süit derlemeyi izleyen ilk koşumda kırılıyor, ikinci
   * koşumda (önbellek tazelendiği için) geçiyordu.
   *
   * Aynı tarif testlerin `beforeEach`'inde de koşuyor; `/__mock/reset`
   * vitrini seed'e geri aldığı için gerekiyor (`e2e/open-ordering.mjs`).
   */
  webServer: {
    command: `node e2e/prepare-mock.mjs && npm run build && npx next start --port ${PORT}`,
    url: BASE_URL,
    reuseExistingServer: !process.env.CI,
    timeout: 300_000,
    env: {
      NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL ?? 'http://127.0.0.1:4010/api',
      NEXT_PUBLIC_SITE_URL: BASE_URL,
    },
  },
});
