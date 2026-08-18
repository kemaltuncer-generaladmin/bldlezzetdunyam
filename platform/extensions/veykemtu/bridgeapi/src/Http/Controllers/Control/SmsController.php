<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Control;

use Illuminate\Database\Query\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\Rule;
use Throwable;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Models\SmsLog;
use Veykemtu\BridgeApi\Models\SmsTemplate;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Services\Sms\NetgsmSettings;
use Veykemtu\BridgeApi\Services\Sms\NetgsmSmsSender;
use Veykemtu\BridgeApi\Services\Sms\SmsException;
use Veykemtu\BridgeApi\Services\Sms\SmsSender;
use Veykemtu\BridgeApi\Support\TurkishText;

/**
 * Kontrol Merkezi — SMS şablonları, gönderim kaydı ve toplu duyuru
 * (`docs/control/sms.md`).
 *
 * BU ALAN SAĞLAYICIYI BİLMEZ, yalnız gönderim ister. Arayüz
 * `Services\Sms\SmsSender`; üretimde `NetgsmSmsSender`, sır tanımsızsa
 * `LogSmsSender`. Sağlayıcıyı buraya gömmek, değiştiğinde panel kodunu
 * değiştirmek demekti.
 *
 * `otp_login` ŞABLON LİSTESİNDE YOK VE OLMAYACAK. Giriş kodu metni
 * `OtpService` içindedir; panelden düzenlenebilir olsaydı kodun kendisini
 * metinden çıkarmak ya da metne bağlantı gömmek tek satırlık bir değişiklik
 * olurdu. Kimlik doğrulama metni yönetim yüzeyinden uzak durur.
 *
 * `preview` BİR OKUMA GİBİ GÖRÜNÜR AMA `POST`'TUR ve yazma kabuğundan
 * geçer: örnek veriyi gövdeyle taşıyor ve gövdesiz bir `GET` onu sorgu
 * dizesine, yani imzanın dışına koyardı. Kabuktan geçmesi ayrıca
 * "listede olmayan yola prova" tuzağını burada da kapatıyor
 * (`00-genel.md` §4).
 *
 * TABLOLAR BAŞKA BİR KULVARDA açılıyor (`veykemtu_sms_templates`,
 * `veykemtu_sms_log`). Şablon listesi tablo olmadan da tam döner —
 * anahtarlar ve başlıklar sistemin kendi sözlüğü, kayıtta yalnız metin ve
 * açık/kapalı bilgisi yaşıyor.
 */
class SmsController extends ControlController
{
    private const string TEMPLATES_TABLE = 'veykemtu_sms_templates';

    private const string LOG_TABLE = 'veykemtu_sms_log';

    /** Duyuru taslağının `location_options` anahtarları. */
    private const string OPT_BODY = 'bld_sms_announcement_body';

    private const string OPT_AUDIENCE = 'bld_sms_announcement_audience';

    private const string OPT_LAST_RUN = 'bld_sms_announcement_last_run_at';

    /**
     * İki duyuru arasındaki en kısa süre.
     *
     * Çift tıklama ile aynı duyuruyu iki kez almak, müşterinin gördüğü tek
     * şeydir; sunucu tarafındaki bu kapı, panelin düğmeyi kilitlemeyi
     * unutmasından bağımsız çalışır.
     */
    private const int COOLDOWN_MINUTES = 10;

    /** `active_customers` kitlesinin geriye bakış penceresi. */
    private const int ACTIVE_CUSTOMER_DAYS = 180;

    /** Yanıttaki hata listesi tavanı; fazlası `GET /log?status=failed`'ta. */
    private const int MAX_FAILURE_ROWS = 20;

    /** Kayıtta saklanan gövdenin gösterim kırpması. */
    private const int LOG_BODY_PREVIEW = 120;

    /** Deneme SMS'inin kaldırılamaz öneki. */
    private const string TEST_PREFIX = '[DENEME] ';

    /**
     * Şablon sözlüğü — anahtar, başlık ve izin verilen değişkenler.
     *
     * SABİTTİR: listede olmayan bir anahtara `PATCH` → 404. `title`
     * yazılamaz; şablonun adı sistemin kendi sözlüğüdür, yöneticinin
     * değiştireceği bir şey değil.
     *
     * @var array<string, array{title: string, variables: list<string>}>
     */
    private const array TEMPLATES = [
        'order_created' => [
            'title' => 'Sipariş alındı',
            'variables' => ['order_no', 'service_date', 'total', 'customer_name'],
        ],
        'order_confirmed' => [
            'title' => 'Sipariş onaylandı',
            'variables' => ['order_no', 'service_date'],
        ],
        'order_on_the_way' => [
            'title' => 'Kurye yola çıktı',
            'variables' => ['order_no', 'eta'],
        ],
        'order_delivered' => [
            'title' => 'Teslim edildi',
            'variables' => ['order_no'],
        ],
        'order_cancelled' => [
            'title' => 'Sipariş iptal edildi',
            'variables' => ['order_no', 'service_date', 'reason'],
        ],
        'order_revised' => [
            'title' => 'Sipariş düzenlendi',
            'variables' => ['order_no', 'reason'],
        ],
        'subscription_contract' => [
            'title' => 'Sözleşme bağlantısı',
            'variables' => ['customer_name', 'link', 'expires_at'],
        ],
        'subscription_payment_due' => [
            'title' => 'Dönem borcu hatırlatma',
            'variables' => ['customer_name', 'period', 'amount', 'due_date'],
        ],
        'invoice_issued' => [
            'title' => 'Fatura belgesi kesildi',
            'variables' => ['invoice_no', 'total', 'link'],
        ],
        'announcement' => [
            'title' => 'Toplu duyuru',
            'variables' => ['customer_name'],
        ],
        /*
         * ZAMANLANMIŞ İŞ, PANELDEN TETİKLENEN DUYURU DEĞİL
         * (`veykemtu:menu-duyur`). `announcement` ile aynı satıra
         * sıkıştırılsalardı birini açmak ötekini de açardı; ikisi ayrı
         * anahtar, ayrı şalter.
         */
        SmsTemplate::KEY_DAILY_MENU_ANNOUNCE => [
            'title' => 'Günün menüsü duyurusu',
            'variables' => ['customer_name', 'date', 'menu'],
        ],
    ];

