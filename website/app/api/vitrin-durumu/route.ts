import { NextResponse } from 'next/server';

import { fetchPrimaryLocation } from '@/lib/api/catalog';

/**
 * Vitrinin anlık durumu — yoğunluk bandı bunu okur.
 *
 * NEDEN AYRI UÇ: sayfalar 60 saniyelik ISR ile önbellekleniyor (menü
 * pahalı, SEO için sunucuda üretiliyor). Mutfak "yoğunuz" tuşuna
 * bastığında müşterinin bunu bir dakika sonra görmesi kabul edilemez.
 * Menü önbelleğini bozmak yerine yalnızca bu küçük durumu taze veriyoruz.
 *
 * NEDEN TARAYICI DOĞRUDAN API'YE GİTMİYOR: API başka bir kökende
 * (`api.` alt alanı). Aynı kökenden proxy'lemek CORS'a hiç girmemeyi ve
 * zorunlu `X-App-Id` başlıklarının sunucuda kalmasını sağlıyor.
 */
export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const location = await fetchPrimaryLocation('fresh');

    return NextResponse.json(
      {
        busy: Boolean(location?.busy),
        busy_message: location?.busy_message ?? null,
        ordering_enabled: Boolean(location?.ordering_enabled),
        is_open: Boolean(location?.is_open),
      },
      { headers: { 'Cache-Control': 'no-store' } },
    );
  } catch {
    // API'ye ulaşılamıyorsa bant GÖSTERİLMEZ. Yanlış "yoğunuz" uyarısı,
    // uyarı olmamasından daha kötü: müşteri sipariş vermekten vazgeçer.
    return NextResponse.json(
      { busy: false, busy_message: null, ordering_enabled: true, is_open: true },
      { status: 200, headers: { 'Cache-Control': 'no-store' } },
    );
  }
}
