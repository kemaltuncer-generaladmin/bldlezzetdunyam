import { expect, type APIRequestContext } from '@playwright/test';

/**
 * Mock API'nin test kancaları — W-14.
 *
 * `/__mock/*` uçları sözleşmenin PARÇASI DEĞİL. Yalnızca testin gerçek
 * kullanıcı akışını izleyebilmesi için var: SMS kodunu okumak, abonelik
 * kurmak. Bunlar olmadan testler ya sabit kodlara bel bağlar ya da hiç
 * kurulamayan durumları atlardı.
 */
const API_BASE = (process.env.NEXT_PUBLIC_API_URL ?? 'http://127.0.0.1:4010/api').replace(
  /\/api\/?$/,
  '',
);

/** Mock'un beklediği istemci başlıkları (`RequireAppHeaders` karşılığı). */
export const API_HEADERS = {
  'X-App-Id': 'website',
  'X-App-Version': '1.0.0',
  'Accept-Language': 'tr',
};

/** Seed müşterisi — `infra/mock/src/seed.js` içindeki ilk kayıt. */
export const SEED_CUSTOMER = {
  id: 12,
  email: 'ayse@ornek.com',
  password: 'parola123',
  phone: '5551234567',
  firstName: 'Ayşe',
} as const;

export async function resetMock(request: APIRequestContext): Promise<void> {
  const response = await request.post(`${API_BASE}/__mock/reset`, { headers: API_HEADERS });
  expect(response.ok(), 'Mock sıfırlanamadı — API ayakta mı?').toBeTruthy();
}

/**
 * Telefona gönderilen son giriş kodunu okur (SMS'in test karşılığı).
 *
 * YOKLAMA ŞART. Kodu üreten şey bir sunucu eylemi ve tarayıcıdaki `click()`
 * onun BİTMESİNİ beklemiyor — istek uçuştayken burada okumaya kalkarsak
 * henüz yazılmamış bir kodu ararız. İlk yazışta böyle oldu ve hata
 * "Giriş kodu üretilmemiş" diye göründü; oysa kod bir an sonra geliyordu.
 */
export async function readOtpCode(request: APIRequestContext, phone: string): Promise<string> {
  let code: string | null = null;

  await expect
    .poll(
      async () => {
        const response = await request.get(`${API_BASE}/__mock/otp/${phone}`, {
          headers: API_HEADERS,
        });
        if (!response.ok()) return null;

        const body = (await response.json()) as { code: string | null };
        code = body.code;

        return code;
      },
      { message: 'Giriş kodu üretilmedi.', timeout: 10_000 },
    )
    .toMatch(/^\d{6}$/);

  return code as unknown as string;
}

/*
 * `seedDebt` KALDIRILDI (B-19). Müşteriye borç yazan tek çağıran cari
 * ekranının testleriydi; o ekran müşteri arayüzünden çıktı. `/__mock/ledger`
 * ucu mock sunucusunda duruyor — arka uç ve admin paneli cari işlemeye devam
 * ediyor, yalnız SİTE ona bakmıyor.
 */

export async function seedSubscription(
  request: APIRequestContext,
  customerId: number,
  status: 'active' | 'paused' | 'pending' = 'active',
): Promise<number> {
  const response = await request.post(`${API_BASE}/__mock/subscriptions`, {
    headers: API_HEADERS,
    data: { customer_id: customerId, status, default_quantity: 25 },
  });
  expect(response.ok(), 'Abonelik kurulamadı.').toBeTruthy();

  const body = (await response.json()) as { id: number };

  return body.id;
}
