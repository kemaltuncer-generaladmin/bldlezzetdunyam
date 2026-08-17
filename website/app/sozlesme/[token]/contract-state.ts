/**
 * Sözleşme onay formunun durumu — M2.
 *
 * `lib/action-state.ts`'e KONMADI: o dosya bu dalgada başka bir kulvarın
 * elinde ve bu tip yalnız bu rotanın iki dosyası arasında dolaşıyor. Yeri
 * geldiğinde ortak dosyaya taşınır.
 *
 * Tip `'use server'` dosyasında DURAMAZ: o dosyalardan yalnız async fonksiyon
 * ihraç edilebilir. Bu modülün yönergesi yok; hem sunucu eylemi hem istemci
 * bileşeni okuyabiliyor.
 */
export type ContractFormState = {
  /**
   * `sent` ile `approved` AYRI: ilki "kod gitti, kutu açıldı", ikincisi
   * "sözleşme onaylandı". Tek bir `ok` durumuna sıkıştırılsalardı ekran
   * hangisini çizeceğini bilemezdi.
   */
  status: 'idle' | 'sent' | 'approved' | 'error';
  message: string | null;
  /** Alan adı → Türkçe hata metni. `aria-describedby` ile alana bağlanır. */
  fieldErrors: Record<string, string>;
  /**
   * "Kodu yeniden gönder" düğmesinin açılacağı MUTLAK an (ms).
   *
   * Kalan saniye olarak taşınsaydı, kullanıcı SMS'i okumak için sekmeyi arka
   * plana alıp döndüğünde sayaç donmuş görünürdü — tarayıcı arka plandaki
   * zamanlayıcıyı kısıyor.
   */
  resendAt: number;
  /** Her çalıştırmada değişir; aynı hata iki kez oluştuğunda React yeniden çizsin. */
  at: number;
};

export const IDLE_CONTRACT_STATE: ContractFormState = {
  status: 'idle',
  message: null,
  fieldErrors: {},
  resendAt: 0,
  at: 0,
};
