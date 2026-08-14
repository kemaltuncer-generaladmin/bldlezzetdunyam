<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Igniter\Cart\Models\Menu;
use Igniter\Cart\Models\Order;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\BbdReceipt;
use Veykemtu\BridgeApi\Models\KitchenCommand;
use Veykemtu\BridgeApi\Models\KitchenDevice;
use Veykemtu\BridgeApi\Models\PrintJob;
use Igniter\Local\Models\Location;
use Veykemtu\BridgeApi\Services\KitchenDeviceSettings;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Services\MenuAvailability;
use Veykemtu\BridgeApi\Services\OrderEditor;
use Veykemtu\BridgeApi\Services\OrderPresenter;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Services\ProductionListService;
use Veykemtu\BridgeApi\Services\SubscriptionKitchenPlan;
use Veykemtu\BridgeApi\Services\ReceiptBuilder;

/**
 * KDS uçları — `docs/openapi.yaml` §Mutfak.
 *
 * Tümü `kitchen` kapsamı gerektirir. Bu uçlar fiyat, müşteri iletişim
 * bilgisi ve rapor **döndürmez**; tek istisna müşteri fişindeki teslimat
 * adresidir (ADR-08, `docs/10-test-kabul.md` S5).
 */
class KitchenController extends ApiController
{
    public function __construct(
        private readonly OrderPresenter $presenter,
        private readonly OrderStatusTransition $transitions,
        private readonly ReceiptBuilder $receipts,
        private readonly ProductionListService $production,
    ) {}

    /**
     * Cihaz eşleme — kimlik gerektirmez, tek kullanımlık kod ile.
     */
    public function pair(Request $request): JsonResponse
    {
        $data = $request->validate([
            'pairing_code' => ['required', 'string', 'max:16'],
            'device_name' => ['required', 'string', 'max:64'],
        ]);

        $device = KitchenDevice::where('pairing_code', strtoupper(trim($data['pairing_code'])))
            ->first();

        // Kodun yanlış olması ile süresinin dolması aynı yanıtı verir:
        // saldırgana hangi kodların var olduğunu söylememek için.
        if ($device === null || !$device->pairingCodeIsUsable()) {
            throw ApiException::notFound('Eşleme kodu geçersiz veya süresi dolmuş.');
        }

        $device->name = $data['device_name'];
        $token = $device->issueToken();

        return $this->json([
            'device_id' => (int) $device->id,
            'token' => $token,
            'server_time' => Carbon::now()->utc()->toIso8601ZuluString(),
        ]);
    }

