import { expect, test } from '@playwright/test';

/**
 * Header ve bilgi mimarisi — W-07 / W-08.
 *
 * Bu dosyanın varlık sebebi somut bir hata: menüye tıklanınca panel
 * kapanmıyordu. Masaüstünde `<details>` kullanıldığı için Next.js istemci
 * tarafında gezinince DOM korunuyor ve panel açık kalıyordu; mobilde ise
 * kapanma yalnızca `pathname` değişimine bağlıydı ve üç durumda deliniyordu.
 *
 * Testler o üç durumu tek tek sabitliyor — düzeltmenin kendisi kolaydı,
 * geri gelmesini engellemek bu dosyanın işi.
 */
test.describe('Üst menü', () => {
  test('mobil menü, bağlantıya tıklanınca kapanır', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'mobile', 'Hamburger yalnızca dar ekranda.');

    await page.goto('/');
    await page.getByRole('button', { name: 'Menüyü aç' }).click();

    const sheet = page.getByRole('dialog');
    await expect(sheet).toBeVisible();

    await sheet.getByRole('link', { name: 'Kurumsal' }).click();

    await expect(page).toHaveURL(/\/kurumsal$/);
    await expect(sheet).toBeHidden();
  });

  /**
   * ESKİ HATANIN TAM KARŞILIĞI: bulunduğun sayfanın kendi bağlantısına
   * dokunmak. `usePathname()` aynı dizeyi döndürüyor, rota değişimine bağlı
   * efekt hiç koşmuyor ve panel açık kalıyordu.
   */
  test('aynı sayfanın bağlantısına tıklanınca da kapanır', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'mobile', 'Hamburger yalnızca dar ekranda.');

    await page.goto('/kurumsal');
    await page.getByRole('button', { name: 'Menüyü aç' }).click();

    const sheet = page.getByRole('dialog');
    await expect(sheet).toBeVisible();

    await sheet.getByRole('link', { name: 'Kurumsal' }).click();

    await expect(sheet).toBeHidden();
  });

  /**
   * İkinci delik: `tel:` / `wa.me` düğmeleri rotayı hiç değiştirmiyor.
   * Kullanıcı arama ekranından dönünce paneli açık buluyordu.
   */
  test('iletişim düğmesine dokununca da kapanır', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'mobile', 'Hamburger yalnızca dar ekranda.');

    await page.goto('/');
    await page.getByRole('button', { name: 'Menüyü aç' }).click();

    const sheet = page.getByRole('dialog');
    const telLink = sheet.locator('a[href^="tel:"]').first();

    // İletişim numarası panelden geliyor; tanımlı değilse düğme hiç
    // çizilmiyor ve test edilecek bir şey yok.
    test.skip((await telLink.count()) === 0, 'Telefon kanalı tanımlı değil.');

    // `tel:` gezinmesini engelliyoruz: tarayıcı harici uygulama açmaya
    // çalışırsa test askıda kalır. Amaç zaten tıklamanın paneli kapatması.
    await page.route('tel:*', (route) => route.abort());
    await telLink.click();

    await expect(sheet).toBeHidden();
  });
});

test.describe('Bilgi mimarisi (W-08)', () => {
  /**
   * Kaldırılan sayfaların adresleri arama motorlarında ve müşterilere
   * gönderilmiş e-postalarda duruyor. 404'e bırakmak hem sıralamayı hem de
   * ziyaretçiyi çöpe atmak olurdu.
   */
  const REDIRECTS: Array<[string, RegExp]> = [
    ['/hizmetler', /\/#hizmetler$|\/$/],
    ['/hizmetler/tasima-yemek', /\/#hizmetler$|\/$/],
    ['/menu-cozumleri', /\/menu$/],
    ['/kalite-hijyen', /\/kurumsal#kalite$|\/kurumsal$/],
    ['/calistigimiz-alanlar', /\/kurumsal#alanlar$|\/kurumsal$/],
  ];

  for (const [from, to] of REDIRECTS) {
    test(`${from} kalıcı olarak yönlendirilir`, async ({ page }) => {
      const response = await page.goto(from);

      expect(response?.status(), `${from} 404 dönmemeli`).toBeLessThan(400);
      await expect(page).toHaveURL(to);
    });
  }

  /**
   * BİLGİ MERKEZİ LİSTEDEN ÇIKTI — M4. Ters yöne bakan bir test bıraktık.
   *
   * `/bilgi-merkezi` v2.0'da `/kurumsal`'a 308'liyordu; blog geri gelince
   * yönlendirme `next.config.ts`'ten silindi. Yalnızca satırı listeden
   * çıkarmak yetmez: yönlendirmeyi "unutulmuş temizlik" sanıp geri ekleyen
   * biri hiçbir testi kırmadan blogun tamamını kapatabilirdi. Bu yüzden
   * kural artık açıkça yazılı — adres KENDİ sayfasını açar.
   */
  test('/bilgi-merkezi artık yönlendirilmiyor, blogu açıyor', async ({ page }) => {
    const response = await page.goto('/bilgi-merkezi');

    expect(response?.status(), '/bilgi-merkezi 200 dönmeli').toBe(200);
    await expect(page).toHaveURL(/\/bilgi-merkezi$/);
  });

  /**
   * Bireysel kayıt kurumsala yönleniyor: sipariş kapısı kurumsal hesaplarda
   * açık ve eski form unvan/vergi sormuyordu — faturalandırılamayan
   * "kurumsal" hesaplar üretiyordu.
   */
  test('/kayit kurumsal kayda yönlendirilir', async ({ page }) => {
    await page.goto('/kayit');

    await expect(page).toHaveURL(/\/kurumsal-kayit$/);
  });

  test('robots ve sitemap kurumsal kayıt konusunda çelişmiyor', async ({ request }) => {
    const [robots, sitemap] = await Promise.all([
      request.get('/robots.txt').then((r) => r.text()),
      request.get('/sitemap.xml').then((r) => r.text()),
    ]);

    // Sayfa haritada ilan ediliyorsa robots onu engellememeli.
    expect(sitemap).toContain('/kurumsal-kayit');
    expect(robots).not.toContain('Disallow: /kurumsal-kayit');
  });

  test('site haritası kaldırılan sayfaları ilan etmez', async ({ request }) => {
    const response = await request.get('/sitemap.xml');
    const body = await response.text();

    // Yönlendirilen bir adresi haritada ilan etmek, arama motoruna "buraya
    // git" deyip kapıda başka yere göndermektir.
    expect(body).not.toContain('/kalite-hijyen');
    expect(body).not.toContain('/menu-cozumleri');
    expect(body).toContain('/menu');

    // Blog geri geldiği için ARTIK ilan EDİLİYOR (M4): 200 dönen ve
    // dizinlenmesini istediğimiz bir sayfanın haritada olmaması, yönlendirilen
    // bir sayfanın haritada olması kadar tutarsız.
    expect(body).toContain('/bilgi-merkezi');
  });
});