    /** Önizlemede kullanılan gerçekçi örnek değerler. */
    private const array SAMPLE_VALUES = [
        'order_no' => 'S-8421',
        'service_date' => '17.08.2026',
        'total' => '180,00',
        'customer_name' => 'Mehmet Kaya',
        'eta' => '12:30',
        'reason' => 'Müşteri talebi',
        'link' => 'https://bld.example/sozlesme/12',
        'expires_at' => '18.08.2026 09:00',
        'period' => 'Ağustos 2026',
        'amount' => '1.920,00',
        'due_date' => '25.08.2026',
        'invoice_no' => 'BLD-2026-000044',
        'date' => '17.08.2026',
        'menu' => 'Mercimek çorbası, Tavuk sote, Pilav',
    ];

    private const array AUDIENCES = ['active_customers', 'subscribers', 'all_customers'];

    public function __construct(private readonly SmsSender $sender) {}

    // ── GET /templates ────────────────────────────────────────────────────

    public function templates(): JsonResponse
    {
        $stored = $this->storedTemplates();

        $data = [];

        foreach (self::TEMPLATES as $key => $spec) {
            $row = $stored[$key] ?? null;
            $body = $row === null ? '' : (string) $row->body;

            $data[] = [
                'key' => $key,
                'title' => $spec['title'],
                'body' => $body,
                /*
                 * KAYIT YOKSA KAPALI. İş kuralı: şablonlar varsayılan
                 * KAPALI doğar. Boş metinli bir şablonu açık göstermek,
                 * müşteriye boş SMS gitmesi demekti.
                 */
                'enabled' => $row === null ? false : (bool) $row->enabled,
                'variables' => $spec['variables'],
                ...$this->metrics($body),
                'updated_at' => $row === null ? null : self::ts($row->updated_at),
            ];
        }

        return $this->json([
            'data' => $data,
            'meta' => [
                'sender_driver' => $this->senderDriver(),
                /*
                 * `false` ise sağlayıcı sırrı tanımsız ve gönderimler yalnız
                 * günlüğe yazılıyor. Panel bunu açıkça göstermeli; aksi
                 * hâlde "SMS gitti" diyen bir ekran hiçbir şey göndermemiş
                 * olur.
                 */
                'sender_configured' => $this->sender instanceof NetgsmSmsSender,
                /*
                 * BAŞLIK AÇILIŞ OKUMASINDA DA DÖNER — F.
                 *
                 * `sender_configured: false` tek başına "bir şey eksik" diyor
                 * ama HANGİSİ olduğunu söylemiyordu; yönetici de eksik olan
                 * parolayken başlığı düzeltmeye çalışıyordu. Üç alanın hangisi
                 * boşsa `missing` onu adıyla söylüyor ve panel Netgsm sekmesine
                 * yönlendiriyor.
                 */
                'sender_header' => NetgsmSettings::header(),
                'sender_header_source' => NetgsmSettings::source(),
                'sender_missing' => NetgsmSettings::missing(),
            ],
            'server_time' => $this->serverTime(),
        ]);
    }

    // ── PATCH /templates/{key} ────────────────────────────────────────────

    public function updateTemplate(Request $request, string $key): JsonResponse
    {
        $spec = $this->templateSpec($key);
        $this->assertTemplatesInstalled();

        $data = $request->validate([
            'body' => ['required', 'string', 'min:1', 'max:500'],
            'enabled' => ['sometimes', 'boolean'],
        ]);

        $body = (string) $data['body'];
        $this->assertKnownVariables($body, $spec['variables']);

        $current = $this->storedTemplates()[$key] ?? null;
        $enabled = array_key_exists('enabled', $data)
            ? (bool) $data['enabled']
            : ($current === null ? false : (bool) $current->enabled);

        $metrics = $this->metrics($body);

        return $this->write(
            $request,
            'sms.template.update',
            ControlAudit::TARGET_SMS_TEMPLATE,
            // `target_id` YOK: birincil anahtar metin, yükte duruyor.
            null,
            // METNİN TAMAMI YAZILMAZ — denetim izi "ne değişti"yi
            // anlatmalı, SMS gövdelerinin ikinci bir arşivi olmamalı.
            [
                'key' => $key,
                'length_from' => $current === null ? 0 : mb_strlen((string) $current->body),
                'length_to' => $metrics['length'],
                'enabled' => $enabled,
            ],
            static fn(): array => [
                'action' => 'sms.template.update',
                'key' => $key,
                ...$metrics,
                'enabled' => $enabled,
            ],
            function () use ($key, $spec, $body, $enabled, $metrics): array {
                $now = Carbon::now();

                DB::table(self::TEMPLATES_TABLE)->updateOrInsert(
                    ['key' => $key],
                    [
                        'title' => $spec['title'],
                        'body' => $body,
                        'enabled' => $enabled,
                        'updated_at' => $now,
                    ],
                );

                return [
                    'data' => [
                        'key' => $key,
                        ...$metrics,
                        'enabled' => $enabled,
                        'updated_at' => self::ts($now),
                    ],
                ];
            },
        );
    }