    /**
     * Aktif siparişler — artımlı çekme.
     *
     * `since` durum değişimlerini de yakalar (`updated_at` üzerinden);
     * `after` yalnızca yeni siparişleri getirir. KDS `since` kullanmalıdır,
     * yoksa "hazırlanıyor" olan bir siparişin durumu ekranda takılı kalır.
     */
    public function orders(Request $request): JsonResponse
    {
        $request->validate([
            'after' => ['sometimes', 'integer'],
            'since' => ['sometimes', 'date'],
            // `boolean` KURALI KULLANILMAZ — sahada KDS'i kör eden hata buydu.
            //
            // Laravel'in `boolean` kuralı yalnızca `1`, `0`, `"1"`, `"0"` ve
            // gerçek boolean kabul eder; `"true"` dizgesini REDDEDER. Sorgu
            // dizesinde ise boolean ancak metin olarak ifade edilebilir ve
            // OpenAPI'nin standart serileştirmesi `?include_completed=true`
            // üretir. Sonuç: KDS'in artımlı yoklaması HER ÇAĞRIDA 422 aldı,
            // ekran tam listeye düşüp geri geldi ve bağlantı göstergesi
            // sürekli yanıp söndü.
            //
            // `$request->boolean()` bu değerlerin hepsini doğru okur;
            // doğrulama yalnızca anlamsız girdiyi eliyor.
            'include_completed' => ['sometimes', Rule::in(['1', '0', 'true', 'false'])],
        ]);

        $includeCompleted = $request->boolean('include_completed');

        $query = Order::query()->orderBy('order_id');

        if (!$includeCompleted) {
            $query->whereNotIn('status_id', $this->terminalStatusIds());
        }

        // Bugünün siparişleri: mutfak ekranı dünün işini göstermez.
        $query->whereDate('order_date', BusinessTime::now()->toDateString());

        if ($request->filled('after')) {
            $query->where('order_id', '>', (int) $request->query('after'));
        }

        if ($request->filled('since')) {
            // Gelen değer UTC'dir; `updated_at` depolama zaman diliminde
            // saklanır. Dönüştürmeden karşılaştırmak, saat farkı kadar
            // geçmişteki her siparişi "yeni güncellenmiş" gösterir ve
            // artımlı polling'i tamamen etkisiz kılar.
            $since = BusinessTime::forStorage(
                Carbon::parse((string) $request->query('since')),
            );
            $dayStart = BusinessTime::startOfBusinessDay();

            $query->where(function ($sub) use ($since, $dayStart): void {
                $sub->where('updated_at', '>', $since);

                /*
                 * ÖN SİPARİŞ KÖR NOKTASI (B-19) — sunucu tarafı düzeltme.
                 *
                 * KDS artımlı çekiyor (`since = son server_time`) ve tam
                 * yenilemeyi yalnız açılışta / bağlantı koptuğunda yapıyor
                 * (`polling_order_source.dart`). Pazartesi verilip cuma
                 * teslim edilecek bir siparişin `updated_at`'i pazartesidir:
                 * cuma günü `updated_at > since` HİÇBİR ZAMAN geçmez ve
                 * sipariş, PİŞECEĞİ GÜN panoda hiç görünmez.
                 *
                 * Bugün nadir; gün seçiciyle birlikte varsayılan yol olur.
                 * İstemcinin imleci iş gününün başlangıcından eskiyse, o gün
                 * servis edilecek ama daha önce oluşturulmuş siparişler de
                 * yanıta katılıyor. İmleç gün başlangıcını geçtiği anda bu
                 * koşul kendiliğinden kapanıyor — sürekli tam liste
                 * göndermiyoruz.
                 *
                 * Düzeltme tamamen burada: `mutfakapp` hiç değişmiyor.
                 */
                if ($dayStart->greaterThan($since)) {
                    $sub->orWhere('created_at', '<', $dayStart);
                }
            });
        }

        $orders = $query->get();

        // max_id daima bugünün TÜM siparişlerinin en büyüğüdür; filtre boş
        // dönse bile istemcinin imleci geriye kaymamalı.
        $maxId = (int) Order::query()
            ->whereDate('order_date', BusinessTime::now()->toDateString())
            ->max('order_id');

        return $this->json([
            'data' => $orders->map(
                fn(Order $order): array => $this->presenter->kitchen($order),
            )->all(),
            'server_time' => Carbon::now()->utc()->toIso8601ZuluString(),
            'max_id' => $maxId,
        ]);
    }

    /**
     * Bugün ve yarının abonelik siparişleri.
     *
     * Ana pano ([orders]) yalnız bugünü gösterir; abonelik yemekleri önceden
     * hazırlandığı için mutfak yarını da görmek ister. Bu uç salt bilgidir —
     * durum ilerletme (onayla/hazır) yine ana panoda, servis günü geldiğinde
     * yapılır. Yalnız `bld_subscription_id` dolu, terminal olmayan siparişler.
     */
    public function subscriptionOrders(Request $request): JsonResponse
    {
        $terminal = $this->terminalStatusIds();

        $fetch = fn(string $date): array => Order::query()
            ->whereNotNull('bld_subscription_id')
            ->whereNotIn('status_id', $terminal)
            ->whereDate('order_date', $date)
            ->orderBy('order_time')
            ->orderBy('order_id')
            ->get()
            ->map(fn(Order $order): array => $this->presenter->kitchen($order))
            ->all();

        return $this->json([
            'today' => $fetch(BusinessTime::now()->toDateString()),
            'tomorrow' => $fetch(BusinessTime::now()->addDay()->toDateString()),
            'server_time' => Carbon::now()->utc()->toIso8601ZuluString(),
        ]);
    }

