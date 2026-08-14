<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Control;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Veykemtu\BridgeApi\Models\PrintJob;
use Veykemtu\BridgeApi\Services\OrderPresenter;

/**
 * Kontrol Merkezi — fiş denetim kaydı (`/api/control/kds/print-jobs`).
 *
 * BU BİR KUYRUK DEĞİLDİR. `veykemtu_print_jobs` yalnızca **denetim**
 * tablosudur: hangi fiş, hangi kasada, ne zaman basıldı. KDS'in kendi
 * kalıcı kuyruğu KASANIN DİSKİNDEDİR ve sunucuda karşılığı yoktur —
 * buradan bir işi silmek ya da yeniden sıraya almak mümkün değil, çünkü
 * silinecek bir sıra yok.
 *
 * "Kaç iş bekliyor / kaçı başarısız" sorusunun cevabı cihaz sağlığından
 * okunur (`device.health.print_queue_pending` / `print_queue_failed`) ve
 * o değerleri kasa BEYAN eder; sunucu doğrulayamaz.
 *
 * Bir işi yeniden bastırmanın tek yolu `reprint` komutudur
 * (`POST /devices/{id}/commands`).
 */
class PrintJobController extends ControlController
{
    public function __construct(private readonly OrderPresenter $presenter) {}

    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'device_id' => ['sometimes', 'integer', 'min:1'],
            'order_id' => ['sometimes', 'integer', 'min:1'],
            // Tavan 200: denetim ekranı sayfalıyor ve sınırsız bir liste
            // yıl sonunda on binlerce satır döndürürdü.
            'limit' => ['sometimes', 'integer', 'min:1', 'max:200'],
        ]);

        $jobs = PrintJob::query()
            // İkisi de N+1'i kesiyor: liste 200 satıra kadar çıkabiliyor.
            ->with(['order', 'device'])
            ->when(
                isset($data['device_id']),
                fn($query) => $query->where('device_id', (int) $data['device_id']),
            )
            ->when(
                isset($data['order_id']),
                fn($query) => $query->where('order_id', (int) $data['order_id']),
            )
            // EN YENİ ÖNCE: denetim sorusu neredeyse her zaman "az önce ne
            // basıldı" biçiminde geliyor.
            ->orderByDesc('id')
            ->limit((int) ($data['limit'] ?? 50))
            ->get();

        return $this->json([
            'data' => $jobs
                ->map(fn(PrintJob $job): array => [
                    'id' => (int) $job->id,
                    'order_id' => (int) $job->order_id,
                    // Sipariş silinmiş olabilir (`veykemtu:siparis-temizle`);
                    // denetim satırı yerinde kalır, numara boşalır.
                    'order_number' => $job->order !== null
                        ? $this->presenter->number($job->order)
                        : null,
                    'type' => (string) $job->type,
                    // K-20 öncesi satırlarda `0`: düzenlenmemiş siparişin
                    // ilk basımı.
                    'revision' => (int) $job->revision,
                    'printed_at' => self::ts($job->printed_at),
                    'device_id' => $job->device_id !== null ? (int) $job->device_id : null,
                    'device_name' => $job->device?->name,
                ])
                ->all(),
            'server_time' => $this->serverTime(),
        ]);
    }
}
