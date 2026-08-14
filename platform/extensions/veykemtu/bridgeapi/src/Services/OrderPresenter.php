<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Igniter\Cart\Models\Order;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Support\Money;

/**
 * Sipariş nesnelerini sözleşme biçimine çevirir — `docs/openapi.yaml`.
 *
 * NEDEN AYRI SINIF: aynı sipariş DÖRT farklı yüzde farklı görünür —
 * müşteri (fiyatlı, adresli), mutfak (fiyatsız, adressiz), fiş ve K-20 ile
 * gelen girişsiz takip (en dar yüz: adres, ad, telefon ve kalem yok). Bu
 * ayrımı denetleyicilere dağıtmak, bir gün mutfak yanıtına fiyat ya da
 * girişsiz uca adres sızdırmanın en kolay yoludur. Kapsam sınırı tek
 * dosyada durur ve denetlenebilir.
 */
class OrderPresenter
{
    public function __construct(private readonly OrderStatusTransition $transitions) {}

    /** @return array<string, mixed> */
    public function created(Order $order): array
    {
        return [
            'id' => (int) $order->order_id,
            'order_number' => $this->number($order),
            'status' => $this->transitions->codeOf($order),
            'total' => Money::toKurus($order->order_total),
            'currency' => 'TRY',
            'payment' => $this->payment($order),
            'created_at' => $this->ts($order->created_at),
        ];
    }

    /** @return array<string, mixed> */
    public function summary(Order $order): array
    {
        return [
            'id' => (int) $order->order_id,
            'order_number' => $this->number($order),
            'status' => $this->transitions->codeOf($order),
            'total' => Money::toKurus($order->order_total),
            'currency' => 'TRY',
            'item_count' => (int) $order->total_items,
            'created_at' => $this->ts($order->created_at),
            // Siparişin hangi GÜN İÇİN olduğu (B-19). `created_at` siparişin
            // verildiği andır; ileri tarihli siparişte ikisi ayrıdır ve
            // listede "20 Ağustos menüsü" yazabilmek için bu gerekiyor.
            'service_date' => $this->serviceDate($order),
            'subscription_id' => $order->bld_subscription_id !== null
                ? (int) $order->bld_subscription_id
                : null,
            // ── Revizyonlar (K-12) ────────────────────────────────────
            //
            // Müşteri "siparişim neden değişti" sorusunun cevabını
            // uygulamada görmeli. Takip ekranı zaten 5 saniyede bir bu
            // ucu çekiyor; adetler kendiliğinden güncelleniyordu ama
            // SEBEP görünmüyordu — sayının gözünün önünde değişmesi,
            // açıklamasız olduğunda güven kaybettiriyor.
            'revision_no' => (int) ($order->bld_revision_no ?? 0),
            'revisions' => $this->revisions($order),
        ];
    }

    /**
     * Müşteriye gösterilen revizyon özeti.
     *
     * İç alanlar (kim yaptı, hangi kasa, ham anlık görüntüler) DÖNMEZ:
     * müşterinin görmesi gereken tek şey ne değiştiği, neden ve para
     * farkı.
     *
     * @return list<array<string, mixed>>
     */
    private function revisions(Order $order): array
    {
        return DB::table('veykemtu_order_revisions')
            ->where('order_id', $order->order_id)
            ->orderBy('revision_no')
            ->get()
            ->map(static fn($row): array => [
                'revision_no' => (int) $row->revision_no,
                'reason' => (string) $row->reason,
                'refund' => (int) $row->refund_kurus,
                'extra_charge' => (int) $row->extra_charge_kurus,
                'created_at' => $row->created_at,
            ])
            ->all();
    }

