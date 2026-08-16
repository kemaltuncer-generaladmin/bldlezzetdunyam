import { formatDayMonth, formatLongDate, type BusinessDate } from '@/lib/business-date';
import type {
  DailyMenuUnavailableReason,
  DeliveryType,
  OrderStatus,
  PaymentStatus,
} from '@/lib/api/types';
import type { CheckoutPaymentMethod } from '@/lib/validation/checkout';

const ORDER_STATUS_LABELS: Record<OrderStatus, string> = {
  yeni: 'Alındı',
  onaylandi: 'Onaylandı',
  hazirlaniyor: 'Hazırlanıyor',
  hazir: 'Hazır',
  yolda: 'Yolda',
  teslim_edildi: 'Teslim edildi',
  iptal: 'İptal edildi',
};

/**
 * Sunucu sözleşmeye değer **ekleyebilir** (`PaymentStatus` notu). Bilinmeyen
 * değerde çökmek yerine "Belirsiz" göster.
 */
export function orderStatusLabel(status: string): string {
  return ORDER_STATUS_LABELS[status as OrderStatus] ?? 'Belirsiz';
}

/*
 * ÖDEME YÖNTEMİ SÖZ DAĞARCIĞI — `PaymentMethod` değil, `CheckoutPaymentMethod`.
 *
 * Sözleşmedeki `PaymentMethod` üç değer taşıyor ve `account` orada KALIYOR:
 * cutover öncesi siparişleri çözen istemci, kapalı birleşim tipine uymayan
 * bir değerle karşılaşırsa kırk siparişlik geçmişi tek eski satır yüzünden
 * hiç açamazdı (`docs/openapi.yaml` → `PaymentMethod`).
 *
 * Sitenin SUNDUĞU küme ise `lib/validation/checkout.ts` içindeki
 * `CheckoutPaymentMethod` — `online` + `cash`. Tabloları o tipe bağlamak,
 * cari hesabın ödeme ekranına geri sızmasını derleme anında engelliyor:
 * `account` için bir metin yazmak artık tip hatası.
 */
const PAYMENT_METHOD_LABELS: Record<CheckoutPaymentMethod, string> = {
  cash: 'Kapıda ödeme',
  online: 'Online ödeme (kredi kartı)',
};

const PAYMENT_METHOD_HINTS: Record<CheckoutPaymentMethod, string> = {
  cash: 'Teslimat sırasında nakit veya kart ile ödersiniz.',
  online: 'Güvenli ödeme sayfasına yönlendirilirsiniz.',
};

/**
 * KALDIRILMIŞ yöntemler — yalnız GEÇMİŞ siparişlerde görünür, hiçbir yerde
 * teklif edilmez.
 *
 * Ayrı tabloda çünkü tek tabloda dursaydı `Record<CheckoutPaymentMethod,…>`
 * kısıtı işlemez, ödeme ekranı da yanlışlıkla buradan metin bulabilirdi.
 * Etiket geçmiş zaman kuruyor ("kapatıldı") ki eski bir siparişi açan
 * müşteri, artık seçemeyeceği bir yöntemi arayıp durmasın.
 */
const RETIRED_PAYMENT_METHOD_LABELS: Record<string, string> = {
  account: 'Cari hesap (kapatıldı)',
};

export function paymentMethodLabel(method: string): string {
  return (
    PAYMENT_METHOD_LABELS[method as CheckoutPaymentMethod] ??
    RETIRED_PAYMENT_METHOD_LABELS[method] ??
    'Diğer'
  );
}

/** Yalnız SUNULAN yöntemlerin ipucu var; geçmişteki bir yöntem seçilemez. */
export function paymentMethodHint(method: string): string {
  return PAYMENT_METHOD_HINTS[method as CheckoutPaymentMethod] ?? '';
}

const PAYMENT_STATUS_LABELS: Record<PaymentStatus, string> = {
  pending: 'Ödeme bekleniyor',
  paid: 'Ödendi',
};

export function paymentStatusLabel(status: string): string {
  return PAYMENT_STATUS_LABELS[status as PaymentStatus] ?? 'Belirsiz';
}

const DELIVERY_TYPE_LABELS: Record<DeliveryType, string> = {
  delivery: 'Adrese teslim',
  pickup: 'Gel-al',
};

export function deliveryTypeLabel(type: string): string {
  return DELIVERY_TYPE_LABELS[type as DeliveryType] ?? 'Belirsiz';
}

/** Sipariş iptal edilebilir mi? Yalnızca `yeni` ve `onaylandi` (`docs/06` §4). */
export function isCancellable(status: string): boolean {
  return status === 'yeni' || status === 'onaylandi';
}

/** Terminal durumlar — polling burada durur. */
export function isTerminalStatus(status: string): boolean {
  return status === 'teslim_edildi' || status === 'iptal';
}

/**
 * GÜNÜN MENÜSÜ — sipariş alınamama sebebinin Türkçesi (B-19).
 *
 * ## Metin neden sunucudan gelmiyor?
 *
 * Sunucu `unavailable_reason` alanında MAKİNE OKUNUR bir sebep veriyor
 * (`closed_day`, `not_published`, …) ve sözleşme bunu açıkça söylüyor:
 * *"Kullanıcıya gösterilecek metni istemci kendi diliyle yazar — sunucudan
 * gelen cümleyi ekrana basmak, arayüz metnini sunucu sürümüne bağlar."*
 * Sunucudaki bir kelime düzeltmesi üç istemcinin metnini birden değiştirirdi
 * ve hiçbiri gözden geçirilmemiş olurdu.
 *
 * ## Neden başlık ve gövde ayrı?
 *
 * Boş/hata paneli ikisini de istiyor (`StatePanel`) ve aynı cümleyi iki kez
 * yazmak panelin düzenini bozuyordu. Başlık NE olduğunu, gövde NE YAPILACAĞINI
 * söylüyor — beş sebebin dördünde yapılacak şey farklı.
 *
 * `closedNote` yalnızca `closed_day` sebebinde anlamlı: sunucunun verdiği
 * kapalı gün açıklaması ("Kurban Bayramı") bir SEBEP metni değil, o günün
 * ADI — onu göstermek arayüz metnini sunucuya bağlamaz.
 */
