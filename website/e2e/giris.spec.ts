import { expect, test } from '@playwright/test';
import { readOtpCode, resetMock, SEED_CUSTOMER } from './mock';

/**
 * Telefonla giriş — W-11 / B-18.
 *
 * Bu akış bir kimlik kapısı, yani yalnızca "çalışıyor mu" değil "sızdırıyor
 * mu" da test ediliyor: kayıtlı olmayan numaranın kayıtlıdan ayırt
 * edilememesi, ekranın kendisi kadar önemli bir davranış.
 */
test.describe('Telefonla giriş', () => {
  test.beforeEach(async ({ request }) => {
    await resetMock(request);
  });

  test('kod alıp giriş yapılır', async ({ page, request }) => {
    await page.goto('/giris');

    // Telefon sekmesi varsayılan: kurumsal müşteri parolayı unutuyor,
    // telefonu her zaman elinin altında.
    await expect(page.getByRole('button', { name: 'Telefon ile' })).toHaveAttribute(
      'aria-pressed',
      'true',
    );

    await page.getByLabel('Cep telefonu').fill(SEED_CUSTOMER.phone);
    await page.getByRole('button', { name: 'Giriş kodu gönder' }).click();

    const codeInput = page.getByLabel('Giriş kodu');
    await expect(codeInput).toBeVisible();
    // Odak koda gitmeli: kullanıcı SMS'ten dönünce yazacağı yeri aramamalı.
    await expect(codeInput).toBeFocused();

    await codeInput.fill(await readOtpCode(request, SEED_CUSTOMER.phone));
    await page.getByRole('button', { name: 'Giriş yap' }).click();

    await expect(page).toHaveURL('/');
    await page.goto('/hesabim');
    await expect(page.getByRole('heading', { name: 'Hesabım' })).toBeVisible();
  });

  test('numaranın yazımı fark etmez', async ({ page, request }) => {
    await page.goto('/giris');

    // Kayıtta `5551234567`, girişte `0555 123 45 67`. Normalleştirme
    // olmasaydı müşteri "kayıtlı değil" muamelesi görürdü — ve numara
    // sayımına kapı bırakmadığımız için sebebini de öğrenemezdi.
    await page.getByLabel('Cep telefonu').fill('0555 123 45 67');
    await page.getByRole('button', { name: 'Giriş kodu gönder' }).click();

    await page.getByLabel('Giriş kodu').fill(await readOtpCode(request, SEED_CUSTOMER.phone));
    await page.getByRole('button', { name: 'Giriş yap' }).click();

    await expect(page).toHaveURL('/');
  });

  test('yanlış kod reddedilir ve ekranda kalınır', async ({ page }) => {
    await page.goto('/giris');
    await page.getByLabel('Cep telefonu').fill(SEED_CUSTOMER.phone);
    await page.getByRole('button', { name: 'Giriş kodu gönder' }).click();

    await page.getByLabel('Giriş kodu').fill('000000');
    await page.getByRole('button', { name: 'Giriş yap' }).click();

    await expect(page.getByRole('alert')).toBeVisible();
    // Kod ekranında kalmalı: numara ekranına geri atmak, elindeki geçerli
    // kodu girememesine yol açardı.
    await expect(page.getByLabel('Giriş kodu')).toBeVisible();
  });

  /**
   * NUMARA SAYIMINA KAPI YOK: kayıtsız numara da aynı ekrana geçer.
   * Arayüzün "bu numara kayıtlı değil" demesi, sunucudaki korumayı delerdi.
   */
  test('kayıtlı olmayan numara da aynı ekrana geçer', async ({ page }) => {
    await page.goto('/giris');
    await page.getByLabel('Cep telefonu').fill('5559998877');
    await page.getByRole('button', { name: 'Giriş kodu gönder' }).click();

    await expect(page.getByLabel('Giriş kodu')).toBeVisible();
  });

  test('e-posta ile giriş yolu açık kalır', async ({ page }) => {
    await page.goto('/giris');
    await page.getByRole('button', { name: 'E-posta ile' }).click();

    await page.getByLabel('E-posta').fill(SEED_CUSTOMER.email);
    await page.getByLabel('Parola').fill(SEED_CUSTOMER.password);
    await page.getByRole('button', { name: /Giriş yap/ }).click();

    await expect(page).toHaveURL('/');
  });
});
