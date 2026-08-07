<?php

declare(strict_types=1);

/**
 * Arayüz dili Türkçedir (`AGENTS.md` §4) — burada ayrı bir İngilizce çeviri
 * YOKTUR, Türkçe dosyanın kendisi kullanılır.
 *
 * NEDEN BU DOSYA VAR: gerekçenin tamamı `en/default.php` üzerindedir —
 * `config/app.php` içinde `locale` ve `fallback_locale` `en`'dir ve bu dosya
 * olmadan etiketler ekranda ham anahtar olarak görünür.
 *
 * `en/sitecontent.php` gibi ELLE ÇEVRİLMEDİ: o dosyanın metinleri uzun
 * yönetici açıklamaları ve iki dilde ayrı yazıldıklarında biri güncellenip
 * diğeri unutuluyor. Takma ad, sessizce eskiyen ikinci bir kopya üretmez.
 */
return require __DIR__.'/../tr/quoterequest.php';
