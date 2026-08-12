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

/** Tam ad — YALNIZ fişte (K-14/K-20). Kurye kapıda kime teslim ettiğini bilmeli. */
function customerName(state, order) {
  const customer = state.customerById(order.customer_id);
  if (!customer) return null;
  return `${customer.first_name} ${customer.last_name}`;
}

/** Telefon — YALNIZ fişte. KDS kartında (`kitchenOrderOut`) yoktur. */
function customerPhone(state, order) {
  return state.customerById(order.customer_id)?.telephone ?? null;
}

/**
 * Kapıda tahsil edilecek tutar (K-20).
 *
 * Ödenmiş siparişte ve gel-al'da 0; KDS o durumda satırı hiç basmaz.
 */
function collectAmount(state, order) {
  if (order.delivery_type !== 'delivery') return 0;
  if ((order.payment?.status ?? 'pending') === 'paid') return 0;
  return state.totals(order).total;
}

/**
 * Siparişin son revizyon özeti (K-12/K-20).
 *
 * Mock revizyon motoru çalıştırmıyor; tohumda hazır bir özet varsa onu
 * döndürüyor. Amaç KDS'in bandı ve DEĞİŞİKLİKLER bloğunu mock'a karşı da
 * çizebilmesi — aksi hâlde revizyon yolu hiç denenemiyordu.
 */
function revisionSummary(order) {
  return order.revision_summary ?? [];
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
    customer_phone: customerPhone(state, order),
    customer_note: order.customer_note,
    printed_at: state.printedAtFor(order, 'mutfak'),
    revision_no: order.revision_no ?? 0,
    revision_summary: revisionSummary(order),
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
    printed_at: state.printedAtFor(order, 'musteri'),

    // ── K-20: müşteri fişi artık kuryenin de fişi ──────────────────────
    //
    // Gel-al'da ad/telefon/adres/tahsilat YOK: kurye yok ve o satırlar
    // personeli olmayan bir teslimatı aramaya iterdi.
    customer_name: isDelivery(order) ? customerName(state, order) : null,
    customer_phone: isDelivery(order) ? customerPhone(state, order) : null,
    customer_note: order.customer_note,
    collect_amount: collectAmount(state, order),
    revision_no: order.revision_no ?? 0,
    revision_summary: revisionSummary(order),
    deliver_url: isDelivery(order) ? state.deliverUrl(order) : null,
    track_url: state.trackUrl(order),
    pay_url: state.payUrl(order),
  };
}

/**
 * `GET /kitchen/orders/{id}/receipt?type=kurye` (K-14).
 *
 * K-20'DEN BERİ OTOMATİK BASILMIYOR ama uç duruyor: personel kâğıt
 * sıkışması ya da kaybolan fiş için elle yeniden bastırabiliyor. Mock'ta
 * eksik olması, o yolun mock'a karşı hiç denenememesi demekti.
 */
export function courierReceiptOut(state, order) {
  const { total } = state.totals(order);
  return {
    type: 'kurye',
    order_number: orderNumber(order),
    delivery_type: order.delivery_type,
    requested_at: order.requested_at,
    items: order.items.map((line) => customerItem(state, line)),
    total,
    currency: 'TRY',
    payment: order.payment,
    address: isDelivery(order) ? order.address : null,
    customer_name: customerName(state, order),
    customer_phone: customerPhone(state, order),
    customer_note: order.customer_note,
    revision_no: order.revision_no ?? 0,
    revision_summary: revisionSummary(order),
    collect_amount: collectAmount(state, order),
    printed_at: state.printedAtFor(order, 'kurye'),
  };
}

/** Girişsiz takip yüzü (K-20) — adres, ad, telefon ve kalem listesi YOK. */
export function publicTrackingOut(state, order) {
  const { total } = state.totals(order);
  return {
    id: order.id,
    order_number: orderNumber(order),
    status: order.status,
    delivery_type: order.delivery_type,
    requested_at: order.requested_at,
    created_at: order.created_at,
    total,
    currency: 'TRY',
    payment: {
      method: order.payment.method,
      status: order.payment.status,
    },
    revision_no: order.revision_no ?? 0,
    status_history: order.status_history,
    server_time: new Date().toISOString(),
  };
}

function isDelivery(order) {
  return order.delivery_type === 'delivery';
}

export function customerOut(customer) {
  return {
    id: customer.id,
    first_name: customer.first_name,
    last_name: customer.last_name,
    email: customer.email,
    telephone: customer.telephone,
    default_location_id: customer.default_location_id,
    // B2B alanları (docs/00 kararı). `can_order` sipariş kapısını açıyor;
    // site bu alana bakıp hızlı sipariş kutusunu çiziyor (W-10).
    account_type: customer.account_type ?? 'corporate',
    can_order: (customer.account_type ?? 'corporate') === 'corporate',
    company_name: customer.company_name ?? null,
    contact_person: customer.contact_person ?? null,
  };
}
