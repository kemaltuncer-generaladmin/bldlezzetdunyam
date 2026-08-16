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
    daily_menu_enabled: location.daily_menu_enabled,
    /*
     * Mutfağın çalıştığı hafta günleri (1 Pazartesi .. 7 Pazar).
     *
     * İstemci hafta sonunu bu listeden bilir; takvimde "menü açıklanmadı"
     * ile "bu gün hiç pişirmiyoruz"u ayırmak için gerekiyor — biri yarın
     * dolabilir, öbürü dolmaz.
     */
    service_weekdays: location.service_weekdays,
    max_lookahead_days: location.max_lookahead_days,
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
function customerItem(state, order, line) {
  const item = state.findMenuItem(line.menu_id);
  const unitPrice = state.lineUnitPrice(order, line);

  return {
    menu_id: line.menu_id,
    name: state.lineName(order, line),
    quantity: line.quantity,
    options: item ? state.optionNames(item, line.option_value_ids) : [],
    note: line.note,
    unit_price: unitPrice,
    line_total: unitPrice * line.quantity,
  };
}

/** Mutfak tarafı kalem — fiyat **yok**. */
function kitchenItem(state, order, line) {
  const item = state.findMenuItem(line.menu_id);
  return {
    name: state.lineName(order, line),
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
    service_date: order.service_date ?? null,
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
    service_date: order.service_date ?? null,
    created_at: order.created_at,
  };
}

export function orderDetailOut(state, order) {
  const { subtotal, deliveryFee, total } = state.totals(order);
  return {
    id: order.id,
    order_number: orderNumber(order),
    status: order.status,
    items: order.items.map((line) => customerItem(state, order, line)),
    subtotal,
    delivery_fee: deliveryFee,
    total,
    currency: 'TRY',
    delivery_type: order.delivery_type,
    address: order.address,
    requested_at: order.requested_at,
    service_date: order.service_date ?? null,
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
    service_date: order.service_date ?? null,
    delivery_type: order.delivery_type,
    customer_label: customerLabel(state, order),
    items: order.items.map((line) => kitchenItem(state, order, line)),
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
    service_date: order.service_date ?? null,
    lines: order.items.map((line) => ({
      quantity: line.quantity,
      name: state.lineName(order, line),
      options: (() => {
        const item = state.findMenuItem(line.menu_id);
        return item ? state.optionNames(item, line.option_value_ids) : [];
      })(),
      note: line.note,
    })),
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
    service_date: order.service_date ?? null,
    items: order.items.map((line) => customerItem(state, order, line)),
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
    service_date: order.service_date ?? null,
    items: order.items.map((line) => customerItem(state, order, line)),
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
    service_date: order.service_date ?? null,
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
    /*
     * SİPARİŞ KAPISI KALKTI. `can_order` eskiden hesap tipine bakıyordu ve
     * bireysel kaydolan müşteri menüyü görüp sepete ekleyemiyordu. Artık
     * herkes sipariş verebiliyor; alan sözleşmede kalıyor ama daima doğru.
     *
     * Kurum alanları serbest METİN olarak duruyor: fatura başlığına
     * yazılıyor, hiçbir kapıyı açıp kapamıyor.
     */
    can_order: true,
    company_name: customer.company_name ?? null,
    contact_person: customer.contact_person ?? null,
  };
}

// ───────────────────────────── Günün menüsü ────────────────────────────────

/**
 * Günün menüsündeki bir kalem.
 *
 * `price` O GÜN İÇİN geçerli birim fiyattır: güne girilmiş istisna varsa o,
 * yoksa ürünün kendi fiyatı. İstemci gördüğü fiyatla ödeyeceği fiyatı ayrı
 * hesaplamaz.
 */
function dailyMenuItemOut(state, day, dayItem) {
  const product = state.findMenuItem(dayItem.menu_id);
  const remaining = state.itemRemaining(day, dayItem);
  const soldOut = remaining === 0;
  const name = dayItem.label ?? product?.name ?? 'Bilinmeyen ürün';

  return {
    id: dayItem.menu_id,
    name,
    description: product?.description ?? null,
    price: state.dailyUnitPrice(day, dayItem),
    currency: 'TRY',
    image_url: product?.image_url ?? null,
    is_available: (product?.is_available ?? false) && !soldOut,
    sold_out_today: soldOut,
    sold_out_reason: soldOut ? `${name} bugünlük tükendi.` : null,
    remaining_portions: remaining,
    allergens: product?.allergens ?? [],
    options: product?.options ?? [],
  };
}

/** Paket bölümü — `null` ise o gün paket satılmıyor. */
function dailyMenuPackageOut(state, day) {
  if (day.package_price === null || day.package_price === undefined) return null;

  const components = [];

  /*
   * GÜN TOPLAMI ÖNCE. Gün tavanı dolduğunda her zorunlu kalemin kalanı da
   * sıfır görünüyor; döngüye önce girseydik "Karnıyarık tükendi" derdik —
   * oysa karnıyarık değil O GÜN doldu ve müşteriye söylenmesi gereken bu.
   */
  let soldOutReason = state.dayRemaining(day) === 0 ? 'Günün menüsü tükendi.' : null;

  for (const dayItem of day.items) {
    // Gerçek denetleyici gibi: bileşen listesi ZORUNLU kalemlerden oluşur.
    if (!dayItem.is_required) continue;

    const product = state.findMenuItem(dayItem.menu_id);
    if (product === null) continue;

    const name = dayItem.label ?? product.name;

    // ZORUNLU BİR KALEM TÜKENDİYSE PAKET DE DÜŞER: ana yemeği olmayan bir
    // menüyü satmak, bir telefon özrünü kırka çevirir.
    if (!product.is_available || state.itemRemaining(day, dayItem) === 0) {
      soldOutReason ??= `${name} bugünlük tükendi.`;
    }

    components.push({
      menu_id: dayItem.menu_id,
      name,
      quantity: Math.max(1, dayItem.quantity),
      image_url: product.image_url ?? null,
      allergens: product.allergens ?? [],
    });
  }

  if (components.length === 0) return null;

  const remaining = state.packageRemaining(day);
  if (remaining === 0) soldOutReason ??= 'Günün menüsü tükendi.';

  return {
    menu_id: state.packageProduct.id,
    name: day.title ?? state.packageProduct.name,
    price: day.package_price,
    currency: 'TRY',
    is_available: soldOutReason === null,
    sold_out_reason: soldOutReason,
    remaining_portions: remaining,
    components,
  };
}

