/**
 * Arayüz ikonları — satır içi SVG.
 *
 * Hepsi `currentColor` ile çizilir, `aria-hidden` gelir — anlam taşıyan yerde
 * yanına metin veya `sr-only` etiket konur.
 *
 * LİSTE B-19'DA KISALDI. Kalan dördü vitrin bilgisi (`LocationFacts`) ve
 * teslim tahmini (`DeliveryEta`) içinde kullanılıyor. Sepet, arama, filtre ve
 * tabak ikonları katalog ekranlarıyla birlikte gitti; geri kalan yerlerde
 * `lucide-react` kullanılıyor (kılavuz: her iki yüzeyde de SADECE outline,
 * ~1.75 optik kalınlık — buradaki çizimler de aynı kalınlıkta).
 */
type IconProps = {
  className?: string;
};

function base(className?: string): React.SVGProps<SVGSVGElement> {
  return {
    className: className ?? 'h-5 w-5',
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    // 1.75: lucide çağrılarıyla AYNI optik kalınlık. Bu dosyadaki çizimler
    // lucide ikonlarıyla yan yana duruyor (örn. sepet satırında) ve 0.05'lik
    // fark bile birinin daha kalın görünmesine yetiyordu.
    strokeWidth: 1.75,
    strokeLinecap: 'round',
    strokeLinejoin: 'round',
    'aria-hidden': true,
    focusable: false,
  };
}

export function IconTruck({ className }: IconProps) {
  return (
    <svg {...base(className)}>
      <path d="M3 7h11v9H3zM14 10h4l3 3v3h-7z" />
      <circle cx="7" cy="18" r="1.6" />
      <circle cx="17.5" cy="18" r="1.6" />
    </svg>
  );
}

export function IconClock({ className }: IconProps) {
  return (
    <svg {...base(className)}>
      <circle cx="12" cy="12" r="8.5" />
      <path d="M12 7.5V12l3 1.8" />
    </svg>
  );
}

export function IconWallet({ className }: IconProps) {
  return (
    <svg {...base(className)}>
      <path d="M3.5 8.5A2.5 2.5 0 0 1 6 6h11a2 2 0 0 1 2 2v1" />
      <path d="M3.5 8.5V17a2 2 0 0 0 2 2H19a1.5 1.5 0 0 0 1.5-1.5v-6A1.5 1.5 0 0 0 19 10H5.5" />
      <circle cx="16.5" cy="14.5" r="1" />
    </svg>
  );
}

export function IconCheck({ className }: IconProps) {
  return (
    <svg {...base(className)}>
      <path d="m5 12.5 4.5 4.5L19 7" />
    </svg>
  );
}
