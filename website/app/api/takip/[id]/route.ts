import { NextResponse } from 'next/server';
import { ApiError } from '@/lib/api/client';
import { fetchPublicTracking } from '@/lib/api/orders';

export const dynamic = 'force-dynamic';

/**
 * Girişsiz takip sayfasının 5 saniyelik yoklaması (K-20).
 *
 * `/api/siparis/[id]` ile karıştırılmamalı: ORASI oturum çerezini okuyup
 * siparişin tam yüzünü döner. Burası hiçbir çerez okumaz; yetki, fişteki
 * QR'dan gelen `e`/`s` imzasındadır ve yanıt siparişin daraltılmış yüzüdür
 * (adres, ad, telefon ve kalem listesi yok).
 *
 * NEDEN BFF ÜZERİNDEN: tarayıcı API alan adını doğrudan çağırsaydı, zorunlu
 * sözleşme başlıkları (`X-App-Id`, `X-App-Version`) ve CORS ayarı istemciye
 * taşınırdı. Girişli takip de aynı deseni kullanıyor.
 */
export async function GET(request: Request, context: { params: Promise<{ id: string }> }) {
  const { id } = await context.params;
  const orderId = Number.parseInt(id, 10);

  if (!Number.isSafeInteger(orderId) || orderId <= 0) {
    return NextResponse.json(
      { error: { code: 'NOT_FOUND', message: 'Sipariş bulunamadı.' } },
      { status: 404 },
    );
  }

  const url = new URL(request.url);
  const expires = url.searchParams.get('e') ?? '';
  const signature = url.searchParams.get('s') ?? '';

  // İmza parçaları eksikse sunucuya hiç gitmiyoruz: cevap zaten `403` olurdu
  // ve boş bir istek oran sınırından pay yerdi.
  if (expires === '' || signature === '') {
    return NextResponse.json(
      { error: { code: 'FORBIDDEN', message: 'Takip bağlantısı geçersiz.' } },
      { status: 403 },
    );
  }

  try {
    const data = await fetchPublicTracking(orderId, expires, signature);
    return NextResponse.json(data, { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) {
    if (error instanceof ApiError) {
      return NextResponse.json(
        { error: { code: error.code, message: error.message } },
        { status: error.status === 0 ? 503 : error.status },
      );
    }
    return NextResponse.json(
      { error: { code: 'SERVER_ERROR', message: 'Sipariş durumu alınamadı.' } },
      { status: 500 },
    );
  }
}
