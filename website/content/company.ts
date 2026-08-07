/**
 * Kurumsal içerik: süreç, ayırt edici yanlar, misyon/vizyon/değerler ve SSS.
 *
 * **YEDEK / BAŞLANGIÇ DEĞERİ.** Tek kaynak admin panelidir; sayfalar bu
 * içeriği `lib/api/site-content.ts` üzerinden okur. Buradaki değerler yalnızca
 * API'ye ulaşılamadığında veya panelde ilgili bölüm boş olduğunda kullanılır.
 * Burada yapılan düzenleme yayındaki siteyi değiştirmez.
 *
 * Kuruluş yılı, çalışan sayısı, günlük üretim kapasitesi gibi rakamlar
 * bilinçli olarak yok — repoda doğrulanmış bir kaynağı yok.
 *
 * ## Ton
 *
 * Metinler mutfaktan konuşur: kısa cümle, somut isim (tencere, tepsi, kapak,
 * servis saati), gündelik Türkçe. Kaçınılan kalıplar —
 *
 * - "X değil, Y'dir" karşıtlığı (bir sayfada üç kez geçince şablon oluyor),
 * - "çözüm, süreç, yaklaşım, altyapı, kurgu, disiplin" gibi soyut isim yığını,
 * - her maddenin aynı uzunlukta olması.
 *
 * Bir cümle kısaysa kısa kalsın. Fiyat, kapasite ve belge iddiası yok.
 */

import type { LucideIcon } from 'lucide-react';
import {
  CalendarCheck,
  ClipboardList,
  MessageSquare,
  Phone,
  Soup,
  Truck,
  UsersRound,
} from 'lucide-react';

export interface ProcessStep {
  readonly title: string;
  readonly body: string;
  readonly icon: LucideIcon;
}

/** İlk telefondan düzenli servise kadar dört adım. */
export const PROCESS_STEPS: readonly ProcessStep[] = [
  {
    title: 'Konuşuyoruz',
    body: 'Kaç kişisiniz, saat kaçta yemek yiyorsunuz, mutfağınız var mı? Çoğu zaman yarım saatlik bir telefon yetiyor.',
    icon: Phone,
  },
  {
    title: 'Menüyü çıkarıyoruz',
    body: 'Size göre bir menü ve fiyat hazırlıyoruz. İsterseniz gelip tadıyorsunuz, sonra karar veriyorsunuz.',
    icon: ClipboardList,
  },
  {
    title: 'Pişirip getiriyoruz',
    body: 'Yemek sabah mutfakta yapılır, kapalı kaplarda yola çıkar. Kapağı açtığınızda hâlâ sıcaktır.',
    icon: Truck,
  },
  {
    title: 'Sonra soruyoruz',
    body: 'Ne bitti, ne arttı, kim ne beğenmedi? Bir sonraki haftanın menüsü bu cevaplara göre değişir.',
    icon: MessageSquare,
  },
];

export interface Differentiator {
  readonly title: string;
  readonly body: string;
  readonly icon: LucideIcon;
}

/** "Neden BLD?" — reklam cümlesi yerine günlük işleyişten dört başlık. */
export const DIFFERENTIATORS: readonly Differentiator[] = [
  {
    title: 'Menüyü önceden görürsünüz',
    body: 'Haftalık menü cuma günü elinizde olur. Salı ne çıkacağını salı sabahı öğrenmezsiniz.',
    icon: CalendarCheck,
  },
  {
    title: 'Tek numara, tek kişi',
    body: 'Sipariş, menü değişikliği, fatura — hepsi aynı kişide. Santralde sıra beklemiyorsunuz.',
    icon: Phone,
  },
  {
    title: 'Sayı her gün değişebilir',
    body: 'Bugün seksen, yarın yüz otuz. Sabah haber verirsiniz, o kadar pişer.',
    icon: UsersRound,
  },
  {
    title: 'Tarif kalabalıkta bozulmaz',
    body: 'Bin porsiyon çıkarken de aynı tarif, aynı ölçü. Yemeğin tadı sayıyla düşmüyor.',
    icon: Soup,
  },
];

