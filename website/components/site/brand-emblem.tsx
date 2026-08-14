import { cn } from '@/lib/utils';

/**
 * Marka amblemi — `app/icon.svg` İLE AYNI GEOMETRİ (aşçı şapkası + buğdaydan
 * küre).
 *
 * ## Neden bu dosya var
 *
 * `app/icon.svg` bir metadata rotasıdır: tarayıcı sekmesine `<link>` olarak
 * gider, React ağacına giremez. Amblemi başlıkta göstermek için ya `<img>` ile
 * o dosyayı çekmek (ikinci bir ağ isteği ve ilk boyamada boş bir kutu) ya da
 * geometriyi burada tekrarlamak gerekiyordu. Tekrar seçildi; `icon.svg`
 * içindeki yorum da ikisinin birlikte güncellenmesi gerektiğini yazıyor.
 *
 * ## Neden harf işareti DEĞİL
 *
 * Önceki sürümde logo yoksa "BLD" üç harf olarak diziliyordu. Marka kılavuzu
 * bunu YASAKLIYOR: logodaki monogram el çizimi bir işaret ve hiçbir font onu
 * üretmiyor — fontla dizilmiş hâli markanın yanlış bir kopyasıydı.
 *
 * ## PLAKA BURADA DEĞİL
 *
 * Amblem yalnızca çizimdir; altındaki turuncu gradyan plaka çağıranın CSS'i
 * (`BrandMark`). Gradyanı SVG'ye koymak `id` + `url(#…)` gerektiriyor ve aynı
 * sayfada üç amblem var (başlık, altbilgi, mobil menü) — üç aynı `id`
 * geçersiz bir belge demek. CSS gradyanının böyle bir sorunu yok ve
 * `app/apple-icon.tsx` de aynı yolu izliyor.
 *
 * Amblemin kendi dolguları KREM olduğu için tek başına açık bir zemine
 * konulamaz: her zaman koyu/marka renginde bir plakanın üstünde çizilir.
 */
export function BrandEmblem({
  className,
  title,
}: {
  className?: string;
  /**
   * Verilirse amblem erişilebilirlik ağacında bir GÖRSEL olur (`role="img"`).
   * Verilmezse dekoratiftir — yanındaki sözcük işareti ya da bağlantının
   * `aria-label`'ı adı zaten söylüyorsa doğru olan budur.
   */
  title?: string;
}) {
  return (
    <svg
      viewBox="0 0 64 64"
      role={title ? 'img' : undefined}
      aria-hidden={title ? undefined : 'true'}
      focusable="false"
      className={cn('shrink-0', className)}
    >
      {title && <title>{title}</title>}

      {/*
        Koordinatlar `app/icon.svg` ile BİREBİR aynı; karşılaştırılabilir
        kalsınlar diye ölçeklenmediler.

        Küre: krem dolgu + koyu halka. Halkasız hâlde alt yarıdaki buğday
        sıraları küreyi değil bir torbayı çiziyor gibi okunuyor.
      */}
      <circle cx="32" cy="42" r="20" fill="#FAF6F0" stroke="#5F1B08" strokeWidth="2.4" />

      {/* Aşçı şapkası: üç kabarık + bant. Bandın alt kenarı koyu bir çizgiyle
          ayrılır; ikisi de krem olduğu için yoksa birleşiyorlar. */}
      <circle cx="32" cy="10" r="9" fill="#FAF6F0" />
      <circle cx="20" cy="12.5" r="7.5" fill="#FAF6F0" />
      <circle cx="44" cy="12.5" r="7.5" fill="#FAF6F0" />
      <path d="M14 15H50L47 25H17Z" fill="#FAF6F0" />
      <path d="M17.5 25H46.5" stroke="#5F1B08" strokeWidth="2.2" strokeLinecap="round" />

      {/* Buğday yayı: dört sıra. Her sıranın genişliği kürenin o yükseklikteki
          kirişine göre daraltıldı, yoksa satırlar halkayı deliyor. Çapraz
          çentikler örgü/başak okumasını veriyor. */}
      <g stroke="#5F1B08" strokeLinecap="round" fill="none">
        <g strokeWidth="2.8">
          <path d="M14 40q9-3 18 0t18 0" />
          <path d="M15 47q8.5-2.8 17 0t17 0" />
          <path d="M18 53.5q7-2.4 14 0t14 0" />
          <path d="M25 59q3.5-1.5 7 0t7 0" />
        </g>
        <g strokeWidth="1.9">
          <path d="M17.7 40.4l3.4-3.4M24.9 40.4l3.4-3.4M35.7 43l3.4-3.4M42.9 43l3.4-3.4" />
          <path d="M18.4 47.5l3.4-3.4M25.2 47.5l3.4-3.4M35.4 49.9l3.4-3.4M42.2 49.9l3.4-3.4" />
          <path d="M20.5 54.2l3.4-3.4M26.1 54.2l3.4-3.4M34.5 56.2l3.4-3.4M40.1 56.2l3.4-3.4" />
          <path d="M26.8 60l3.4-3.4M33.8 61.4l3.4-3.4" />
        </g>
      </g>
    </svg>
  );
}

/**
 * Amblem + turuncu plaka. Uygulama simgesiyle aynı okuma.
 *
 * Amblem plakanın %80'i: `app/icon.svg` içindeki `scale(0.8)` ile aynı oran.
 * Yarıçap kart adımı (`rounded-md`, 14 px) — simge 40 px çizildiğinde bu
 * `icon.svg`'nin 64/14 oranına en yakın adım.
 */
export function BrandEmblemPlate({ className, title }: { className?: string; title?: string }) {
  return (
    <span
      className={cn(
        'grid size-10 shrink-0 place-items-center rounded-md bg-linear-[135deg] from-brand-800 to-brand-500',
        className,
      )}
    >
      <BrandEmblem title={title} className="size-4/5" />
    </span>
  );
}
