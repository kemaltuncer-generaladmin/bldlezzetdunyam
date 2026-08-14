import Image from 'next/image';
import { cn } from '@/lib/utils';

/**
 * ORTAK ÇİZİM — BUĞDAY YAYI (görseli olmayan ürünün yer tutucusu).
 *
 * ## Neden bu çizim?
 *
 * Logodaki kürenin ayırt edici yarısı buğday yayıdır (bkz. `app/icon.svg`).
 * Ürünlerin yaklaşık yarısında fotoğraf yok ve yer tutucu, kullanıcının
 * menüde en çok gördüğü ikinci grafik. Önceki hâli genel bir "tabak" ikonuydu
 * — hiçbir markaya ait değildi ve mobil uygulama BAŞKA bir çizim
 * kullanıyordu; platformlar arasındaki en görünür tutarsızlık buydu.
 *
 * ## Koordinat sistemi SÖZLEŞMEDİR
 *
 * Yollar 64×64'lük bir kutuda, `stroke-width: 2` (yay) ve `1.4` (çentik) ile
 * tanımlıdır. Flutter tarafı AYNI sayıları AYNI kutuda ölçekler
 * (`musteriapp`). Buradaki bir sayıyı değiştirmek iki yüzeyi ayırır; çizim
 * değişecekse iki tarafta birlikte değişir.
 *
 * Yaylar sırayla daralır (40 → 34 → 26 birim) ve her yayın SOL yarısı yukarı,
 * SAĞ yarısı aşağı bombelidir (`q` sonrası `t` denetim noktasını yansıtır) —
 * bu yüzden sağ yarının çentikleri iki birim daha aşağıda. Çentikler örgü/
 * başak okumasını veriyor: çentiksiz hâli su dalgası gibi görünüyor.
 */
export const WHEAT_ARC = {
  viewBox: '0 0 64 64',
  /** Üç yığılı buğday sırası. `stroke-width: 2`. */
  rows: ['M12 22q10-3.4 20 0t20 0', 'M15 32q8.5-3 17 0t17 0', 'M19 42q6.5-2.6 13 0t13 0'],
  /** Başak çentikleri — her sırada ikisi solda, ikisi sağda. `stroke-width: 1.4`. */
  notches: [
    'M16.5 22.4l2.8-2.8M23.5 22.4l2.8-2.8M35.5 24.6l2.8-2.8M42.5 24.6l2.8-2.8',
    'M19 32.4l2.8-2.8M25.5 32.4l2.8-2.8M36 34.4l2.8-2.8M42 34.4l2.8-2.8',
    'M22.5 42.4l2.8-2.8M28 42.4l2.8-2.8M36 44l2.8-2.8M40.5 44l2.8-2.8',
  ],
} as const;

/** Buğday yayı işareti. Renk `currentColor` — kabı verir. */
export function WheatArcMark({ className }: { className?: string }) {
  return (
    <svg
      viewBox={WHEAT_ARC.viewBox}
      fill="none"
      stroke="currentColor"
      strokeLinecap="round"
      aria-hidden="true"
      focusable="false"
      className={className}
    >
      <g strokeWidth="2">
        {WHEAT_ARC.rows.map((d) => (
          <path key={d} d={d} />
        ))}
      </g>
      <g strokeWidth="1.4">
        {WHEAT_ARC.notches.map((d) => (
          <path key={d} d={d} />
        ))}
      </g>
    </svg>
  );
}

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
 * Kapsayıcı `position: relative` olmalıdır — görsel `fill` ile yerleşir.
 *
 * Gerçek fotoğraf `bld-photo` ile çiziliyor: 1 px iç halka. Beyaz tabaklı bir
 * yemek fotoğrafı beyaz kartın içinde eriyor ve kart kenarını kaybediyordu.
 * Marka rengi overlay ATILMAZ — yemeğin kendi rengi ürünün kendisi.
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
        className={cn('bld-photo', className)}
      />
    );
  }

  return (
    /*
     * İşaretin boyu kabın KISA kenarının %33'ü (`cqmin`). Yüzde GENİŞLİK
     * verilseydi 16:9 bir detay görselinde işaret devleşir, 1:1 sepet
     * satırında kaybolurdu — üç oranda da aynı okunması gerekiyor.
     *
     * `container-type: size`, Tailwind'in `@container`ı (inline-size) DEĞİL:
     * `inline-size` yalnızca yatay ekseni sorgulanabilir yapıyor ve `cqmin`in
     * dikey yarısı sessizce küçük görünüm alanı birimine (`svh`) düşüyor —
     * yani yer tutucu telefon ekranının üçte biri kadar oluyordu. Bu kutu
     * `absolute inset-0` olduğu için iki boyutu da kesin; `size` güvenli.
     */
    <span className="[container-type:size] absolute inset-0 grid place-items-center bg-linear-[135deg] from-brand-50 to-brand-100">
      <WheatArcMark className="size-[33cqmin] text-brand-300" />
      {alt.length > 0 && <span className="sr-only">{alt}</span>}
    </span>
  );
}
