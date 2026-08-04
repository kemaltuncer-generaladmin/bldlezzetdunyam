/**
 * `?next=` parametresi yalnızca **site içi** bir yola işaret edebilir.
 * Protokol veya `//` ile başlayan değerler açık yönlendirme (open redirect)
 * açığı yaratır; bunlar sessizce varsayılana düşürülür.
 */
export function safeInternalPath(value: string | null | undefined, fallback = '/'): string {
  if (typeof value !== 'string' || value.length === 0) return fallback;
  if (!value.startsWith('/')) return fallback;
  if (value.startsWith('//') || value.startsWith('/\\')) return fallback;
  return value;
}
