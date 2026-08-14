import Link from 'next/link';
import { TriangleAlert, WifiOff } from 'lucide-react';
import type { ReactNode } from 'react';
import { Button } from '@/components/ui/button';
import { StatePanel } from '@/components/state-panel';

type Props = {
  title?: string;
  message: string;
  /** "Tekrar deneyin" bağlantısının hedefi. */
  retryHref?: string;
  retryLabel?: string;
  className?: string;
};

/**
 * Hata paneli.
 *
 * ## `role="alert"`
 *
 * Ekran okuyucuyu keser ve metni araya sokar. Bu davranış YALNIZCA hata için
 * doğru; boş liste (`EmptyState`) ve çevrimdışı bilgisi (`OfflineState`) onu
 * kullanmaz.
 *
 * ## Eylem neden OUTLINE?
 *
 * "Tekrar deneyin" bir onarım denemesidir, sayfanın birincil eylemi değil.
 * Hata kutusunun içinde dolu bir primary buton, arkadaki sayfanın gerçek
 * birincil eylemiyle yarışıyordu (görünüm başına TEK primary).
 */
export function ErrorState({
  title = 'Bir sorun oluştu',
  message,
  retryHref,
  retryLabel = 'Tekrar deneyin',
  className,
}: Props) {
  return (
    <StatePanel
      tone="error"
      role="alert"
      icon={<TriangleAlert aria-hidden="true" strokeWidth={1.75} />}
      title={title}
      message={message}
      className={className}
      action={
        retryHref ? (
          <Button asChild variant="outline">
            <Link href={retryHref}>{retryLabel}</Link>
          </Button>
        ) : undefined
      }
    />
  );
}

/**
 * Çevrimdışı / erişilemiyor durumu.
 *
 * `role="status"` — kibar sıra: kullanıcı okuduğu cümleyi bitirsin, sonra
 * duyulsun. Bağlantının kopması kullanıcının YAPTIĞI bir hata değil ve
 * `role="alert"` ile kesmek, ağ birkaç saniyede bir gidip geldiğinde ekran
 * okuyucuyu kullanılamaz hâle getiriyor.
 *
 * Eylem çağırana bırakıldı: çevrimdışıyken sayfa yenilemek bir istemci
 * davranışıdır (`onClick`), sunucu bileşeni olan bu dosya buton mantığı
 * taşıyamaz.
 */
export function OfflineState({
  title = 'Bağlantı kurulamadı',
  message = 'İnternet bağlantınızı kontrol edip tekrar deneyin. Sepetiniz kayıtlı kalır.',
  action,
  className,
}: {
  title?: string;
  message?: string;
  action?: ReactNode;
  className?: string;
}) {
  return (
    <StatePanel
      tone="offline"
      role="status"
      icon={<WifiOff aria-hidden="true" strokeWidth={1.75} />}
      title={title}
      message={message}
      className={className}
      action={action}
    />
  );
}
