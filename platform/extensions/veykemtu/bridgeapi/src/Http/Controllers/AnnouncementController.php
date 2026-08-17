<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Igniter\Main\Classes\MediaLibrary;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Throwable;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\Announcement;
use Veykemtu\BridgeApi\Models\AnnouncementRead;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\Subscription;

/**
 * Uygulama-içi duyurular — `docs/openapi.yaml` §Duyuru.
 *
 * PUSH (FCM) KAPSAM DIŞI. Müşteriye ulaşmanın iki yolu kaldı: SMS ve bu uç.
 * `POST /api/me/push-token` sözleşmede duruyor ama hiçbir bildirim
 * göndermiyor; buradan çağrılmıyor ve silinmiyor (sözleşme §1.4).
 *
 * ## BOŞ LİSTE HATA DEĞİLDİR
 *
 * Duyurusu olmayan bir kurulum olağan hâldir — hatta çoğu gün öyledir.
 * `[]` dönmek yerine 404 dönseydi, her istemci açılışta bir hata yakalamak
 * zorunda kalırdı ve o hatayı yakalamayı unutan istemci, hiç duyuru
 * yokken KIRMIZI bir hata ekranı gösterirdi. Bu uç 404 DÖNMEZ.
 *
 * ## ÜÇ SÜZGEÇ DE SUNUCUDA
 *
 * Yayın durumu, yayın penceresi ve kitle `Announcement::scopeVisibleTo`
 * içinde; kapatılmış duyuruların elenmesi burada. Süzgeç istemciye
 * bırakılsaydı üç istemci aynı kuralı üç kez yazar, biri unuturdu; dahası
 * saati kaymış bir telefon süresi dolmuş duyuruyu göstermeye devam ederdi.
 *
 * ## `seen` İLE `dismiss` NEDEN AYRI UÇ
 *
 * Görülmek duyuruyu listeden DÜŞÜRMEZ, kapatmak düşürür. Tek uca
 * indirilseydi ekranda çizilen her duyuru ilk karede kaybolur, müşteri
 * okumaya fırsat bulamazdı.
 */
class AnnouncementController extends ApiController
{
    /**
     * Metot adları ROTA DOSYASINDAN gelir (`routes/api.php`): `index`,
     * `markSeen`, `dismiss`. Rota ile denetleyici arasındaki ad ayrışması
     * ne açılışta ne `route:list`'te hata verir — yalnız uç çağrılınca
     * patlar. Yeniden adlandırma gerekirse önce rota dosyası değişir.
     */
    public function index(Request $request): JsonResponse
    {
        $customer = $this->customer($request);
        $placement = $request->query('placement');

        $rows = Announcement::query()
            ->visibleTo($this->isSubscriber((int) $customer->getKey()))
            /*
             * BİLİNMEYEN YERLEŞİM 422 DEĞİL, BOŞ LİSTE ÜRETİR: yerleşim
             * kümesi panelde büyüyor ve sözleşmede olmayan bir yerleşimi
             * soran istemcinin ekranı hata vermek yerine duyurusuz
             * açılmalıdır (sözleşme, `placement` parametresi). Doğrulama
             * yok; eşleşmeyen değer kendiliğinden hiçbir satır getirmez.
             */
            ->when(is_string($placement) && $placement !== '',
                static fn($query) => $query->where('placement', $placement))
            /*
             * SIRALAMA SUNUCUDAN (sözleşme: "önce `critical`, sonra yeni
             * olan"). Üç kademe:
             *
             *   1. `critical` her şeyin üstünde — hizmet kesintisi
             *      duyurusunun kampanya duyurusunun altında kalması,
             *      duyuruyu hiç yayınlamamakla aynı şey.
             *   2. `priority` azalan — yöneticinin elle verdiği ağırlık.
             *   3. `id` azalan — eşitlikte yeni olan üstte. Belirsiz bir
             *      sıra, aynı listeyi iki kez çeken istemcide duyuruların
             *      yer değiştirmesi demek olurdu.
             */
            ->orderByRaw("CASE WHEN severity = '".Announcement::SEVERITY_CRITICAL."' THEN 0 ELSE 1 END")
            ->orderByDesc('priority')
            ->orderByDesc('id')
            ->get();

        $reads = $this->readsFor($rows, (int) $customer->getKey());

        $data = $rows
            // KAPATILANLAR BURADA ELENİYOR, sorguda değil: alt sorgu her
            // satır için ayrı bir okuma doğururdu, oysa işaretlerin tamamı
            // tek seferde okundu.
            ->reject(static fn(Announcement $a): bool => ($reads[$a->id] ?? null)?->dismissed_at !== null)
            ->map(fn(Announcement $a): array => $this->present($a, $reads[$a->id] ?? null))
            ->values()
            ->all();

        return $this->json(['data' => $data]);
    }