    /** @return array<string, mixed> */
    public function detail(Order $order): array
    {
        $totals = $this->totals($order);
        $isDelivery = $order->order_type === Order::DELIVERY;

        return [
            'id' => (int) $order->order_id,
            'order_number' => $this->number($order),
            'status' => $this->transitions->codeOf($order),
            'items' => $this->pricedItems($order),
            'subtotal' => $totals['subtotal'],
            'delivery_fee' => $totals['delivery'],
            'total' => $totals['total'],
            'currency' => 'TRY',
            'delivery_type' => $this->deliveryType($order),
            'address' => $isDelivery ? $this->address($order) : null,
            'requested_at' => $this->requestedAt($order),
            'service_date' => $this->serviceDate($order),
            'customer_note' => $order->comment !== null ? (string) $order->comment : null,
            'payment' => $this->payment($order),
            'status_history' => $this->statusHistory($order),
            'created_at' => $this->ts($order->created_at),
            'subscription_id' => $order->bld_subscription_id !== null
                ? (int) $order->bld_subscription_id
                : null,
            // ── Revizyonlar (K-12) ────────────────────────────────────
            //
            // BURAYA DA GEREKİYOR: alan `summary()` ve `kitchen()`'a
            // eklenmişti ama **takip ekranının çektiği uç bu**
            // (`GET /api/orders/{id}`). Eksik kalınca müşteri adetlerin
            // değiştiğini görüyor, sebebini göremiyordu; mobildeki
            // "siparişiniz güncellendi" bildirimi de `revision_no`
            // değişimine bakıyor ve hiç tetiklenmiyordu.
            'revision_no' => (int) ($order->bld_revision_no ?? 0),
            'revisions' => $this->revisions($order),
        ];
    }

    /**
     * Girişsiz takip görünümü — fişteki QR'ın açtığı yüz (K-20).
     *
     * ADRES, AD, TELEFON VE KALEM LİSTESİ DÖNMEZ. Bu, `detail()`in yanına
     * konmuş ikinci bir sipariş yüzü değil; daha DAR bir yüz.
     *
     * NEDEN BU KADAR DAR: bu veriyi açan şey bir oturum değil, kâğıda
     * basılmış bir kare. Fiş düşürülebilir, fotoğraflanabilir, çöpten
     * çıkarılabilir. Buradan çıkarılan her şey zaten o kâğıdın üstünde
     * yazıyor — kâğıttan daha uzun yaşayan bir URL üzerinden ikinci kez
     * sızdırmak hiçbir şey kazandırmıyor.
     *
     * VARSAYIM: `total` ve ödeme durumu İÇERİDE. QR'ı okutan müşterinin ilk
     * sorusu çoğu zaman "borcum kapandı mı"; ikisi de fişin üstünde zaten
     * basılı. Fazla bulunursa iki satır silinerek geri alınır.
     *
     * @return array<string, mixed>
     */
    public function publicTracking(Order $order): array
    {
        $payment = $this->payment($order);

        return [
            'id' => (int) $order->order_id,
            'order_number' => $this->number($order),
            'status' => $this->transitions->codeOf($order),
            'delivery_type' => $this->deliveryType($order),
            'requested_at' => $this->requestedAt($order),
            'created_at' => $this->ts($order->created_at),
            'total' => $this->totals($order)['total'],
            'currency' => 'TRY',
            // `redirect_url` ELENIYOR: ödeme başlatmak girişli akışın işi.
            // Fişteki ödeme QR'ı zaten ayrı ve imzalı bir yol kullanıyor.
            'payment' => [
                'method' => $payment['method'],
                'status' => $payment['status'],
            ],
            'revision_no' => (int) ($order->bld_revision_no ?? 0),
            'status_history' => $this->statusHistory($order),
            'server_time' => Carbon::now()->utc()->toIso8601ZuluString(),
        ];
    }

    /**
     * Mutfak görünümü — fiyat, telefon, adres, e-posta **yoktur**.
     *
     * @return array<string, mixed>
     */
    public function kitchen(Order $order): array
    {
        return [
            'id' => (int) $order->order_id,
            'order_number' => $this->number($order),
            'status' => $this->transitions->codeOf($order),
            'requested_at' => $this->requestedAt($order),
            'delivery_type' => $this->deliveryType($order),
            'customer_label' => $this->customerLabel($order),
            // ── TELEFON PANODA GÖRÜNÜR (K-14, 11.08.2026) ──────────────
            //
            // `docs/03` §5 üç ayrı yerde "mutfak listesinde telefon
            // GÖRÜNMEZ" diyordu ve sipariş düzenleme gelene kadar
            // doğruydu: mutfağın telefona ihtiyacı yoktu. Artık personel
            // müşteriyi ARAYIP anlaşmak zorunda ve numarayı görmek için
            // fişi basmak (ya da basılmış fişi aramak) saçma.
            //
            // FİYAT VE ADRES HÂLÂ GİZLİ — ADR-08 duruyor. Değişen tek
            // şey telefon; kural kaldırılmadı, daraltıldı.
            'customer_name' => $this->customerName($order),
            'customer_phone' => $this->customerPhone($order),
            'items' => $this->kitchenItems($order),
            'customer_note' => $order->comment !== null ? (string) $order->comment : null,
            'created_at' => $this->ts($order->created_at),
            'updated_at' => $this->ts($order->updated_at),
            // Kaçıncı revizyon (K-12). 0 = hiç düzenlenmedi.
            'revision_no' => (int) ($order->bld_revision_no ?? 0),
            // Abonelikten üretilen sipariş — KDS kartında "abonelik" rozeti.
            // Yeni kolon yok; çekirdek `orders.bld_subscription_id`'den türer.
            'is_subscription' => $order->bld_subscription_id !== null,
        ];
    }

