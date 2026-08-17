import { expect, test, type Page } from '@playwright/test';
import { readOtpCode, resetMock, SEED_CUSTOMER } from './mock';

/**
 * "Sepette N ürün var" — sepetin GERÇEKTEN dolduğunun tek işareti.
 *
 * Sepet bağlantısının kendisi işe yaramıyor: sipariş rotalarında
 * (`/menu`, `/sepet` …) sepet boşken de duruyor, yani onu beklemek hiçbir
 * şey beklememekle aynı. İlk yazışta bu tuzağa düşüldü ve test, ekleme
 * tamamlanmadan geçip `/sepet`i boş buldu.
 *
 * Metin `messages/tr.json` → `nav.cartCount`; sayaç sıfırdan büyükken
 * `HeaderActions` bunu `sr-only` olarak yazıyor.
 */
function cartHasItems(page: Page) {
  return page.getByRole('link', { name: /Sepette \d+ ürün var/ });
}

/**
 * Sipariş akışı ve ana sayfadaki hızlı sipariş — W-10.
 *
 * `docs/06` §8 bu akış için bir e2e testi şart koşuyordu; `test:e2e`
 * betiği aylardır vardı ama test yoktu. Buradaki senaryolar menü → sepet →
 * ödeme zincirini ve "geçen siparişi tekrarla" kısayolunu kapsıyor.
 */
test.describe('Sipariş akışı', () => {
  test.beforeEach(async ({ request }) => {
    await resetMock(request);
  });

  test('menüden sepete ürün eklenir', async ({ page }) => {
    await page.goto('/menu');

    // İlk satılabilir ürünün kartından sepete ekle.
    const firstAdd = page.getByRole('button', { name: /Sepete ekle/ }).first();
    await expect(firstAdd).toBeVisible();
    await firstAdd.click();

    /*
     * SEPETE GİTMEDEN ÖNCE ONAYI BEKLE. `click()` sunucu eyleminin
     * bitmesini beklemiyor; hemen `/sepet`e gidersek çerez henüz
     * yazılmamış olabiliyor ve sepet boş görünüyor.
     *
     * BEKLENEN SİNYAL SEPET ROZETİ, "role=status" DEĞİL. İlk yazışta
     * `getByRole('status')` kullanılmıştı ve test geçiyordu — ama yanlış
     * sebeple: `/menu` sayfasında sipariş şalteri banner'ı zaten
     * `role="status"` taşıyor, yani beklenen şey ekleme onayı değil
     * sayfanın en başından beri orada duran bir kutuydu. Sepete eklemenin
     * gerçekten olduğunu gösteren tek şey sepet sayacı.
     */
    await expect(cartHasItems(page)).toBeVisible();

    await page.goto('/sepet');
    await expect(page.getByRole('heading', { name: /Sepet/ })).toBeVisible();
    // Boş sepet mesajı görünmemeli.
    await expect(page.getByText('Sepetiniz boş')).toHaveCount(0);
  });

  /**
   * Fişteki takip QR'ının açtığı sayfa GİRİŞ İSTEMEZ — K-20.
   *
   * Düzeltilen gerçek kusur: bağlantı eskiden `/siparis/{id}` idi ve o rota
   * `middleware.ts` matcher'ında. Fişteki kareyi okutan müşteri sipariş
   * durumunu değil `/giris` ekranını görüyordu.
   *
   * ÇEREZSİZ BAĞLAM ŞART: `page` varsayılan bağlamda çalışıyor ve önceki
   * bir test oturum çerezi bırakmış olsaydı, giriş duvarına çarpmadığımızı
   * sanırdık. `browser.newContext()` bunu garantiliyor.
   */
  test('fişteki takip bağlantısı giriş istemez', async ({ browser }) => {
    const context = await browser.newContext();
    const anonim = await context.newPage();

    // Mock imzayı doğrulamıyor ama VARLIĞINI arıyor: istemcinin imzayı hiç
    // göndermediği bir hata, parametresiz istekte fark edilmezdi.
    await anonim.goto('/takip/5010?e=1786512000&s=mock-imza');

    await expect(anonim).toHaveURL(/\/takip\/5010/);
    await expect(anonim.getByRole('heading', { name: /Sipariş S-5010/ })).toBeVisible();

    // Girişli takip ekranının aksine burada adres ve kalem listesi YOKTUR:
    // bu sayfayı açan şey bir oturum değil, kâğıda basılmış bir kare.
    await expect(anonim.getByText('Örnek Mah. 12. Sk No:3')).toHaveCount(0);

    await context.close();
  });

  test('imzasız takip bağlantısı sipariş göstermez', async ({ browser }) => {
    const context = await browser.newContext();
    const anonim = await context.newPage();

    await anonim.goto('/takip/5010');

    await expect(anonim.getByText(/Bağlantı geçersiz/)).toBeVisible();

    await context.close();
  });

  test('giriş yapmadan ödemeye gidilemez', async ({ page }) => {
    await page.goto('/odeme');

    // Middleware çerez yokluğunu görüp girişe atıyor.
    await expect(page).toHaveURL(/\/giris\?next=%2Fodeme/);
  });
});

