import { getRequestConfig } from 'next-intl/server';
import trMessages from '../messages/tr.json';

/**
 * Tek dil (tr). Locale isteğe göre değişmediği için sayfalar statik/ISR
 * kalabiliyor — `requestLocale` bilinçli olarak okunmuyor (docs/06 §2, §5).
 */
export const DEFAULT_LOCALE = 'tr' as const;
export const TIME_ZONE = 'Europe/Istanbul' as const;

export default getRequestConfig(() => {
  return Promise.resolve({
    locale: DEFAULT_LOCALE,
    timeZone: TIME_ZONE,
    messages: trMessages,
  });
});
