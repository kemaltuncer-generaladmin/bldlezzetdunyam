'use server';

import { revalidatePath } from 'next/cache';
import { ApiError, userMessage } from '@/lib/api/client';
import { approveContract, requestContractOtp } from '@/lib/api/contracts';
import type { ContractFormState } from '@/app/sozlesme/[token]/contract-state';

/**
 * Abonelik sözleşmesi onay eylemleri — M2.
 *
 * ## Belirteç neden formdan geliyor?
 *
 * Eylemler `token`'ı gizli alandan okuyor ve bu bir açık DEĞİL: belirtecin
 * kendisi yetkidir ve zaten adres çubuğunda duruyor. Sunucu eylemi olmadan da
 * aynı uçlara doğrudan istek atılabilirdi; burada saklanacak bir sır yok.
 * Saklanan şey, uçların adresi ve `X-App-*` başlıkları — onlar `lib/api`
 * içinde kalıyor.
 *
 * ## Oturum neden okunmuyor?
 *
 * Sözleşmeyi onaylayan kişi çoğu zaman sitede oturum açmış kişi değil, satın
 * almayı onaylayan yetkilidir. `readToken()` çağırıp giriş istemek, SMS'i alan
 * kişinin onaylayamaması demekti.
 */

/** `docs/openapi.yaml`: `minLength: 20, maxLength: 200`. */
const TOKEN_MIN = 20;
const TOKEN_MAX = 200;

const CODE_PATTERN = /^[0-9]{6}$/;

const INVALID_LINK = 'Bu sözleşme bağlantısı geçersiz. SMS ile gelen bağlantıyı yeniden açın.';

function readContractToken(formData: FormData): string | null {
  const token = String(formData.get('token') ?? '').trim();
  if (token.length < TOKEN_MIN || token.length > TOKEN_MAX) return null;
  return token;
}

function fail(
  message: string,
  fieldErrors: Record<string, string> = {},
  resendAt = 0,
): ContractFormState {
  return { status: 'error', message, fieldErrors, resendAt, at: Date.now() };
}

/**
 * Onay kodunu ister.
 *
 * Bekleme süresi SUNUCUDAN geliyor (`resend_after`); arayüz sabit saniye
 * yazmıyor. Sunucudaki bekleme değiştiğinde ekrandaki sayaç kendiliğinden
 * uyar.
 */
export async function requestContractOtpAction(
  previous: ContractFormState,
  formData: FormData,
): Promise<ContractFormState> {
  const token = readContractToken(formData);
  if (!token) return fail(INVALID_LINK);

  try {
    const { resend_after: resendAfter } = await requestContractOtp(token);

    return {
      status: 'sent',
      message: null,
      fieldErrors: {},
      resendAt: Date.now() + Math.max(0, resendAfter) * 1000,
      at: Date.now(),
    };
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) return fail(INVALID_LINK);

    /*
     * Oran sınırına takılan istek KOD KUTUSUNU KAPATMAMALI: kullanıcının
     * elinde çoktan gelmiş bir kod olabilir ve tek yapması gereken onu
     * girmek. Önceki `resendAt` korunuyor, yoksa sayaç sıfırlanır ve düğme
     * sınıra takılacağını bile bile açık görünürdü.
     */
    if (error instanceof ApiError && error.status === 429) {
      return fail(error.message, {}, previous.resendAt);
    }

    return fail(
      userMessage(error, 'Onay kodu gönderilemedi, tekrar deneyin.'),
      {},
      previous.resendAt,
    );
  }
}

/**
 * Kodu doğrular ve sözleşmeyi onaylar.
 *
 * ONAY GERİ ALINAMAZ. Vazgeçme, sözleşmenin iptali değil aboneliğin
 * iptalidir — onay kaydı hukuki bir izdir ve silinmez.
 *
 * Aynı kodla ikinci çağrı sunucuda idempotenttir ve `200` döner; ekran bu
 * yüzden "onaylandı"yı iki kez göstermekten çekinmiyor. SMS gecikip
 * kullanıcının iki kez dokunması sık yaşanıyor.
 */
export async function approveContractAction(
  previous: ContractFormState,
  formData: FormData,
): Promise<ContractFormState> {
  const token = readContractToken(formData);
  if (!token) return fail(INVALID_LINK);

  const code = String(formData.get('code') ?? '').trim();
  const fullName = String(formData.get('full_name') ?? '').trim();

  if (!CODE_PATTERN.test(code)) {
    return fail('Onay kodunu kontrol edin.', { code: 'Kod 6 rakamdan oluşur.' }, previous.resendAt);
  }

  // Sözleşme `maxLength: 120`. Uzun metni kırpmak yerine reddediyoruz:
  // belgeye yarısı yazılmış bir ad, hiç yazılmamış olmasından kötüdür.
  if (fullName.length > 120) {
    return fail(
      'Ad soyad çok uzun.',
      { full_name: 'En fazla 120 karakter yazabilirsiniz.' },
      previous.resendAt,
    );
  }

  try {
    await approveContract(token, code, fullName || undefined);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) return fail(INVALID_LINK);

    /*
     * `422` iki ayrı şey demek: kod hatalı/süresi dolmuş VEYA sözleşme onaya
     * uygun durumda değil (`approved`, `expired`, `cancelled`). Ayrımı sunucu
     * mesajı taşıyor; kendi metnimizi yazsaydık ikisinden birine yanlış
     * cümleyi kurardık.
     */
    if (error instanceof ApiError && error.status === 422) {
      // Alan hatası varsa kutunun altına da yazılıyor; yoksa `fieldErrors`
      // BOŞ kalıyor — boş dize konsaydı ekran boş bir hata satırı çizerdi.
      const codeError = error.fieldErrors().code;
      return fail(error.message, codeError ? { code: codeError } : {}, previous.resendAt);
    }

    return fail(
      userMessage(error, 'Sözleşme onaylanamadı, tekrar deneyin.'),
      {},
      previous.resendAt,
    );
  }

  // Sayfa sunucudan yeniden çiziliyor: onaydan sonra metnin üstündeki durum
  // rozeti ve "onaylandı" bilgisi tazelensin. Sayfa `force-dynamic`, bu
  // çağrı yalnız istemcideki RSC önbelleğini düşürüyor.
  revalidatePath(`/sozlesme/${token}`);

  return {
    status: 'approved',
    message: null,
    fieldErrors: {},
    resendAt: 0,
    at: Date.now(),
  };
}
