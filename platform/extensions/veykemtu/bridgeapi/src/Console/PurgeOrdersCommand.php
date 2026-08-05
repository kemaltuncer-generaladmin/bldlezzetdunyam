<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Console;

use Igniter\Cart\Models\Order;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Models\PrintJob;

/**
 * Sipariş verisini siler — deneme sonrası temizlik.
 *
 * NEDEN KOMUT, NEDEN ELLE SQL DEĞİL:
 * Bir siparişin arkasında altı tablo var (`order_menus`,
 * `order_menu_options`, `order_totals`, `status_history`, `payment_logs`,
 * `veykemtu_print_jobs`). Elle yazılan bir `DELETE FROM orders`, bunları
 * öksüz bırakır; öksüz `order_menus` satırları rapor sorgularında
 * silinmiş siparişleri saymaya devam eder ve sebebi aylar sonra bulunur.
 *
 * NEDEN MENÜ VE VİTRİN SİLİNMEZ: bunlar sipariş verisi değil, işletme
 * yapılandırması. `veykemtu:setup` ile kurulmuş durumlar, vitrin ve
 * ödeme yöntemleri yerinde kalır — yoksa temizlikten sonra sipariş
 * verilemez hâle gelir.
 *
 *   php artisan veykemtu:siparis-temizle           # ne silineceğini sayar
 *   php artisan veykemtu:siparis-temizle --onayla  # siler
 *   php artisan veykemtu:siparis-temizle --onayla --musteriler
 */
class PurgeOrdersCommand extends Command
{
    protected $signature = 'veykemtu:siparis-temizle
        {--onayla : Gerçekten sil. Verilmezse yalnızca sayar.}
        {--musteriler : Müşteri kayıtlarını da sil.}';

    protected $description = 'Sipariş verisini siler (deneme sonrası temizlik). Menü ve vitrin korunur.';

    /**
     * Silinecek tablolar, **yabancı anahtar sırasına göre**.
     *
     * Çocuklar önce: ters sırada silmek, `orders` gittikten sonra
     * kalanları hangi siparişe ait olduklarını bilmeden bırakırdı.
     */
    private const array ORDER_TABLES = [
        'veykemtu_print_jobs',
        'payment_logs',
        'order_menu_options',
        'order_menus',
        'order_totals',
    ];

    public function handle(): int
    {
        $counts = $this->counts();

        $this->table(['Tablo', 'Satır'], collect($counts)
            ->map(static fn(int $n, string $t): array => [$t, $n])
            ->values()
            ->all());

        if ($counts['orders'] === 0 && $counts['customers'] === 0) {
            $this->info('Silinecek bir şey yok.');

            return self::SUCCESS;
        }

        if (!$this->option('onayla')) {
            $this->warn('Hiçbir şey silinmedi. Silmek için --onayla ekleyin.');

            return self::SUCCESS;
        }

        $this->purge();

        $this->info('Sipariş verisi silindi. Menü, vitrin, durumlar ve mutfak cihazları korundu.');

        return self::SUCCESS;
    }

    /** @return array<string, int> */
    private function counts(): array
    {
        $counts = ['orders' => Order::query()->count()];

        foreach (self::ORDER_TABLES as $table) {
            $counts[$table] = DB::table($table)->count();
        }

        $counts['status_history'] = DB::table('status_history')
            ->where('object_type', 'like', '%Order%')
            ->count();

        $counts['customers'] = $this->option('musteriler')
            ? DB::table('customers')->count()
            : 0;

        return $counts;
    }

    private function purge(): void
    {
        DB::transaction(function (): void {
            foreach (self::ORDER_TABLES as $table) {
                DB::table($table)->delete();
            }

            // Yalnızca SİPARİŞ geçmişi. `status_history` çok biçimli bir
            // tablo; koşulsuz silmek rezervasyon geçmişini de götürürdü.
            DB::table('status_history')->where('object_type', 'like', '%Order%')->delete();

            DB::table('orders')->delete();

            if ($this->option('musteriler')) {
                // Adres defteri müşteriye bağlı; müşteri gidiyorsa
                // adresleri de gitmeli, yoksa sahipsiz satır kalır.
                DB::table('addresses')->delete();
                DB::table('customers')->delete();
            }
        });

        // Sipariş yoksa basılacak fiş de yok. Kuyruk kaydını bırakmak,
        // kasanın olmayan siparişlerin fişini basmaya çalışması demekti.
        PrintJob::query()->delete();
    }
}
