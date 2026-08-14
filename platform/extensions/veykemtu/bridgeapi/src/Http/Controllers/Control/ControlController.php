<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Control;

use Closure;
use Igniter\Admin\Models\Status;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Throwable;
use Veykemtu\BridgeApi\Http\Controllers\ApiController;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;

/**
 * Kontrol Merkezi uçlarının ortak tabanı — K-21.
 *
 * NEDEN AYRI BİR UÇ AİLESİ VAR: mutfak uçları (`/api/kitchen/*`) bir
 * KASANIN token'ıyla korunuyor ve her istek o kasanın `last_seen_at`'ini
 * tazeliyor. Kontrol Merkezi oraya eşleşerek girseydi, panelde açık duran
 * bir ekran mutfakta olmayan bir kasayı "çevrimiçi" gösterirdi. Kimlik
 * doğrulama gerekçesinin tamamı `Http\Middleware\VerifyControlSignature`
 * sınıf yorumundadır.
 *
 * BU SINIF İŞ MANTIĞI TAŞIMAZ. Revizyon `OrderEditor`'da, durum geçişi
 * `OrderStatusTransition`'da, ayarlar `KitchenDeviceSettings`'te, eşleme
 * ve iptal `KitchenDevice`'ta kalır. Buradaki tek katman "gerekçe iste,
 * denetime yaz, kuru provada yazma" kabuğudur.
 */
abstract class ControlController extends ApiController
{
    /**
     * Gerekçenin en kısa hâli.
     *
     * On karakter bir cümlenin başlangıcını zorlar. Sınır olmasaydı "ok"
     * yazıp geçmek serbest olurdu ve denetim izi, doldurulmuş ama hiçbir
     * şey anlatmayan bir sütuna dönerdi.
     */
    public const int REASON_MIN = 10;

    /** Denetim tablosundaki `reason` sütununun boyu. */
    public const int REASON_MAX = 500;

    /**
     * Yazma isteğinin ortak kabuğu.
     *
     * SIRALAMA ÖNEMLİ ve tek yerde duruyor:
     *   1. `actor` + `reason` doğrulanır (yoksa 422, denetim satırı YOK —
     *      geçerli bir istek hiç oluşmadı),
     *   2. denetim satırı İŞLEMDEN ÖNCE açılır,
     *   3. kuru provada `$apply` HİÇ ÇAĞRILMAZ,
     *   4. hata çıkarsa satır `failed` işaretlenir ve istisna yukarı gider.
     *
     * DENETİM SATIRI NEDEN ÖNCE AÇILIYOR: sonra açılsaydı, yarıda kalan
     * bir yazma (veritabanı hatası, zaman aşımı) hiçbir iz bırakmazdı —
     * oysa "denendi ve olmadı" tam da soruşturulması gereken hâldir.
     *
     * @param  array<string, mixed>  $payload  denetime yazılacak istek özeti
     * @param  Closure(array{actor:string, reason:string, dry_run:bool}): array<string, mixed>  $would
     * @param  Closure(array{actor:string, reason:string, dry_run:bool}): array<string, mixed>  $apply
     */
    protected function write(
        Request $request,
        string $action,
        ?string $targetType,
        ?int $targetId,
        array $payload,
        Closure $would,
        Closure $apply,
    ): JsonResponse {
        $intent = $this->intent($request);
        $dryRun = $intent['dry_run'];

        $audit = ControlAudit::record(
            $intent['actor'],
            $action,
            $targetType,
            $targetId,
            $intent['reason'],
            $payload,
            $dryRun ? ControlAudit::RESULT_DRY_RUN : ControlAudit::RESULT_PENDING,
        );

        try {
            $body = $dryRun ? ['would' => $would($intent)] : $apply($intent);
        } catch (Throwable $e) {
            $audit->markFailed($e->getMessage());

            throw $e;
        }

        if (!$dryRun) {
            $audit->markApplied();
        }

        return $this->json([
            'ok' => true,
            'dry_run' => $dryRun,
            'audit_id' => (int) $audit->id,
            ...$body,
        ]);
    }

