/**
 * Kurumsal içerik: süreç, ayırt edici yanlar, misyon/vizyon/değerler ve SSS.
 *
 * **YEDEK / BAŞLANGIÇ DEĞERİ.** Tek kaynak admin panelidir; sayfalar bu
 * içeriği `lib/api/site-content.ts` üzerinden okur. Buradaki değerler yalnızca
 * API'ye ulaşılamadığında veya panelde ilgili bölüm boş olduğunda kullanılır.
 * Burada yapılan düzenleme yayındaki siteyi değiştirmez.
 *
 * Kuruluş yılı, çalışan sayısı, günlük üretim kapasitesi gibi rakamlar
 * bilinçli olarak yok — repoda doğrulanmış bir kaynağı yok. Güven, rakam
 * iddiasıyla değil, işin nasıl yürüdüğünü anlatarak kuruluyor.
 */

import type { LucideIcon } from 'lucide-react';
import {
  CalendarCheck,
  ClipboardList,
  HandshakeIcon,
  MessageSquare,
  Soup,
  Sparkles,
  Truck,
  UsersRound,
} from 'lucide-react';

export interface ProcessStep {
  readonly title: string;
  readonly body: string;
  readonly icon: LucideIcon;
}

/** "Nasıl çalışıyoruz" — ilk temastan düzenli hizmete kadar. */
export const PROCESS_STEPS: readonly ProcessStep[] = [
  {
    title: 'İhtiyacı dinliyoruz',
    body: 'Kişi sayısı, öğün saatleri, hizmet konumu ve varsa mevcut mutfak altyapınızı konuşuyoruz.',
    icon: MessageSquare,
  },
  {
    title: 'Menü ve teklif hazırlıyoruz',
    body: 'İhtiyacınıza uygun menü kurgusu ve fiyatlandırma çıkarılıyor; gerekirse tadım planlanıyor.',
    icon: ClipboardList,
  },
  {
    title: 'Planı sabitliyoruz',
    body: 'Teslimat saatleri, servis düzeni ve haftalık menü onayınızla kesinleşiyor.',
    icon: CalendarCheck,
  },
  {
    title: 'Üretip teslim ediyoruz',
    body: 'Öğünler planlanan saatte hazırlanıp sıcaklık kontrollü biçimde teslim ediliyor.',
    icon: Truck,
  },
  {
    title: 'Takip edip düzeltiyoruz',
    body: 'Tüketim ve geri bildirim izleniyor; menü ve porsiyonlar buna göre güncelleniyor.',
    icon: Sparkles,
  },
];

export interface Differentiator {
  readonly title: string;
  readonly body: string;
  readonly icon: LucideIcon;
}

/** "Neden BLD?" — vaat değil, çalışma biçimi. */
export const DIFFERENTIATORS: readonly Differentiator[] = [
  {
    title: 'Menü planı önceden belli',
    body: 'Haftalık menü önden paylaşılır. Ne çıkacağını sabahında öğrenmezsiniz; planlama yapabilirsiniz.',
    icon: ClipboardList,
  },
  {
    title: 'Tek muhatap',
    body: 'Sipariş, teslimat, menü değişikliği ve faturalama tek kişiyle yürür. Sorun için sıraya girmezsiniz.',
    icon: HandshakeIcon,
  },
  {
    title: 'Değişken sayıya uyum',
    body: 'Personel sayısı gün gün değişen iş yerlerinde öğün adedi günlük olarak güncellenir.',
    icon: UsersRound,
  },
  {
    title: 'Yemek yemek gibi',
    body: 'Toplu üretimde de tarif ve porsiyon disiplini korunur. Menü, insanların gerçekten yediği yemeklerden kurulur.',
    icon: Soup,
  },
];

export const MISSION =
  'Kalabalık için yemek üretmenin, evdeki özenden ödün vermeyi gerektirmediğini göstermek. Her öğünü, servis edeceğimiz insanların masasına kendi masamıza koyar gibi hazırlamak.';

export const VISION =
  'Yerel bağını koruyan, ulusal ölçekte kurumlara hizmet verebilecek düzende çalışan; planlaması, hijyeni ve lezzetiyle tercih edilen bir catering markası olmak.';