    // ── POST /templates/{key}/preview ─────────────────────────────────────

    /** HİÇBİR ŞEY GÖNDERİLMEZ; bu uç ağa çıkmaz. */
    public function previewTemplate(Request $request, string $key): JsonResponse
    {
        $spec = $this->templateSpec($key);

        $request->validate([
            'body' => ['sometimes', 'string', 'max:500'],
            'sample' => ['sometimes', 'array'],
            'sample.*' => ['nullable', 'string', 'max:200'],
        ]);

        // GÖVDE VERİLMEZSE KAYITLI ŞABLON işlenir; verilirse taslak işlenir
        // (kaydetmeden önce görmek için).
        $body = $request->filled('body')
            ? (string) $request->input('body')
            : (string) (($this->storedTemplates()[$key] ?? null)?->body ?? '');

        /** @var array<string, string> $sample */
        $sample = $request->input('sample', []);
        $sample = is_array($sample) ? $sample : [];

        if ($sample === []) {
            $sample = $this->defaultSample($spec['variables']);
        }

        [$rendered, $unresolved] = $this->render($body, $sample);

        return $this->write(
            $request,
            'sms.template.preview',
            ControlAudit::TARGET_SMS_TEMPLATE,
            null,
            ['key' => $key, 'length' => mb_strlen($rendered)],
            static fn(): array => [
                'action' => 'sms.template.preview',
                'key' => $key,
                'rendered' => $rendered,
            ],
            fn(): array => [
                'data' => [
                    'key' => $key,
                    'rendered' => $rendered,
                    ...$this->metrics($rendered),
                    /*
                     * ÇÖZÜLEMEYEN DEĞİŞKEN OLDUĞU GİBİ BIRAKILIR (`{eta}`),
                     * boşa çevrilmez: yöneticinin eksiği görmesi gerekiyor.
                     * Sessizce boşaltılan bir değişken, müşteriye "Sayın ,
                     * siparişiniz…" diye giden bir SMS üretirdi.
                     */
                    'unresolved_variables' => $unresolved,
                ],
            ],
        );
    }

    // ── POST /send-test ───────────────────────────────────────────────────

    public function sendTest(Request $request): JsonResponse
    {
        $data = $request->validate([
            'phone' => ['required', 'string', 'regex:/^5\d{9}$/'],
            'template_key' => ['sometimes', 'string', Rule::in(array_keys(self::TEMPLATES))],
            'body' => ['sometimes', 'string', 'max:500'],
            'sample' => ['sometimes', 'array'],
            'sample.*' => ['nullable', 'string', 'max:200'],
        ]);

        $hasKey = array_key_exists('template_key', $data);
        $hasBody = array_key_exists('body', $data);

        if ($hasKey === $hasBody) {
            throw ApiException::validationFailed(
                $hasKey
                    ? 'Şablon anahtarı ve serbest metin birlikte gönderilemez.'
                    : 'Şablon anahtarı ya da serbest metin gönderilmeli.',
                ['field' => 'template_key'],
            );
        }

        $phone = (string) $data['phone'];
        $key = $hasKey ? (string) $data['template_key'] : null;

        $body = $hasBody
            ? (string) $data['body']
            : (string) (($this->storedTemplates()[(string) $key] ?? null)?->body ?? '');

        /** @var array<string, string> $sample */
        $sample = is_array($data['sample'] ?? null) ? $data['sample'] : [];

        if ($sample === []) {
            $sample = $this->defaultSample(
                $key === null ? array_keys(self::SAMPLE_VALUES) : self::TEMPLATES[$key]['variables'],
            );
        }

        [$rendered] = $this->render($body, $sample);

        if (trim($rendered) === '') {
            throw ApiException::validationFailed(
                'Gönderilecek metin boş.',
                ['field' => $hasBody ? 'body' : 'template_key'],
            );
        }

        // ÖNEK KALDIRILAMAZ. Deneme SMS'inin gerçek bir bildirimden ayırt
        // edilememesi, yanlış numaraya giden bir mesajın müşteride panik
        // yaratması demekti.
        $message = self::TEST_PREFIX.$rendered;

        return $this->write(
            $request,
            'sms.send_test',
            null,
            null,
            // DENETİME MASKELİ NUMARA yazılır, tam numara değil.
            ['phone' => $this->maskPhone($phone), 'template_key' => $key],
            fn(): array => [
                'action' => 'sms.send_test',
                'phone' => $this->maskPhone($phone),
                'rendered' => $message,
                ...$this->metrics($message),
            ],
            fn(): array => ['data' => $this->deliver($phone, $message, $key, 'test')],
        );
    }

    // ── GET /netgsm ───────────────────────────────────────────────────────

