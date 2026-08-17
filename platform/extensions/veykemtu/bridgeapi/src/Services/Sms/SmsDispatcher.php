<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services\Sms;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;
use Veykemtu\BridgeApi\Models\SmsLog;
use Veykemtu\BridgeApi\Models\SmsTemplate;
use Veykemtu\BridgeApi\Services\OtpService;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Support\TurkishText;

/**
 * Şablonlu SMS gönderiminin TEK kapısı — B1.
 *
 * `SmsSender` "bu metni bu numaraya gönder" der ve gönderemezse patlar.
 * Bu sınıf onun üzerindeki iş katmanıdır: hangi metin, açık mı, daha önce
 * gitti mi, ne oldu.
 *
 * ═════════════════════════════════════════════════════════════════════════
 * ÜÇ SÖZ VERİR VE ÜÇÜ DE İŞ KURALIDIR:
 *
 * 1. **KAPALI ŞABLON HİÇBİR İZ BIRAKMAZ.** Kapalıysa sessizce döner:
 *    gönderim denenmez, kayda satır yazılmaz (`docs/control/sms.md`).
 *    Şablonlar KAPALI doğduğu için bu, sistemin varsayılan davranışıdır.
 *
 * 2. **AYNI OLAY İKİ MESAJ ÜRETMEZ.** Kayıt satırı gönderimden ÖNCE ve
 *    `insertOrIgnore` ile yazılır; `UNIQUE(template_key, reference_type,
 *    reference_id)` kapıyı veritabanı seviyesinde tutar. "Önce sorgula,
 *    sonra yaz" iki eşzamanlı işçi arasında hiçbir şey garanti etmezdi —
 *    yeniden deneme fırtınasının müşteriye beş mesaj attığı yer tam olarak
 *    o penceredir.
 *
 * 3. **ÇAĞIRANA ASLA İSTİSNA FIRLATMAZ.** Sağlayıcı hatası kayda `failed`
 *    olarak geçer ve orada kalır. Bu sınıf sipariş durum değişiminin,
 *    abonelik onayının, fatura kesiminin İÇİNDEN çağrılıyor; ölü bir SMS
 *    sağlayıcısının bir siparişin durumunu geri alması, mutfağın yanlış
 *    ekran görmesi demek olurdu. SMS bir yan etkidir, işin kendisi değil.
 * ═════════════════════════════════════════════════════════════════════════
 *
 * ARAYÜZ P2 İÇİN SABİTTİR. `Services\OrderStatusTransition` tetikleyici
 * çağrısını bu imzaya bağlayacak; imza değişirse orası sessizce değil,
 * derleme zamanında kırılır.
 */
final class SmsDispatcher
{
    /**
     * Sipariş olayı referansı — `('order', order_id)`.
     *
     * SABİT BURADA DURUYOR ki çağıranlar dize yazmasın: `OrderStatusTransition`
     * ile bu sınıf arasında yazım farkı, hatasız çalışan ama hiçbir zaman
     * tekilleşmeyen bir gönderim üretirdi.
     */
    public const string REF_ORDER = 'order';

    /** Abonelik olayı referansı — `('subscription', subscription_id)`. */
    public const string REF_SUBSCRIPTION = 'subscription';

    /**
     * Günlük menü duyurusu referans öneki — `('dailymenu:YYYY-AA-GG', customer_id)`.
     *
     * Gün referans TÜRÜNDE, müşteri referans KİMLİĞİNDE. Gün türe
     * girmeseydi yarının duyurusu bugünkünün satırına çarpardı; müşteri
     * kimliğe girmeseydi 500 alıcı tek satıra çökerdi.
     */
    public const string REF_DAILY_MENU_PREFIX = 'dailymenu:';

    private const string TABLE = 'veykemtu_sms_log';

    public function __construct(private readonly SmsSender $sender) {}

