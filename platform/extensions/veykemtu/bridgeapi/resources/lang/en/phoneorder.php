<?php

declare(strict_types=1);

// Phone order entry screen (B-13) strings.
return [
    'permission' => 'Enter phone orders (creates orders and customers)',
    'side_menu' => 'Phone order',
    'text_title' => 'Order taken by phone',

    'section_customer' => 'Customer',
    'label_customer' => 'Existing customer',
    'option_new_customer' => '— Create new customer —',
    'help_new_customer' => 'If the customer is not in the system, fill in the three fields below; a corporate account is created together with the order. The current account starts CLOSED — set a limit under Corporate → Current accounts to allow credit.',
    'label_org_name' => 'Company name',
    'label_contact' => 'Contact person',
    'label_phone' => 'Phone',

    'section_items' => 'Items',
    'column_item' => 'Item',
    'column_quantity' => 'Qty',
    'column_line_note' => 'Line note (shown on the kitchen ticket)',
    'button_add_line' => 'Add row',
    'help_items' => 'Rows with quantity 0 or no item selected are ignored — there is no need to clear unused rows. Prices come from the menu; they cannot be typed in.',

    'section_delivery' => 'Delivery and payment',
    'label_delivery_type' => 'Delivery type',
    'delivery' => 'Delivery',
    'pickup' => 'Pickup',
    'label_date' => 'Delivery date',
    'label_time' => 'Delivery time',
    'help_time' => 'Leaving the time empty marks the order as "as soon as possible". A future date may be chosen; the order appears in that day\'s list.',
    'label_payment' => 'Payment method',
    'payment_cash' => 'Pay on delivery',
    'payment_account' => 'Charge to current account',
    'payment_online' => 'Card (simulated)',
    'label_address' => 'Address',
    'label_district' => 'District',
    'label_city' => 'City',
    'label_address_note' => 'Directions (door, floor, landmark)',
    'label_note' => 'Order note',

    'section_subscription' => 'Subscription link',
    'label_subscription' => 'Subscription',
    'option_no_subscription' => '— Not linked to a subscription —',
    'portion' => 'portions',
    'help_subscription' => 'A linked order appears in the kitchen subscription production plan and is billed to that contract on the month-end statement. Only the selected customer\'s subscriptions are listed.',

    'section_extra' => 'Extra portions on a subscription (future day)',
    'help_extra' => 'This section DOES NOT create an order. It raises the portion count of a future service day; the order itself is created by the nightly generation job. For cases like "Thursday will be 10 people more". Enter extra portions for today through the order form above — doing both cooks the same food twice.',
    'label_extra_date' => 'Service day',
    'label_extra_quantity' => 'Extra portions',
    'button_extra' => 'Add portions',

    'confirm_create' => 'The order will be created and sent to the kitchen IMMEDIATELY; a ticket will print. Continue?',
    'button_create' => 'Create order and send to kitchen',

    'alert_no_location' => 'No active location found. Enable the location under Settings → Locations.',
    'alert_no_items' => 'Select at least one item and enter a quantity.',
    'alert_customer_missing' => 'The selected customer was not found.',
    'alert_new_customer_fields' => 'Company name and phone are required for a new customer.',
    'alert_subscription_missing' => 'The selected subscription was not found.',
    'alert_subscription_mismatch' => 'The selected subscription belongs to another customer. A subscription can only be linked to its owner\'s order.',
    'alert_created' => 'Order #%s was created and sent to the kitchen.',
    'alert_confirm_failed' => 'Order #%s was created but COULD NOT BE SENT TO THE KITCHEN (%s). Confirm it manually from the order list.',
    'alert_extra_quantity' => 'Extra portion count must be greater than zero.',
    'alert_extra_date' => 'Choose a service day.',
    'alert_extra_past' => 'Extra portions cannot be added for a past day — that day was already produced.',
    'alert_extra_saved' => 'Total portions for %s updated to %s.',
    'exception_note' => 'Extra portions added from the admin panel',
];