/**
 * `GET /locations/{id}/daily-menu` gövdesi.
 *
 * Menüsü olmayan gün de **200** döner (`id: null`, `items: []`): boş gün bir
 * hata değil, cevaptır.
 */
export function dailyMenuOut(state, verdict) {
  const { day, date } = verdict;

  if (day === null) {
    return {
      id: null,
      date,
      title: null,
      description: null,
      image_url: null,
      image_urls: [],
      package: null,
      items_total: null,
      currency: 'TRY',
      closed: verdict.closed,
      cutoff_at: verdict.cutoff_at,
      remaining_portions: null,
      is_orderable: false,
      unavailable_reason: verdict.reason,
      items: [],
    };
  }

  /*
   * `sellable_alone` yanlış olan kalem (ekmek, ayran) bu listede YOKTUR —
   * yalnız paketin bileşenlerinde görünür. Listede olsaydı arayüz ona
   * "sepete ekle" düğmesi çizer, düğme de her basışta ITEM_UNAVAILABLE
   * alırdı; mock'un istemciye kurduğu tuzak olurdu.
   *
   * `items_total` ise TÜM kalemleri toplar (gerçek `itemsTotalKurus()` gibi):
   * paket avantajı, paketin içindekilerin tamamına göre hesaplanır.
   */
  const items = day.components_sellable
    ? day.items.filter((item) => item.sellable_alone !== false)
    : [];

  return {
    id: day.id,
    date: day.date,
    title: day.title,
    description: day.description,
    image_url: day.image_urls[0] ?? null,
    // Sözleşme en fazla 4 adres taşıyor; fazlası galeriyi kaydırma alanına
    // çeviriyordu.
    image_urls: day.image_urls.slice(0, 4),
    package: dailyMenuPackageOut(state, day),
    items_total: state.itemsTotal(day),
    currency: 'TRY',
    closed: verdict.closed,
    cutoff_at: verdict.cutoff_at,
    remaining_portions: verdict.remaining,
    is_orderable: verdict.orderable,
    unavailable_reason: verdict.reason,
    items: items.map((item) => dailyMenuItemOut(state, day, item)),
  };
}

/** `GET /locations/{id}/menu-calendar` gövdesindeki bir gün. */
export function menuCalendarDayOut(state, verdict) {
  const { day } = verdict;

  return {
    date: verdict.date,
    has_menu: day !== null,
    closed: verdict.closed,
    weekend: verdict.weekend,
    is_orderable: verdict.orderable,
    sold_out: day !== null && verdict.remaining === 0,
    cutoff_at: verdict.cutoff_at,
    title: day?.title ?? null,
    package_price: day?.package_price ?? null,
    note: verdict.closed_note,
  };
}

// ──────────────────── Abonelik ödemesi, sözleşme, duyuru ───────────────────

export function subscriptionPaymentOut(payment) {
  return {
    payment_id: payment.id,
    subscription_id: payment.subscription_id,
    amount: payment.amount,
    currency: payment.currency,
    period: payment.period,
    payment_method: payment.method,
    status: payment.status,
    /*
     * `otp` = banka SMS'i bekleniyor, `none` = ödeme kapandı.
     *
     * İstemci bu alana bakıp OTP ekranını açıyor. Sabit bir dal olsaydı
     * mobilin 3D Secure yolu hiç denenemezdi.
     */
    next_action: payment.next_action,
    otp_expires_in: payment.next_action === 'otp' ? 300 : null,
    paid_at: payment.paid_at,
    created_at: payment.created_at,
  };
}

/** Telefonun son iki hanesi dışında maskesi — sözleşme ekranında gösterilir. */
function maskPhone(phone) {
  const digits = String(phone ?? '').replace(/\D+/g, '');
  if (digits.length < 4) return null;
  return `${digits.slice(0, 3)} *** ** ${digits.slice(-2)}`;
}

export function contractOut(state, contract) {
  return {
    token: contract.token,
    subscription_id: contract.subscription_id,
    status: contract.status,
    title: contract.title,
    body: contract.body,
    signer_name: contract.signer_name,
    // TAM TELEFON DÖNMEZ: bağlantıyı ele geçiren biri numarayı okuyamamalı.
    signer_phone_masked: maskPhone(contract.signer_phone),
    signed_at: contract.signed_at,
    url: state.contractUrl(contract),
    created_at: contract.created_at,
  };
}

export function announcementOut(item) {
  return {
    id: item.id,
    level: item.level,
    title: item.title,
    body: item.body,
    url: item.url,
    starts_at: item.starts_at,
    ends_at: item.ends_at,
    published_at: item.published_at,
  };
}
