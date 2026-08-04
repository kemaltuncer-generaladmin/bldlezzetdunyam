import { NextResponse, type NextRequest } from 'next/server';

const SESSION_COOKIE = 'bld_token';

/**
 * Korumalı rotalar. Middleware yalnızca **token var mı** diye bakar; geçerli
 * olup olmadığını sayfa kendisi doğrular (`401` → `/giris`). Böylece geçersiz
 * token'la da sonsuz döngü oluşmaz.
 */
export function middleware(request: NextRequest) {
  if (request.cookies.get(SESSION_COOKIE)?.value) return NextResponse.next();

  const target = `${request.nextUrl.pathname}${request.nextUrl.search}`;
  const loginUrl = new URL('/giris', request.url);
  loginUrl.searchParams.set('next', target);
  return NextResponse.redirect(loginUrl);
}

export const config = {
  matcher: ['/odeme/:path*', '/siparis/:path*', '/siparislerim/:path*', '/hesabim/:path*'],
};
