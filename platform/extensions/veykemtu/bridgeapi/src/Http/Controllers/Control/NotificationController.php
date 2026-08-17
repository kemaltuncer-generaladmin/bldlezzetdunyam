<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Control;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\Announcement;
use Veykemtu\BridgeApi\Models\AnnouncementRead;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Kontrol Merkezi — uygulama-içi duyuru (`docs/control/notifications.md`).
 *
 * PUSH BİLDİRİMİ YOK (iş kararı 11). Müşteriye ulaşmanın iki yolu var:
 * SMS (`control/sms`) ve bu alan. Farkı İTTİRİLMEMESİDİR — müşteri
 * uygulamayı açtığında görür. Acil bir şey duyurulacaksa SMS kullanılır;
 * duyuru, uygulamayı açanı bilgilendirir.
 *
 * GÖVDE DÜZ METİNDİR, HTML DEĞİL. Duyuru üç istemcide birden gösteriliyor
 * (Next.js, Flutter müşteri, ileride başkaları) ve HTML'i üçünde tutarlı
 * çizmek imkânsız; Flutter tarafında ayrıca bir HTML işleyici bağımlılığı
 * gerektirirdi. Satır sonu `\n` desteklenir, biçimlendirme yok.
 *
 * ── DEPOLAMA: `Models\Announcement` ──────────────────────────────────────
 * Rota adı `control/notifications`, tablo adı `veykemtu_announcements`.
 * İkisi aynı şeyin iki adı ve MÜŞTERİ YÜZÜ ZATEN O TABLOYU OKUYOR
 * (`Http\Controllers\AnnouncementController`). Kendi tablomuzu açsaydık
 * panelden yazılan duyuru müşteride hiç görünmezdi.
 *
 * Alan adları müşteri yüzüyle AYNI KALIYOR: `severity` (sözleşmedeki
 * `level`), `action_url` ↔ `action_value`. Panelde üçüncü bir ad seti
 * açmak, aynı kaydı iki farklı sözlükle konuşan iki ekran demekti.
 * Sözleşmedeki `published_at` alanının SÜTUNU YOK ve `null` dönüyor;
 * uydurmak yerine eksik bırakmak, rapora düşen bir boşluktur.
 */
class NotificationController extends ControlController
{
    /** `daily` en fazla bu kadar gün taşır. */
    private const int MAX_DAILY_DAYS = 90;

