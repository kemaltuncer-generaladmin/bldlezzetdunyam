import { NextResponse } from 'next/server';
import { ApiError } from '@/lib/api/client';
import { fetchOrder } from '@/lib/api/orders';
import { readToken } from '@/lib/session';

export const dynamic = 'force-dynamic';

/**
 * Takip ekranının 5 saniyelik yoklaması bu uca gelir. Oturum token'ı
 * `httpOnly` cookie'de durduğu için tarayıcı API'yi doğrudan çağıramaz;
 * burada sunucu tarafında okunup sözleşmeye iletilir.
 *
 * Yanıt gövdesi `OrderDetail` sözleşmesinin aynısıdır — ek alan üretilmez.
 */
export async function GET(_request: Request, context: { params: Promise<{ id: string }> }) {
  const { id } = await context.params;
  const orderId = Number.parseInt(id, 10);

  if (!Number.isSafeInteger(orderId) || orderId <= 0) {
    return NextResponse.json(
      { error: { code: 'NOT_FOUND', message: 'Sipariş bulunamadı.' } },
      { status: 404 },
    );
  }

  const token = await readToken();
  if (!token) {
    return NextResponse.json(
      { error: { code: 'UNAUTHENTICATED', message: 'Oturumunuz sona erdi.' } },
      { status: 401 },
    );
  }

  try {
    const order = await fetchOrder(token, orderId);
    return NextResponse.json(order, { headers: { 'Cache-Control': 'no-store' } });
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