    /**
     * Abonelik üretim planı — mutfağın sabah baktığı ekran (K-15).
     *
     * `subscription-orders` ucundan farkı: ürün toplamları, teslimat
     * saatleri ve **uyarılar** taşıyor. Uyarılar en önemlisi ve en kolay
     * atlananı: üretim koşmamışsa mutfak "bugün abonelik yok" sanıp
     * hazırlık yapmıyor.
     *
     * `days` parametresi: `today` (varsayılan, bugün+yarın), `tomorrow`,
     * `week`. Hafta her yoklamada hesaplanmıyor — mutfağın bakmadığı altı
     * gün için boşuna sorgu.
     */
    public function subscriptionPlan(
        Request $request,
        SubscriptionKitchenPlan $plan,
    ): JsonResponse {
        $data = $request->validate([
            'days' => ['sometimes', Rule::in(['today', 'tomorrow', 'week'])],
        ]);

        return $this->json($plan->plan($data['days'] ?? 'today'));
    }

    public function setStatus(Request $request, int $order): JsonResponse
    {
        $data = $request->validate([
            'status' => ['required', 'string', Rule::in(OrderStatusTransition::CODES)],
        ]);

        $model = $this->findOrder($order);
        $updated = $this->transitions->apply($model, $data['status']);

        return $this->json($this->presenter->kitchen($updated));
    }

    /**
     * Fiş verisi. Yazdırma **metnini** sunucu hazırlar, KDS yalnızca
     * ESC/POS'a çevirip basar — ne yazacağına karar istemcide değildir.
     */
    public function receipt(Request $request, int $order): JsonResponse
    {
        $data = $request->validate([
            'type' => ['required', Rule::in(PrintJob::TYPES)],
        ]);

        $model = $this->findOrder($order);

        return $this->json(match ($data['type']) {
            PrintJob::TYPE_KITCHEN => $this->receipts->kitchen($model),
            PrintJob::TYPE_COURIER => $this->receipts->courier($model),
            default => $this->receipts->customer($model),
        });
    }

    /**
     * Fiş basıldı bildirimi. İdempotenttir — KDS ağ hatasında tekrar
     * gönderirse yeni kayıt açılmaz (`docs/10-test-kabul.md` S4).
     */
    public function ackPrint(Request $request, int $order): JsonResponse
    {
        $data = $request->validate([
            'type' => ['required', Rule::in(PrintJob::TYPES)],
            'printed_at' => ['required', 'date'],
            // `sometimes` KASITLI: alanı hiç göndermeyen eski KDS sürümleri
            // `0` kovasına düşer ve bugünkü davranışları aynen sürer (K-20).
            'revision' => ['sometimes', 'integer', 'min:0'],
        ]);

        $model = $this->findOrder($order);

        /** @var KitchenDevice $device */
        $device = $request->user();

        PrintJob::record(
            (int) $model->order_id,
            $data['type'],
            BusinessTime::forStorage(Carbon::parse($data['printed_at'])),
            (int) $device->id,
            (int) ($data['revision'] ?? 0),
        );

        return $this->noContent();
    }

    public function productionList(): JsonResponse
    {
        return $this->json([
            'data' => $this->production->today(),
            'as_of' => Carbon::now()->utc()->toIso8601ZuluString(),
        ]);
    }

    /**
     * Canlılık bildirimi.
     *
     * `last_seen_at` güncellemesi `bld.scope` middleware'inde yapılır — her
     * mutfak isteği canlılık kanıtıdır, yalnızca heartbeat değil.
     */
    public function heartbeat(): JsonResponse
    {
        return $this->json([
            'server_time' => Carbon::now()->utc()->toIso8601ZuluString(),
            'min_supported_version' => '1.0.0',
        ]);
    }

