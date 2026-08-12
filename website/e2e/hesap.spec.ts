import { expect, test, type Page, type APIRequestContext } from '@playwright/test';
import { readOtpCode, resetMock, seedDebt, seedSubscription, SEED_CUSTOMER } from './mock';

/**
 * Cari hesap ve abonelik self-servisi — W-12 / W-13.
 *
 * İkisi de v2.0'da web'e açıldı; öncesinde yalnızca mobil uygulamada
 * vardı. Testlerin ağırlık merkezi PARA: ödemenin bakiyeyi gerçekten
 * düşürdüğü ve borcu aşan tutarın reddedildiği doğrulanıyor.
 */

async function signIn(page: Page, request: APIRequestContext): Promise<void> {
  await page.goto('/giris');
  await page.getByLabel('Cep telefonu').fill(SEED_CUSTOMER.phone);
  await page.getByRole('button', { name: 'Giriş kodu gönder' }).click();
  await page.getByLabel('Giriş kodu').fill(await readOtpCode(request, SEED_CUSTOMER.phone));
  await page.getByRole('button', { name: 'Giriş yap' }).click();
  await expect(page).toHaveURL('/');
}

test.describe('Cari hesap', () => {
  test.beforeEach(async ({ request }) => {
    await resetMock(request);
  });

  test('bakiye ve ekstre görünür', async ({ page, request }) => {
    await seedDebt(request, SEED_CUSTOMER.id, 125_000); // 1.250,00 ₺
    await signIn(page, request);

    await page.goto('/hesabim/cari');

    await expect(page.getByRole('heading', { name: 'Cari hesabım' })).toBeVisible();
    await expect(page.getByText('1.250,00 ₺').first()).toBeVisible();
    await expect(page.getByText('Ödenmemiş borcunuz.')).toBeVisible();
  });

  /**
   * UÇTAN UCA PARA ZİNCİRİ: borç → ödeme → sağlayıcı → dönüş → düşen bakiye.
   * Zincirin herhangi bir halkası koparsa müşteri ödediğini sanıp borçlu
   * kalır; bu testin varlık sebebi o.
   */
  test('borcun tamamı ödenince bakiye sıfırlanır', async ({ page, request }) => {
    await seedDebt(request, SEED_CUSTOMER.id, 50_000);
    await signIn(page, request);

    await page.goto('/hesabim/cari');
    await page.getByRole('button', { name: /Borcun tamamı/ }).click();
    await page.getByRole('button', { name: 'Ödemeye geç' }).click();

    // Sağlayıcı (mock POS) ödemeyi tamamlayıp `?durum=odendi` ile döndürüyor.
    await expect(page).toHaveURL(/\/hesabim\/cari\?durum=odendi/);
    await expect(page.getByText('Ödemeniz alındı')).toBeVisible();
    await expect(page.getByText('Hesabınız kapalı, borcunuz yok.')).toBeVisible();
  });

  test('kısmi ödeme borcu azaltır', async ({ page, request }) => {
    await seedDebt(request, SEED_CUSTOMER.id, 100_000); // 1.000,00 ₺
    await signIn(page, request);

    await page.goto('/hesabim/cari');
    await page.getByRole('button', { name: /İstediğim tutar/ }).click();
    await page.getByLabel('Ödenecek tutar (TL)').fill('400');
    await page.getByRole('button', { name: 'Ödemeye geç' }).click();

    await expect(page).toHaveURL(/durum=odendi/);
    await expect(page.getByText('600,00 ₺').first()).toBeVisible();
  });

  /**
   * Fazla ödeme defterde negatif bakiye yaratır ve iadesi elle iş demektir;
   * müşteri arayüzünden yanlışlıkla yapılmasına izin verilmiyor.
   */
  test('borçtan büyük tutar reddedilir', async ({ page, request }) => {
    await seedDebt(request, SEED_CUSTOMER.id, 10_000); // 100,00 ₺
    await signIn(page, request);

    await page.goto('/hesabim/cari');
    await page.getByRole('button', { name: /İstediğim tutar/ }).click();
    await page.getByLabel('Ödenecek tutar (TL)').fill('500');
    await page.getByRole('button', { name: 'Ödemeye geç' }).click();

    await expect(page.getByRole('alert')).toBeVisible();
    await expect(page).toHaveURL(/\/hesabim\/cari$/);
  });

  test('borcu olmayan müşteriye ödeme formu çıkmaz', async ({ page, request }) => {
    await signIn(page, request);
    await page.goto('/hesabim/cari');

    await expect(page.getByText('Ödenecek borcunuz bulunmuyor.')).toBeVisible();
  });
});