export interface Value {
  readonly title: string;
  readonly body: string;
}

export const VALUES: readonly Value[] = [
  {
    title: 'Söz verdiğimiz saatte',
    body: 'Yemeğin lezzeti kadar zamanında gelmesi de hizmetin parçasıdır. Teslim saati taahhüttür.',
  },
  {
    title: 'Hijyen tartışma konusu değil',
    body: 'Temizlik, işler sıkıştığında esnetilen bir başlık değil; üretim akışının kendisidir.',
  },
  {
    title: 'Abartmadan konuşmak',
    body: 'Yapabileceğimizi söyler, yapamayacağımıza hayır deriz. Beklentiyi baştan doğru kurmak sonradan özür dilemekten iyidir.',
  },
  {
    title: 'İnsan önce gelir',
    body: 'Servis ettiğimiz kişi de, mutfakta çalışan ekip de aynı özeni hak eder.',
  },
];

/** Şirket ailesi bağı — Kurumsal sayfasında tek paragraf olarak geçer. */
export const GROUP_RELATION =
  'Benim Lezzet Dünyam, Benim Başarı Dünyam şirket ailesinin yemek ve catering markasıdır. Aynı kurumsal disiplinle çalışır; kendi alanında bağımsız bir yapı olarak yönetilir.';

export interface FaqItem {
  readonly question: string;
  readonly answer: string;
}

export const FAQ: readonly FaqItem[] = [
  {
    question: 'Minimum kaç kişilik hizmet veriyorsunuz?',
    answer:
      'Alt sınır hizmet türüne göre değişir. Düzenli kurumsal yemekte ve tek seferlik organizasyonlarda ölçek farklıdır; kişi sayınızı ilettiğinizde uygun olup olmadığını net biçimde söylüyoruz.',
  },
  {
    question: 'Menüyü biz mi seçiyoruz, siz mi hazırlıyorsunuz?',
    answer:
      'İkisi de mümkün. Genellikle ihtiyacınıza göre bir menü planı hazırlayıp onayınıza sunuyoruz; üzerinde değişiklik yapabilir, kendi menünüzü de verebilirsiniz.',
  },
  {
    question: 'Vejetaryen veya alerjisi olan çalışanlarımız için ne yapılıyor?',
    answer:
      'Ana menüye alternatif öğün planlanır, ayrı hazırlanır ve etiketlenir. Alerjen bilgisi kurumdan gelen listeye göre takip edilir; liste değiştiğinde menü planı da güncellenir.',
  },
  {
    question: 'Kişi sayımız her gün değişiyor, bu sorun olur mu?',
    answer:
      'Olmaz. Değişken sayıyla çalışan iş yerleri için günlük bildirim düzeni kuruyoruz; öğün adedi sabahtan gelen sayıya göre güncellenir.',
  },
  {
    question: 'Yemek nasıl taşınıyor, sıcak geliyor mu?',
    answer:
      'Öğünler ısı yalıtımlı kapalı kaplarda taşınır ve teslimde sıcaklık kontrol edilir. Uzun bekleme gerektiren teslimatlarda menü, taşımaya uygun yemeklerden kurulur.',
  },
  {
    question: 'Servis malzemesi ve personeli siz mi sağlıyorsunuz?',
    answer:
      'Hizmet türüne göre değişir. Taşıma yemekte servise hazır teslim yapılır; yerinde üretim ve organizasyon catering hizmetlerinde servis ekibi ve ekipman kurulumu dâhil planlanabilir.',
  },
  {
    question: 'Fiyatları neden sitede göremiyorum?',
    answer:
      'Catering fiyatı kişi sayısı, öğün sayısı, hizmet sıklığı ve konuma göre değişiyor. Sabit bir liste vermek yanıltıcı olurdu; ihtiyacınızı ilettiğinizde size özel teklif hazırlıyoruz.',
  },
  {
    question: 'Sözleşme süresi ne kadar olmak zorunda?',
    answer:
      'Zorunlu bir alt süre dayatmıyoruz. Düzenli hizmetlerde genellikle dönemsel bir çerçeve tercih ediliyor; tek seferlik organizasyonlar için sözleşme etkinliğe özel hazırlanıyor.',
  },
];