    /** Mutfağın arayabilmesi için tam ad (K-14). */
    public function customerName(Order $order): ?string
    {
        $name = trim(($order->first_name ?? '').' '.($order->last_name ?? ''));

        return $name === '' ? null : $name;
    }

    /**
     * Düzenleme ekranının gördüğü sipariş — **FİYATSIZ** (ADR-08).
     *
     * Personel adet değiştirirken fiyata bakmıyor; iade/fark tutarı
     * kaydetme onayında ayrıca gösteriliyor ve o tek bir sayı, cari
     * bakiye değil.
     *
     * @return array<string, mixed>
     */
    public function editable(Order $order): array
    {
        /*
         * BİLEŞEN SATIRLARI DÜZENLEME EKRANINDA GÖRÜNMEZ (B-19).
         *
         * Menü paketi bir üst satır + altında sıfır fiyatlı bileşenler
         * olarak yazılıyor. Bileşenler de listelenseydi KDS onları geri
         * gönderir, `LineResolver` onları tek tek satılan ürünler gibi
         * fiyatlandırır ve siparişin toplamı kendiliğinden şişerdi.
         *
         * Personel paketi tek bir birim olarak düzenler ("Günün Menüsü ×3"
         * → ×2); sunucu bileşenleri yeniden açar. Bu, tasarımdaki en keskin
         * kenar ve kendi testi var.
         */
        /*
         * SEÇENEK KİMLİKLERİ AYRI TABLODAN OKUNUR.
         *
         * `order_menus.option_values` yalnız seçenek ADLARINI tutuyor
         * (`serialize(array_column($line['options'], 'name'))`); kimlik o
         * sütunda hiç durmuyor. Revizyon ucu ise kimlik istiyor
         * (`LineResolver::resolve` → `option_value_ids`).
         *
         * Kimlik dışarı çıkmadığı sürece KDS onu geri gönderemiyordu:
         * personel yalnız adedi değiştirdiğinde `LineResolver` satırı
         * SEÇENEKSİZ yeniden fiyatlıyor, müşteri eksik ücretlendiriliyor
         * ve seçenek satırı mutfak fişinden düşüyordu — hiçbir hata
         * dönmeden. Kendi testi var.
         *
         * Adları kimliğe geri çevirmek seçenek DEĞİLDİ: aynı adı taşıyan
         * iki değer (iki ayrı grupta "Bol") yanlış eşleşir ve sessiz
         * kaybın yerini sessiz yanlışlık alırdı.
         */
        $optionValueIds = $this->optionValueIdsByLine($order);

        $items = DB::table('order_menus')
            ->where('order_id', $order->order_id)
            ->where(function ($query): void {
                $query->whereNull('bld_line_role')
                    ->orWhere('bld_line_role', '!=', 'component');
            })
            ->orderBy('order_menu_id')
            ->get()
            ->map(fn($row): array => [
                'order_menu_id' => (int) $row->order_menu_id,
                'menu_id' => (int) $row->menu_id,
                'name' => (string) $row->name,
                'quantity' => (int) $row->quantity,
                // ADLAR KALIYOR (AGENTS.md §2.3 — yalnız ekleme yapılır).
                // Ekran seçeneği personele bunlarla yazıyor; kimlikler
                // insana gösterilmez, yalnız geri gönderilir.
                'options' => $this->unserializeNames($row->option_values),
                'option_value_ids' => $optionValueIds[(int) $row->order_menu_id] ?? [],
                'note' => $row->comment,
            ])
            ->all();

        return [
            'id' => (int) $order->order_id,
            'order_number' => $this->number($order),
            'status' => $this->transitions->codeOf($order),
            'delivery_type' => $this->deliveryType($order),
            'requested_at' => $this->requestedAt($order),
            'customer_name' => $this->customerName($order),
            'customer_phone' => $this->customerPhone($order),
            'customer_note' => $order->comment !== null ? (string) $order->comment : null,
            'revision_no' => (int) ($order->bld_revision_no ?? 0),
            // Abonelikten doğan sipariş düzenlenebilir ama düzenleme
            // YALNIZ O GÜNÜ etkiler; abonelik tanımı değişmez. İstemci
            // bunu personele yazıyor.
            'is_subscription' => $order->bld_subscription_id !== null,
            'items' => $items,
        ];
    }