    // ── GET / ─────────────────────────────────────────────────────────────

    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'status' => ['sometimes', Rule::in(Announcement::STATUSES)],
            'audience' => ['sometimes', Rule::in(Announcement::AUDIENCES)],
            'level' => ['sometimes', Rule::in(Announcement::SEVERITIES)],
            'live' => ['sometimes', 'boolean'],
            'q' => ['sometimes', 'string', 'max:200'],
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);

        $query = Announcement::query();

        if ($request->filled('status')) {
            $query->where('status', (string) $request->query('status'));
        }

        if ($request->filled('audience')) {
            $query->where('audience', (string) $request->query('audience'));
        }

        if ($request->filled('level')) {
            // Sözleşmedeki `level`, tablodaki `severity`.
            $query->where('severity', (string) $request->query('level'));
        }

        if ($request->has('live')) {
            $this->applyLiveFilter($query, $request->boolean('live'));
        }

        if ($request->filled('q')) {
            $term = '%'.str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], trim((string) $request->query('q'))).'%';

            $query->where(function (Builder $inner) use ($term): void {
                $inner->where('title', 'like', $term)->orWhere('body', 'like', $term);
            });
        }

        $page = max(1, (int) $request->query('page', '1'));
        $perPage = min(100, max(1, (int) $request->query('per_page', '25')));
        $total = (int) $query->clone()->count();

        $rows = $query->clone()
            /*
             * TASLAKLAR EN ÜSTTE. Yayınlanmamış bir duyuru bekleyen bir iş;
             * yayınlanmış olan bir kayıt. Sıralamayı yalnız tarih
             * belirleseydi taslaklar veritabanına göre başa ya da sona
             * düşer ve sıra sunucu ayarına bağlı olurdu.
             */
            ->orderByRaw("CASE WHEN status = '".Announcement::STATUS_DRAFT."' THEN 0 ELSE 1 END")
            ->orderByDesc('id')
            ->forPage($page, $perPage)
            ->get();

        $seen = $this->seenCounts($rows->pluck('id')->map(intval(...))->all());

        return $this->json([
            'data' => $rows->map(fn(Announcement $row): array => $this->row($row, $seen))->values()->all(),
            'meta' => [
                'page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'last_page' => max(1, (int) ceil($total / $perPage)),
                /*
                 * ŞU AN GERÇEKTEN GÖRÜNEN duyuru sayısı. "Üç duyuru yayında"
                 * demek ile "üçü de tarih aralığının dışında" demek
                 * arasındaki farkı görmeyen yönetici, duyurusunun neden
                 * görünmediğini anlayamaz.
                 */
                'live_count' => $this->liveCount(),
                // Kapalı enum olmayan tek alan `placement`; panelin açılır
                // listesi kullanımdakilerden dolduruluyor.
                'placements' => Announcement::query()
                    ->distinct()->orderBy('placement')->pluck('placement')
                    ->map(strval(...))->values()->all(),
            ],
            'server_time' => $this->serverTime(),
        ]);
    }

    // ── POST / ────────────────────────────────────────────────────────────

    /** HER ZAMAN `draft` DOĞAR. Yayın ayrı bir eylemdir. */
    public function store(Request $request): JsonResponse
    {
        $data = $this->validatePayload($request, creating: true);

        return $this->write(
            $request,
            'notification.create',
            ControlAudit::TARGET_NOTIFICATION,
            null,
            // GÖVDENİN TAMAMI YAZILMAZ; başlık, kitle ve uzunluk yeter.
            [
                'title' => $data['title'] ?? null,
                'audience' => $data['audience'],
                'body_length' => mb_strlen((string) $data['body']),
            ],
            static fn(): array => [
                'action' => 'notification.create',
                'title' => $data['title'] ?? null,
                'audience' => $data['audience'],
                'status' => Announcement::STATUS_DRAFT,
            ],
            function () use ($data): array {
                $row = new Announcement;

                foreach ($data as $field => $value) {
                    $row->{$field} = $value;
                }

                $row->status = Announcement::STATUS_DRAFT;
                $row->save();

                return ['data' => $this->row($row->refresh(), [])];
            },
        );
    }

    // ── PATCH /{id} ───────────────────────────────────────────────────────

    public function update(Request $request, int $notification): JsonResponse
    {
        $row = $this->find($notification);
        $data = $this->validatePayload($request, creating: false, current: $row);

        if ($data === []) {
            throw ApiException::validationFailed('Güncellenecek bir alan gönderilmedi.');
        }

        $warnings = [];

        if (array_key_exists('audience', $data)
            && (string) $data['audience'] !== (string) $row->audience
            && (string) $row->status === Announcement::STATUS_PUBLISHED
        ) {
            /*
             * KAPSAM DEĞİŞİMİ UYARI ÜRETİR. Yayınlanmış bir duyuruyu
             * düzenlemek bilinçli olarak serbest (yazım hatası düzeltmek,
             * tarihi uzatmak gerçek ihtiyaçlar) ama kitleyi değiştirmek,
             * duyuruyu görmüş bir kısım müşteriyi kapsam dışında bırakır ve
             * bu, geri alınamaz gibi görünmemeli.
             */
            $seen = $this->seenCounts([(int) $row->id])[(int) $row->id] ?? 0;

            $warnings[] = [
                'code' => 'audience_changed_after_publish',
                'from' => (string) $row->audience,
                'to' => (string) $data['audience'],
                'note' => 'Duyuruyu daha önce görmüş '.$seen
                    .' müşterinin bir kısmı artık kapsam dışında kalabilir.',
            ];
        }

        return $this->write(
            $request,
            'notification.update',
            ControlAudit::TARGET_NOTIFICATION,
            (int) $row->id,
            [
                'title' => $row->title,
                'audience' => (string) $row->audience,
                'fields' => array_keys($data),
            ],
            static fn(): array => [
                'action' => 'notification.update',
                'id' => (int) $row->id,
                'fields' => array_keys($data),
                'warnings' => $warnings,
            ],
            function () use ($row, $data, $warnings): array {
                foreach ($data as $field => $value) {
                    $row->{$field} = $value;
                }

                $row->save();

                // GÖRÜLME KAYITLARI SİLİNMEZ: kapsam değişince kimin gördüğü
                // bilgisi kaybolmamalı.
                return [
                    'data' => $this->row($row->refresh(), []),
                    'warnings' => $warnings,
                ];
            },
        );
    }

    // ── POST /{id}/publish ────────────────────────────────────────────────

    public function publish(Request $request, int $notification): JsonResponse
    {
        $row = $this->find($notification);

        // ÖN DENETİMLER KURU PROVADA DA KOŞAR: "kuru prova geçti" diyen bir
        // ekran gerçek gönderimde patlamamalı (`00-genel.md` §3.1).
        if ((string) $row->status === Announcement::STATUS_PUBLISHED) {
            throw new ApiException(
                'CONFLICT',
                'Bu duyuru zaten yayında.',
                409,
                ['conflict' => 'already_published'],
            );
        }

        if ($row->ends_at !== null && $row->ends_at->isPast()) {
            throw ApiException::validationFailed(
                'Bitiş tarihi geçmiş bir duyuru yayınlanamaz.',
                ['reason' => 'already_expired', 'ends_at' => self::ts($row->ends_at)],
            );
        }

        return $this->write(
            $request,
            'notification.publish',
            ControlAudit::TARGET_NOTIFICATION,
            (int) $row->id,
            ['title' => $row->title, 'audience' => (string) $row->audience],
            fn(): array => [
                'action' => 'notification.publish',
                'id' => (int) $row->id,
                'estimated_audience' => $this->audienceSize((string) $row->audience),
            ],
            function () use ($row): array {
                $row->status = Announcement::STATUS_PUBLISHED;
                $row->save();

                $fresh = $row->refresh();

                return [
                    'data' => [
                        'id' => (int) $fresh->id,
                        'status' => (string) $fresh->status,
                        // SÜTUN YOK — sınıf başlığındaki eşleme kutusu.
                        'published_at' => null,
                        'live' => $this->isLive($fresh),
                        /*
                         * `live_from` panelin "yayınlandı ama henüz
                         * görünmüyor" mesajını yazmasını sağlar — yayınla
                         * düğmesine basıp hiçbir şey görmeyen yönetici, aksi
                         * hâlde ikinci kez basardı.
                         */
                        'live_from' => $fresh->starts_at !== null && $fresh->starts_at->isFuture()
                            ? self::ts($fresh->starts_at)
                            : null,
                        'estimated_audience' => $this->audienceSize((string) $fresh->audience),
                    ],
                ];
            },
        );
    }

    // ── DELETE /{id} — arşivle ────────────────────────────────────────────

    /**
     * YUMUŞAK: `status = archived`, satır silinmez.
     *
     * Gerçek silme ucu yoktur: bir duyurunun kaç kişiye ulaştığı sonradan
     * sorulan bir sorudur ve kaydı silinmiş bir duyuru o soruyu cevapsız
     * bırakır.
     */
    public function destroy(Request $request, int $notification): JsonResponse
    {
        $row = $this->find($notification);

        if ((string) $row->status === Announcement::STATUS_ARCHIVED) {
            throw new ApiException(
                'CONFLICT',
                'Bu duyuru zaten arşivlenmiş.',
                409,
                ['conflict' => 'already_archived'],
            );
        }

        return $this->write(
            $request,
            'notification.archive',
            ControlAudit::TARGET_NOTIFICATION,
            (int) $row->id,
            ['title' => $row->title, 'audience' => (string) $row->audience],
            static fn(): array => [
                'action' => 'notification.archive',
                'id' => (int) $row->id,
                'status' => Announcement::STATUS_ARCHIVED,
            ],
            function () use ($row): array {
                // ARŞİVLENEN DUYURU ANINDA GÖRÜNMEZ OLUR, `ends_at`
                // beklenmez. Görülme kayıtları kalır ve `stats` çalışmaya
                // devam eder.
                $row->status = Announcement::STATUS_ARCHIVED;
                $row->save();

                return ['data' => ['id' => (int) $row->id, 'status' => Announcement::STATUS_ARCHIVED]];
            },
        );
    }

    // ── GET /{id}/stats ───────────────────────────────────────────────────

    public function stats(int $notification): JsonResponse
    {
        $row = $this->find($notification);
        $audience = (string) $row->audience;

        /*
         * `all` DUYURUSU ÖLÇÜLEMEZ: giriş yapmamış ziyaretçinin kimliği yok
         * ve okunma kaydı yazılamaz. `seen_count` SIFIR DEĞİL `null` döner —
         * sıfır "kimse görmedi" demektir, `null` "ölçülemiyor". İkisini
         * karıştırmak, çalışan bir duyuruyu başarısız gösterirdi.
         */
        $trackable = $audience !== Announcement::AUDIENCE_ALL;
        $size = $this->audienceSize($audience);

        $data = [
            'id' => (int) $row->id,
            'status' => (string) $row->status,
            'audience' => $audience,
            // `audience_size` ŞU ANKİ büyüklüktür, yayın anındaki değil:
            // müşteri sayısı artıyor ve donmuş bir payda, oranı zamanla
            // yanlış gösterirdi.
            'audience_size' => $size,
            'seen_count' => null,
            'dismissed_count' => null,
            'seen_rate' => null,
            'first_seen_at' => null,
            'last_seen_at' => null,
            'trackable' => $trackable,
            'daily' => null,
        ];

        if (!$trackable) {
            return $this->json(['data' => $data, 'server_time' => $this->serverTime()]);
        }

        $reads = AnnouncementRead::query()->where('announcement_id', $row->id);

        $seenCount = (int) $reads->clone()->whereNotNull('seen_at')->count();

        $data['seen_count'] = $seenCount;
        // `dismissed_count` yalnız `dismissible: true` duyurularda anlamlı;
        // kapatılamayan bir duyuruda sütun hep boş kalır ve sıfır döner.
        $data['dismissed_count'] = (int) $reads->clone()->whereNotNull('dismissed_at')->count();
        $data['seen_rate'] = $size > 0 ? round($seenCount / $size, 2) : null;
        $data['first_seen_at'] = self::ts($reads->clone()->min('seen_at'));
        $data['last_seen_at'] = self::ts($reads->clone()->max('seen_at'));

        $data['daily'] = $reads->clone()
            ->whereNotNull('seen_at')
            ->where('seen_at', '>=', BusinessTime::forStorage(Carbon::now()->subDays(self::MAX_DAILY_DAYS)))
            ->groupByRaw('DATE(seen_at)')
            ->selectRaw('DATE(seen_at) AS gun, COUNT(*) AS toplam')
            ->orderBy('gun')
            ->get()
            ->map(static fn(object $r): array => ['date' => (string) $r->gun, 'seen' => (int) $r->toplam])
            ->values()
            ->all();

        return $this->json(['data' => $data, 'server_time' => $this->serverTime()]);
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    private function find(int $id): Announcement
    {
        $row = Announcement::find($id);

        if ($row === null) {
            throw ApiException::notFound('Duyuru bulunamadı.');
        }

        return $row;
    }

    /**
     * Ortak doğrulama — oluşturma ve güncelleme aynı kuralları paylaşır.
     *
     * `status` YAZILAMAZ: yayın ve arşivleme kendi uçlarına sahip. Duruma
     * `PATCH` ile de dokunulabilseydi, "duyuru neden görünmüyor" sorusunun
     * iki ayrı cevabı olurdu.
     *
     * Dönen dizinin ANAHTARLARI KOLON ADLARIDIR: `level` → `severity`,
     * `action_url` → `action_value`. Eşleme tek yerde.
     *
     * @return array<string, mixed>
     */
    private function validatePayload(Request $request, bool $creating, ?Announcement $current = null): array
    {
        $required = $creating ? 'required' : 'sometimes';

        $data = $request->validate([
            // Kolon 120 karakter ve nullable; müşteri yüzü başlıksız
            // duyuruyu da çiziyor (yalnız gövde).
            'title' => ['sometimes', 'nullable', 'string', 'max:120'],
            'body' => [$required, 'string', 'min:2', 'max:1000'],
            'level' => [$required, Rule::in(Announcement::SEVERITIES)],
            'audience' => [$required, Rule::in(Announcement::AUDIENCES)],
            'placement' => ['sometimes', 'string', 'max:32'],
            'style' => ['sometimes', Rule::in(Announcement::STYLES)],
            'priority' => ['sometimes', 'integer', 'min:-1000', 'max:1000'],
            'starts_at' => ['sometimes', 'nullable', 'date'],
            'ends_at' => ['sometimes', 'nullable', 'date'],
            'action_label' => ['sometimes', 'nullable', 'string', 'max:80'],
            'action_url' => ['sometimes', 'nullable', 'string', 'max:500'],
            'dismissible' => ['sometimes', 'boolean'],
        ]);

        $out = [];

        foreach (['title', 'body', 'placement', 'style', 'priority'] as $field) {
            if (array_key_exists($field, $data)) {
                $out[$field] = $data[$field];
            }
        }

        if (array_key_exists('level', $data)) {
            $out['severity'] = $data['level'];
        }

        if (array_key_exists('audience', $data)) {
            $out['audience'] = $data['audience'];
        }

        foreach (['starts_at', 'ends_at'] as $field) {
            if (array_key_exists($field, $data)) {
                $out[$field] = $data[$field] === null
                    ? null
                    : BusinessTime::forStorage(Carbon::parse((string) $data[$field]));
            }
        }

        if (array_key_exists('action_label', $data)) {
            $label = $data['action_label'] === null ? null : trim((string) $data['action_label']);
            $out['action_label'] = ($label === '' ? null : $label);
        }

        if (array_key_exists('action_url', $data)) {
            $url = $data['action_url'] === null ? null : trim((string) $data['action_url']);
            $out['action_value'] = ($url === '' ? null : $url);
            /*
             * HEDEFİN CİNSİ SUNUCUDA TÜRETİLİR. İstemci bunu bilmeden
             * tanımadığı bir yolu tarayıcıda açar ve müşteriyi uygulamadan
             * çıkarır; panelden ayrıca sormak ise yöneticiye anlamsız bir
             * seçim yaptırırdı — cinsi adresin kendisi zaten söylüyor.
             */
            $out['action_type'] = $out['action_value'] === null
                ? null
                : (str_starts_with($out['action_value'], '/') ? 'route' : 'url');
        }

        if (array_key_exists('dismissible', $data)) {
            $out['dismissible'] = (bool) $data['dismissible'];
        }

        if ($creating) {
            // İSTEĞE BAĞLI ALANLARIN VARSAYILANLARI BURADA, doğrulayıcıda
            // değil: kısmi güncelleme yalnız gönderilen alanları döndürmeyi
            // gerektiriyor ve oluşturmada eksik anahtar sessiz bir `null`
            // olurdu.
            $out += [
                'title' => null,
                'placement' => 'home',
                'style' => Announcement::STYLE_BANNER,
                'priority' => 0,
                'starts_at' => null,
                'ends_at' => null,
                'action_label' => null,
                'action_value' => null,
                'action_type' => null,
                'dismissible' => true,
            ];
        }

        $this->assertConsistent($out, $current);

        return $out;
    }

    /**
     * Alanlar arası kurallar — tek tek geçerli değerler birlikte geçersiz
     * olabilir.
     *
     * @param  array<string, mixed>  $data
     */
    private function assertConsistent(array $data, ?Announcement $current): void
    {
        $starts = array_key_exists('starts_at', $data) ? $data['starts_at'] : $current?->starts_at;
        $ends = array_key_exists('ends_at', $data) ? $data['ends_at'] : $current?->ends_at;

        if ($starts instanceof Carbon && $ends instanceof Carbon && $ends->lessThanOrEqualTo($starts)) {
            throw ApiException::validationFailed(
                'Bitiş anı başlangıçtan sonra olmalı.',
                ['field' => 'ends_at'],
            );
        }

        if ($ends instanceof Carbon && $ends->isPast()) {
            // DOĞDUĞU ANDA BİTMİŞ BİR DUYURU, yöneticinin fark etmediği bir
            // hatadır; sessizce kaydetmek onu hiç görünmeyen bir kayda
            // çevirir.
            throw ApiException::validationFailed(
                'Bitiş anı geçmişte olamaz.',
                ['field' => 'ends_at'],
            );
        }

        $label = array_key_exists('action_label', $data) ? $data['action_label'] : $current?->action_label;
        $url = array_key_exists('action_value', $data) ? $data['action_value'] : $current?->action_value;

        // ETİKETSİZ BİR DÜĞME ÇİZİLEMEZ, ADRESSİZ BİR ETİKET TIKLANAMAZ.
        if (($label === null) !== ($url === null)) {
            throw ApiException::validationFailed(
                'Düğme etiketi ve adresi birlikte verilmeli.',
                ['field' => $url === null ? 'action_url' : 'action_label'],
            );
        }

        if (is_string($url) && !$this->isSafeUrl($url)) {
            throw ApiException::validationFailed(
                'Düğme adresi https:// ile ya da / ile başlamalı.',
                ['field' => 'action_url'],
            );
        }

        $dismissible = array_key_exists('dismissible', $data)
            ? $data['dismissible']
            : (bool) ($current?->dismissible ?? true);

        $severity = array_key_exists('severity', $data)
            ? (string) $data['severity']
            : (string) ($current?->severity ?? Announcement::SEVERITY_INFO);

        // KAPATILAMAYAN BİR BİLGİLENDİRME, uygulamayı kullanılamaz hâle
        // getirir. Yalnız `critical` bunu hak eder.
        if ($dismissible === false && $severity !== Announcement::SEVERITY_CRITICAL) {
            throw ApiException::validationFailed(
                'Kapatılamayan duyuru yalnız kritik seviyede olabilir.',
                ['field' => 'dismissible'],
            );
        }
    }

    /**
     * `https://` ya da uygulama-içi göreli yol.
     *
     * `http://`, `javascript:` ve `data:` reddedilir: duyuru üç istemcide
     * birden açılıyor ve güvenilmeyen bir şema en az birinde
     * çalıştırılabilir olurdu.
     */
    private function isSafeUrl(string $url): bool
    {
        if (str_starts_with($url, 'https://')) {
            return true;
        }

        // `//ornek.com` protokole duyarsız bir DIŞ adrestir, göreli yol
        // değil; tek `/` ile başlayan yollar uygulamanın kendi içidir.
        return str_starts_with($url, '/') && !str_starts_with($url, '//');
    }

    /**
     * @param  list<int>  $ids
     * @return array<int, int>
     */
    private function seenCounts(array $ids): array
    {
        if ($ids === []) {
            return [];
        }

        return AnnouncementRead::query()
            ->whereIn('announcement_id', $ids)
            ->whereNotNull('seen_at')
            ->groupBy('announcement_id')
            ->selectRaw('announcement_id, COUNT(*) AS toplam')
            ->pluck('toplam', 'announcement_id')
            ->map(intval(...))
            ->all();
    }

    /**
     * Kitle büyüklüğü — ŞU ANKİ değer.
     *
     * `all` için giriş yapmamış ziyaretçi sayılamaz; en yakın ölçülebilir
     * sayı olan aktif müşteri sayısı dönüyor ve `trackable: false` panele
     * bunun bir alt sınır olduğunu söylüyor.
     */
    private function audienceSize(string $audience): int
    {
        $subscriberIds = static function (\Illuminate\Database\Query\Builder $query): void {
            $query->select('customer_id')
                ->from('veykemtu_subscriptions')
                ->where('status', Subscription::STATUS_ACTIVE);
        };

        $query = DB::table('customers')->where('status', 1);

        if ($audience === Announcement::AUDIENCE_SUBSCRIBERS) {
            $query->whereIn('customer_id', $subscriberIds);
        } elseif ($audience === Announcement::AUDIENCE_NON_SUBSCRIBERS) {
            $query->whereNotIn('customer_id', $subscriberIds);
        }

        return (int) $query->count();
    }

    private function liveCount(): int
    {
        $query = Announcement::query();
        $this->applyLiveFilter($query, true);

        return (int) $query->count();
    }

    /**
     * `live` süzgeci — sunucuda hesaplanır.
     *
     * İstemcide hesaplansaydı saati kaymış bir panelde duyuru bir gün erken
     * "bitmiş" görünürdü. Karşılaştırma `BusinessTime::forStorage()` ile:
     * `datetime` kolonları PHP'nin yerel diliminde okunuyor ve çıplak
     * `Carbon::now()` (UTC) üç saat kaydırırdı.
     *
     * @param  Builder<Announcement>  $query
     */
    private function applyLiveFilter(Builder $query, bool $live): void
    {
        $now = BusinessTime::forStorage(Carbon::now());

        if ($live) {
            $query->where('status', Announcement::STATUS_PUBLISHED)
                ->where(fn(Builder $q) => $q->whereNull('starts_at')->orWhere('starts_at', '<=', $now))
                ->where(fn(Builder $q) => $q->whereNull('ends_at')->orWhere('ends_at', '>=', $now));

            return;
        }

        $query->where(function (Builder $q) use ($now): void {
            $q->where('status', '!=', Announcement::STATUS_PUBLISHED)
                ->orWhere('starts_at', '>', $now)
                ->orWhere('ends_at', '<', $now);
        });
    }

    private function isLive(Announcement $row): bool
    {
        if ((string) $row->status !== Announcement::STATUS_PUBLISHED) {
            return false;
        }

        $now = BusinessTime::forStorage(Carbon::now());

        if ($row->starts_at !== null && $row->starts_at->greaterThan($now)) {
            return false;
        }

        return !($row->ends_at !== null && $row->ends_at->lessThan($now));
    }

    /**
     * @param  array<int, int>  $seen
     * @return array<string, mixed>
     */
    private function row(Announcement $row, array $seen): array
    {
        $id = (int) $row->id;

        return [
            'id' => $id,
            'title' => $row->title,
            'body' => (string) $row->body,
            // Sözleşmedeki `level`; müşteri yüzü de `severity` diyor ve iki
            // ad tek kolonu gösteriyor.
            'level' => (string) $row->severity,
            'severity' => (string) $row->severity,
            'audience' => (string) $row->audience,
            'status' => (string) $row->status,
            'placement' => (string) $row->placement,
            'style' => (string) $row->style,
            'priority' => (int) $row->priority,
            'starts_at' => self::ts($row->starts_at),
            'ends_at' => self::ts($row->ends_at),
            'action_label' => $row->action_label,
            'action_type' => $row->action_type,
            'action_url' => $row->action_value,
            'dismissible' => (bool) $row->dismissible,
            // SÜTUN YOK — sınıf başlığındaki eşleme kutusu.
            'published_at' => null,
            'live' => $this->isLive($row),
            // `all` duyurusu istatistik üretmez; ayrımı `stats` ucundaki
            // `trackable` taşıyor.
            'seen_count' => (string) $row->audience === Announcement::AUDIENCE_ALL ? 0 : ($seen[$id] ?? 0),
            'created_at' => self::ts($row->created_at),
            'updated_at' => self::ts($row->updated_at),
        ];
    }
}
