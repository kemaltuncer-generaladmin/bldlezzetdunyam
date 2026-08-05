/**
 * Arayüz ikonları. Harici ikon paketi eklenmedi (AGENTS.md §2.4): ihtiyacımız
 * olan on ikon için 40 KB'lık bir bağımlılık taşımak yerine satır içi SVG.
 *
 * Hepsi `currentColor` ile çizilir, `aria-hidden` gelir — anlam taşıyan yerde
 * yanına metin veya `sr-only` etiket konur.
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
    strokeWidth: 1.8,
    strokeLinecap: 'round',
    strokeLinejoin: 'round',
    'aria-hidden': true,
    focusable: false,
  };
}

export function IconSearch({ className }: IconProps) {
  return (
    <svg {...base(className)}>
      <circle cx="11" cy="11" r="7" />
      <path d="m20 20-3.5-3.5" />
    </svg>
  );
}

export function IconClose({ className }: IconProps) {
  return (
    <svg {...base(className)}>
      <path d="M6 6l12 12M18 6 6 18" />
    </svg>
  );
}

export function IconSliders({ className }: IconProps) {
  return (
    <svg {...base(className)}>
      <path d="M4 6h10M18 6h2M4 12h4M12 12h8M4 18h10M18 18h2" />
      <circle cx="16" cy="6" r="2" />
      <circle cx="10" cy="12" r="2" />
      <circle cx="16" cy="18" r="2" />
    </svg>
  );
}

export function IconCart({ className }: IconProps) {
  return (
    <svg {...base(className)}>
      <path d="M3 4h2l2.4 11.2a2 2 0 0 0 2 1.6h7.5a2 2 0 0 0 2-1.55L20.5 8H6" />
      <circle cx="10" cy="20" r="1.2" />
      <circle cx="17" cy="20" r="1.2" />
    </svg>
  );
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

export function IconRoute({ className }: IconProps) {
  return (
    <svg {...base(className)}>
      <circle cx="6" cy="6" r="2.5" />
      <circle cx="18" cy="18" r="2.5" />
      <path d="M8.5 6H14a3.5 3.5 0 0 1 0 7h-4a3.5 3.5 0 0 0 0 7h5.5" />
    </svg>
  );
}

export function IconLeaf({ className }: IconProps) {
  return (
    <svg {...base(className)}>
      <path d="M5 19c0-7 4.5-11 15-11 0 8-4 12-10 12-2.8 0-5-1.5-5-1z" />
      <path d="M9 15c2-3 4.5-4.8 8-6" />
    </svg>
  );
}

export function IconPlate({ className }: IconProps) {
  return (
    <svg {...base(className)}>
      <circle cx="12" cy="12" r="8.5" />
      <circle cx="12" cy="12" r="4.5" />
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

export function IconChevronRight({ className }: IconProps) {
  return (
    <svg {...base(className)}>
      <path d="m9.5 5 7 7-7 7" />
    </svg>
  );
}

export function IconInfo({ className }: IconProps) {
  return (
    <svg {...base(className)}>
      <circle cx="12" cy="12" r="8.5" />
      <path d="M12 11v5.5" />
      <path d="M12 7.8h.01" />
    </svg>
  );
}