    /**
     * Kasa sağlık bildirimi — `docs/03-api-sozlesmesi.md` §Mutfak.
     *
     * ÇİFT YÖNLÜ, ve bu bilinçli: cihaz kendi bilebileceğini (yazıcı,
     * kuyruk, sürüm) bildirir; sunucu cihazın bilemeyeceğini (bugünkü
     * toplam sipariş) döndürür. Ekrandaki sağlık paneli bunların ikisini
     * birden gösteriyor ve iki ayrı çağrı yapmasının anlamı yok.
     *
     * Bugünkü sayıyı cihazın kendisi hesaplayamaz: mutfak listesi
     * yalnızca AKTİF siparişleri taşır, teslim edilenler düşer. Vardiya
     * boyunca kaç sipariş geçtiğini yalnızca sunucu bilir.
     *
     * Bildirilen değerler DOĞRULANMAZ, yalnızca kaydedilir. Yazıcının
     * gerçekten çalıştığını sunucudan anlamanın yolu yok; cihazın
     * beyanına güveniyoruz ve zaman damgasıyla birlikte saklıyoruz ki
     * bayat veri taze sanılmasın.
     */
    public function health(
        Request $request,
        KitchenDeviceSettings $settings,
    ): JsonResponse {
        $data = $request->validate([
            'printer_ok' => ['required', 'boolean'],
            'print_queue_pending' => ['required', 'integer', 'min:0', 'max:100000'],
            'print_queue_failed' => ['required', 'integer', 'min:0', 'max:100000'],
            'app_version' => ['sometimes', 'string', 'max:32'],

            /*
             * ZENGİNLEŞTİRİLMİŞ TELEMETRİ (K-22) — HEPSİ OPSİYONEL.
             *
             * Sahadaki kasalar bu alanları göndermeyen bir sürümde ve öyle
             * kalabilirler. `sometimes` + `nullable`: alan hiç gelmezse
             * doğrulama karışmaz, `null` gelirse de kabul edilir. Zorunlu
             * yapmak, sunucu güncellendiği anda TÜM eski kasaların sağlık
             * bildirimini 422'ye düşürürdü — yani yönetici, kasaların
             * durumunu görmek için eklediği alan yüzünden hiçbirini
             * göremez hâle gelirdi.
             *
             * Sınırlar sütun genişlikleriyle birebir (göç
             * `2026_08_18_000001`): MySQL'in sessizce kesmesi yerine
             * istemci hatayı görsün.
             */
            'last_error' => ['sometimes', 'nullable', 'string', 'max:255'],
            'alarm_muted' => ['sometimes', 'nullable', 'boolean'],
            'alarm_mute_reason' => ['sometimes', 'nullable', 'string', 'max:120'],
            'queue_oldest_at' => ['sometimes', 'nullable', 'date'],
            'sound_ok' => ['sometimes', 'nullable', 'boolean'],

            // Bir önceki turda teslim edilen komutların sonuçları.
            'command_results' => ['sometimes', 'array', 'max:50'],
            'command_results.*.id' => ['required', 'integer'],
            'command_results.*.ok' => ['required', 'boolean'],
            'command_results.*.message' => ['sometimes', 'nullable', 'string', 'max:255'],
        ]);

        $device = $request->user();

        if (!$device instanceof KitchenDevice) {
            throw ApiException::unauthenticated();
        }

        // `saveQuietly` + `withoutTimestamps`: sağlık dakikada bir gelir,
        // `updated_at`'i kirletip model olaylarını tetiklemesine gerek yok.
        $this->recordCommandResults($device, $data['command_results'] ?? []);

        KitchenDevice::withoutTimestamps(fn() => $device->forceFill([
            'health_reported_at' => Carbon::now(),
            'printer_ok' => (bool) $data['printer_ok'],
            'print_queue_pending' => (int) $data['print_queue_pending'],
            'print_queue_failed' => (int) $data['print_queue_failed'],
            'app_version' => $data['app_version'] ?? $device->app_version,

            /*
             * TELEMETRİ ALANLARI GÖNDERİLMEDİĞİNDE `null` YAZILIR —
             * `app_version` gibi eski değer KORUNMAZ, ve bu bilinçli.
             *
             * `app_version` bir KİMLİKTİR: kasa sürümünü bildirmediyse hâlâ
             * son bildirdiği sürümdedir. Buradakiler ise ANLIK ÖLÇÜMDÜR:
             * "kuyrukta bekleyen en eski iş 40 dakikalık" bilgisi bir sonraki
             * bildirimde gelmiyorsa o iş büyük olasılıkla basılmıştır. Eski
             * değeri korumak, çözülmüş bir arızayı panelde sonsuza kadar
             * kırmızı bırakırdı — ve gösterge yalan söylüyorsa hiç olmaması
             * daha iyidir.
             *
             * Aynı kural eski kasaları da doğru gösteriyor: alanı hiç
             * göndermeyen bir kasa için sütun `null` kalır, panel de
             * "bildirmedi" der; "sorun yok" DEMEZ.
             */
            'last_error' => self::trimOrNull($data['last_error'] ?? null, 255),
            'alarm_muted' => self::boolOrNull($data['alarm_muted'] ?? null),
            'alarm_mute_reason' => self::trimOrNull($data['alarm_mute_reason'] ?? null, 120),
            // `BusinessTime::forStorage` ŞART, çıplak `Carbon::parse` DEĞİL:
            // Eloquent `datetime` alanını yazarken Carbon'un kendi zaman
            // dilimini kullanıyor ama okurken PHP'nin varsayılanını
            // (Europe/Istanbul) varsayıyor. Damga üç saat kayar ve panelde
            // "en eskisi 40 dakikadır bekliyor" yerine "3 saat 40 dakika"
            // yazardı. Aynı tuzak `printed_at`'te yakalanmıştı — gerekçe
            // `BusinessTime::forStorage` yorumunda.
            'queue_oldest_at' => isset($data['queue_oldest_at'])
                ? BusinessTime::forStorage(Carbon::parse((string) $data['queue_oldest_at']))
                : null,
            'sound_ok' => self::boolOrNull($data['sound_ok'] ?? null),
        ])->saveQuietly());

        return $this->json([
            'server_time' => Carbon::now()->utc()->toIso8601ZuluString(),
            'orders_today' => $this->ordersToday(),
            'orders_active' => $this->activeOrderCount(),
            // Ayarlar SAĞLIK YANITINDA dönüyor, ayrı bir uçta değil:
            // kasa zaten dakikada bir buraya geliyor ve ikinci bir
            // yoklama döngüsü kurmanın anlamı yok. Dokunulmamış alanlar
            // `null` gelir; kasa o alanda kendi derleme varsayılanını
            // kullanır.
            'settings' => $settings->forDevice($device),
            // Bekleyen komutlar. Kasa bunları çalıştırıp sonuçlarını bir
            // sonraki bildirimde `command_results` ile geri gönderir.
            'commands' => $this->takeCommands($device),
        ]);
    }

