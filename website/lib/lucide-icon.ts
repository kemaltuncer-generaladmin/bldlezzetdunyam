import {
  Apple,
  Award,
  BadgeCheck,
  Beef,
  Bike,
  Boxes,
  Building,
  Building2,
  CalendarCheck,
  CalendarHeart,
  Carrot,
  Check,
  ChefHat,
  CircleCheck,
  ClipboardCheck,
  ClipboardList,
  Clock,
  Coffee,
  Compass,
  CookingPot,
  Croissant,
  Egg,
  Eye,
  Factory,
  FileCheck,
  Flame,
  Flower2,
  GlassWater,
  GraduationCap,
  Handshake,
  HardHat,
  Heart,
  HeartPulse,
  Hospital,
  Info,
  Landmark,
  Leaf,
  Lightbulb,
  Mail,
  MapPin,
  MessageSquare,
  MessagesSquare,
  Milk,
  Package,
  PackageCheck,
  PartyPopper,
  Phone,
  Recycle,
  Refrigerator,
  RefreshCw,
  Salad,
  Scale,
  School,
  ScrollText,
  Send,
  ShieldCheck,
  Snowflake,
  Soup,
  Sparkles,
  Sprout,
  Star,
  Stethoscope,
  Store,
  Sun,
  Target,
  ThermometerSnowflake,
  ThumbsUp,
  Timer,
  TrafficCone,
  TrendingUp,
  Truck,
  Users,
  UsersRound,
  Utensils,
  UtensilsCrossed,
  Warehouse,
  Wheat,
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';

/**
 * İkon adı → bileşen eşlemesi.
 *
 * ## Neden açık bir kayıt defteri, `lucide-react`'ın tamamı değil?
 *
 * Admin panelinde ikon bir **metin** olarak giriliyor (`"ChefHat"`). Bunu
 * bileşene çevirmenin kolay yolu `import * as icons from 'lucide-react'` yazıp
 * `icons[name]` demek olurdu; o zaman paketin binden fazla ikonu modül grafiğine
 * girer ve ağaç sarsma tamamen devre dışı kalır (`next.config.ts` içindeki
 * `optimizePackageImports` notuna bakın — barrel içe aktarımların maliyetini
 * bir kez ölçtük).
 *
 * Bu yüzden catering içeriğinde işe yarayabilecek ikonlar tek tek listeleniyor.
 * Listede olmayan bir ad geldiğinde **çökmüyoruz ve boş kutu basmıyoruz**;
 * `DEFAULT_ICON` devreye giriyor. Panelde yeni bir ikon kullanılmak isteniyorsa
 * yapılacak tek iş buraya bir satır eklemek.
 */
const ICON_REGISTRY = {
  Apple,
  Award,
  BadgeCheck,
  Beef,
  Bike,
  Boxes,
  Building,
  Building2,
  CalendarCheck,
  CalendarHeart,
  Carrot,
  Check,
  ChefHat,
  CircleCheck,
  ClipboardCheck,
  ClipboardList,
  Clock,
  Coffee,
  Compass,
  CookingPot,
  Croissant,
  Egg,
  Eye,
  Factory,
  FileCheck,
  Flame,
  Flower2,
  GlassWater,
  GraduationCap,
  Handshake,
  HardHat,
  Heart,
  HeartPulse,
  Hospital,
  Info,
  Landmark,
  Leaf,
  Lightbulb,
  Mail,
  MapPin,
  MessageSquare,
  MessagesSquare,
  Milk,
  Package,
  PackageCheck,
  PartyPopper,
  Phone,
  Recycle,
  Refrigerator,
  RefreshCw,
  Salad,
  Scale,
  School,
  ScrollText,
  Send,
  ShieldCheck,
  Snowflake,
  Soup,
  Sparkles,
  Sprout,
  Star,
  Stethoscope,
  Store,
  Sun,
  Target,
  ThermometerSnowflake,
  ThumbsUp,
  Timer,
  TrafficCone,
  TrendingUp,
  Truck,
  Users,
  UsersRound,
  Utensils,
  UtensilsCrossed,
  Warehouse,
  Wheat,
} satisfies Record<string, LucideIcon>;

/**
 * Ad bulunamadığında basılan ikon.
 *
 * Bilerek nötr ve konuyla ilgili bir simge: kart düzeni bozulmuyor, ziyaretçi
 * "burada bir şey eksik" hissi almıyor. Yanlış ikon, boş kutudan iyidir.
 */
export const DEFAULT_ICON: LucideIcon = UtensilsCrossed;

/**
 * Aramayı biçimden bağımsız kılan dizin.
 *
 * Panelde ad `ChefHat`, `chef-hat` veya `chef hat` olarak girilebiliyor;
 * lucide belgeleri kebab-case, kod PascalCase kullanıyor. Harf dışı her şeyi
 * atıp küçük harfe indirerek üçünü de aynı anahtara topluyoruz.
 */
const LOOKUP: ReadonlyMap<string, LucideIcon> = new Map(
  Object.entries(ICON_REGISTRY).map(([name, icon]) => [normalizeIconName(name), icon]),
);

function normalizeIconName(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9]/g, '');
}

/** Bilinmeyen ad, boş metin ve `null` için varsayılana düşer — asla `undefined`. */
export function resolveIcon(name: unknown, fallback: LucideIcon = DEFAULT_ICON): LucideIcon {
  if (typeof name !== 'string') return fallback;

  const trimmed = name.trim();
  if (trimmed.length === 0) return fallback;

  // Lucide bazı ikonları `XIcon` takma adıyla da yayınlıyor (`HandshakeIcon`).
  // Panelden o biçim gelirse de eşleşsin diye son ek bir kez soyuluyor.
  return (
    LOOKUP.get(normalizeIconName(trimmed)) ??
    LOOKUP.get(normalizeIconName(trimmed.replace(/icon$/i, ''))) ??
    fallback
  );
}
