'use server';

import { quoteSchema } from '@/lib/validation/quote';
import type { QuoteState } from '@/lib/action-state';

/**
 * Teklif talebi gönderimi.
 *
 * ## Alıcı uç neden env değişkeni?
 *
 * `docs/openapi.yaml` sözleşmesinde teklif talebi diye bir uç YOK ve platform
 * tarafında da böyle bir tablo yok. Sözleşmeye kendi başımıza uç eklemek
 * AGENTS.md §2.3'e aykırı olurdu.
 *
 * Bu yüzden gönderim, dışarıdan tanımlanan bir HTTP hedefine yapılıyor:
 * `QUOTE_WEBHOOK_URL`. Bu bir e-posta servisi, bir form toplayıcı veya
 * ileride yazılacak kendi uç noktamız olabilir — form kodu değişmeden.
 *
 * ## Tanımlı değilse ne oluyor?
 *
 * **Başarı mesajı GÖSTERİLMİYOR.** Kullanıcıya talebin iletilemediği açıkça
 * söyleniyor. Sessizce "teşekkürler" deyip veriyi çöpe atmak, kullanıcının
 * cevap beklemesine ve işin kaybolmasına yol açar.
 *
 * Talep her hâlükârda sunucu günlüğüne yazılıyor; böylece yapılandırma
 * eksikken gelen talep en azından log üzerinden kurtarılabilir.
 */

const WEBHOOK_URL = process.env.QUOTE_WEBHOOK_URL;

/** Formun açılışından gönderime kadar geçmesi beklenen en kısa süre. */
const MIN_FILL_MS = 3000;

export async function submitQuote(_previous: QuoteState, formData: FormData): Promise<QuoteState> {
  const raw = Object.fromEntries(formData) as Record<string, unknown>;

  // Onay kutusu FormData'da yalnızca işaretliyse ve "on" olarak gelir.
  raw.kvkk_accepted = formData.get('kvkk_accepted') === 'on';

  const parsed = quoteSchema.safeParse(raw);

  if (!parsed.success) {
    const fieldErrors: Record<string, string> = {};
    for (const issue of parsed.error.issues) {
      const field = issue.path[0];
      if (typeof field === 'string' && !fieldErrors[field]) fieldErrors[field] = issue.message;
    }
    return {
      status: 'error',
      message: 'Formda eksik veya hatalı alanlar var. Lütfen kontrol edin.',
      fieldErrors,
      at: Date.now(),
    };
  }

  const { website, ...payload } = parsed.data;

  /*
   * Spam elemesi iki katmanlı ve ikisi de sessiz:
   *   1. Bal küpü alanı dolu → bot.
   *   2. Form üç saniyeden kısa sürede gönderilmiş → otomatik doldurma.
   * Bota "yakalandın" demiyoruz; başarı görünümü döndürüp geçiyoruz, yoksa
   * bot yöntemini değiştirip tekrar dener.
   */
  const openedAt = Number(formData.get('opened_at'));
  const tooFast = Number.isFinite(openedAt) && Date.now() - openedAt < MIN_FILL_MS;

  if (website || tooFast) {
    return { status: 'ok', message: null, fieldErrors: {}, at: Date.now() };
  }

  if (!WEBHOOK_URL) {
    // Talebi kaybetmemek için günlüğe yaz — yapılandırma tamamlanınca kaldırılabilir.
    console.error('[teklif] QUOTE_WEBHOOK_URL tanımlı değil, talep iletilemedi:', payload);
    return {
      status: 'unconfigured',
      message:
        'Teklif formu henüz bir alıcıya bağlanmadı, bu yüzden talebinizi iletemedik. Site yöneticisinin QUOTE_WEBHOOK_URL ayarını tamamlaması gerekiyor.',
      fieldErrors: {},
      at: Date.now(),
    };
  }

  try {
    const response = await fetch(WEBHOOK_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...payload, submitted_at: new Date().toISOString() }),
      // Teklif talebi önbelleğe alınacak bir istek değil.
      cache: 'no-store',
    });

    if (!response.ok) {
      console.error('[teklif] Alıcı uç hata döndü:', response.status, payload);
      return {
        status: 'error',
        message:
          'Talebiniz gönderilemedi. Lütfen birazdan tekrar deneyin veya doğrudan bizimle iletişime geçin.',
        fieldErrors: {},
        at: Date.now(),
      };
    }
  } catch (error) {
    console.error('[teklif] Alıcı uca ulaşılamadı:', error, payload);
    return {
      status: 'error',
      message:
        'Talebiniz gönderilemedi. Bağlantınızı kontrol edip tekrar deneyin veya doğrudan bizimle iletişime geçin.',
      fieldErrors: {},
      at: Date.now(),
    };
  }

  return { status: 'ok', message: null, fieldErrors: {}, at: Date.now() };
}
