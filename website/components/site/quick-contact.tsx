import { MessageCircle, Phone } from 'lucide-react';
import { CONTACT } from '@/content/site';

/**
 * Sabit hızlı iletişim düğmesi.
 *
 * Hiçbir kanal girilmemişse **hiç render edilmez** — boş bir baloncuk
 * göstermek yerine.
 *
 * Yerleşim notu: mobilde sağ altta duruyor ve içeriğin üstüne biniyor. Bunun
 * kapattığı alanı telafi etmek için `<body>` yerine burada değil, `layout`
 * içinde alt boşluk verilmiyor — bunun yerine düğme `bottom-4` yerine
 * `bottom-[max(1rem,env(safe-area-inset-bottom))]` kullanıyor ki iPhone'daki
 * ana ekran çubuğunun altında kalmasın, ve footer'ın son satırı zaten
 * yasal bağlantılardan oluştuğu için üzerine binmesi bilgi kaybı yaratmıyor.
 */
export function QuickContact() {
  const channel = CONTACT.whatsapp ?? CONTACT.phone;
  if (!channel) return null;

  const isWhatsapp = CONTACT.whatsapp !== null;
  const Icon = isWhatsapp ? MessageCircle : Phone;
  const label = isWhatsapp ? 'WhatsApp ile yazın' : `Telefon: ${channel.display}`;

  return (
    <a
      href={channel.href}
      aria-label={label}
      className="fixed right-4 bottom-[max(1rem,env(safe-area-inset-bottom))] z-30 grid size-14 place-items-center rounded-full bg-primary text-primary-foreground shadow-lg transition-transform hover:shadow-xl focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 motion-safe:hover:scale-105"
    >
      <Icon aria-hidden="true" className="size-6" />
    </a>
  );
}