    /**
     * Duyuru ekranda çizildi.
     *
     * İDEMPOTENT: ağ hatasında istemci tekrar çağırır ve ilk görülme anı
     * DEĞİŞMEZ (`AnnouncementRead::stamp`).
     */
    public function markSeen(Request $request, int $announcement): JsonResponse
    {
        $customer = $this->customer($request);
        $model = $this->findOrFail($announcement);

        AnnouncementRead::stamp((int) $model->id, (int) $customer->getKey(), 'seen_at');

        return $this->noContent();
    }

    /**
     * Müşteri duyuruyu kapattı; bir daha listede dönmez.
     *
     * `dismissible = false` İSE 422. Kapatılamayan bir duyuruyu istemcinin
     * isteğiyle kapatmak, hizmet kesintisi duyurusunu ilk dokunuşta yok
     * etmek olurdu — müşteri aynı soruyu bu kez telefonla sorar.
     */
    public function dismiss(Request $request, int $announcement): JsonResponse
    {
        $customer = $this->customer($request);
        $model = $this->findOrFail($announcement);

        if (!$model->dismissible) {
            throw ApiException::validationFailed('Bu duyuru kapatılamaz.');
        }

        AnnouncementRead::stamp((int) $model->id, (int) $customer->getKey(), 'dismissed_at');

        return $this->noContent();
    }

    /**
     * Duyuruyu kimliğinden bulur.
     *
     * TASLAK VE ARŞİVLENMİŞ DUYURU DA BULUNUR ve bu bilinçli: müşteri
     * listeden aldığı bir duyuruyu kapatmaya çalışırken duyuru o arada
     * arşivlenmiş olabilir. 404 dönmek, kullanıcının ekranında sebepsiz
     * bir hata çıkarırdı — oysa yapmak istediği şey (kapatmak) zaten
     * gerçekleşmiş sayılır. Var olmayan kimlik yine 404 alır.
     */
    private function findOrFail(int $id): Announcement
    {
        $model = Announcement::find($id);

        if (!$model instanceof Announcement) {
            throw ApiException::notFound('Duyuru bulunamadı.');
        }

        return $model;
    }

    private function customer(Request $request): ApiCustomer
    {
        $customer = $request->user();

        // İMPORT EDİLMEMİŞ SINIFA `instanceof` PHP'DE SESSİZCE `false`
        // DÖNER — sınıf yukarıda import edildi; kaldırılırsa bu uç her
        // müşteriye 401 verir ve sebebi hiçbir yerde görünmez.
        if (!$customer instanceof ApiCustomer) {
            throw ApiException::unauthenticated();
        }

        return $customer;
    }

    /**
     * Bu müşterinin aktif aboneliği var mı?
     *
     * YALNIZ `active` SAYILIYOR: `pending` bir talep henüz abonelik değil
     * (fiyatı bile konuşulmadı) ve `paused` abone hizmeti almıyor ama
     * abonedir — duraklatmış birine "abone olun" duyurusu göstermek
     * yanlış olurdu, o yüzden `paused` da abone tarafında sayılmalı mı
     * sorusu doğuyor. Sayılmıyor çünkü `paused` geçici bir hâl ve
     * duraklatan kişi çoğunlukla aboneliğe dair duyuruları görmek ister:
     * `AUDIENCE_SUBSCRIBERS` "hizmeti şu an alan" değil, "sözleşmesi
     * yürürlükte olan" demektir. `paused` da yürürlüktedir.
     */
    private function isSubscriber(int $customerId): bool
    {
        return Subscription::query()
            ->where('customer_id', $customerId)
            ->whereIn('status', [Subscription::STATUS_ACTIVE, Subscription::STATUS_PAUSED])
            ->exists();
    }