test.describe('Ana sayfa hızlı sipariş', () => {
  test.beforeEach(async ({ request }) => {
    await resetMock(request);
  });

  test('girişsiz ziyaretçiye giriş ve kayıt sunulur', async ({ page }) => {
    await page.goto('/');

    const box = page.getByRole('heading', { name: 'Sipariş vermek için giriş yapın' });
    await expect(box).toBeVisible();
    await expect(page.getByRole('link', { name: 'Kurumsal kayıt' }).first()).toBeVisible();
  });

  test('girişli müşteriye karşılama ve menü kısayolu çıkar', async ({ page, request }) => {
    await page.goto('/giris');
    await page.getByLabel('Cep telefonu').fill(SEED_CUSTOMER.phone);
    await page.getByRole('button', { name: 'Giriş kodu gönder' }).click();
    await page.getByLabel('Giriş kodu').fill(await readOtpCode(request, SEED_CUSTOMER.phone));
    await page.getByRole('button', { name: 'Giriş yap' }).click();

    await expect(page).toHaveURL('/');

    // Kutu verisini istemciden çekiyor (ana sayfa ISR'da kalsın diye), bu
    // yüzden başlık ilk boyamadan sonra beliriyor.
    await expect(
      page.getByRole('heading', { name: new RegExp(SEED_CUSTOMER.firstName) }),
    ).toBeVisible();
  });
});

test.describe('Ana sayfadan sipariş (gömülü menü)', () => {
  test.beforeEach(async ({ request }) => {
    await resetMock(request);
  });

  /**
   * v2.0'da "bugün mutfakta" bölümü sipariş verilebilir hâle geldi (W-10).
   * Öncesinde kartlar yalnızca ürün sayfasına bağlanıyordu ve sipariş
   * vermek isteyen ziyaretçi üç adım atıyordu.
   *
   * B-19'DAN SONRA DÜĞMENİN ADI DEĞİŞTİ. Bant artık altı ürün kartı değil
   * TEK bir günlük menü teklifi gösteriyor, düğmesi de "Menüyü sepete ekle".
   * Eşleşme bu yüzden büyük/küçük harfe duyarsız: sınanan şey etiketin tam
   * metni değil, ana sayfadan sepete eklenebilmesi.
   */
  test('ana sayfadaki menüden sepete eklenebilir', async ({ page }) => {
    await page.goto('/');

    const add = page.getByRole('button', { name: /sepete ekle/i }).first();
    await expect(add).toBeVisible();
    await add.click();

    /*
     * Eklenen ürünün nereye gittiği GÖRÜNMELİ. Sepet çubuğu mobilde alta
     * sabitleniyor, header rozeti masaüstünde çıkıyor; ikisi de yalnızca
     * sepet doluyken beliriyor, yani biri görünüyorsa ekleme gerçekten
     * olmuştur.
     */
    await expect(cartHasItems(page)).toBeVisible();
  });
});

test.describe('Kurumsal kayıt', () => {
  test.beforeEach(async ({ request }) => {
    await resetMock(request);
  });

  test('yeni firma kaydolup sipariş verebilir hâle gelir', async ({ page }) => {
    await page.goto('/kurumsal-kayit');

    await page.getByLabel('Ticari unvan').fill('Deneme Gıda Ltd. Şti.');
    await page.getByLabel('Vergi dairesi').fill('Selçuklu');
    await page.getByLabel('Vergi no / TCKN').fill('1234567890');
    await page.getByLabel('Ad', { exact: true }).fill('Kemal');
    await page.getByLabel('Soyad').fill('Deneme');
    await page.getByLabel('E-posta').fill(`deneme${Date.now()}@ornek.com`);
    await page.getByLabel('Cep telefonu').fill('5321112233');
    await page.getByLabel('Parola', { exact: true }).fill('parola1234');
    await page.getByLabel('Parola (tekrar)').fill('parola1234');
    await page.getByRole('checkbox').check();

    await page.getByRole('button', { name: /Hesabı oluştur/ }).click();

    // Onay beklemeden sipariş verebiliyor: kayıt sonrası menüye gidiyor.
    await expect(page).toHaveURL(/\/menu$/);
  });

  test('eksik vergi bilgisi kaydı durdurur', async ({ page }) => {
    await page.goto('/kurumsal-kayit');

    await page.getByLabel('Ticari unvan').fill('Eksik Firma');
    await page.getByLabel('Ad', { exact: true }).fill('Kemal');
    await page.getByLabel('Soyad').fill('Deneme');
    await page.getByLabel('E-posta').fill('eksik@ornek.com');
    await page.getByLabel('Cep telefonu').fill('5321112244');
    await page.getByLabel('Parola', { exact: true }).fill('parola1234');
    await page.getByLabel('Parola (tekrar)').fill('parola1234');
    await page.getByRole('checkbox').check();

    await page.getByRole('button', { name: /Hesabı oluştur/ }).click();

    await expect(page).toHaveURL(/\/kurumsal-kayit/);
    await expect(page.getByText('Vergi dairesini girin.')).toBeVisible();
  });
});