    /**
     * Satır kimliği → seçilen seçenek değeri kimlikleri.
     *
     * TEK SORGU, satır başına bir tane değil: bir siparişte onlarca kalem
     * olabiliyor ve düzenleme ekranı personel telefonda beklerken açılıyor.
     *
     * KİMLİĞİ OLMAYAN SATIR BOŞ DİZİ DÖNER, hata değil. `order_menu_options`
     * kaydı iki durumda eksik olabilir: `LineResolver` gelmeden önce yazılmış
     * eski siparişler ve seçeneği hiç olmayan kalemler. İkisi de düzenlemeyi
     * durdurmamalı — sipariş zaten mutfakta ve personel müşteriyle telefonda.
     * Sonuç seçeneksiz bir satır olur; bugünkü davranışın aynısı.
     *
     * @return array<int, list<int>>
     */
    private function optionValueIdsByLine(Order $order): array
    {
        $map = [];

        $rows = DB::table('order_menu_options')
            ->where('order_id', $order->order_id)
            ->orderBy('order_option_id')
            ->get(['order_menu_id', 'menu_option_value_id']);

        foreach ($rows as $row) {
            $map[(int) $row->order_menu_id][] = (int) $row->menu_option_value_id;
        }

        return $map;
    }

    /** @return list<string> */
    private function unserializeNames(mixed $value): array
    {
        if (!is_string($value) || $value === '') {
            return [];
        }

        $decoded = @unserialize($value, ['allowed_classes' => false]);

        return is_array($decoded) ? array_values(array_map(strval(...), $decoded)) : [];
    }

    public function number(Order $order): string
    {
        return 'S-'.$order->order_id;
    }

    /** Sözleşmedeki `pickup`; TastyIgniter içeride `collection` saklar. */
    public function deliveryType(Order $order): string
    {
        return $order->order_type === Order::DELIVERY ? 'delivery' : 'pickup';
    }

    /** @return array{subtotal:int, delivery:int, total:int} */
    public function totals(Order $order): array
    {
        $rows = DB::table('order_totals')
            ->where('order_id', $order->order_id)
            ->pluck('value', 'code');

        $subtotal = $rows->has('subtotal')
            ? Money::toKurus($rows['subtotal'])
            : Money::toKurus($order->order_total);

        $delivery = $rows->has('delivery') ? Money::toKurus($rows['delivery']) : 0;

        $total = $rows->has('order_total')
            ? Money::toKurus($rows['order_total'])
            : Money::toKurus($order->order_total);

        return ['subtotal' => $subtotal, 'delivery' => $delivery, 'total' => $total];
    }

    /** @return list<array<string, mixed>> */
    public function pricedItems(Order $order): array
    {
        $rows = DB::table('order_menus')
            ->where('order_id', $order->order_id)
            ->orderBy('order_menu_id')
            ->get();

        /*
         * `included_in` — bileşen satırının ait olduğu paketin, `items`
         * dizisindeki SIRASI (kimliği değil). İstemci paketi ve içindekileri
         * iç içe gösterebilsin diye; `order_menu_id`'yi dışarı vermek,
         * sözleşmeye istemcinin işine yaramayan bir iç kimlik sokardı.
         */
        $indexByLineId = [];
        $position = 0;

        foreach ($rows as $row) {
            $indexByLineId[(int) $row->order_menu_id] = $position++;
        }

        return $rows
            ->map(function (object $row) use ($indexByLineId): array {
                $parentId = $row->bld_parent_line_id !== null
                    ? (int) $row->bld_parent_line_id
                    : null;

                return [
                    'menu_id' => (int) $row->menu_id,
                    'name' => (string) $row->name,
                    'quantity' => (int) $row->quantity,
                    'options' => $this->optionNames($row->option_values),
                    'note' => $row->comment !== null ? (string) $row->comment : null,
                    'unit_price' => Money::toKurus($row->price),
                    'line_total' => Money::toKurus($row->subtotal),
                    // Eski satırlarda kolon boş; sözleşmedeki varsayılan
                    // `item` ve istemci davranışı hiç değişmiyor.
                    'role' => $row->bld_line_role !== null
                        ? (string) $row->bld_line_role
                        : 'item',
                    'included_in' => $parentId !== null
                        ? ($indexByLineId[$parentId] ?? null)
                        : null,
                    'daily_menu_id' => $row->bld_daily_menu_id !== null
                        ? (int) $row->bld_daily_menu_id
                        : null,
                ];
            })
            ->all();
    }

