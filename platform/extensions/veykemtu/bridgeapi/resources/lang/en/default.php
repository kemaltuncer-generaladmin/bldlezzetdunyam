<?php

declare(strict_types=1);

/**
 * Arayüz dili Türkçedir (`AGENTS.md` §4) — burada ayrı bir İngilizce çeviri
 * YOKTUR, Türkçe dosyanın kendisi kullanılır.
 *
 * NEDEN BU DOSYA VAR: `config/app.php` içinde `locale` ve `fallback_locale`
 * `en`'dir ve TastyIgniter admin panelinde yönetici dili de varsayılan olarak
 * `en` gelir. Bu dosya olmadan çevirmen anahtarı bulamaz ve etiketler
 * ekranda ham anahtar olarak ("veykemtu.bridgeapi::default.label_busy")
 * görünür. Kopya değil, aynı diziyi geri veren tek satırlık takma addır.
 */
return require __DIR__.'/../tr/default.php';
