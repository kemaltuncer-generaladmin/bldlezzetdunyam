<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Control;

use Igniter\Cart\Models\Menu;
use Illuminate\Http\JsonResponse;
use Veykemtu\BridgeApi\Services\MenuAvailability;
use Veykemtu\BridgeApi\Support\Money;

/**
 * Kontrol Merkezi — sipariş düzenlemenin ürün seçicisi
 * (`GET /api/control/kds/menu`).
 *
 * NEDEN VAR: revizyon ucu `menu_id` istiyor ve o sayı kimsenin ezberinde
 * değil. Seçici olmadan Kontrol Merkezi'ndeki kullanıcı kimliği elle
 * yazmak zorunda kalıyor; yanlış yazılan bir kimlik siparişe başka bir
 * ürün koyar ve bunu ancak mutfak, tabağı hazırlarken fark eder.
 *
 * HANGİ ÜRÜNLERİN LİSTELENECEĞİ KARARI `MenuAvailability`'DE.
 * `kitchenCatalog()` günün menüsü rejiminde listeyi bugüne daraltıyor,
 * tükenme işaretlerini okuyor ve yöneticinin kalıcı kararını (`listed`)
 * ayrı taşıyor. Bu kararlar burada tekrar yazılsaydı, "günün menüsü"
 * rejimi değiştiği gün iki liste iki ayrı şey gösterirdi.
 *
 * FİYAT VE SEÇENEKLER BURADA VAR, `/api/kitchen/menu`'DE YOK — ve bu
 * bilinçli. ADR-08 **mutfak kapsamını** para görmekten men ediyor; kasa
 * ekranı gün boyu mutfakta açık duruyor ve fiyat orada yalnız sızıntı
 * riski. Kontrol Merkezi ise bir yönetim yüzeyi: revizyonun iade mi ek
 * tahsilat mı üreteceğini gönderMEDEN önce görebilmek gerekiyor.
 * Seçenekler ise zorunlu: `LineResolver` satırı `option_value_ids` ile
 * fiyatlıyor ve kimlikler gönderilmezse seçenekli bir ürün seçeneksiz
 * yeniden fiyatlanır.
 */
class MenuController extends ControlController
{
    public function __construct(private readonly MenuAvailability $availability) {}

    public function index(): JsonResponse
    {
        // `/api/kitchen/menu` ile aynı süzgeç: seçici yalnız EKLENEBİLİR
        // ürünleri göstermeli. Satıştan kaldırılmış bir ürünü seçtirmek,
        // düzenlemeyi kaydetme anında hataya çevirirdi.
        $catalog = array_values(array_filter(
            $this->availability->kitchenCatalog(),
            static fn(array $item): bool => $item['listed'] === true,
        ));

        $ids = array_map(static fn(array $item): int => $item['menu_id'], $catalog);

        /*
         * Bağıntı adları kurulu sürümden doğrulandı (B-02):
         * `MenuItemOption`'ın değerleri `menu_option_values`'tır,
         * `option_values` değil. Tek `with()` ile çekiliyor; kalem başına
         * sorgu, seksen ürünlük katalogda yüzlerce sorgu demekti.
         */
        $menus = Menu::query()
            ->with(['menu_options.menu_option_values.option_value'])
            ->whereIn('menu_id', $ids)
            ->get()
            ->keyBy('menu_id');

        $data = [];

        foreach ($catalog as $item) {
            /** @var Menu|null $menu */
            $menu = $menus->get($item['menu_id']);

            if ($menu === null) {
                continue;
            }

            $data[] = [
                'menu_id' => $item['menu_id'],
                'name' => $item['name'],
                // `Support\Money` kuruş ↔ TL arasındaki TEK geçit; dönüşümü
                // burada elle yapmak, bir yerde `round` unutulduğunda
                // toplamların kalemleri tutmamasıyla biterdi.
                'price_kurus' => Money::toKurus($menu->menu_price),
                // Bugünlük tükenmiş ürün listede KALIR ama işaretli:
                // gizlemek, "ürün nerede" sorusunu doğururdu; işaretsiz
                // bırakmak ise mutfağın bugün yapamayacağı bir kalemi
                // siparişe koydururdu.
                'sold_out' => $item['sold_out'],
                'options' => $this->options($menu),
            ];
        }

        return $this->json([
            'data' => $data,
            'server_time' => $this->serverTime(),
        ]);
    }

    /**
     * Ürün seçenekleri — değer kimlikleri DÂHİL.
     *
     * `values[].id` = `menu_option_value_id`, yani revizyon gövdesindeki
     * `items[].option_value_ids` alanına doğrudan konabilecek kimlik
     * (`LineResolver::resolve`). Yalnız adı döndürmek, seçeneğin
     * kaydedilirken sessizce düşmesine yol açardı.
     *
     * @return list<array<string, mixed>>
     */
    private function options(Menu $menu): array
    {
        $options = [];

        foreach ($menu->menu_options as $menuOption) {
            $option = $menuOption->option;

            if ($option === null) {
                continue;
            }

            $values = [];

            foreach ($menuOption->menu_option_values as $menuOptionValue) {
                $values[] = [
                    'id' => (int) $menuOptionValue->menu_option_value_id,
                    'name' => (string) ($menuOptionValue->option_value->value ?? ''),
                    'price_delta_kurus' => Money::toKurus($menuOptionValue->price ?? 0),
                ];
            }

            $options[] = [
                'id' => (int) $menuOption->menu_option_id,
                'name' => (string) $option->option_name,
                'type' => (string) $option->display_type,
                'required' => (bool) $menuOption->is_required,
                'values' => $values,
            ];
        }

        return $options;
    }
}
