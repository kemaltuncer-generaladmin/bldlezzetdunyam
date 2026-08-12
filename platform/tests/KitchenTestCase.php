<?php

declare(strict_types=1);

namespace Tests;

use Igniter\Cart\Models\Order;
use Illuminate\Contracts\Console\Kernel as ConsoleKernel;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\RefreshDatabaseState;
use Illuminate\Support\Facades\DB;
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
 *
 * NEDEN `platform/tests/` ALTINDA, eklentinin yanında DEĞİL: PHPUnit
 * paketi eklentilerin `tests` dizinlerini `suffix="Test.php"` ile
 * tarıyor; `KitchenTestCase.php` o desene uymadığı için toplanmıyor ve
 * eklenti test dizini composer autoload haritasında olmadığı için
 * **sınıf hiç yüklenmiyordu** (sunucuda "Class not found" ile patladı).
 * `tests/` dizini `Tests\` ad alanıyla autoload-dev'de kayıtlı.
 */
abstract class KitchenTestCase extends TestCase
{
    use RefreshDatabase;

    protected const array HEADERS = [
        'X-App-Id' => 'website',
        'X-App-Version' => '1.0.0',
        'Accept' => 'application/json',
    ];

    /**
     * Şema kurulumu: `migrate:fresh` + `igniter:up`, İŞLEM AÇILMADAN ÖNCE.
     *
     * `migrate:fresh` TastyIgniter'ın tablolarını KURMAZ; çekirdek göçler
     * eklenti sisteminden gelir ve yalnızca `igniter:up` ile koşar.
     *
     * NEDEN LARAVEL'İN METODUNU ÇAĞIRMIYORUZ: o metot şemayı kurduktan
     * sonra **işlemi de başlatıyor** (`beginDatabaseTransaction`). Önceki
     * hâlde `igniter:up` o çağrıdan SONRA koşuyordu, yani açık bir işlemin
     * içinde DDL çalışıyordu. MySQL'de DDL **örtük commit** yapar:
     * savepoint yok olur, `DB::transaction()` kullanan her uç
     * `SAVEPOINT trans2 does not exist` ile 500 döner ve testler arası
     * geri alma çalışmaz — demo menü her testte üstüne yüklenirdi.
     * Sahada 25 testi tek başına düşürüyordu (12.08.2026).
     *
     * Şema yenilemesi koşum başına bir kez; sonrası işlemle geri alınır.
     */
    protected function refreshTestDatabase(): void
    {
        $this->assertTestDatabase();

        if (!RefreshDatabaseState::$migrated) {
            $this->artisan('migrate:fresh', [
                '--drop-views' => $this->shouldDropViews(),
                '--drop-types' => $this->shouldDropTypes(),
            ]);

            $this->app[ConsoleKernel::class]->setArtisan(null);

            $this->artisan('igniter:up');

            RefreshDatabaseState::$migrated = true;
        }

        $this->beginDatabaseTransaction();
    }

    /**
     * Test veritabanına bağlı olduğumuzu ŞEMA DÜŞÜRÜLMEDEN ÖNCE doğrular.
     *
     * Bir sonraki satır `migrate:fresh` koşuyor, yani bağlı olduğu
     * veritabanının bütün tablolarını düşürüyor. Yanlış veritabanına
     * bağlıysak veri gider ve bunu ancak sonradan fark ederiz.
     */
    private function assertTestDatabase(): void
    {
        $name = (string) DB::connection()->getDatabaseName();

        if (!str_ends_with($name, '_test')) {
            $this->fail(
                "Testler '{$name}' veritabanına bağlı ve bir sonraki adım "
                .'tüm tabloları düşürecekti. Test veritabanı adı "_test" ile '
                .'bitmelidir.',
            );
        }
    }

    protected function setUp(): void
    {
        parent::setUp();

        $this->artisan('veykemtu:setup');
        $this->artisan('veykemtu:demo-menu');
    }

    /**
     * Kayıt gövdesi — `asCustomer()` bunu kullanıyor.
     *
     * TABANI ÇIKARIRKEN UNUTULDU ve `asCustomer()` çağıran 13 testin
     * tamamı "undefined method" ile düştü. `ContractTest`'teki kopyası
     * `private` olduğu için miras da çözmüyordu.
     */
    protected function registerPayload(array $overrides = []): array
    {
        return array_merge([
            'first_name' => 'Test',
            'last_name' => 'Müşteri',
            'email' => 'test@ornek.com',
            'telephone' => '5551234567',
            'password' => 'parola123',
            'kvkk_accepted' => true,
        ], $overrides);
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