export const MISSION =
  'Kalabalığa yemek yapmak, özenden vazgeçmek anlamına gelmesin istiyoruz. Bininci tabak da ilkiyle aynı tada sahip olsun diye uğraşıyoruz.';

export const VISION =
  'Kendi bölgesinde adı iyi anılan, başka şehirlerde de aynı düzeni kurabilen bir catering mutfağı olmak.';

export interface Value {
  readonly title: string;
  readonly body: string;
}

export const VALUES: readonly Value[] = [
  {
    title: 'Saatinde',
    body: 'Soğumuş yemeğin lezzeti tartışılmaz. Teslim saati bizim için bir söz.',
  },
  {
    title: 'Temiz mutfak',
    body: 'İşler sıkıştığında da aynı temizlik. Burada pazarlık yapmıyoruz.',
  },
  {
    title: 'Ölçülü konuşmak',
    body: 'Yetişmeyecek işe baştan hayır diyoruz. Sonradan mazeret aramak kimsenin işine yaramıyor.',
  },
  {
    title: 'Aynı sofra',
    body: 'Servis ettiğimiz insana ne yapıyorsak, mutfaktaki ekibe de aynısını yapıyoruz.',
  },
];

/** Şirket ailesi bağı — Kurumsal sayfasında tek paragraf olarak geçer. */
export const GROUP_RELATION =
  'Benim Lezzet Dünyam, Benim Başarı Dünyam şirket ailesinin mutfağıdır. Kurumsal düzenini oradan alır; menüsü, ocağı ve ekibi kendisine aittir.';

export interface FaqItem {
  readonly question: string;
  readonly answer: string;
}

export const FAQ: readonly FaqItem[] = [
  {
    question: 'En az kaç kişiye yemek yapıyorsunuz?',
    answer:
      'Düzenli hizmette ve tek günlük davette alt sınır aynı olmuyor. Kişi sayınızı söyleyin, yetişip yetişmeyeceğini o gün net söyleyelim.',
  },
  {
    question: 'Menüyü siz mi seçiyorsunuz, biz mi?',
    answer:
      'Genelde biz bir taslak çıkarıyoruz, siz üstünde oynuyorsunuz. Elinizde kendi menünüz varsa onu da uygularız.',
  },
  {
    question: 'Vejetaryen ya da alerjisi olan çalışanlarımız var.',
    answer:
      'Onlara ayrı yemek pişiriyoruz, ayrı kaba koyup etiketliyoruz. Alerjen listesini siz veriyorsunuz; liste değişince menü de değişiyor.',
  },
  {
    question: 'Kişi sayımız her gün değişiyor, sorun olur mu?',
    answer:
      'Olmaz. Sabah kaç kişi olduğunuzu bildiriyorsunuz, o kadar hazırlıyoruz. Değişken sayı bizim için olağan.',
  },
  {
    question: 'Yemek sıcak geliyor mu?',
    answer:
      'Isı tutan kapalı kaplarda taşınıyor ve teslimde sıcaklığa bakılıyor. Yol uzunsa menüyü de ona göre kuruyoruz — yolda dağılacak yemeği o güne koymuyoruz.',
  },
  {
    question: 'Tabak, çatal ve servis elemanı da veriyor musunuz?',
    answer:
      'Taşıma yemekte yemeği servise hazır bırakıyoruz. Davet ve organizasyonlarda kurulum, servis ekibi ve toplama işi de bize ait olabilir.',
  },
  {
    question: 'Fiyatlar neden sitede yazmıyor?',
    answer:
      'Kişi sayısı, öğün sayısı, kaç gün ve nereye — dördü değişince fiyat da değişiyor. Sabit bir liste yazsak yanıltıcı olurdu. Bilgileri iletin, size özel çıkaralım.',
  },
  {
    question: 'Ne kadar süreyle sözleşme yapmamız gerekiyor?',
    answer:
      'Zorunlu bir alt süre koymuyoruz. Düzenli hizmette genelde dönemsel bir çerçeve tercih ediliyor; davetler için sözleşme etkinliğe özel yazılıyor.',
  },
];
