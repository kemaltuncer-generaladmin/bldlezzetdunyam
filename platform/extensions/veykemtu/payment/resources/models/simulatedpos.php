<?php

declare(strict_types=1);

use Igniter\Admin\Models\Status;

/**
 * Simülasyon POS'unun admin panel yapılandırması.
 *
 * Gerçek bir sağlayıcının anahtar/parola alanları YOKTUR — bu geçit hiçbir
 * yere bağlanmaz. Tek ayar, ödeme onaylandığında siparişin hangi duruma
 * geçeceğidir; boş bırakılırsa varsayılan sipariş durumu (`yeni`) kullanılır.
 */
return [
    'fields' => [
        'order_status' => [
            'label' => 'Ödeme sonrası sipariş durumu',
            'type' => 'select',
            'options' => [Status::class, 'getDropdownOptionsForOrder'],
            'comment' => 'Boş bırakılırsa varsayılan sipariş durumu kullanılır.',
        ],
    ],
    'rules' => [
        ['order_status', 'Ödeme sonrası sipariş durumu', 'nullable|integer'],
    ],
];
