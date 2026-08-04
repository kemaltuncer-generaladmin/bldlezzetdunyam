/**
 * Yapılandırılmış veri (`docs/06` §2). İçerik sunucuda üretilir ve yalnızca
 * bizim oluşturduğumuz nesnelerden gelir; kullanıcı girdisi buraya akmaz.
 */
export function JsonLd({ data }: { data: Record<string, unknown> }) {
  return (
    <script
      type="application/ld+json"
      // JSON.stringify çıktısındaki `<` kaçırılır ki script etiketi kapanmasın.
      dangerouslySetInnerHTML={{
        __html: JSON.stringify(data).replace(/</g, '\\u003c'),
      }}
    />
  );
}