    /**
     * Şablonu işler ve gönderir.
     *
     * SIRA ANLAMLIDIR: şablonu bul → kapalıysa sessizce dön → işle →
     * numarayı doğrula → ÖNCE kayıt satırını yaz → sağlayıcıyı çağır.
     *
     * @param  string  $key  Sabit şablon anahtarı (`order_confirmed` …).
     * @param  string  $phone  Ham ya da normalleştirilmiş numara.
     * @param  array<string, string|int|float|null>  $vars  `{degisken}` karşılıkları.
     * @param  ?string  $refType  Olayın türü (`order`, `subscription`,
     *                            `dailymenu:2026-08-23`). `null` ise bu
     *                            gönderim tekilleştirilmez.
     * @param  ?int  $refId  Olayın kimliği (sipariş, abonelik, müşteri).
     * @param  bool  $dryRun  `true` ise hiçbir şey gönderilmez; ne
     *                        gideceği `dry_run` satırı olarak yazılır.
     */
    public function send(
        string $key,
        string $phone,
        array $vars = [],
        ?string $refType = null,
        ?int $refId = null,
        bool $dryRun = false,
    ): void {
        $template = SmsTemplate::findByKey($key);

        if ($template === null) {
            /*
             * BİLİNMEYEN ANAHTAR SESSİZ DEĞİL, GÜRÜLTÜLÜ BİR HİÇLİKTİR.
             *
             * Anahtar kümesi göçte tohumlanıyor; buraya düşmek ya bir
             * yazım hatası ya da göçün koşmamış olması demek. Yine de
             * FIRLATMIYORUZ (3 numaralı söz): bir yazım hatası siparişi
             * geri almamalı. `warning` seviyesi, `LogSmsSender` ile aynı
             * gerekçe — günlükte gözden kaçmayacak yükseklikte durmalı.
             */
            Log::warning('SMS şablonu bulunamadı — mesaj gönderilmedi.', [
                'template_key' => $key,
            ]);

            return;
        }

        if (!$template->enabled) {
            // Kapalı şablon: iz yok. Kuru koşum da buraya düşer ve bu
            // bilinçli — kapalı bir şablonun "provası" da gönderimdir ve
            // kayıtta gerçekmiş gibi görünen satırlar bırakırdı.
            return;
        }

        $body = TurkishText::toGsm7($template->render($vars));
        $normalized = OtpService::normalize($phone);

        if (!self::isMobile($normalized)) {
            /*
             * Numara SMS'e uygun değil: sabit hat, eksik hane, boş alan.
             * SESSİZCE YUTULMAZ — `skipped` satırı yazılır. Yutulsaydı
             * "müşteriye haber verildi mi" sorusunun cevabı "kayıt yok"
             * olurdu ve bu, "göndermedik" ile "gönderemedik" arasındaki
             * farkı silerdi.
             */
            $this->writeLog(
                $key,
                $normalized,
                $body,
                SmsLog::STATUS_SKIPPED,
                $refType,
                $refId,
                'SMS gönderilemeyen numara.',
            );

            return;
        }

        if ($dryRun) {
            /*
             * KURU KOŞUM REFERANSSIZ YAZILIR ve bu, kolay atlanan ama
             * pahalı bir ayrıntı: referanslar korunsaydı prova satırı
             * gerçek gönderimin idempotans yuvasını İŞGAL ederdi ve
             * duyuruyu önce prova edip sonra göndermek isteyen yönetici
             * hiçbir şey gönderemezdi — üstelik hata da almadan.
             */
            $this->writeLog(
                $key,
                $normalized,
                $body,
                SmsLog::STATUS_DRY_RUN,
                null,
                null,
                null,
            );

            return;
        }

        /*
         * KAYIT ÖNCE, GÖNDERİM SONRA — ve satır KÖTÜMSER doğar (`failed`).
         *
         * Sıra tersine çevrilseydi (gönder, sonra yaz), gönderim ile
         * yazma arasında ölen bir süreç müşteriye gitmiş ama kaydı olmayan
         * bir mesaj bırakırdı; yeniden deneme onu bir kez daha gönderirdi.
         *
         * `failed` doğması da aynı dürüstlük: satır yazıldıktan sonra,
         * sağlayıcı yanıtı gelmeden süreç ölürse geride "gitti" diyen bir
         * yalan değil, "bilmiyoruz" diyen bir satır kalır.
         */
        $logId = $this->writeLog(
            $key,
            $normalized,
            $body,
            SmsLog::STATUS_FAILED,
            $refType,
            $refId,
            null,
        );

        if ($logId === null) {
            // İndeks reddetti: bu olay için mesaj zaten yazıldı, yani biri
            // zaten gönderdi ya da gönderiyor. Dur.
            return;
        }

        try {
            $this->sender->send($normalized, $body);
        } catch (Throwable $e) {
            // 3 numaralı söz: hata burada biter, çağırana ulaşmaz.
            DB::table(self::TABLE)->where('id', $logId)->update([
                'error' => mb_substr($e->getMessage(), 0, 255),
            ]);

            Log::warning('SMS gönderilemedi.', [
                'template_key' => $key,
                'phone' => SmsLog::maskPhone($normalized),
                'error' => $e->getMessage(),
            ]);

            return;
        }

        DB::table(self::TABLE)->where('id', $logId)->update([
            'status' => SmsLog::STATUS_SENT,
        ]);
    }

