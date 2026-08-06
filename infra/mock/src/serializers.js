// İç durumdan sözleşme biçimine çeviriciler.
//
// Ayrı dosyada tutuluyor çünkü mutfak kapsamının fiyat/adres görmemesi
// (docs/03 §5) bir güvenlik kuralıdır ve tek yerde denetlenebilmelidir.

export function locationOut(location) {
  return {
    id: location.id,
    name: location.name,
    slug: location.slug,
    is_open: location.is_open,
    ordering_enabled: location.ordering_enabled,
    order_cutoff: location.order_cutoff,
    min_order_total: location.min_order_total,
    delivery_fee: location.delivery_fee,
    payment_methods: location.payment_methods,
    eta: location.eta,
  };
}

export function orderNumber(order) {
  return `S-${order.id}`;
}

/** Müşteri tarafı kalem — fiyatlı. */
function customerItem(state, line) {
  const item = state.findMenuItem(line.menu_id);
  const unitPrice = item ? state.unitPrice(item, line.option_value_ids) : 0;
  return {
    menu_id: line.menu_id,
    name: item?.name ?? 'Bilinmeyen ürün',
    quantity: line.quantity,
    options: item ? state.optionNames(item, line.option_value_ids) : [],
    note: line.note,
    unit_price: unitPrice,
    line_total: unitPrice * line.quantity,
  };
}

/** Mutfak tarafı kalem — fiyat **yok**. */
function kitchenItem(state, line) {
  const item = state.findMenuItem(line.menu_id);
  return {
    name: item?.name ?? 'Bilinmeyen ürün',
    quantity: line.quantity,
    options: item ? state.optionNames(item, line.option_value_ids) : [],
    note: line.note,
  };
}

export function orderCreatedOut(state, order) {
  const { total } = state.totals(order);
  return {
    id: order.id,
    order_number: orderNumber(order),
    status: order.status,
    total,
    currency: 'TRY',
    payment: order.payment,
    created_at: order.created_at,
  };
}

export function orderSummaryOut(state, order) {
  const { total } = state.totals(order);
  return {
    id: order.id,
    order_number: orderNumber(order),
    status: order.status,
    total,
    currency: 'TRY',
    item_count: order.items.reduce((sum, i) => sum + i.quantity, 0),
    created_at: order.created_at,
  };
}

export function orderDetailOut(state, order) {
  const { subtotal, deliveryFee, total } = state.totals(order);
  return {
    id: order.id,
    order_number: orderNumber(order),
    status: order.status,
    items: order.items.map((line) => customerItem(state, line)),
    subtotal,
    delivery_fee: deliveryFee,
    total,
    currency: 'TRY',
    delivery_type: order.delivery_type,
    address: order.address,
    requested_at: order.requested_at,
    customer_note: order.customer_note,
    payment: order.payment,
    status_history: order.status_history,
    created_at: order.created_at,
  };
}

/** Ad + soyad baş harfi. Telefon, adres, e-posta asla dönmez. */
function customerLabel(state, order) {
  const customer = state.customerById(order.customer_id);
  if (!customer) return null;
  return `${customer.first_name} ${customer.last_name.charAt(0)}.`;
}

export function kitchenOrderOut(state, order) {
  return {
    id: order.id,
    order_number: orderNumber(order),
    status: order.status,
    requested_at: order.requested_at,
    delivery_type: order.delivery_type,
    customer_label: customerLabel(state, order),
    items: order.items.map((line) => kitchenItem(state, line)),
    customer_note: order.customer_note,
    created_at: order.created_at,
    updated_at: order.updated_at,
  };
}

export function kitchenReceiptOut(state, order) {
  return {
    type: 'mutfak',
    order_number: orderNumber(order),
    delivery_type: order.delivery_type,
    requested_at: order.requested_at,
    lines: order.items.map((line) => {
      const item = state.findMenuItem(line.menu_id);
      return {
        quantity: line.quantity,
        name: item?.name ?? 'Bilinmeyen ürün',
        options: item ? state.optionNames(item, line.option_value_ids) : [],
        note: line.note,
      };
    }),
    customer_note: order.customer_note,
    printed_at: state.printJobs.get(`${order.id}:mutfak`) ?? null,
  };
}

export function customerReceiptOut(state, order) {
  const { subtotal, deliveryFee, total } = state.totals(order);
  return {
    type: 'musteri',
    order_number: orderNumber(order),
    delivery_type: order.delivery_type,
    requested_at: order.requested_at,
    items: order.items.map((line) => customerItem(state, line)),
    subtotal,
    delivery_fee: deliveryFee,
    total,
    currency: 'TRY',
    payment: order.payment,
    // Gel-al siparişte adres bloğu basılmaz.
    address: order.delivery_type === 'delivery' ? order.address : null,
    customer_label: customerLabel(state, order),
    printed_at: state.printJobs.get(`${order.id}:musteri`) ?? null,
  };
}

export function customerOut(customer) {
  return {
    id: customer.id,
    first_name: customer.first_name,
    last_name: customer.last_name,
    email: customer.email,
    telephone: customer.telephone,
    default_location_id: customer.default_location_id,
  };
}