    /**
     * Telemetri metnini kırpar; boş kalırsa `null`.
     *
     * BOŞ DİZE `null`'A DÜŞÜYOR — ayarlardaki `audio_sink` istisnasının
     * TERSİ, ve doğrusu bu: orada boş dize yöneticinin verdiği bir emirdi
     * ("varsayılan çıkışa dön"), burada ise kasanın "hata yok" demesinin
     * biçimsiz hâli. Boş dizeyi saklamak, panelde boş bir hata satırı
     * gösterirdi.
     */
    private static function trimOrNull(mixed $value, int $max): ?string
    {
        if ($value === null) {
            return null;
        }

        $text = trim((string) $value);

        return $text === '' ? null : mb_substr($text, 0, $max);
    }

    /**
     * Üç hâlli bayrak: `null` "bildirmedi", aksi hâlde `bool`.
     *
     * `(bool) null` `false` verirdi ve "kasa bildirmedi" ile "kasa kötü
     * bildirdi" aynı şeye düşerdi — panel de var olmayan bir arıza
     * gösterirdi.
     */
    private static function boolOrNull(mixed $value): ?bool
    {
        return $value === null ? null : (bool) $value;
    }

    /**
     * Kasanın bildirdiği komut sonuçlarını kaydeder.
     *
     * Sonucu gelen komut bir daha gönderilmez. Kasa başka bir cihazın
     * komut kimliğini bildirse bile o satıra dokunulmaz — kimlik sorgusu
     * cihazla sınırlı.
     *
     * @param  array<int, array<string, mixed>>  $results
     */
    private function recordCommandResults(KitchenDevice $device, array $results): void
    {
        foreach ($results as $result) {
            KitchenCommand::query()
                ->where('device_id', $device->id)
                ->where('id', (int) $result['id'])
                ->whereNull('executed_at')
                ->update([
                    'executed_at' => Carbon::now(),
                    'succeeded' => (bool) $result['ok'],
                    'result' => isset($result['message'])
                        ? mb_substr((string) $result['message'], 0, 255)
                        : null,
                ]);
        }
    }

    /**
     * Bekleyen komutları döndürür ve teslim edilmiş işaretler.
     *
     * @return list<array<string, mixed>>
     */
    private function takeCommands(KitchenDevice $device): array
    {
        $commands = KitchenCommand::pendingFor($device->id)->limit(20)->get();

        if ($commands->isEmpty()) {
            return [];
        }

        KitchenCommand::query()
            ->whereIn('id', $commands->pluck('id'))
            ->update(['delivered_at' => Carbon::now()]);

        return $commands
            ->map(static fn(KitchenCommand $c): array => [
                'id' => (int) $c->id,
                'command' => (string) $c->command,
                'payload' => $c->payload ?? [],
            ])
            ->all();
    }