    /**
     * Listedeki duyuruların bu müşteriye ait işaretleri — TEK sorguda.
     *
     * @param Collection<int, Announcement> $rows
     * @return array<int, AnnouncementRead>
     */
    private function readsFor(Collection $rows, int $customerId): array
    {
        if ($rows->isEmpty()) {
            return [];
        }

        return AnnouncementRead::query()
            ->where('customer_id', $customerId)
            ->whereIn('announcement_id', $rows->pluck('id')->all())
            ->get()
            ->keyBy('announcement_id')
            ->all();
    }

    /** @return array<string, mixed> */
    private function present(Announcement $announcement, ?AnnouncementRead $read): array
    {
        return [
            'id' => (int) $announcement->id,
            'placement' => (string) $announcement->placement,
            'severity' => (string) $announcement->severity,
            // `style` sözleşmede yok ama zararsız bir ek: `placement`
            // duyurunun HANGİ ekranda, `style` NASIL (bant/kart)
            // çizileceğini söylüyor ve ikisi ayrı sorular. Şemada olmayan
            // alanlar istemcide sessizce yok sayılır.
            'style' => (string) $announcement->style,
            'title' => $announcement->title,
            'body' => (string) $announcement->body,
            'action_label' => $announcement->action_label,
            'action_type' => $announcement->action_type,
            // Sözleşmedeki ad `action_url`; kolonun adı `action_value`
            // çünkü değer uygulama-içi bir YOL da olabiliyor.
            'action_url' => $announcement->action_value,
            'image_url' => $this->mediaUrl($announcement->image_path),
            'dismissible' => (bool) $announcement->dismissible,
            'starts_at' => self::ts($announcement->starts_at),
            'ends_at' => self::ts($announcement->ends_at),
            'seen' => $read?->seen_at !== null,
            // Listede her zaman `false` — kapatılan duyuru zaten elendi.
            // Alan yine de dönüyor: istemcinin iyimser güncellemesini geri
            // alabilmesi için sözleşmede zorunlu.
            'dismissed' => $read?->dismissed_at !== null,
            'created_at' => self::ts($announcement->created_at),
        ];
    }

    /**
     * Görsel yolunu mutlak adrese çevirir.
     *
     * Yol saklanıyor, adres türetiliyor: alan adı ya da şema değiştiğinde
     * (http → https) tablodaki bütün satırlar bir anda kırık bağlantıya
     * dönmesin. `CatalogController::mediaUrl` ile aynı kalıp — orada
     * küçük resim üretiliyor, burada tam boy: duyuru görseli ekran
     * genişliğinde bir bant olabilir ve 800×600'e sıkıştırmak onu bulanık
     * gösterirdi.
     */
    private function mediaUrl(?string $path): ?string
    {
        $path = trim((string) $path);

        if ($path === '') {
            return null;
        }

        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
            return $path;
        }

        try {
            // Çekirdek `MediaLibrary`'yi konteynerde tekil tutuyor ve
            // `initialize()`'ı orada çağırıyor; `new` ile kurulan bir
            // örnek yapılandırmasız kalırdı.
            $url = resolve(MediaLibrary::class)->getMediaUrl($path);
        } catch (Throwable) {
            // Görseli çözülemeyen duyuru YİNE DÖNER, metni okunur. Bir
            // istisnanın bütün listeyi 500'e düşürmesi, tek bir bozuk
            // görsel yüzünden hizmet kesintisi duyurusunu görünmez
            // kılardı.
            return null;
        }

        return $url === '' ? null : $url;
    }
}
