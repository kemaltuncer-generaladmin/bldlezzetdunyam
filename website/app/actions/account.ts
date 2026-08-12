'use server';

import { redirect } from 'next/navigation';
import { startAccountPayment } from '@/lib/api/account';
import { ApiError, SITE_URL, userMessage } from '@/lib/api/client';
import { readToken } from '@/lib/session';
import type { AccountPaymentState } from '@/lib/action-state';

/**
 * Cari borç ödemesini başlatır ve sağlayıcının sayfasına yönlendirir — W-12.
 *
 * TUTAR SUNUCUDA DOĞRULANIYOR. Burada yaptığımız tek şey "tamamı mı, bir
 * kısmı mı" ayrımını taşımak; `full` modunda hiçbir rakam göndermiyoruz ki
 * ekrandaki eski bakiye ile gerçek borç ayrışmışsa (arada bir sipariş
 * geçmişse) müşteri eksik ödeyip "kapattım" sanmasın.
 *
 * `redirect` TRY/CATCH DIŞINDA: Next.js yönlendirmeyi özel bir istisna
 * fırlatarak yapıyor; `try` içinde çağrılsaydı kendi `catch`'imiz onu
 * yakalar ve yönlendirme sessizce "ödeme başlatılamadı" hatasına dönerdi.
 */
export async function startAccountPaymentAction(
  _prev: AccountPaymentState,
  formData: FormData,
): Promise<AccountPaymentState> {
  const token = await readToken();
  if (!token) redirect('/giris?next=%2Fhesabim%2Fcari');

  const mode = formData.get('mode');
  const rawAmount = formData.get('amount');

  let payload: { amount: number } | { full: true };

  if (mode === 'full') {
    payload = { full: true };
  } else {
    // Kullanıcı TL yazıyor, sözleşme kuruş istiyor. Virgül ve nokta ikisi de
    // ondalık ayıracı olarak kabul ediliyor: klavyeye göre ikisi de yazılıyor.
    const normalized = String(rawAmount ?? '')
      .replace(/\s/g, '')
      .replace(',', '.');
    const lira = Number.parseFloat(normalized);

    if (!Number.isFinite(lira) || lira <= 0) {
      return { status: 'error', message: 'Geçerli bir tutar girin.', at: Date.now() };
    }

    payload = { amount: Math.round(lira * 100) };
  }

  let redirectUrl: string;
  try {
    const started = await startAccountPayment(token, payload);
    redirectUrl = withReturnUrl(started.redirect_url);
  } catch (error) {
    if (error instanceof ApiError && error.status === 422) {
      return { status: 'error', message: error.message, at: Date.now() };
    }
    if (error instanceof ApiError && error.status === 401) {
      redirect('/giris?next=%2Fhesabim%2Fcari&durum=suresi-doldu');
    }
    return {
      status: 'error',
      message: userMessage(error, 'Ödeme başlatılamadı, tekrar deneyin.'),
      at: Date.now(),
    };
  }

  redirect(redirectUrl);
}

/**
 * Sağlayıcıya "işin bitince buraya dön" adresini iletir.
 *
 * Sunucu tarafı yalnızca YAPILANDIRILMIŞ ön yüz adresine dönmeye izin
 * veriyor (açık yönlendirme açığına karşı); burada gönderdiğimiz adres o
 * kontrolden geçmezse yok sayılıyor ve varsayılan cari sayfasına dönülüyor.
 * Yani bu satır bir kolaylık, güvenlik dayanağı değil.
 */
function withReturnUrl(url: string): string {
  const separator = url.includes('?') ? '&' : '?';

  return `${url}${separator}return=${encodeURIComponent(`${SITE_URL}/hesabim/cari`)}`;
}