    /**
     * Bugün oluşturulan sipariş sayısı — iptaller HARİÇ.
     *
     * Gün sınırı Europe/Istanbul'a göre: sunucu UTC tutuyor ve gece
     * yarısından sonraki üç saatlik siparişler "dün" görünürdü
     * (`docs/03` §1.3).
     */
    private function ordersToday(): int
    {
        $cancelled = \Igniter\Admin\Models\Status::query()
            ->where('status_code', OrderStatusTransition::CANCELLED)
            ->value('status_id');

        return Order::query()
            ->where('created_at', '>=', BusinessTime::startOfBusinessDay())
            ->when($cancelled !== null, fn($q) => $q->where('status_id', '!=', $cancelled))
            ->count();
    }

    /** Mutfak ekranında kart olarak duran sipariş sayısı. */
    private function activeOrderCount(): int
    {
        return Order::query()
            ->whereNotIn('status_id', $this->terminalStatusIds())
            ->count();
    }

    /**
     * Yoğunluk şalteri — mutfaktaki tek tuş.
     *
     * Sipariş almayı DURDURMAZ. Açıkken müşteri arayüzlerinde "hazırlanması
     * uzun sürebilir" uyarısı çıkar, admin panelde de görünür. Siparişi
     * gerçekten kesen şalter ayrıdır: `setOrdering` (K-11) — ve o şalter
     * onay, sebep, süre ve kasanın açılış şifresini ister.
     *
     * Durum vitrine yazılır, cihaza değil: iki kasa olsa ikisi de aynı
     * şeyi göstermeli ve müşteri tarafı zaten vitrini okuyor.
     */
    public function setBusy(Request $request, LocationGate $gate): JsonResponse
    {
        $data = $request->validate(['busy' => ['required', 'boolean']]);

        $location = $this->defaultLocation();

        $gate->setBusy($location, (bool) $data['busy']);

        return $this->json([
            'busy' => $gate->isBusy($location),
            'busy_message' => $gate->busyMessage($location),
            'server_time' => Carbon::now()->utc()->toIso8601ZuluString(),
        ]);
    }

    /**
     * Satış şalteri — sipariş almayı gerçekten durdurur (K-11).
     *
     * NEDEN MUTFAKTA: sahada yazıcı bozulduğunda, malzeme bittiğinde ya da
     * ekip yetişemediğinde mutfak sipariş almaya devam ediyor, gelenleri
     * tek tek telefonla iptal ediyordu. Müşteri için "siparişim alındı,
     * sonra arandı ve iptal edildi", kapalı bir dükkândan çok daha kötü.
     *
     * NEDEN TEK TUŞ DEĞİL: bu şalter ciroyu kapatıyor. Kasa tarafında onay
     * + sebep + süre + açılış şifresi isteniyor (`docs/05` §11); sunucu
     * tarafında ise sebep ve süre kayda geçiyor ki "kim kapattı, neden,
     * ne zamana kadar" sorusu cevapsız kalmasın.
     *
     * SÜRE ZORUNLU DEĞİL ama şiddetle önerilir: "kapattım, açmayı unuttum"
     * en olası hata ve süreli durdurma onu kendiliğinden çözüyor.
     */
    public function setOrdering(Request $request, LocationGate $gate): JsonResponse
    {
        $data = $request->validate([
            'enabled' => ['required', 'boolean'],
            'reason' => ['nullable', 'string', 'max:160'],
            // `null` = süresiz, `0` = gün sonuna kadar, >0 = dakika.
            'minutes' => ['nullable', 'integer', 'min:0', 'max:1440'],
        ]);

        $location = $this->defaultLocation();

        if ((bool) $data['enabled']) {
            $gate->resumeOrdering($location);
        } else {
            $minutes = array_key_exists('minutes', $data) ? $data['minutes'] : null;

            $until = match (true) {
                $minutes === null => null,
                // 0 = "bugünün sonuna kadar". Mutfağın en sık istediği
                // seçenek bu: yarın sabah dükkân kendiliğinden açılmalı.
                $minutes === 0 => BusinessTime::now()->endOfDay(),
                default => BusinessTime::now()->addMinutes($minutes),
            };

            $gate->pauseOrdering($location, $until, $data['reason'] ?? null);
        }

        return $this->json($this->orderingPayload($gate, $location));
    }