    /**
     * Netgsm gönderici ayarı — F.
     *
     * PAROLA VE KULLANICI ADI BU YANITTA YOKTUR ve olmayacak: ikisi de
     * ortam değişkeninde yaşıyor (`Services\Sms\NetgsmSettings` sınıf
     * yorumu), bir uçtan geri dönmeleri sırrı istemci günlüklerine, tarayıcı
     * önbelleğine ve Kontrol Merkezi'nin denetim izine yayardı. Panelin
     * bilmesi gereken tek şey "dolu mu" — o da `missing` içinde.
     *
     * BAŞLIK İSE AÇIK DÖNER çünkü düzeltilecek olan odur ve Netgsm'in `40`
     * hatası ("başlık sistemde tanımlı değil") ancak gönderilen ad ile
     * panelde onaylı ad yan yana görülünce anlaşılır.
     */
    public function netgsm(): JsonResponse
    {
        return $this->json([
            'data' => [
                'header' => NetgsmSettings::header(),
                // Panelden yazılmış değer; boşsa ortamdan gelen kullanılıyor.
                // İkisini ayırmadan göstermek, yöneticinin "ayar boş demek ki
                // başlık yok" diye düşünüp ÇALIŞAN bir yapılandırmayı
                // bozmasına yol açardı.
                'stored_header' => NetgsmSettings::storedHeader(),
                'env_header' => NetgsmSettings::envHeader(),
                'source' => NetgsmSettings::source(),
                'header_max' => NetgsmSettings::HEADER_MAX,
                'username_configured' => NetgsmSettings::username() !== '',
                'password_configured' => NetgsmSettings::password() !== '',
                'missing' => NetgsmSettings::missing(),
                'driver' => $this->senderDriver(),
            ],
            'server_time' => $this->serverTime(),
        ]);
    }

    // ── PUT /netgsm ───────────────────────────────────────────────────────

    /**
     * Gönderici başlığını yazar.
     *
     * BOŞ DİZE AYARI SİLER ve ortam değişkenine döner — bir "geri al" yolu
     * olmasaydı, panelden bir kez yazılan yanlış başlık ortamdaki doğru
     * değeri kalıcı olarak gölgelerdi.
     *
     * BÜYÜK HARF ZORLANMAZ. Netgsm başlıkları geleneksel olarak büyük harf
     * ama sağlayıcı bunu şart koşmuyor; sessizce dönüştürmek, yöneticinin
     * panelde onaylattığı adı BAŞKA bir ada çevirip yine `40` hatası
     * üretebilirdi.
     */
    public function updateNetgsm(Request $request): JsonResponse
    {
        $data = $request->validate([
            'header' => [
                'present', 'string', 'max:'.NetgsmSettings::HEADER_MAX,
                // Netgsm gönderici adı yalnız harf/rakam/boşluk kabul ediyor;
                // Türkçe karakterli bir başlık sağlayıcıda zaten onaylanamaz
                // ve buradan geçmesi "kaydedildi ama hiç gitmiyor" hâlini
                // üretirdi.
                'regex:/^[A-Za-z0-9 ]*$/',
            ],
        ]);

        $header = trim((string) $data['header']);
        $before = NetgsmSettings::header();

        return $this->write(
            $request,
            'sms.netgsm.update',
            ControlAudit::TARGET_SMS_TEMPLATE,
            null,
            ['header_from' => $before, 'header_to' => $header],
            static fn(): array => [
                'action' => 'sms.netgsm.update',
                'header' => $header,
                'cleared' => $header === '',
            ],
            function () use ($header): array {
                NetgsmSettings::setHeader($header);

                return [
                    'data' => [
                        'header' => NetgsmSettings::header(),
                        'stored_header' => NetgsmSettings::storedHeader(),
                        'env_header' => NetgsmSettings::envHeader(),
                        'source' => NetgsmSettings::source(),
                        'missing' => NetgsmSettings::missing(),
                    ],
                    /*
                     * GÖNDERİCİ TEKİLİ BU İSTEK İÇİN ZATEN ÇÖZÜLMÜŞ OLABİLİR;
                     * yeni başlık ANCAK BİR SONRAKİ İSTEKTE yürürlüğe girer.
                     * Ekranın bunu söylemesi gerekiyor, aksi hâlde yönetici
                     * hemen deneme SMS'i gönderip eski başlıkla `40` alır ve
                     * kaydın işlemediğini sanır.
                     */
                    'warnings' => ['netgsm_header_applies_next_request'],
                ];
            },
        );
    }

    // ── GET /log ──────────────────────────────────────────────────────────

