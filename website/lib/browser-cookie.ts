/**
 * Tarayıcıda `httpOnly` olmayan cookie okuma. Yalnızca görsel ipuçları için
 * kullanılır (sepet rozeti, başlıktaki ad) — yetki kararı **asla** buna
 * dayandırılmaz, oturum token'ı `httpOnly`'dir.
 */
export function readBrowserCookie(name: string): string | null {
  if (typeof document === 'undefined') return null;
  const prefix = `${encodeURIComponent(name)}=`;
  for (const part of document.cookie.split('; ')) {
    if (part.startsWith(prefix)) {
      return decodeURIComponent(part.slice(prefix.length));
    }
  }
  return null;
}