test.describe('Adres defteri (W-15)', () => {
  test.beforeEach(async ({ request }) => {
    await resetMock(request);
  });

  /**
   * Uçlar sözleşmede baştan beri vardı ve mobil kullanıyordu; site hiç
   * çağırmıyordu. Sonuç: siteden sipariş veren müşteri adresini HER
   * SEFERİNDE elden yazıyordu.
   */
  test('adres kaydedilir ve listede görünür', async ({ page, request }) => {
    await signIn(page, request);
    await page.goto('/hesabim/adresler');

    await expect(page.getByText('Kayıtlı adresiniz yok')).toBeVisible();

    await page.getByRole('button', { name: 'Yeni adres ekle' }).click();
    await page.getByLabel('Etiket').fill('Ofis');
    await page.getByLabel('Adres', { exact: true }).fill('Örnek Mah. 12. Sk No:3');
    await page.getByRole('button', { name: 'Kaydet' }).click();

    await expect(page.getByText('Ofis')).toBeVisible();
    await expect(page.getByText('Varsayılan')).toBeVisible();
  });

  /**
   * İlk adres kendiliğinden varsayılan olur; defterde varsayılansız adres
   * bırakmak, ödeme adımında hiçbirini önceden seçmemek demekti.
   */
  test('kayıtlı adres ödeme adımında önceden seçili gelir', async ({ page, request }) => {
    await signIn(page, request);

    await page.goto('/hesabim/adresler');
    await page.getByRole('button', { name: 'Yeni adres ekle' }).click();
    await page.getByLabel('Etiket').fill('Ofis');
    await page.getByLabel('Adres', { exact: true }).fill('Örnek Mah. 12. Sk No:3');
    await page.getByRole('button', { name: 'Kaydet' }).click();
    await expect(page.getByText('Ofis')).toBeVisible();

    /*
     * Sepete ASGARİ TUTARI AŞACAK kadar ürün koy. Tek ürünle 210 ₺'de
     * kalıyordu ve ödeme adımı formu hiç çizmeyip "minimum sipariş tutarı"
     * uyarısını gösteriyordu — testin aradığı seçici de doğal olarak yoktu.
     */
    await page.goto('/menu');
    const add = page.getByRole('button', { name: /Sepete ekle/ }).first();
    await add.click();
    await expect(page.getByRole('link', { name: /Sepette 1 ürün var/ })).toBeVisible();
    await add.click();
    await expect(page.getByRole('link', { name: /Sepette 2 ürün var/ })).toBeVisible();

    await page.goto('/odeme');

    await expect(page.getByLabel('Kayıtlı adreslerim')).toBeVisible();
    await expect(page.getByLabel('Adres', { exact: true })).toHaveValue('Örnek Mah. 12. Sk No:3');
  });

  test('adres silinir', async ({ page, request }) => {
    await signIn(page, request);
    await page.goto('/hesabim/adresler');

    await page.getByRole('button', { name: 'Yeni adres ekle' }).click();
    await page.getByLabel('Etiket').fill('Şantiye');
    await page.getByLabel('Adres', { exact: true }).fill('Sanayi Cad. 5');
    await page.getByRole('button', { name: 'Kaydet' }).click();
    await expect(page.getByText('Şantiye')).toBeVisible();

    page.once('dialog', (dialog) => dialog.accept());
    await page.getByRole('button', { name: 'Sil' }).click();

    await expect(page.getByText('Kayıtlı adresiniz yok')).toBeVisible();
  });
});

test.describe('Abonelik self-servisi', () => {
  test.beforeEach(async ({ request }) => {
    await resetMock(request);
  });

  test('aboneliği yoksa yönlendirme gösterilir', async ({ page, request }) => {
    await signIn(page, request);
    await page.goto('/hesabim/abonelikler');

    await expect(page.getByText('Henüz aboneliğiniz yok')).toBeVisible();
  });

  test('abonelik duraklatılıp devam ettirilir', async ({ page, request }) => {
    await seedSubscription(request, SEED_CUSTOMER.id, 'active');
    await signIn(page, request);

    await page.goto('/hesabim/abonelikler');

    // Rozet metni kartta tek yerde geçiyor ama "Aktif" kelimesi başka
    // yerlerde de bulunabilir; kesin eşleşme kullanılıyor.
    await expect(page.getByText('Aktif', { exact: true })).toBeVisible();

    await page.getByRole('button', { name: 'Duraklat' }).click();
    await expect(page.getByText('Duraklatıldı', { exact: true })).toBeVisible();

    await page.getByRole('button', { name: 'Devam ettir' }).click();
    await expect(page.getByText('Aktif', { exact: true })).toBeVisible();
  });

  /**
   * Gün atlama, aboneliğin en çok kullanılan self-servis işlemi (tatil,
   * bayram, yarım gün). Kuralı değiştirmiyor; yalnız o günü etkiliyor.
   */
  test('bir gün atlanabilir', async ({ page, request }) => {
    await seedSubscription(request, SEED_CUSTOMER.id, 'active');
    await signIn(page, request);

    await page.goto('/hesabim/abonelikler');
    await page.getByRole('button', { name: /Gün atla/ }).click();

    const tomorrow = new Date(Date.now() + 86_400_000).toISOString().slice(0, 10);
    await page.getByLabel('Gün').fill(tomorrow);
    await page.getByRole('button', { name: 'O gün istemiyorum' }).click();

    /*
     * Başarı mesajının varlığı hatanın yokluğunu ZATEN kanıtlıyor: kart
     * ikisini de aynı duruma bakarak çiziyor (`latest.status`), yani
     * birlikte görünemezler.
     *
     * `getByRole('alert')` ile ayrıca "hata yok" demeye çalışmak yanlıştı:
     * Next.js her sayfanın sonuna boş bir `role="alert"` rota duyurucusu
     * koyuyor ve o sayaç hiçbir zaman sıfır olmuyor.
     */
    await expect(page.getByText('Değişiklik kaydedildi.')).toBeVisible();
  });

  test('fiyatı belirlenmemiş talep beklemede gösterilir', async ({ page, request }) => {
    await seedSubscription(request, SEED_CUSTOMER.id, 'pending');
    await signIn(page, request);

    await page.goto('/hesabim/abonelikler');

    await expect(page.getByText('Fiyat bekleniyor')).toBeVisible();
    await expect(page.getByText('Talebiniz alındı')).toBeVisible();
  });
});