    public function log(Request $request): JsonResponse
    {
        $request->validate([
            'phone' => ['sometimes', 'string', 'max:32'],
            'template_key' => ['sometimes', 'string', 'max:48'],
            'status' => ['sometimes', Rule::in([
                SmsLog::STATUS_SENT, SmsLog::STATUS_FAILED,
                SmsLog::STATUS_SKIPPED, SmsLog::STATUS_DRY_RUN,
            ])],
            'context' => ['sometimes', Rule::in(['auto', 'test', 'announcement'])],
            'customer_id' => ['sometimes', 'integer'],
            'from' => ['sometimes', 'string', 'max:40'],
            'to' => ['sometimes', 'string', 'max:40'],
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);

        $page = max(1, (int) $request->query('page', '1'));
        $perPage = min(100, max(1, (int) $request->query('per_page', '25')));

        if (!Schema::hasTable(self::LOG_TABLE)) {
            return $this->json([
                'data' => [],
                'meta' => [
                    'page' => $page, 'per_page' => $perPage, 'total' => 0, 'last_page' => 1,
                    'sent_count' => 0, 'failed_count' => 0, 'segment_total' => 0,
                ],
                'server_time' => $this->serverTime(),
            ]);
        }

        $query = DB::table(self::LOG_TABLE);

        if ($request->filled('phone')) {
            $digits = preg_replace('/\D+/', '', (string) $request->query('phone')) ?? '';

            if ($digits !== '') {
                $query->where('phone', 'like', '%'.$digits.'%');
            }
        }

        foreach (['template_key', 'status', 'context'] as $field) {
            if ($request->filled($field)) {
                $query->where($field, (string) $request->query($field));
            }
        }

        if ($request->filled('customer_id')) {
            $query->where('customer_id', (int) $request->query('customer_id'));
        }

        if ($request->filled('from')) {
            $query->where('sent_at', '>=', $this->moment((string) $request->query('from'), 'from'));
        }

        if ($request->filled('to')) {
            $query->where('sent_at', '<=', $this->moment((string) $request->query('to'), 'to'));
        }

        $total = (int) $query->clone()->count();

        $rows = $query->clone()
            ->orderByDesc('sent_at')
            ->orderByDesc('id')
            ->forPage($page, $perPage)
            ->get();

        return $this->json([
            'data' => $rows->map(fn(object $row): array => [
                'id' => (int) $row->id,
                'template_key' => $row->template_key === null ? null : (string) $row->template_key,
                // TELEFON MASKELENİR. Tam numara zaten müşteri kartında ve
                // orası denetleniyor; gönderim kaydı bir iletişim defterine
                // dönüşmemeli.
                'phone' => $this->maskPhone((string) $row->phone),
                'customer_id' => $row->customer_id === null ? null : (int) $row->customer_id,
                'order_id' => $row->order_id === null ? null : (int) $row->order_id,
                'subscription_id' => $row->subscription_id === null ? null : (int) $row->subscription_id,
                // GÖVDE KIRPILIR: kayıtta tutmanın amacı "hangi metin
                // gitti"yi doğrulamak, arşiv değil.
                'body' => mb_strimwidth((string) $row->body, 0, self::LOG_BODY_PREVIEW, '…', 'UTF-8'),
                'segments' => (int) $row->segments,
                'status' => (string) $row->status,
                'error' => $row->error === null ? null : (string) $row->error,
                'provider_ref' => $row->provider_ref === null ? null : (string) $row->provider_ref,
                'context' => (string) $row->context,
                'sent_at' => self::ts($row->sent_at),
            ])->values()->all(),
            'meta' => [
                'page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'last_page' => max(1, (int) ceil($total / $perPage)),
                'sent_count' => (int) $query->clone()->where('status', 'sent')->count(),
                'failed_count' => (int) $query->clone()->where('status', 'failed')->count(),
                // SÜZGEÇLENMİŞ KÜMENİN segment toplamı — maliyet sorusunun
                // cevabı. Segment sayısı doğrudan paradır.
                'segment_total' => (int) $query->clone()->sum('segments'),
            ],
            'server_time' => $this->serverTime(),
        ]);
    }

    // ── Duyuru ────────────────────────────────────────────────────────────

    public function announcement(): JsonResponse
    {
        $body = (string) ($this->option(self::OPT_BODY) ?? '');
        $audience = (string) ($this->option(self::OPT_AUDIENCE) ?? 'active_customers');
        $lastRun = $this->option(self::OPT_LAST_RUN);

        $recipients = $this->recipients($audience);

        return $this->json([
            'data' => [
                'body' => $body,
                'audience' => $audience,
                ...$this->metrics($body),
                'last_run_at' => $lastRun === null ? null : self::ts((string) $lastRun),
                /*
                 * TAHMİN HER OKUMADA YENİDEN HESAPLANIR. Alıcı sayısı
                 * sürekli değişiyor ve donmuş bir tahmin, yöneticinin
                 * sandığından fazla SMS göndermesi demekti.
                 */
                'estimate' => [
                    'recipients' => count($recipients),
                    'segments' => count($recipients) * $this->metrics($body)['segments'],
                ],
            ],
            'server_time' => $this->serverTime(),
        ]);
    }

    /** YALNIZ TASLAĞI YAZAR, GÖNDERMEZ. */
    public function updateAnnouncement(Request $request): JsonResponse
    {
        $data = $request->validate([
            'body' => ['required', 'string', 'min:1', 'max:500'],
            'audience' => ['required', Rule::in(self::AUDIENCES)],
        ]);

        $body = (string) $data['body'];
        $audience = (string) $data['audience'];

        // Duyuru şablonunun tek değişkeni `customer_name`; tanınmayan bir
        // değişken burada da reddedilir.
        $this->assertKnownVariables($body, self::TEMPLATES['announcement']['variables']);

        return $this->write(
            $request,
            'sms.announcement.update',
            ControlAudit::TARGET_ANNOUNCEMENT,
            null,
            ['audience' => $audience, 'length' => mb_strlen($body)],
            fn(): array => [
                'action' => 'sms.announcement.update',
                'audience' => $audience,
                ...$this->metrics($body),
            ],
            function () use ($body, $audience): array {
                $this->setOption(self::OPT_BODY, $body);
                $this->setOption(self::OPT_AUDIENCE, $audience);

                return [
                    'data' => [
                        'audience' => $audience,
                        ...$this->metrics($body),
                    ],
                ];
            },
        );
    }

    /**
     * Duyuruyu gönderir.
     *
     * GÖNDERİM KUYRUĞA ALINMAZ, AKIŞ HÂLİNDE yapılır. Kuyruk altyapısı
     * eklemek bu turda gerekmeyen bir bağımlılık olurdu; birkaç yüz mesaj
     * tek istekte gidiyor ve her alıcı için bir kayıt satırı yazılıyor.
     */
    public function runAnnouncement(Request $request): JsonResponse
    {
        $data = $request->validate([
            'confirm_recipients' => ['required', 'integer', 'min:0'],
        ]);

        $body = (string) ($this->option(self::OPT_BODY) ?? '');
        $audience = (string) ($this->option(self::OPT_AUDIENCE) ?? 'active_customers');

        if (trim($body) === '') {
            throw ApiException::validationFailed('Duyuru metni boş.', ['field' => 'body']);
        }

        $lastRun = $this->option(self::OPT_LAST_RUN);

        if ($lastRun !== null) {
            $next = Carbon::parse((string) $lastRun)->addMinutes(self::COOLDOWN_MINUTES);

            if ($next->isFuture()) {
                throw new ApiException(
                    'CONFLICT',
                    'Son duyurudan bu yana 10 dakika geçmedi.',
                    409,
                    [
                        'conflict' => 'cooldown',
                        'retry_after_seconds' => (int) Carbon::now()->diffInSeconds($next, absolute: true),
                    ],
                );
            }
        }

        $recipients = $this->recipients($audience);
        $count = count($recipients);

        /*
         * ONAY SAYISI BİREBİR EŞLEŞMELİ. Yönetici ekranda 186 görüp
         * onayladıysa ve arada 5 müşteri daha eklendiyse, gönderimin
         * sessizce büyümemesi gerekir. Ekran sayıyı tazeler ve yeniden
         * sorar.
         */
        if ((int) $data['confirm_recipients'] !== $count) {
            throw new ApiException(
                'CONFLICT',
                'Alıcı sayısı değişti; ekranı tazeleyip yeniden onaylayın.',
                409,
                [
                    'conflict' => 'recipient_count',
                    'expected' => $count,
                    'given' => (int) $data['confirm_recipients'],
                ],
            );
        }

        $segments = $this->metrics($body)['segments'];

        return $this->write(
            $request,
            'sms.announcement.run',
            ControlAudit::TARGET_ANNOUNCEMENT,
            null,
            ['audience' => $audience, 'recipients' => $count, 'segments' => $count * $segments],
            fn(): array => [
                'action' => 'sms.announcement.run',
                'audience' => $audience,
                'recipients' => $count,
                'segments' => $count * $segments,
                'sample_rendered' => $this->render($body, [
                    'customer_name' => $recipients[0]['name'] ?? self::SAMPLE_VALUES['customer_name'],
                ])[0],
            ],
            fn(): array => ['data' => $this->broadcast($body, $recipients)],
        );
    }

    // ── Gönderim ──────────────────────────────────────────────────────────

    /**
     * Tek mesaj gönderir ve kayda yazar.
     *
     * SAĞLAYICI HATASI `502` ÜRETMEZ: `ok: true` + `data.status: "failed"`
     * döner ve hata metni gövdededir. Gönderim denemesi kayda geçti; isteğin
     * kendisi başarısız değil ve `500` dönmek yöneticiye "istek gitmedi"
     * dedirtirdi.
     *
     * @return array<string, mixed>
     */
    private function deliver(string $phone, string $message, ?string $templateKey, string $context): array
    {
        /*
         * GERÇEK GÖNDERİMLERLE AYNI METİN. `SmsDispatcher` her mesajı
         * `TurkishText::toGsm7()` ile çeviriyor; deneme SMS'i çevirmeseydi
         * yöneticiye müşterinin ASLA görmeyeceği bir metin gösterirdi ve
         * denemenin tek amacı tam da "müşteri ne görecek" sorusudur.
         */
        $message = TurkishText::toGsm7($message);
        $error = null;
        $providerCode = null;

        try {
            $this->sender->send($phone, $message);
        } catch (Throwable $exception) {
            $error = mb_strimwidth($exception->getMessage(), 0, 255, '…', 'UTF-8');
            // SAĞLAYICI KODU AYRI TAŞINIR: panel `40` (başlık tanımlı değil)
            // durumunu diğer hatalardan ayırıp yöneticiye ne yapacağını
            // yazıyor. Türkçe cümlenin içinde metin aramak, cümle
            // düzeltildiği gün o kapıyı sessizce kapatırdı.
            $providerCode = $exception instanceof SmsException ? $exception->providerCode : null;
        }

        $logId = $this->writeLog([
            'template_key' => $templateKey,
            'phone' => $phone,
            'body' => mb_substr($message, 0, 500),
            'segments' => $this->metrics($message)['segments'],
            'status' => $error === null ? SmsLog::STATUS_SENT : SmsLog::STATUS_FAILED,
            'error' => $error,
            'context' => $context,
        ]);

        return [
            'log_id' => $logId,
            'phone' => $this->maskPhone($phone),
            'rendered' => $message,
            'segments' => $this->metrics($message)['segments'],
            'status' => $error === null ? SmsLog::STATUS_SENT : SmsLog::STATUS_FAILED,
            'error' => $error,
            'provider_code' => $providerCode,
            // `40` HATASINDA GÖNDERİLEN BAŞLIK DA DÖNER. Hatanın tek sebebi
            // Netgsm panelindeki onaylı ad ile bizimkinin ayrışmasıdır ve
            // düzeltmenin ilk adımı ikisini yan yana görmektir.
            'header' => $providerCode === '40' ? NetgsmSettings::header() : null,
        ];
    }

    /**
     * @param  list<array{customer_id:int, phone:string, name:string}>  $recipients
     * @return array<string, mixed>
     */
    private function broadcast(string $body, array $recipients): array
    {
        $started = Carbon::now();
        $sent = 0;
        $failed = 0;
        $segments = 0;
        $failures = [];

        foreach ($recipients as $recipient) {
            [$rendered] = $this->render($body, ['customer_name' => $recipient['name']]);
            // Gönderimle kayıt aynı metni taşısın diye çeviri BURADA, tek
            // yerde (`deliver()` ile aynı gerekçe).
            $message = TurkishText::toGsm7($rendered);
            $messageSegments = $this->metrics($message)['segments'];
            $error = null;

            try {
                $this->sender->send($recipient['phone'], $message);
                $sent++;
            } catch (Throwable $exception) {
                $failed++;
                $error = mb_strimwidth($exception->getMessage(), 0, 255, '…', 'UTF-8');

                // HATA LİSTESİ TAVANLI: yanıtı yüzlerce hatayla şişirmek,
                // ekranda okunamayan bir liste üretirdi. Fazlası
                // `GET /log?status=failed` ile okunur.
                if (count($failures) < self::MAX_FAILURE_ROWS) {
                    $failures[] = ['phone' => $this->maskPhone($recipient['phone']), 'error' => $error];
                }
            }

            $segments += $messageSegments;

            $this->writeLog([
                'template_key' => 'announcement',
                'phone' => $recipient['phone'],
                'customer_id' => $recipient['customer_id'],
                'body' => mb_substr($message, 0, 500),
                'segments' => $messageSegments,
                'status' => $error === null ? SmsLog::STATUS_SENT : SmsLog::STATUS_FAILED,
                'error' => $error,
                'context' => 'announcement',
            ]);
        }

        $this->setOption(self::OPT_LAST_RUN, Carbon::now()->utc()->toIso8601ZuluString());

        return [
            'recipients' => count($recipients),
            'sent' => $sent,
            'failed' => $failed,
            'segments' => $segments,
            'started_at' => self::ts($started),
            'finished_at' => self::ts(Carbon::now()),
            'failures' => $failures,
        ];
    }

    /**
     * Kayıt satırı yazar; tablo yoksa sessizce atlar.
     *
     * KAYIT YOKLUĞU GÖNDERİMİ DURDURMAZ: mesaj müşteriye ulaştı ve kayıt
     * satırının yazılamaması onu geri almıyor. Tablo bu kurulumda henüz
     * açılmadıysa gönderim yine de yapılmalı.
     *
     * @param  array<string, mixed>  $row
     */
    private function writeLog(array $row): ?int
    {
        if (!Schema::hasTable(self::LOG_TABLE)) {
            return null;
        }

        $now = Carbon::now();

        /*
         * İKİ ZAMAN DAMGASI, AYNI AN. `created_at` satırın doğuşu,
         * `sent_at` panelin sıraladığı ve süzdüğü alan; satır gönderim
         * DENEMESİYLE BİRLİKTE doğduğu için ayrışmıyorlar. `sent_at`
         * BAŞARISIZ SATIRDA DA DOLU — boş bırakılsaydı
         * `GET /log?status=failed&from=…` hiçbir şey döndürmezdi, yani tam
         * da hataları aramaya gelen kişi hiçbir şey bulamazdı.
         */
        return (int) DB::table(self::LOG_TABLE)->insertGetId([
            'template_key' => null,
            'phone' => null,
            'customer_id' => null,
            'order_id' => null,
            'subscription_id' => null,
            'body' => '',
            'segments' => 1,
            'status' => SmsLog::STATUS_SENT,
            'error' => null,
            'provider_ref' => null,
            'context' => 'auto',
            'created_at' => $now,
            'sent_at' => $now,
            ...$row,
        ]);
    }

    // ── Kitle ─────────────────────────────────────────────────────────────

    /**
     * Duyuru alıcıları — NUMARASI OLMAYANLAR SESSİZCE ELENİR.
     *
     * `estimate.recipients` zaten elenmiş sayıyı verir; elemeden saymak,
     * yöneticinin gönderdiğini sandığından az kişiye ulaşması demekti.
     *
     * @return list<array{customer_id:int, phone:string, name:string}>
     */
    private function recipients(string $audience): array
    {
        $query = DB::table('customers')
            ->where('status', 1)
            ->whereNotNull('telephone')
            ->where('telephone', '!=', '');

        /*
         * SMS'E KAPALI MÜŞTERİ HİÇBİR KİTLEYE GİRMEZ. Ticari ileti onayını
         * geri çeken birine duyuru göndermek yalnız kaba değil, İYS
         * karşısında hukuki bir sorun; sütun varsa süzgece giriyor.
         */
        if (Schema::hasColumn('customers', 'bld_sms_opt_out')) {
            $query->where('bld_sms_opt_out', false);
        }

        if ($audience === 'subscribers') {
            $query->whereIn('customer_id', function (Builder $inner): void {
                $inner->select('customer_id')
                    ->from('veykemtu_subscriptions')
                    ->where('status', Subscription::STATUS_ACTIVE);
            });
        } elseif ($audience === 'active_customers') {
            /*
             * `all_customers` BİLİNÇLİ OLARAK EN GENİŞ VE EN SON: iki yıl
             * önce bir kez sipariş vermiş birine duyuru göndermek, spam
             * şikâyeti ve numara kaybı demektir. Varsayılan kitle son 180
             * günde siparişi olanlar.
             */
            $query->whereIn('customer_id', function (Builder $inner): void {
                $inner->select('customer_id')
                    ->from('orders')
                    ->whereNotNull('customer_id')
                    ->where('created_at', '>=', Carbon::now()->subDays(self::ACTIVE_CUSTOMER_DAYS));
            });
        }

        return $query
            ->orderBy('customer_id')
            ->get(['customer_id', 'telephone', 'first_name', 'last_name', 'bld_org_name'])
            ->map(static fn(object $row): array => [
                'customer_id' => (int) $row->customer_id,
                'phone' => preg_replace('/\D+/', '', (string) $row->telephone) ?? '',
                'name' => trim((string) ($row->bld_org_name ?: ($row->first_name.' '.$row->last_name))),
            ])
            ->filter(static fn(array $row): bool => preg_match('/^5\d{9}$/', $row['phone']) === 1)
            ->values()
            ->all();
    }

    // ── Metin ve ölçüm ────────────────────────────────────────────────────

    /**
     * Uzunluk, segment ve kodlama.
     *
     * SEGMENT SAYISI DOĞRUDAN MALİYETTİR. Türkçe karakter varsa metin GSM-7
     * tablosuna sığmaz ve UCS-2 gönderilir: tek segment 70 karakter (çoklu
     * segmentte 67). Aksi hâlde GSM-7: tek segment 160 (çoklu segmentte
     * 153). Sunucu iki segmente geçen bir şablonu ENGELLEMEZ — bazı
     * mesajlar gerçekten uzun; panel uyarır.
     *
     * @return array{length:int, segments:int, encoding:string, has_turkish_chars:bool}
     */
    private function metrics(string $body): array
    {
        $length = mb_strlen($body);
        $turkish = preg_match('/[çğıöşüÇĞİÖŞÜ]/u', $body) === 1;

        [$single, $multi] = $turkish ? [70, 67] : [160, 153];

        $segments = $length === 0
            ? 0
            : ($length <= $single ? 1 : (int) ceil($length / $multi));

        return [
            'length' => $length,
            'segments' => $segments,
            'encoding' => $turkish ? 'ucs2' : 'gsm7',
            'has_turkish_chars' => $turkish,
        ];
    }

    /**
     * `{degisken}` yerine koyma.
     *
     * @param  array<string, string|null>  $values
     * @return array{0: string, 1: list<string>}
     */
    private function render(string $body, array $values): array
    {
        $unresolved = [];

        $rendered = preg_replace_callback(
            '/\{([a-z0-9_]+)\}/',
            static function (array $match) use ($values, &$unresolved): string {
                $key = $match[1];
                $value = $values[$key] ?? null;

                if ($value === null || $value === '') {
                    $unresolved[] = $key;

                    // OLDUĞU GİBİ BIRAKILIR — boşa çevirmek eksiği görünmez
                    // kılardı.
                    return $match[0];
                }

                return (string) $value;
            },
            $body,
        ) ?? $body;

        return [$rendered, array_values(array_unique($unresolved))];
    }

    /**
     * TANINMAYAN DEĞİŞKEN KAYDEDİLMEZ.
     *
     * Sessizce boş bırakılan bir değişken, müşteriye "Sayın , siparişiniz…"
     * diye giden bir SMS üretirdi.
     *
     * @param  list<string>  $allowed
     */
    private function assertKnownVariables(string $body, array $allowed): void
    {
        preg_match_all('/\{([a-z0-9_]+)\}/', $body, $matches);

        $unknown = array_values(array_unique(array_diff($matches[1], $allowed)));

        if ($unknown !== []) {
            throw ApiException::validationFailed(
                'Şablonda tanınmayan değişken var.',
                ['field' => 'body', 'unknown_variables' => $unknown, 'allowed' => $allowed],
            );
        }
    }

    /**
     * @param  list<string>  $variables
     * @return array<string, string>
     */
    private function defaultSample(array $variables): array
    {
        $sample = [];

        foreach ($variables as $variable) {
            $sample[$variable] = self::SAMPLE_VALUES[$variable] ?? $variable;
        }

        return $sample;
    }

    /**
     * İlk üç + son üç hane; ortası yıldız (`532****567`).
     *
     * Maskeleme `SmsLog::maskPhone()` içinde ve TEK YERDE: panel ile
     * modelin farklı maskeler üretmesi, aynı numaranın iki ekranda iki
     * farklı görünmesi demekti.
     */
    private function maskPhone(string $phone): string
    {
        return SmsLog::maskPhone(preg_replace('/\D+/', '', $phone) ?? '');
    }

    // ── Depolama yardımcıları ─────────────────────────────────────────────

    /** @return array<string, SmsTemplate> */
    private function storedTemplates(): array
    {
        if (!Schema::hasTable(self::TEMPLATES_TABLE)) {
            return [];
        }

        /** @var array<string, SmsTemplate> */
        return SmsTemplate::query()->get()->keyBy('key')->all();
    }

    /** @return array{title: string, variables: list<string>} */
    private function templateSpec(string $key): array
    {
        if (!array_key_exists($key, self::TEMPLATES)) {
            throw ApiException::notFound('Bilinmeyen SMS şablonu: '.$key);
        }

        return self::TEMPLATES[$key];
    }

    private function assertTemplatesInstalled(): void
    {
        if (Schema::hasTable(self::TEMPLATES_TABLE)) {
            return;
        }

        throw ApiException::serverError(
            'SMS şablon tablosu bu kurulumda bulunmuyor; göç henüz uygulanmamış.',
        );
    }

    private function senderDriver(): string
    {
        return $this->sender instanceof NetgsmSmsSender ? 'netgsm' : 'log';
    }

    /**
     * Duyuru taslağı `location_options` içinde yaşıyor — kendi tablosunu
     * açmaya değmeyecek kadar küçük (üç alan, tek satır).
     */
    private function option(string $key): mixed
    {
        $raw = DB::table('location_options')->where('item', $key)->value('value');

        if ($raw === null) {
            return null;
        }

        return json_decode((string) $raw, true);
    }

    private function setOption(string $key, mixed $value): void
    {
        $locationId = (int) (DB::table('locations')->orderBy('location_id')->value('location_id') ?? 1);

        DB::table('location_options')->updateOrInsert(
            ['location_id' => $locationId, 'item' => $key],
            ['value' => json_encode($value)],
        );
    }

    private function moment(string $value, string $field): Carbon
    {
        try {
            return Carbon::parse($value)->utc();
        } catch (Throwable) {
            throw ApiException::validationFailed(
                'Zaman damgası ISO 8601 (UTC) biçiminde olmalı.',
                ['field' => $field],
            );
        }
    }
}