    /**
     * Kayıt satırını atomik olarak yazar.
     *
     * @return ?int Yazılan satırın kimliği; indeks reddettiyse `null`.
     */
    private function writeLog(
        string $key,
        string $phone,
        string $body,
        string $status,
        ?string $refType,
        ?int $refId,
        ?string $error,
    ): ?int {
        // Kolon 500 karakter; şablon 500 karakterken değişkenler yerine
        // konunca daha uzun bir metin çıkabilir ve kırpılmamış bir değer
        // INSERT'i düşürürdü — yani SMS'i değil, ÇAĞIRANIN İŞLEMİNİ
        // kaybederdik.
        $body = mb_substr($body, 0, 500);
        $now = BusinessTime::forStorage(BusinessTime::now());

        $inserted = DB::table(self::TABLE)->insertOrIgnore([
            'template_key' => $key,
            'phone' => $phone,
            'body' => $body,
            'segments' => self::segments($body),
            'status' => $status,
            'error' => $error,
            'context' => self::contextOf($key),
            'reference_type' => $refType,
            'reference_id' => $refId,
            /*
             * SORGU ALANLARI REFERANSTAN TÜRETİLİYOR.
             *
             * `docs/control/sms.md` `GET /log` süzgeçlerinde
             * `customer_id`/`order_id`/`subscription_id` istiyor; çağıran
             * bunları ayrıca vermek zorunda kalsaydı imza üç parametre
             * şişer ve her çağıran aynı bilgiyi iki kez yazardı — biri
             * unutulduğu gün de kayıt sessizce eksik kalırdı.
             */
            'customer_id' => str_starts_with((string) $refType, self::REF_DAILY_MENU_PREFIX)
                ? $refId
                : null,
            'order_id' => $refType === self::REF_ORDER ? $refId : null,
            'subscription_id' => $refType === self::REF_SUBSCRIPTION ? $refId : null,
            'created_at' => $now,
            'sent_at' => $now,
        ]);

        if ($inserted === 0) {
            return null;
        }

        /*
         * `lastInsertId()` — `insertOrIgnore` yalnızca etkilenen satır
         * sayısını döndürüyor. Satırı (template_key, reference_type,
         * reference_id) ile geri sorgulamak İŞE YARAMAZDI: referanslar
         * `null` olduğunda o üçlü tekil değildir ve sorgu başka bir
         * alıcının satırını getirebilirdi.
         */
        return (int) DB::getPdo()->lastInsertId();
    }

    /**
     * Numara SMS alabilir mi?
     *
     * Türkiye'de mobil hatlar `5` ile başlar ve 10 hanedir. Sabit hatta
     * SMS gönderilemez; sağlayıcı bunu bir hata koduyla reddeder ve her
     * reddedilen istek hem gecikme hem de kota demektir. Elemeyi burada
     * yapmak, o isteği hiç yapmamak anlamına gelir.
     */
    private static function isMobile(string $phone): bool
    {
        return preg_match('/^5\d{9}$/', $phone) === 1;
    }

    /**
     * Gövdenin segment sayısı — GSM-7'ye göre.
     *
     * `TurkishText::toGsm7()`'den geçmiş bir metni sayıyoruz, yani UCS-2
     * dalı yok: tek segment 160, çoklu segmentte 153 (çoklu mesaj başlığı
     * her parçadan 7 karakter götürür).
     *
     * ÇÖZÜLMEMİŞ DEĞİŞKENLER İKİ KARAKTER SAYILIR. `{` ve `}` GSM-7'de
     * genişletme tablosundadır ve her biri iki karakter yer kaplar. Yerine
     * konmamış bir `{eta}` yalnız çirkin değil, PAHALI — ve sayacın bunu
     * gizlemesi, maliyet ekranını olduğundan iyimser gösterirdi.
     */
    private static function segments(string $body): int
    {
        $length = mb_strlen($body)
            + preg_match_all('/[{}\[\]~^|\\\\€]/u', $body);

        if ($length === 0) {
            return 0;
        }

        return $length <= 160 ? 1 : (int) ceil($length / 153);
    }

    /**
     * Kaydın bağlamı — `auto` | `announcement`.
     *
     * BAĞLAM ÇAĞIRANIN DEĞİL ŞABLONUN ÖZELLİĞİ. Çağırandan alınsaydı aynı
     * duyuru şablonu, tetikleyen yere göre kayıtta bir `auto` bir
     * `announcement` görünürdü. `test` bağlamını yalnız panel yazar
     * (`POST /send-test`); bu sınıf deneme göndermez.
     */
    private static function contextOf(string $key): string
    {
        return in_array($key, ['announcement', SmsTemplate::KEY_DAILY_MENU_ANNOUNCE], true)
            ? 'announcement'
            : 'auto';
    }
}
