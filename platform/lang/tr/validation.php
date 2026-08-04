<?php

declare(strict_types=1);

/**
 * Türkçe doğrulama mesajları.
 *
 * NEDEN GEREKLİ: sözleşme, hata gövdesindeki `message` ve `details`
 * değerlerinin **kullanıcıya doğrudan gösterilebilir Türkçe metin** olduğunu
 * söylüyor (`docs/03-api-sozlesmesi.md` §1.2). Laravel'in varsayılan
 * mesajları İngilizcedir; bu dosya olmadan istemci "The selected type is
 * invalid." gibi bir metni kullanıcıya gösterirdi.
 *
 * Admin paneli de aynı dosyadan yararlanır.
 */
return [
    'accepted' => ':attribute onaylanmalıdır.',
    'after' => ':attribute, :date tarihinden sonra olmalıdır.',
    'array' => ':attribute bir liste olmalıdır.',
    'before' => ':attribute, :date tarihinden önce olmalıdır.',
    'between' => [
        'array' => ':attribute :min ile :max arasında öğe içermelidir.',
        'file' => ':attribute :min ile :max kilobayt arasında olmalıdır.',
        'numeric' => ':attribute :min ile :max arasında olmalıdır.',
        'string' => ':attribute :min ile :max karakter arasında olmalıdır.',
    ],
    'boolean' => ':attribute doğru veya yanlış olmalıdır.',
    'confirmed' => ':attribute tekrarı eşleşmiyor.',
    'date' => ':attribute geçerli bir tarih değil.',
    'date_format' => ':attribute :format biçimine uymuyor.',
    'different' => ':attribute ile :other farklı olmalıdır.',
    'digits' => ':attribute :digits haneli olmalıdır.',
    'digits_between' => ':attribute :min ile :max hane arasında olmalıdır.',
    'email' => ':attribute geçerli bir e-posta adresi olmalıdır.',
    'exists' => 'Seçilen :attribute geçersiz.',
    'file' => ':attribute bir dosya olmalıdır.',
    'filled' => ':attribute boş bırakılamaz.',
    'gt' => [
        'numeric' => ':attribute :value değerinden büyük olmalıdır.',
        'string' => ':attribute :value karakterden uzun olmalıdır.',
    ],
    'gte' => [
        'numeric' => ':attribute en az :value olmalıdır.',
        'string' => ':attribute en az :value karakter olmalıdır.',
    ],
    'image' => ':attribute bir görsel olmalıdır.',
    'in' => 'Seçilen :attribute geçersiz.',
    'integer' => ':attribute tam sayı olmalıdır.',
    'json' => ':attribute geçerli bir JSON metni olmalıdır.',
    'lt' => [
        'numeric' => ':attribute :value değerinden küçük olmalıdır.',
        'string' => ':attribute :value karakterden kısa olmalıdır.',
    ],
    'lte' => [
        'numeric' => ':attribute en fazla :value olmalıdır.',
        'string' => ':attribute en fazla :value karakter olmalıdır.',
    ],
    'max' => [
        'array' => ':attribute en fazla :max öğe içermelidir.',
        'file' => ':attribute en fazla :max kilobayt olmalıdır.',
        'numeric' => ':attribute en fazla :max olmalıdır.',
        'string' => ':attribute en fazla :max karakter olmalıdır.',
    ],
    'min' => [
        'array' => ':attribute en az :min öğe içermelidir.',
        'file' => ':attribute en az :min kilobayt olmalıdır.',
        'numeric' => ':attribute en az :min olmalıdır.',
        'string' => ':attribute en az :min karakter olmalıdır.',
    ],
    'not_in' => 'Seçilen :attribute geçersiz.',
    'numeric' => ':attribute bir sayı olmalıdır.',
    'present' => ':attribute gönderilmelidir.',
    'regex' => ':attribute biçimi geçersiz.',
    'required' => ':attribute zorunludur.',
    'required_if' => ':other :value olduğunda :attribute zorunludur.',
    'required_with' => ':values gönderildiğinde :attribute zorunludur.',
    'required_without' => ':values gönderilmediğinde :attribute zorunludur.',
    'same' => ':attribute ile :other eşleşmelidir.',
    'size' => [
        'array' => ':attribute :size öğe içermelidir.',
        'file' => ':attribute :size kilobayt olmalıdır.',
        'numeric' => ':attribute :size olmalıdır.',
        'string' => ':attribute :size karakter olmalıdır.',
    ],
    'string' => ':attribute bir metin olmalıdır.',
    'unique' => ':attribute zaten kullanılıyor.',
    'url' => ':attribute geçerli bir adres olmalıdır.',

    'custom' => [],

    /**
     * Alan adları — mesajlarda `:attribute` yerine geçer.
     *
     * Sözleşmedeki alan adları snake_case'tir; kullanıcıya "payment_method"
     * değil "Ödeme yöntemi" gösterilmeli.
     */
    'attributes' => [
        'first_name' => 'Ad',
        'last_name' => 'Soyad',
        'email' => 'E-posta',
        'telephone' => 'Telefon',
        'password' => 'Şifre',
        'kvkk_accepted' => 'KVKK onayı',
        'location_id' => 'Vitrin',
        'items' => 'Ürünler',
        'items.*.menu_id' => 'Ürün',
        'items.*.quantity' => 'Adet',
        'items.*.note' => 'Ürün notu',
        'delivery_type' => 'Teslimat tipi',
        'address' => 'Adres',
        'address.line1' => 'Adres satırı',
        'address.district' => 'İlçe',
        'address.city' => 'Şehir',
        'requested_at' => 'İstenen teslim zamanı',
        'payment_method' => 'Ödeme yöntemi',
        'customer_note' => 'Sipariş notu',
        'status' => 'Durum',
        'type' => 'Fiş tipi',
        'printed_at' => 'Basım zamanı',
        'pairing_code' => 'Eşleme kodu',
        'device_name' => 'Cihaz adı',
        'fcm_token' => 'Bildirim anahtarı',
        'app_id' => 'Uygulama',
        'after' => 'Sipariş kimliği',
        'since' => 'Zaman damgası',
    ],
];
