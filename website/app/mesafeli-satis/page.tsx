import type { Metadata } from 'next';
import { LegalNotice } from '@/components/legal-notice';

export const metadata: Metadata = {
  title: 'Mesafeli Satış Sözleşmesi',
  description:
    'Benim Lezzet Dünyam üzerinden verilen siparişlere uygulanan mesafeli satış sözleşmesi koşulları.',
  alternates: { canonical: '/mesafeli-satis' },
};

export default function MesafeliSatisPage() {
  return (
    <article className="mx-auto max-w-3xl px-4 py-10 sm:py-14">
      <h1 className="text-3xl font-bold text-neutral-900">Mesafeli Satış Sözleşmesi</h1>
      <p className="mt-2 text-sm text-neutral-600">
        6502 sayılı Tüketicinin Korunması Hakkında Kanun ve Mesafeli Sözleşmeler Yönetmeliği
        kapsamındadır.
      </p>

      <LegalNotice />

      <div className="mt-8 space-y-6 text-sm leading-relaxed text-neutral-800">
        <section>
          <h2 className="text-lg font-semibold text-neutral-900">1. Taraflar ve konu</h2>
          <p className="mt-2">
            Bu sözleşme; satıcı sıfatıyla Benim Lezzet Dünyam ile bu site üzerinden sipariş veren
            alıcı arasında, siparişe konu yiyecek ürünlerinin satışı ve teslimi hakkındadır.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-neutral-900">2. Sipariş ve fiyat</h2>
          <p className="mt-2">
            Ürün fiyatları sipariş anında sitede gösterilen tutarlardır ve KDV dahildir. Sipariş
            toplamı her durumda sunucuda yeniden hesaplanır; ödenecek tutar sipariş onayında
            gösterilen tutardır. Adrese teslim siparişlerde varsa teslimat ücreti toplama eklenir;
            gel-al siparişlerde teslimat ücreti alınmaz.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-neutral-900">3. Teslimat</h2>
          <p className="mt-2">
            Teslimat, sipariş sırasında belirtilen adrese ve seçilen zaman aralığında yapılır.
            Gel-al seçilmişse ürünler işletme adresinden teslim alınır. Günlük son sipariş saatinden
            sonra verilen siparişler bir sonraki hizmet gününe aktarılabilir.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-neutral-900">4. Ödeme</h2>
          <p className="mt-2">
            Ödeme, sipariş ekranında gösterilen yöntemlerle yapılır: kapıda ödeme veya cari hesaba
            işleme. Online kart ile ödeme, sanal POS entegrasyonu tamamlandığında ödeme ekranında
            görünecektir.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-neutral-900">5. Cayma hakkı</h2>
          <p className="mt-2">
            Mesafeli Sözleşmeler Yönetmeliği&apos;nin 15. maddesi uyarınca çabuk bozulabilen veya
            son kullanma tarihi geçebilecek ürünler ile hazırlanması sipariş üzerine başlayan
            yiyecek teslimlerinde cayma hakkı kullanılamaz. Hazırlığa başlanmadan önce, sipariş
            &quot;Alındı&quot; veya &quot;Onaylandı&quot; durumundayken siparişinizi takip
            ekranından iptal edebilirsiniz.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-neutral-900">6. Uyuşmazlık</h2>
          <p className="mt-2">
            Şikâyet ve itirazlarda, ilgili mevzuatta belirlenen parasal sınırlar dâhilinde alıcının
            yerleşim yerindeki Tüketici Hakem Heyetleri ile Tüketici Mahkemeleri yetkilidir.
          </p>
        </section>
      </div>
    </article>
  );
}