    /** @return list<array<string, mixed>> */
    public function kitchenItems(Order $order): array
    {
        return DB::table('order_menus')
            ->where('order_id', $order->order_id)
            /*
             * MENÜ PAKETİNİN ÜST SATIRI MUTFAĞA HİÇ GİTMEZ (B-19).
             *
             * "Ev Yemeği Menüsü (20.08.2026)" pişirilecek bir yemek değil, bir
             * başlık. Mutfağın ihtiyacı olan tek şey ne pişeceği; bileşenler
             * zaten kendi adları ve adetleriyle bu listede.
             *
             * Rolü istemciye gönderip panoya ve fişe "bu bir başlık" mantığı
             * yazmak da bir seçenekti; SATIRI HİÇ GÖNDERMEMEK daha az kod ve
             * daha az kavram. Mutfak yazılımı bu değişiklikten hiç haberdar
             * olmuyor — ne yeni bir alan, ne yeni bir çizim kuralı.
             */
            ->where(function ($query): void {
                $query->whereNull('bld_line_role')
                    ->orWhere('bld_line_role', '!=', 'package');
            })
            ->orderBy('order_menu_id')
            ->get()
            ->map(fn(object $row): array => [
                'name' => (string) $row->name,
                'quantity' => (int) $row->quantity,
                'options' => $this->optionNames($row->option_values),
                'note' => $row->comment !== null ? (string) $row->comment : null,
            ])
            ->all();
    }

    /** @return array<string, mixed>|null */
    public function address(Order $order): ?array
    {
        if ($order->address_id === null) {
            return null;
        }

        $row = DB::table('addresses')->where('address_id', $order->address_id)->first();
        if ($row === null) {
            return null;
        }

        return [
            'line1' => (string) $row->address_1,

            // Yapılandırılmış alanlar (B-21). Sipariş adresi KOPYADIR:
            // defterdeki kayıt sonradan düzelse bile bunlar sipariş anındaki
            // hâlini gösterir. Eski siparişlerde hepsi `null`.
            ...StructuredAddress::read($row),

            'district' => (string) ($row->state ?? ''),
            'city' => (string) ($row->city ?? ''),
            'note' => $row->address_2 !== null && $row->address_2 !== ''
                ? (string) $row->address_2
                : null,

            // Çift olarak veriliyor: yarısı dolu bir koordinat haritada
            // gösterilemez ama istemci "var" sanıp iğneyi yanlış yere koyar.
            'latitude' => $row->bld_latitude !== null && $row->bld_longitude !== null
                ? (float) $row->bld_latitude
                : null,
            'longitude' => $row->bld_latitude !== null && $row->bld_longitude !== null
                ? (float) $row->bld_longitude
                : null,
        ];
    }

    /** @return array<string, mixed> */
    public function payment(Order $order): array
    {
        $method = (string) ($order->payment ?? 'cash');
        $odendi = (bool) $order->processed;

        return array_filter([
            'method' => $method,
            'status' => $odendi ? 'paid' : 'pending',
            'redirect_url' => $this->redirectUrl($order, $method, $odendi),
        ], static fn($value): bool => $value !== null);
    }

