// Mock'un bellek içi durumu ve iş kuralları.
//
// Bu dosya sözleşmenin **davranışını** taklit eder, gerçek backend'i değil.
// Amaç: istemci hatlarının artımlı polling, durum geçişi ve idempotentlik
// gibi zor kısımları backend'i beklemeden gerçekten test edebilmesi (X-04).

import {
  CUSTOMERS,
  DELIVERY_FEE,
  LOCATION,
  MENU,
  seedOrders,
} from './seed.js';

// docs/02-veri-modeli.md §3 — geçiş matrisi.
const TRANSITIONS = {
  yeni: ['onaylandi', 'iptal'],
  onaylandi: ['hazirlaniyor', 'iptal'],
  hazirlaniyor: ['hazir', 'iptal'],
  hazir: ['yolda', 'teslim_edildi', 'iptal'],
  yolda: ['teslim_edildi', 'iptal'],
  teslim_edildi: [],
  iptal: [],
};

export class MockState {
  constructor() {
    this.reset();
  }

  reset() {
    const now = new Date();
    this.location = structuredClone(LOCATION);
    this.menu = structuredClone(MENU);
    this.customers = structuredClone(CUSTOMERS);
    this.orders = seedOrders(now);
    this.nextOrderId = 5013;

    /** token -> { kind: 'customer'|'kitchen', customerId?, deviceId? } */
    this.tokens = new Map();
    this.nextDeviceId = 1;
    this.revokedDevices = new Set();

    /** "orderId:type" -> printed_at — ack idempotentliği için. */
    this.printJobs = new Map();

    /** customerId -> fcm token */
    this.pushTokens = new Map();
  }

  // ── Katalog ───────────────────────────────────────────────────────────

  findMenuItem(menuId) {
    for (const category of this.menu) {
      const item = category.items.find((i) => i.id === menuId);
      if (item) return item;
    }
    return null;
  }

  /** Seçenek farkları dahil birim fiyat (kuruş). */
  unitPrice(item, optionValueIds) {
    let price = item.price;
    for (const option of item.options ?? []) {
      for (const value of option.values) {
        if (optionValueIds.includes(value.id)) price += value.price_delta;
      }
    }
    return price;
  }

  /** Sipariş kaleminin görünen seçenek adları. */
  optionNames(item, optionValueIds) {
    const names = [];
    for (const option of item.options ?? []) {
      for (const value of option.values) {
        if (optionValueIds.includes(value.id)) names.push(value.name);
      }
    }
    return names;
  }

  // ── Kimlik ────────────────────────────────────────────────────────────

  issueCustomerToken(customerId) {
    const token = `cus_mock_${customerId}_${this.tokens.size + 1}`;
    this.tokens.set(token, { kind: 'customer', customerId });
    return token;
  }

  issueKitchenToken() {
    const deviceId = this.nextDeviceId++;
    const token = `kdev_mock_${deviceId}`;
    this.tokens.set(token, { kind: 'kitchen', deviceId });
    return { token, deviceId };
  }

  resolveToken(token) {
    const principal = this.tokens.get(token);
    if (!principal) return null;
    if (
      principal.kind === 'kitchen' &&
      this.revokedDevices.has(principal.deviceId)
    ) {
      return { kind: 'revoked' };
    }
    return principal;
  }

  customerById(id) {
    return this.customers.find((c) => c.id === id) ?? null;
  }

  // ── Sipariş ───────────────────────────────────────────────────────────

  orderById(id) {
    return this.orders.find((o) => o.id === id) ?? null;
  }

  /** Sipariş tutarları — her zaman sunucuda hesaplanır. */
  totals(order) {
    let subtotal = 0;
    for (const line of order.items) {
      const item = this.findMenuItem(line.menu_id);
      if (!item) continue;
      subtotal += this.unitPrice(item, line.option_value_ids) * line.quantity;
    }
    const deliveryFee = order.delivery_type === 'delivery' ? DELIVERY_FEE : 0;
    return { subtotal, deliveryFee, total: subtotal + deliveryFee };
  }

  createOrder({ customerId, deliveryType, items, address, requestedAt, paymentMethod, customerNote }) {
    const now = new Date().toISOString();
    const order = {
      id: this.nextOrderId++,
      customer_id: customerId,
      delivery_type: deliveryType,
      status: 'yeni',
      created_at: now,
      updated_at: now,
      requested_at: requestedAt ?? null,
      customer_note: customerNote ?? null,
      address: deliveryType === 'delivery' ? address : null,
      payment: {
        method: paymentMethod,
        status: 'pending',
        // Faz 1'de online kapalı; yine de sözleşme davranışı taklit edilsin.
        ...(paymentMethod === 'online'
          ? { redirect_url: `https://sanalpos.mock/odeme/${this.nextOrderId}` }
          : {}),
      },
      items: items.map((i) => ({
        menu_id: i.menu_id,
        quantity: i.quantity,
        option_value_ids: i.option_value_ids ?? [],
        note: i.note ?? null,
      })),
      status_history: [{ status: 'yeni', at: now }],
    };
    this.orders.push(order);
    return order;
  }

  canTransition(order, to) {
    const allowed = TRANSITIONS[order.status] ?? [];
    if (!allowed.includes(to)) return false;

    // docs/02 §3: yolda yalnızca adrese gönderimde, teslim_edildi doğrudan
    // yalnızca gel-al'da.
    if (order.status === 'hazir') {
      if (to === 'yolda' && order.delivery_type !== 'delivery') return false;
      if (to === 'teslim_edildi' && order.delivery_type !== 'pickup') {
        return false;
      }
    }
    return true;
  }

  applyTransition(order, to) {
    const now = new Date().toISOString();
    order.status = to;
    order.updated_at = now;
    order.status_history.push({ status: to, at: now });
    return order;
  }

  // ── Yazdırma denetimi ─────────────────────────────────────────────────

  /** İdempotent: aynı (order_id, type) ikinci kez kaydedilmez. */
  ackPrint(orderId, type, printedAt) {
    const key = `${orderId}:${type}`;
    if (this.printJobs.has(key)) return false;
    this.printJobs.set(key, printedAt);
    return true;
  }

  // ── Üretim listesi ────────────────────────────────────────────────────

  productionList() {
    const totals = new Map();
    for (const order of this.orders) {
      if (order.status !== 'onaylandi' && order.status !== 'hazirlaniyor') {
        continue;
      }
      for (const line of order.items) {
        const item = this.findMenuItem(line.menu_id);
        if (!item) continue;
        totals.set(item.id, {
          menu_id: item.id,
          name: item.name,
          total: (totals.get(item.id)?.total ?? 0) + line.quantity,
        });
      }
    }
    return [...totals.values()].sort((a, b) => b.total - a.total);
  }
}