    /** Şalterin o anki durumu. */
    public function ordering(LocationGate $gate): JsonResponse
    {
        return $this->json($this->orderingPayload($gate, $this->defaultLocation()));
    }

    /** @return array<string, mixed> */
    private function orderingPayload(LocationGate $gate, Location $location): array
    {
        return [
            // `orderingEnabled` süresi dolmuş durdurmayı kendiliğinden
            // kaldırıyor; yanıt bu yüzden HER ZAMAN gerçeği söyler.
            'ordering_enabled' => $gate->orderingEnabled($location),
            'reason' => $gate->pauseReason($location),
            'resumes_at' => $gate->pauseEndsAt($location)?->toIso8601ZuluString(),
            'busy' => $gate->isBusy($location),
            'server_time' => Carbon::now()->utc()->toIso8601ZuluString(),
        ];
    }

    /**
     * Mutfağın ürün listesi ve "bugün tükendi" işaretleri (K-11).
     *
     * FİYAT YOK — ADR-08 korunuyor. Mutfak neyin bittiğine karar verirken
     * fiyata bakmıyor; para bilgisi bu ekranda yalnızca sızıntı riski.
     */
    public function menuAvailability(MenuAvailability $availability): JsonResponse
    {
        return $this->json([
            'data' => $availability->kitchenCatalog(),
            'server_time' => Carbon::now()->utc()->toIso8601ZuluString(),
        ]);
    }

    /** Ürünü bugünlük tükendi işaretler ya da işareti kaldırır. */
    public function setMenuAvailability(
        Request $request,
        MenuAvailability $availability,
    ): JsonResponse {
        $device = $request->user();
        $data = $request->validate([
            'menu_id' => ['required', 'integer', 'min:1'],
            'sold_out' => ['required', 'boolean'],
            'reason' => ['nullable', 'string', 'max:160'],
        ]);

        $menuId = (int) $data['menu_id'];

        if (Menu::where('menu_id', $menuId)->doesntExist()) {
            throw ApiException::notFound('Ürün bulunamadı.');
        }

        if ((bool) $data['sold_out']) {
            $availability->markSoldOut(
                $menuId,
                $data['reason'] ?? null,
                deviceId: $device instanceof KitchenDevice ? (int) $device->id : null,
            );
        } else {
            $availability->clearSoldOut($menuId);
        }

        return $this->json([
            'data' => $availability->kitchenCatalog(),
            'server_time' => Carbon::now()->utc()->toIso8601ZuluString(),
        ]);
    }

    // ── Sipariş düzenleme (K-12) ──────────────────────────────────────────

    /**
     * Düzenlenebilir sipariş görüntüsü — fiyatsız (ADR-08).
     */
    public function editable(int $order, OrderPresenter $presenter): JsonResponse
    {
        return $this->json(['data' => $presenter->editable($this->findOrder($order))]);
    }

    /**
     * Ürün ekleme için sadeleşmiş menü — fiyatsız.
     *
     * `menu-availability` ucundan AYRI: bu, düzenleme ekranının ürün
     * seçicisi ve yalnız **eklenebilir** ürünleri döndürür. Diğeri satış
     * kontrolü ekranının listesi ve kapalıları da gösterir, çünkü orada
     * amaç kapatmak/açmak.
     */
    public function menu(MenuAvailability $availability): JsonResponse
    {
        $data = array_values(array_filter(
            $availability->kitchenCatalog(),
            static fn(array $item): bool => $item['listed'] === true,
        ));

        return $this->json([
            'data' => $data,
            'server_time' => Carbon::now()->utc()->toIso8601ZuluString(),
        ]);
    }