    /**
     * Online ödemede sağlayıcının ödeme sayfası.
     *
     * Faz 1'de bu adres **simülasyon** sayfasıdır; gerçek tahsilat yapmaz
     * (`veykemtu/payment`). Kuveyt Türk entegrasyonu geldiğinde yalnızca
     * bu metodun ürettiği adres değişir — sözleşme ve istemciler aynı kalır.
     *
     * Ödenmiş siparişte `null` döner: istemci kullanıcıyı ikinci kez ödeme
     * sayfasına göndermemeli.
     */
    private function redirectUrl(Order $order, string $method, bool $odendi): ?string
    {
        if ($method !== 'online' || $odendi) {
            return null;
        }

        $hash = (string) ($order->hash ?? '');
        if ($hash === '') {
            return null;
        }

        return rtrim((string) config('app.url'), '/').'/odeme-simulasyon/'.$hash;
    }

    /** @return list<array<string, mixed>> */
    public function statusHistory(Order $order): array
    {
        return DB::table('status_history')
            ->join('statuses', 'statuses.status_id', '=', 'status_history.status_id')
            ->where('status_history.object_id', $order->order_id)
            ->where('status_history.object_type', 'orders')
            ->whereNotNull('statuses.status_code')
            ->orderBy('status_history.status_history_id')
            ->get(['statuses.status_code', 'status_history.created_at'])
            ->map(fn(object $row): array => [
                'status' => (string) $row->status_code,
                'at' => $this->ts($row->created_at),
            ])
            ->all();
    }

    /**
     * Müşterinin telefonu — **yalnızca fişe** basılmak üzere.
     *
     * KDS kartında (`KitchenOrder`) telefon YOKTUR ve olmamalıdır: ekran
     * mutfakta gün boyu açık duruyor, kartlarda telefon olması her müşterinin
     * numarasını salondan görülebilir hâle getirirdi. Fiş ise tek bir sipariş
     * için basılıp kuryeye/paketin üstüne gidiyor.
     *
     * NEDEN GEREKLİ: adres tarifi yetmediğinde ya da kapı açılmadığında
     * kuryenin elinde arayacak numara olmuyor; sipariş kasadan telefonla
     * aranana kadar bekliyordu.
     */
    public function customerPhone(Order $order): ?string
    {
        $phone = trim((string) ($order->telephone ?? ''));

        return $phone === '' ? null : $phone;
    }

    /**
     * Ad + soyad baş harfi. Adres ve e-posta asla dönmez.
     */
    public function customerLabel(Order $order): ?string
    {
        $first = trim((string) ($order->first_name ?? ''));
        $last = trim((string) ($order->last_name ?? ''));

        if ($first === '') {
            return null;
        }

        return $last === '' ? $first : $first.' '.mb_substr($last, 0, 1).'.';
    }

    public function requestedAt(Order $order): ?string
    {
        // ASAP siparişte "istenen zaman" yoktur; sipariş anı zaten created_at.
        if ((bool) $order->order_time_is_asap) {
            return null;
        }

        $date = $order->order_date;
        $time = $order->order_time;

        if ($date === null || $time === null) {
            return null;
        }

        // order_date/order_time işletme duvar saatidir; API UTC döner.
        return Carbon::parse(
            Carbon::parse($date)->toDateString().' '.Carbon::parse($time)->format('H:i:s'),
            BusinessTime::ZONE,
        )->utc()->toIso8601ZuluString();
    }

    /**
     * Siparişin hangi gün için olduğu, `YYYY-AA-GG` (B-19).
     *
     * `requested_at`'ten farklı olarak ASAP siparişte de doludur: "en kısa
     * sürede" bir SAAT belirsizliğidir, gün belirsizliği değil. Müşteri
     * sipariş listesinde her siparişin hangi günün menüsü olduğunu görmeli.
     *
     * Göç öncesi satırlarda kolon boş olabilir; `order_date`'e düşülüyor —
     * değişmez zaten `bld_service_date === DATE(order_date)`.
     */
    public function serviceDate(Order $order): ?string
    {
        $date = $order->bld_service_date ?? $order->order_date;

        return $date !== null ? Carbon::parse($date)->toDateString() : null;
    }

    /** @return list<string> */
    private function optionNames(mixed $serialized): array
    {
        if (!is_string($serialized) || $serialized === '') {
            return [];
        }

        $decoded = @unserialize($serialized, ['allowed_classes' => false]);

        if (!is_array($decoded)) {
            return [];
        }

        return array_values(array_map(strval(...), $decoded));
    }

    private function ts(mixed $value): ?string
    {
        return $value === null ? null : Carbon::parse($value)->utc()->toIso8601ZuluString();
    }
}
