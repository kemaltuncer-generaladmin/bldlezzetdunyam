import { TriangleAlert } from 'lucide-react';
import type { LegalIdentity } from '@/content/site';
import type { SiteContact } from '@/lib/api/site-content';

/**
 * İşletmenin yasal kimliği — dört yasal sayfanın (gizlilik, KVKK, mesafeli
 * satış, çerez) ortak bloğu.
 *
 * ## Neden ortak bileşen
 *
 * Aynı tablo üç sayfada ayrı ayrı yazılsaydı, vergi numarası değiştiğinde üç
 * yerden birinin unutulması kaçınılmazdı; ve yasal metinlerde iki farklı vergi
 * numarası göstermek, hiç göstermemekten kötüdür.
 *
 * ## "Girilmesi gerekiyor" neden var
 *
 * Boş alan uydurulmuş bir metinle DOLDURULMAZ. Panelde bilgi yoksa bunu
 * kullanıcıya da, sayfayı yayına alacak kişiye de açıkça söylemek gerekir;
 * sahte bir vergi numarası basmak metni yasal göstermek olurdu, yasal yapmak
 * değil.
 *
 * ## `notApplicable` ile `value === null` farkı
 *
 * `null` = "henüz girilmedi, girilmesi gerekiyor".
 * `notApplicable` = "bu işletmede böyle bir bilgi YOK".
 *
 * Ayrım şart: ticaret siciline kayıtlı olmayan bir şahıs işletmesinde MERSİS
 * ve KEP hiçbir zaman doldurulamaz. İkisini aynı saymak, kapanması mümkün
 * olmayan bir "yayın öncesi tamamlanacak" uyarısı bırakırdı — ve sürekli
 * ekranda duran bir uyarı, uyarı olmaktan çıkıp gürültü olur. Mesafeli
 * Sözleşmeler Yönetmeliği de bu iki bilgiyi "varsa" kaydıyla ister.
 */
export type IdentityField = {
  readonly label: string;
  readonly value: string | null;
  readonly notApplicable?: boolean;
};

export function identityFields(
  contact: SiteContact,
  legal: LegalIdentity,
): readonly IdentityField[] {
  const taxOffice =
    legal.taxOffice && legal.taxNumber ? `${legal.taxOffice} / ${legal.taxNumber}` : null;

  return [
    { label: 'Ticari unvan', value: legal.tradeName },
    { label: 'İşletme türü', value: legal.legalForm },
    {
      /*
       * Merkez adresi `legal.registeredAddress`ten okunur, `contact.address`ten
       * DEĞİL: ikincisi müşteriye gösterilen ziyaret adresidir ve mutfak başka
       * bir yerdeyse yasal merkezle aynı olmaz. Yasal metinler merkezi ister.
       * Yasal adres girilmemişse iletişim adresine düşülür — yanlış olma
       * ihtimali, hiç adres göstermemekten iyidir.
       */
      label: 'Merkez adresi',
      value:
        legal.registeredAddress ??
        (contact.address
          ? `${contact.address.streetAddress}, ${contact.address.district} / ${contact.address.city}`
          : null),
    },
    { label: 'Vergi dairesi ve numarası', value: taxOffice },
    { label: 'MERSİS numarası', value: legal.mersisNo, notApplicable: legal.mersisNo === null },
    { label: 'KEP adresi', value: legal.kepAddress, notApplicable: legal.kepAddress === null },
    { label: 'Telefon', value: contact.phone ? contact.phone.display : null },
    { label: 'E-posta', value: contact.email ? contact.email.display : null },
  ];
}

/**
 * Kimlik alanlarına ek olarak metnin kendisinde netleşmesi gereken başlıklar.
 *
 * Listede TEK madde kaldı. Barındırma sağlayıcısı/konumu ve sunucu kayıtlarının
 * saklama süresi 19.08.2026'da netleşti ve gizlilik metnine doğrudan yazıldı —
 * bunlar mühendislik gerçekleri, yöneticinin panelden düzenleyeceği iş verisi
 * değil; sunucu taşınırsa zaten kod/altyapı değişikliği olur.
 *
 * Ödeme sağlayıcısı listede KALIYOR çünkü gerçekten yok: `veykemtu/payment`
 * altında nakit, havale ve bir SİMÜLASYON geçidi var (bkz.
 * `docs/03-api-sozlesmesi.md` §"Faz 1 notu"), yani kart verisi işleyen bir
 * sağlayıcı ortada değil. Panelde sağlayıcı adı girildiğinde madde
 * kendiliğinden listeden düşer ve kutu tamamen kaybolur.
 */
export function openLegalItems(legal: LegalIdentity): readonly string[] {
  return legal.paymentProvider === null ? ['Ödeme hizmeti sağlayıcısının ticari adı'] : [];
}

export function pendingLegalFields(
  fields: readonly IdentityField[],
  legal: LegalIdentity,
): readonly string[] {
  return [
    ...fields
      .filter((field) => field.value === null && field.notApplicable !== true)
      .map((field) => field.label),
    ...openLegalItems(legal),
  ];
}

/** `null` alanlar için ortak işaret — sahte değer basmak yerine eksikliği söyler. */
function MissingValue() {
  return (
    <span className="inline-flex items-center gap-1.5 rounded-xs bg-warning-surface px-2 py-0.5 text-caption font-semibold text-warning-foreground">
      <TriangleAlert strokeWidth={1.75} aria-hidden="true" className="size-3.5" />
      Girilmesi gerekiyor
    </span>
  );
}

export function LegalIdentityTable({ fields }: { readonly fields: readonly IdentityField[] }) {
  return (
    <dl className="mt-6 divide-y rounded-md border">
      {fields
        .filter((field) => field.notApplicable !== true)
        .map((field) => (
          <div
            key={field.label}
            className="grid gap-1 px-4 py-3 sm:grid-cols-[15rem_1fr] sm:items-center sm:gap-4"
          >
            <dt className="text-label">{field.label}</dt>
            <dd className="text-body">{field.value ?? <MissingValue />}</dd>
          </div>
        ))}
    </dl>
  );
}

/**
 * "Yayın öncesi tamamlanacak" kutusu. Liste boşaldığında hiç çizilmez —
 * kutunun kaybolması, bilginin tamamlandığının görünür işaretidir.
 */
export function PendingLegalNotice({ items }: { readonly items: readonly string[] }) {
  if (items.length === 0) return null;

  return (
    <div className="mt-6 rounded-md border p-5">
      <h2 className="font-display text-h3 font-semibold text-heading">
        Yayın öncesi tamamlanacak bilgiler
      </h2>
      <p className="mt-1 text-body text-muted-foreground">
        Aşağıdaki bilgiler işletmeden alınmadığı için metne yazılmadı. Bilgi girildiğinde bu kutu
        kendiliğinden kaybolur.
      </p>
      <ul className="mt-3 grid gap-1.5 text-body-sm sm:grid-cols-2">
        {items.map((item) => (
          <li key={item} className="flex items-start gap-2">
            <TriangleAlert
              strokeWidth={1.75}
              aria-hidden="true"
              className="mt-0.5 size-3.5 shrink-0 text-warning"
            />
            {item}
          </li>
        ))}
      </ul>
    </div>
  );
}