    /**
     * Her yazma isteğinin taşımak zorunda olduğu üç alan.
     *
     * `actor` BLD'de bir hesaba bağlanmıyor ve bağlanmayacak: Kontrol
     * Merkezi ayrı bir depo, ayrı bir kullanıcı tablosu. Serbest metin,
     * iki sistemi birbirine bağlamadan "kim yaptı" sorusuna cevap verir.
     * Doğruluğu Kontrol Merkezi'nin sorumluluğundadır ve imza zaten
     * isteğin oradan geldiğini kanıtlıyor.
     *
     * @return array{actor:string, reason:string, dry_run:bool}
     */
    protected function intent(Request $request): array
    {
        $data = $request->validate([
            'actor' => ['required', 'string', 'min:2', 'max:120'],
            'reason' => ['required', 'string', 'min:'.self::REASON_MIN, 'max:'.self::REASON_MAX],
            'dry_run' => ['sometimes', 'boolean'],
        ]);

        return [
            'actor' => trim((string) $data['actor']),
            'reason' => trim((string) $data['reason']),
            // `boolean()` sorgu dizesindeki `"true"` metnini de doğru okur;
            // Kontrol Merkezi geçidinde varsayılan AÇIK olduğu için bu
            // alan çoğu istekte dolu gelecek.
            'dry_run' => $request->boolean('dry_run'),
        ];
    }

    /**
     * Revizyon ve durum uçlarında gerekçenin ek üst sınırı.
     *
     * `veykemtu_order_revisions.reason` 160 karakterlik bir sütun ve aynı
     * metin oraya da yazılıyor. Kabuğun 500'lük sınırı burada 160'a
     * daralıyor; taşan gerekçe sessizce kırpılmak yerine 422 alıyor.
     *
     * @return list<string>
     */
    protected function orderReasonRules(): array
    {
        return ['required', 'string', 'min:'.self::REASON_MIN, 'max:160'];
    }

    /**
     * `created_by_staff` yerine geçen aktör etiketi.
     *
     * Sözleşme (§2.5) revizyonun "Kontrol Merkezi · <actor>" ile
     * damgalanmasını istiyor; `veykemtu_order_revisions.created_by_staff`
     * ise `unsignedBigInteger` (bir yönetici kimliği) ve `OrderEditor`
     * onu `?int` olarak alıyor. Metni oraya yazmak sütun tipini
     * değiştirmeyi gerektirirdi — yayınlanmış bir şemayı kırmak
     * (`AGENTS.md` §2.3) ve K-21'in dışına çıkmak olurdu.
     *
     * Bu yüzden etiket revizyonun `note` alanına yazılıyor: `note` zaten
     * revizyon belgesinin serbest metin tarafı ve müşteriye
     * gösterilmiyor. `created_by_device_id` de NULL kalıyor, yani
     * "kasadan mı merkezden mi" ayrımı hem cihaz kimliğinden hem
     * etiketten okunabiliyor. Tam ayrım için sütun tipinin
     * değiştirilmesi gerekir ve bu rapora düşülmüştür.
     */
    protected function actorLabel(string $actor): string
    {
        return 'Kontrol Merkezi · '.$actor;
    }

    /**
     * Terminal durumların kimlikleri — mutfak panosuyla aynı tanım.
     *
     * `KitchenController::terminalStatusIds()` ile aynı sorgu; o metot
     * `private` ve o denetleyici K-21 kapsamının dışında. Tanım
     * `OrderStatusTransition` sabitlerinden okunuyor, elle yazılmış bir
     * kimlik listesinden değil — iki kopya da aynı kaynağa bakıyor.
     *
     * @return list<int>
     */
    protected function terminalStatusIds(): array
    {
        return Status::query()
            ->whereIn('status_code', [
                OrderStatusTransition::DELIVERED,
                OrderStatusTransition::CANCELLED,
            ])
            ->pluck('status_id')
            ->map(intval(...))
            ->all();
    }

    protected function serverTime(): string
    {
        return Carbon::now()->utc()->toIso8601ZuluString();
    }
}