    /**
     * Yeni revizyon — mutfak müşteriyle konuştuktan sonra uygular.
     *
     * ONAY BEKLENMEZ: personel değişikliği sisteme girmeden ÖNCE
     * telefonda anlaşıyor (`docs/05` §12). Bu uç bir talep değil, bir
     * kayıt ucudur.
     */
    public function storeRevision(
        int $order,
        Request $request,
        OrderEditor $editor,
        OrderPresenter $presenter,
    ): JsonResponse {
        $data = $request->validate([
            'reason' => ['required', 'string', 'max:160'],
            'note' => ['nullable', 'string', 'max:1000'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.menu_id' => ['required', 'integer', 'min:1'],
            'items.*.quantity' => ['required', 'integer', 'min:1', 'max:999'],
            'items.*.option_value_ids' => ['sometimes', 'array'],
            'items.*.option_value_ids.*' => ['integer', 'min:1'],
            'items.*.note' => ['nullable', 'string', 'max:255'],
            'requested_at' => ['nullable', 'date'],
            'customer_note' => ['nullable', 'string', 'max:1000'],
        ]);

        $model = $this->findOrder($order);
        $device = $request->user();

        $revision = $editor->apply(
            $model,
            $data['items'],
            $data['reason'],
            $data['note'] ?? null,
            isset($data['requested_at']) ? Carbon::parse($data['requested_at']) : null,
            $data['customer_note'] ?? null,
            $device instanceof KitchenDevice ? (int) $device->id : null,
        );

        return $this->json([
            'order' => $presenter->kitchen($model->refresh()),
            'revision' => $revision,
        ]);
    }

    /** Revizyon geçmişi — "ne oldu" sorusunun cevabı. */
    public function revisions(int $order): JsonResponse
    {
        $this->findOrder($order);

        $rows = DB::table('veykemtu_order_revisions')
            ->where('order_id', $order)
            ->orderBy('revision_no')
            ->get()
            ->map(static fn($row): array => [
                'revision_no' => (int) $row->revision_no,
                'reason' => (string) $row->reason,
                'note' => $row->note,
                'refund_kurus' => (int) $row->refund_kurus,
                'extra_charge_kurus' => (int) $row->extra_charge_kurus,
                'created_at' => $row->created_at,
            ])
            ->all();

        return $this->json(['data' => $rows]);
    }

    // ── BBD Store köprüsü (K-16) ──────────────────────────────────────────

    /**
     * Basılmayı bekleyen BBD fişleri.
     *
     * `since` YOK, `printed_at IS NULL` VAR: BBD fişleri bir "liste"
     * değil, bir **kuyruk**. Zaman damgasıyla artımlı çekmek, ağ
     * kesintisinde basılmamış bir fişi sonsuza dek atlayabilirdi.
     * Kasa bastıkça işaretliyor ve kuyruk boşalıyor.
     *
     * Sınır 20: kasa uzun süre kapalı kalmışsa 200 fişi tek seferde
     * basmaya kalkmamalı; sıradaki yoklamada kalanlar gelir.
     */
    public function bbdOrders(): JsonResponse
    {
        $rows = BbdReceipt::query()
            ->whereNull('printed_at')
            ->orderBy('id')
            ->limit(20)
            ->get()
            ->map(static fn(BbdReceipt $row): array => [
                'id' => (int) $row->id,
                'external_id' => (string) $row->external_id,
                'received_at' => $row->received_at?->utc()->toIso8601ZuluString(),
                'payload' => $row->payload_json,
            ])
            ->all();

        return $this->json([
            'data' => $rows,
            'server_time' => Carbon::now()->utc()->toIso8601ZuluString(),
        ]);
    }

    /**
     * Fiş basıldı bildirimi — idempotent.
     *
     * İlk `printed_at` korunuyor: ağ hatasında kasa tekrar gönderirse
     * "ne zaman basıldı" cevabı değişmemeli.
     */
    public function ackBbd(int $receipt): JsonResponse
    {
        $row = BbdReceipt::find($receipt);

        if ($row === null) {
            throw ApiException::notFound('BBD fişi bulunamadı.');
        }

        if (!$row->isPrinted()) {
            $row->printed_at = BusinessTime::now();
            $row->save();
        }

        return $this->noContent();
    }

    /** @throws ApiException */
    private function defaultLocation(): Location
    {
        $location = Location::query()
            ->where('location_status', true)
            ->orderByDesc('is_default')
            ->first();

        if ($location === null) {
            throw ApiException::notFound('Vitrin bulunamadı.');
        }

        return $location;
    }

    /** @throws ApiException */
    private function findOrder(int $orderId): Order
    {
        $order = Order::where('order_id', $orderId)->first();

        if ($order === null) {
            throw ApiException::notFound('Sipariş bulunamadı.');
        }

        return $order;
    }

    /** @return list<int> */
    private function terminalStatusIds(): array
    {
        return \Igniter\Admin\Models\Status::query()
            ->whereIn('status_code', [
                OrderStatusTransition::DELIVERED,
                OrderStatusTransition::CANCELLED,
            ])
            ->pluck('status_id')
            ->map(intval(...))
            ->all();
    }
}