export type DayUnavailableCopy = { title: string; message: string };

/**
 * Sebep bilinmiyor ya da verilmemiş.
 *
 * İki ayrı yoldan buraya gelinir ve ikisinde de söylenecek şey aynı:
 * sunucu `unavailable_reason: null` gönderdi (bilinen senaryo: vitrinin ana
 * şalteri kapalı — gün sorunsuz, sipariş alımı durmuş), ya da sözleşmeye
 * bizim tanımadığımız yeni bir sebep eklendi. Sözleşme ikincisi için
 * çökmemeyi ŞART KOŞUYOR: *"Bilinmeyen değer çökertmemelidir."*
 */
const GENERIC_UNAVAILABLE_COPY: DayUnavailableCopy = {
  title: 'Şu anda sipariş alamıyoruz',
  message: 'Menüyü inceleyebilirsiniz. Sipariş alımı açıldığında sepete ekleyebilirsiniz.',
};

export function dayUnavailableCopy(
  reason: DailyMenuUnavailableReason | null | undefined,
  date: BusinessDate,
  closedNote?: string | null,
): DayUnavailableCopy {
  const day = formatLongDate(date);

  switch (reason) {
    case 'closed_day':
      /*
       * "Kapalıyız" ile "servis günü değil" AYRI cümleler (bkz.
       * `no_service_day`). Buradaki metin tatili anlatır: normalde yemek
       * çıkan bir gün istisnaen kapatılmıştır.
       */
      return {
        title: `${formatDayMonth(date)} kapalıyız`,
        message: closedNote
          ? `${closedNote} nedeniyle bu gün kapalıyız. Takvimden başka bir gün seçebilirsiniz.`
          : 'Bu gün kapalıyız. Takvimden başka bir gün seçebilirsiniz.',
      };
    case 'no_service_day':
      /*
       * SATIŞ KANALI AÇIK, yalnız o gün servis yok: cumartesi günü
       * pazartesiye sipariş verilebiliyor. Metin bunu söylemezse müşteri
       * hafta sonu siteyi "kapalı" sanıp çıkar.
       */
      return {
        title: 'Bu gün yemek çıkarmıyoruz',
        message: `${day} servis günümüz değil. Sipariş almaya devam ediyoruz — takvimden menü çıkan bir gün seçip şimdi sipariş verebilirsiniz.`,
      };
    case 'not_published':
      return {
        title: 'Bu günün menüsü henüz açıklanmadı',
        message: `${day} için menü hazırlandığında burada görünecek. Takvimde menüsü açıklanmış günler işaretli.`,
      };
    case 'cutoff_passed':
      return {
        title: 'Bugünün sipariş saati doldu',
        message:
          'Bugüne sipariş kabul etmiyoruz ama yarın ve sonrası için sipariş verebilirsiniz. Takvimden bir gün seçin.',
      };
    case 'sold_out':
      /*
       * Menü OKUNMAYA DEVAM EDİYOR; kapanan yalnız satış. Tükenmiş günü
       * "menü yok" gibi anlatmak, kapış kapış giden bir günü hiç
       * hazırlanmamış gibi gösterirdi.
       */
      return {
        title: 'Bu günün kontenjanı doldu',
        message: `${day} için ayırdığımız porsiyonlar tükendi. Menüyü inceleyebilirsiniz; sipariş için takvimden başka bir gün seçin.`,
      };
    case 'past':
      return {
        title: 'Bu gün geçti',
        message: `${day} için sipariş alınamıyor. Bugünden başlayarak ileri bir gün seçin.`,
      };
    case 'too_far':
      return {
        title: 'Bu tarih için henüz sipariş almıyoruz',
        message: `${day} takvimimizde çok ileride. Menüler yaklaştıkça açılıyor; daha yakın bir gün seçin.`,
      };
    case null:
    case undefined:
      return GENERIC_UNAVAILABLE_COPY;
  }

  /*
   * TÜKENMEZLİK BEKÇİSİ — `default:` dalı BİLEREK YOK.
   *
   * `default` varken sözleşmeye eklenen her yeni sebep sessizce genel metne
   * düşüyordu: `no_service_day` ve `sold_out` eklendiğinde derleyici tek bir
   * uyarı vermedi, oysa `lib/api/types.ts` "derleyici burayı gösterir" diye
   * iddia ediyordu. Aşağıdaki atama o iddiayı gerçek yapıyor — sekizinci bir
   * sebep eklenip `schema.ts` yeniden üretildiğinde `reason` artık `never`
   * olmaz ve `npm run typecheck` kırılır.
   *
   * Buna rağmen ÇALIŞMA ZAMANINDA metin dönülüyor: tipe uymayan bir değer
   * gönderen sunucu ekranı çökertmemeli (sözleşmenin açık şartı).
   */
  const _exhaustive: never = reason;

  return GENERIC_UNAVAILABLE_COPY;
}
