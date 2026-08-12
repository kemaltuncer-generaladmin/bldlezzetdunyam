<?php

declare(strict_types=1);

// Refund tracking screen (B-15) strings.
return [
    'side_menu' => 'Refunds',
    'text_title' => 'Payment refunds',
    'text_empty' => 'No pending or past refunds.',
    'text_search' => 'Search order number or reason',

    'column_order' => 'Order',
    'column_created' => 'Opened',
    'column_amount' => 'Amount',
    'column_gateway' => 'Channel',
    'column_status' => 'Status',
    'column_reason' => 'Reason',
    'column_action' => 'Action',
    'filter_date' => 'Date range',
    'revision' => 'Revision',

    'status_manual' => 'Awaiting manual refund',
    'status_pending' => 'With provider',
    'status_failed' => 'Failed',
    'status_succeeded' => 'Completed',

    'button_settle' => 'Refunded',
    'confirm_settle' => 'The refund of %s TRY for order S-%s will be marked as sent BY HAND/TRANSFER. Are you sure the money was actually sent?',
    'alert_settled' => 'The refund for order S-%s was marked as completed.',
    'alert_missing' => 'Refund record not found.',
    'alert_already_settled' => 'This refund is already closed. It cannot be marked twice.',
];
