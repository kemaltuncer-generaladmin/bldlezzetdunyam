import type { Metadata } from 'next';
import { LegalNotice } from '@/components/legal-notice';

export const metadata: Metadata = {
  title: 'KVKK Aydınlatma Metni',
  description:
    'Benim Lezzet Dünyam kişisel verilerin işlenmesine ilişkin aydınlatma metni: hangi veriler, hangi amaçla işlenir ve haklarınız.',
  alternates: { canonical: '/kvkk' },
};

export default function KvkkPage() {
  return (
    <article className="mx-auto max-w-3xl px-4 py-10 sm:py-14">
      <h1 className="text-3xl font-bold text-neutral-900">KVKK Aydınlatma Metni</h1>
      <p className="mt-2 text-sm text-neutral-600">
        6698 sayılı Kişisel Verilerin Korunması Kanunu kapsamında hazırlanmıştır.
      </p>

      <LegalNotice />

      <div className="mt-8 space-y-6 text-sm leading-relaxed text-neutral-800">
        <section>
          <h2 className="text-lg font-semibold text-neutral-900">1. İşlenen kişisel veriler</h2>
          <p className="mt-2">
            Sipariş sürecini yürütebilmek için şu veriler işlenir: ad, soyad, e-posta adresi, cep
            telefonu numarası, teslimat adresi ve adres notu, sipariş içeriği ile sipariş notu,
            ödeme yöntemi ve ödeme durumu, sipariş tarih-saat kayıtları.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-neutral-900">2. İşleme amaçları</h2>
          <ul className="mt-2 list-disc space-y-1 pl-5">
            <li>Siparişin alınması, hazırlanması ve teslim edilmesi</li>
            <li>Sipariş durumunun tarafınıza bildirilmesi ve takip ekranının sunulması</li>
            <li>Ödeme ve tahsilat süreçlerinin yürütülmesi</li>
            <li>Yasal saklama ve belge düzenleme yükümlülüklerinin yerine getirilmesi</li>
            <li>Talep ve şikâyetlerin karşılanması</li>
          </ul>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-neutral-900">3. Hukuki sebep</h2>
          <p className="mt-2">
            Veriler; sözleşmenin kurulması ve ifası, hukuki yükümlülüğün yerine getirilmesi ve
            meşru menfaat hukuki sebeplerine dayanılarak, kayıt sırasında verdiğiniz açık onay ile
            işlenir.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-neutral-900">4. Aktarım</h2>
          <p className="mt-2">
            Kişisel verileriniz; teslimatın yapılabilmesi için görevli kuryeye teslimat adresi ile
            sınırlı olarak, ödeme işlemleri için ödeme hizmeti sağlayıcısına ve yasal talep hâlinde
            yetkili kamu kurumlarına aktarılabilir. Mutfak ekranına düşen sipariş kaydında fiyat ve
            iletişim bilgisi bulunmaz; adres yalnızca müşteri fişinde yer alır.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-neutral-900">5. Saklama süresi</h2>
          <p className="mt-2">
            Veriler, ilgili mevzuatta öngörülen zamanaşımı ve saklama süreleri boyunca tutulur; süre
            dolduğunda silinir, yok edilir veya anonim hâle getirilir.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-neutral-900">6. Haklarınız</h2>
          <p className="mt-2">
            Kanunun 11. maddesi uyarınca; verilerinizin işlenip işlenmediğini öğrenme, bilgi talep
            etme, düzeltilmesini veya silinmesini isteme, işlemeye itiraz etme ve zarara uğramanız
            hâlinde giderim talep etme haklarına sahipsiniz. Taleplerinizi iletişim sayfamızdaki
            kanallardan iletebilirsiniz; başvurunuz en geç 30 gün içinde sonuçlandırılır.
          </p>
        </section>
      </div>
    </article>
  );
}
