<?php

declare(strict_types=1);

return [
    'permission' => 'Subscriptions',
    'side_menu' => 'Subscriptions',
    'closed_side_menu' => 'Closed days',

    'text_title' => 'Subscriptions',
    'text_empty' => 'No subscriptions yet.',
    'text_filter_search' => 'Search customer email',
    'text_form_name' => 'Subscription',
    'text_edit_title' => 'Subscription: price and manage',
    'confirm_delete' => 'Are you sure you want to delete this subscription?',

    'column_customer' => 'Customer',
    'column_status' => 'Status',
    'column_start' => 'Start',
    'column_end' => 'End',
    'column_quantity' => 'Daily quantity',
    'column_price' => 'Agreed price',
    'column_payment' => 'Payment',

    'status_pending' => 'Request (awaiting price)',
    'status_active' => 'Active',
    'status_paused' => 'Paused',
    'status_cancelled' => 'Cancelled',

    'section_pricing' => 'Price and status',
    'section_pricing_comment' => 'Enter the agreed per-portion price and activate the subscription.',
    'help_status' => 'To approve a request, set the price and mark it Active.',
    'payment_account' => 'Current account (month-end)',
    'payment_prepaid' => 'Prepaid (monthly)',
    'label_agreed_price' => 'Agreed price per portion (TRY)',
    'help_agreed_price' => 'e.g. 150 or 150.00. Left empty means unpriced.',
    'label_quantity' => 'Daily portion quantity',
    'section_details' => 'Customer request (read only)',
    'section_details_comment' => 'Schedule and products were set by the customer.',
    'no_price' => '—',

    'day_1' => 'Mon',
    'day_2' => 'Tue',
    'day_3' => 'Wed',
    'day_4' => 'Thu',
    'day_5' => 'Fri',
    'day_6' => 'Sat',
    'day_7' => 'Sun',

    'detail_period' => 'Period',
    'detail_open_ended' => 'open-ended',
    'detail_days' => 'Days',
    'detail_delivery' => 'Delivery',
    'detail_lines' => 'Products',
    'detail_no_lines' => 'No product lines.',

    'closed_title' => 'Closed days',
    'closed_empty' => 'No closed days defined.',
    'closed_form_name' => 'Closed day',
    'closed_create_title' => 'Add closed day',
    'closed_edit_title' => 'Edit closed day',
    'closed_date' => 'Date',
    'closed_date_help' => 'Production is skipped on this day (public holiday, etc.).',
    'closed_description' => 'Description',

    'dashboard_label' => 'Corporate summary',
    'dashboard_active' => 'Active subscriptions',
    'dashboard_portions' => 'Portions tomorrow',
    'dashboard_closed' => 'Closed day',
    'dashboard_balance' => 'Open account',
];
