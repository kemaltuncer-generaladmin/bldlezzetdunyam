/**
 * Sözleşme tipleri. Hepsi `docs/openapi.yaml`'dan üretilen `schema.ts`
 * içinden gelir — burada elle tip **yazılmaz**, yalnızca ad verilir
 * (`docs/03-api-sozlesmesi.md` §9).
 *
 * Yeniden üretmek için: `npm run api:generate`
 */
import type { components, operations } from './schema';

type Schemas = components['schemas'];

/** Bir işlemin `200`/`201` gövdesini sözleşmeden çıkarır. */
type JsonOk<T extends { responses: { 200: { content: { 'application/json': unknown } } } }> =
  T['responses'][200]['content']['application/json'];
type JsonCreated<T extends { responses: { 201: { content: { 'application/json': unknown } } } }> =
  T['responses'][201]['content']['application/json'];

export type Money = Schemas['Money'];
export type Currency = Schemas['Currency'];
export type SemVer = Schemas['SemVer'];

export type OrderStatus = Schemas['OrderStatus'];
export type DeliveryType = Schemas['DeliveryType'];
export type PaymentMethod = Schemas['PaymentMethod'];
export type PaymentStatus = Schemas['PaymentStatus'];
export type ErrorCode = Schemas['ErrorCode'];
export type ApiErrorBody = Schemas['Error'];
export type PaginationMeta = Schemas['PaginationMeta'];

export type RegisterRequest = Schemas['RegisterRequest'];
export type AuthResponse = Schemas['AuthResponse'];
export type Customer = Schemas['Customer'];

export type Location = Schemas['Location'];
export type LocationEta = Schemas['LocationEta'];
export type EtaWindow = Schemas['EtaWindow'];
export type MenuCategory = Schemas['MenuCategory'];
export type MenuItem = Schemas['MenuItem'];
export type MenuOption = Schemas['MenuOption'];
export type MenuOptionValue = Schemas['MenuOptionValue'];

/** Günün menüsü (B-19). */
export type DailyMenu = Schemas['DailyMenu'];
export type DailyMenuPackage = Schemas['DailyMenuPackage'];
/** Paketin içindeki yemek. Sözleşmede satır içi tanımlı, adı buradan gelir. */
export type DailyMenuComponent = DailyMenuPackage['components'][number];
export type MenuCalendarDay = Schemas['MenuCalendarDay'];
/**
 * `is_orderable` yanlışken sunucunun verdiği makine okunur sebep.
 *
 * `null` DIŞARIDA BIRAKILDI: alan `null` da olabiliyor ama o hâli "sebep yok"
 * demek, yani gösterilecek bir metni de yok. Metin eşlemesi
 * (`lib/labels.ts`) böylece YEDİ sebebin hepsini karşılamak ZORUNDA kalıyor.
 *
 * "Derleyici burayı gösterir" iddiası bir süre YALANDI: `lib/labels.ts`
 * içindeki `switch` bir `default` dalıyla bitiyordu ve sözleşmeye eklenen
 * her yeni sebep sessizce genel metne düşüyordu — `no_service_day` ile
 * `sold_out` eklendiğinde tek bir uyarı çıkmadı. `default` kaldırıldı ve
 * yerine `never` bekçisi kondu; artık sekizinci sebep gerçekten
 * `npm run typecheck` kırar.
 */
export type DailyMenuUnavailableReason = NonNullable<DailyMenu['unavailable_reason']>;

export type Address = Schemas['Address'];
export type OrderCreateRequest = Schemas['OrderCreateRequest'];
export type OrderCreateItem = OrderCreateRequest['items'][number];
export type OrderCreated = Schemas['OrderCreated'];
export type OrderSummary = Schemas['OrderSummary'];
export type OrderItem = Schemas['OrderItem'];
export type OrderDetail = Schemas['OrderDetail'];
export type Payment = Schemas['Payment'];
export type StatusHistoryEntry = Schemas['StatusHistoryEntry'];

/**
 * Fişteki takip QR'ının açtığı, giriş istemeyen sipariş yüzü (K-20).
 *
 * `OrderDetail` ile karıştırılmamalı: adres, ad, telefon ve kalem listesi
 * YOKTUR. Bu veriyi açan şey bir oturum değil, kâğıda basılmış bir kare.
 */
export type PublicOrderTracking = Schemas['PublicOrderTracking'];

// Sarmalayıcı gövdeler de sözleşmeden çıkarılır, elle yazılmaz.
export type LocationListResponse = JsonOk<operations['listLocations']>;
export type MenuResponse = JsonOk<operations['getMenu']>;
export type DailyMenuResponse = JsonOk<operations['getDailyMenu']>;
export type MenuCalendarResponse = JsonOk<operations['getMenuCalendar']>;
export type OrderListResponse = JsonOk<operations['listOrders']>;
export type OrderCreatedResponse = JsonCreated<operations['createOrder']>;
export type LoginRequest = NonNullable<
  operations['login']['requestBody']
>['content']['application/json'];

/**
 * Telefonla giriş (W-11 / B-18).
 *
 * `202` gövdesi `expires_in` ve `resend_after` taşıyor: geri sayımın
 * süresini SUNUCU söylüyor, arayüz sabit yazmıyor. Sunucudaki bekleme
 * (`OtpService::RESEND_COOLDOWN_SECONDS`) değiştiğinde ekrandaki sayaç
 * kendiliğinden uyuyor; sabit yazılsaydı ikisi sessizce ayrışırdı.
 */
export type OtpRequestResponse =
  operations['requestOtp']['responses'][202]['content']['application/json'];

/** Adres defteri (W-15). */
export type SavedAddress = Schemas['SavedAddress'];
export type SavedAddressList = JsonOk<operations['listAddresses']>;
export type SavedAddressInput = NonNullable<
  operations['createAddress']['requestBody']
>['content']['application/json'];

/*
 * Cari hesap (W-12) KALDIRILDI: iş modeli cari hesaptan çıktı, `/account/*`
 * uçları sözleşmeden silindi ve `lib/api/account.ts` sarmalayıcısı da gitti.
 * Tipler burada bırakılsaydı var olmayan bir `operations` üyesine bakacak ve
 * derleme kırılacaktı.
 */

/** Abonelik (W-13). */
export type SubscriptionListResponse = JsonOk<operations['listSubscriptions']>;
export type Subscription = Schemas['Subscription'];
