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

export type Address = Schemas['Address'];
export type OrderCreateRequest = Schemas['OrderCreateRequest'];
export type OrderCreateItem = OrderCreateRequest['items'][number];
export type OrderCreated = Schemas['OrderCreated'];
export type OrderSummary = Schemas['OrderSummary'];
export type OrderItem = Schemas['OrderItem'];
export type OrderDetail = Schemas['OrderDetail'];
export type Payment = Schemas['Payment'];
export type StatusHistoryEntry = Schemas['StatusHistoryEntry'];

// Sarmalayıcı gövdeler de sözleşmeden çıkarılır, elle yazılmaz.
export type LocationListResponse = JsonOk<operations['listLocations']>;
export type MenuResponse = JsonOk<operations['getMenu']>;
export type OrderListResponse = JsonOk<operations['listOrders']>;
export type OrderCreatedResponse = JsonCreated<operations['createOrder']>;
export type LoginRequest = NonNullable<
  operations['login']['requestBody']
>['content']['application/json'];
