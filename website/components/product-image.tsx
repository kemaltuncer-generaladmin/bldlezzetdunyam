import Image from 'next/image';
import { cn } from '@/lib/cn';

type Props = {
  /** Sözleşmede `MenuItem.image_url` `null` olabilir (`docs/openapi.yaml`). */
  src?: string | null;
  /** Görsel dekoratifse boş bırakılır — ürün adı zaten yanında yazar. */
  alt: string;
  sizes: string;
  priority?: boolean;
  /** Görselin üstüne uygulanacak ek sınıflar (örn. hover büyütme). */
  className?: string;
};

/**
 * Ürün görseli ve görselsiz durumun yer tutucusu.
 *
 * Yer tutucu neden emoji değil: emoji her işletim sisteminde farklı boyda
 * çiziliyor ve kart ızgarasında hizayı bozuyordu. Marka renginde çizilmiş
 * sabit bir SVG her yerde aynı görünür.
 *
 * Kapsayıcı `position: relative` olmalıdır — görsel `fill` ile yerleşir.
 */
export function ProductImage({ src, alt, sizes, priority = false, className }: Props) {
  if (src) {
    return (
      <Image
        src={src}
        alt={alt}
        fill
        sizes={sizes}
        priority={priority}
        className={cn('object-cover', className)}
      />
    );
  }

  return (
    <span className="absolute inset-0 grid place-items-center bg-linear-to-br from-brand-100 via-brand-50 to-brand-200">
      <svg
        viewBox="0 0 64 64"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden="true"
        focusable="false"
        className="h-1/3 max-h-16 w-1/3 max-w-16 text-brand-400"
      >
        <circle cx="32" cy="32" r="20" />
        <circle cx="32" cy="32" r="11" />
        <path d="M12 32h-4M56 32h4M32 12V8M32 56v4" />
      </svg>
      {alt.length > 0 && <span className="sr-only">{alt}</span>}
    </span>
  );
}
