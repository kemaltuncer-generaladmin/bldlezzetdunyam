<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Order;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\KitchenDevice;

/**
 * Mutfak testlerinin ortak tabanı.
 *
 * NEDEN AYRI TABAN SINIF: `ContractTest` 1300 satır ve yardımcıları
 * (`asKitchen`, `menuId`, `advance`) `private`. K-12 ile gelen sipariş
 * düzenleme testleri aynı kuruluma ihtiyaç duyuyor; kopyalamak yerine
 * paylaşılan taban çıkarıldı. `ContractTest` kendi kopyalarını korumaya
 * devam ediyor — o dosyaya dokunmamak, 100 testlik bir paketi riske
 * atmamak demek.
 */
abstract class KitchenTestCase extends TestCase
{
    use RefreshDatabase {
        refreshTestDatabase as private laravelRefreshTestDatabase;
    }

    protected const array HEADERS = [
        'X-App-Id' => 'website',
        'X-App-Version' => '1.0.0',
        'Accept' => 'application/json',
    ];

    /**
     * `migrate:fresh` TastyIgniter tablolarını KURMAZ; `igniter:up` şart.
     *
     * Gerekçe `ContractTest` içinde ayrıntılı yazılı.
     */
    protected function refreshTestDatabase(): void
    {
        $name = (string) DB::connection()->getDatabaseName();

        if (!str_ends_with($name, '_test')) {
            $this->fail(
                "Testler '{$name}' veritabanına bağlı ve bir sonraki adım "
                .'tüm tabloları düşürecekti. Test veritabanı adı "_test" ile '
                .'bitmelidir.',
            );
        }

        $this->laravelRefreshTestDatabase();
        $this->artisan('igniter:up');
    }

    protected function setUp(): void
    {
        parent::setUp();

        $this->artisan('veykemtu:setup');
        $this->artisan('veykemtu:demo-menu');
    }

    protected function locationId(): int
    {
        return (int) $this->getJson('/api/locations', self::HEADERS)->json('data.0.id');
    }

    protected function menuId(string $name): int
    {
        $items = collect($this->getJson('/api/locations/'.$this->locationId().'/menu', self::HEADERS)
            ->json('data'))->flatMap(static fn(array $c): array => $c['items']);

        return (int) $items->firstWhere('name', $name)['id'];
    }

    protected function asCustomer(): static
    {
        if (ApiCustomer::where('email', 'test@ornek.com')->doesntExist()) {
            $this->postJson('/api/auth/register', $this->registerPayload(), self::HEADERS);
        }

        $token = $this->postJson('/api/auth/login', [
            'email' => 'test@ornek.com', 'password' => 'parola123',
        ], self::HEADERS)->json('token');

        return $this->withToken($token);
    }

    protected function pairedDevice(): array
    {
        $device = new KitchenDevice;
        $device->name = 'Test Kasası';
        $device->save();
        $code = $device->refreshPairingCode();

        $token = $this->postJson('/api/kitchen/pair', [
            'pairing_code' => $code,
            'device_name' => 'Test Kasası',
        ], self::HEADERS)->json('token');

        return ['token' => $token, 'model' => $device->refresh()];
    }

    protected function asKitchen(): static
    {
        return $this->withToken($this->pairedDevice()['token']);
    }

    protected function advance(int $orderId, array $statuses): void
    {
        foreach ($statuses as $status) {
            $this->asKitchen()->postJson(
                '/api/kitchen/orders/'.$orderId.'/status',
                ['status' => $status],
                self::HEADERS,
            )->assertOk();
        }

        $this->assertNotNull(Order::find($orderId));
    }
}
