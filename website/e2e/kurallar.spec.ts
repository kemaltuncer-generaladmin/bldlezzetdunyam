import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { expect, test } from '@playwright/test';

import {
  DEFAULT_HARD_MAX,
  DEFAULT_LOW_THRESHOLD,
  maxAddable,
  stockLevel,
  type StockLevel,
} from '../lib/stock-policy';

/**
 * SATIŞ KURALLARI — altın veri kümesi koşumu.
 *
 * `docs/contract/sales-rules.cases.json` stok aritmetiğinin NORMATİF
 * kaynağı; aynı vakaları `packages/core` (Dart) ve `platform/tests/Unit`
 * (PHP) da koşuyor. Buradaki test onların TypeScript ayağı: kural değişince
 * üç dil birden kırılsın, tek bir dilde sessizce sapmak mümkün olmasın.
 *
 * TARAYICI AÇMIYOR. `page` fixture'ı istenmiyor, ağ isteği yok; test saf bir
 * fonksiyon tablosunu doğruluyor. Playwright'ta durmasının sebebi projenin
 * başka bir birim testi koşucusu olmaması — ayrı bir koşucu kurmak, aynı
 * doğrulama için ikinci bir bağımlılık ve ikinci bir CI adımı demekti.
 *
 * DOSYA ÇALIŞMA ZAMANINDA OKUNUYOR, kopyalanmıyor. Vakaları buraya elle
 * yazsaydık kaynak ile testin ayrışması an meselesiydi ve testin geçmesi
 * hiçbir şey kanıtlamazdı.
 */

type CaseInput = {
  day_remaining: number | null;
  item_remaining: number | null;
  in_cart_day: number;
  in_cart_item: number;
  hard_max: number;
  low_threshold: number;
};

type GoldenCase = {
  id: string;
  note: string;
  input: CaseInput;
  expect: { max_addable: number; stock_level: StockLevel };
};

type GoldenFile = {
  version: number;
  defaults: { hard_max: number; low_threshold: number };
  cases: GoldenCase[];
};

const CASES_PATH = join(__dirname, '..', '..', 'docs', 'contract', 'sales-rules.cases.json');

const golden = JSON.parse(readFileSync(CASES_PATH, 'utf8')) as GoldenFile;

/**
 * Vakadaki tek girdiden STOK BANDI girdisini kurar — dosyanın kendi
 * `case_input_binding` bölümündeki tarif.
 *
 * Band gün tavanı ile kalem tavanının DAR OLANINI anlatır ve SEPETTEN
 * ARINDIRILMAZ: "son 3 porsiyon" rozeti herkes için aynı sayıdır.
 * Uygulamadaki karşılığı `lib/api/daily-menu.ts` → `itemStock`; o okuyucu
 * sözleşme nesnelerini aldığı için (ve `server-only` zincirine bağlı olduğu
 * için) burada aynı bağlama ham sayılarla tekrarlanıyor.
 */
function effectiveRemaining(input: CaseInput): number | null {
  if (input.day_remaining === null) return input.item_remaining;
  if (input.item_remaining === null) return input.day_remaining;

  return Math.min(input.day_remaining, input.item_remaining);
}

test.describe('Satış kuralları — stok aritmetiği', () => {
  test('altın veri kümesi okunabiliyor', () => {
    expect(golden.version, 'Veri kümesi sürümü değiştiyse bu test gözden geçirilmeli').toBe(1);
    expect(golden.cases.length).toBeGreaterThan(0);

    const ids = golden.cases.map((item) => item.id);
    expect(new Set(ids).size, 'Vaka kimlikleri benzersiz olmalı').toBe(ids.length);
  });

  test('kod içindeki varsayılanlar veri kümesiyle aynı', () => {
    // Varsayılanlar iki yerde yazılı; ayrışırlarsa vakaların hepsi kendi
    // `hard_max`/`low_threshold` değerini taşıdığı için hiçbiri kırılmaz ve
    // sapma yalnız sahada görünürdü.
    expect(DEFAULT_HARD_MAX).toBe(golden.defaults.hard_max);
    expect(DEFAULT_LOW_THRESHOLD).toBe(golden.defaults.low_threshold);
  });

  for (const item of golden.cases) {
    test(`vaka: ${item.id}`, () => {
      const addable = maxAddable({
        dayRemaining: item.input.day_remaining,
        itemRemaining: item.input.item_remaining,
        alreadyInCartForDay: item.input.in_cart_day,
        alreadyInCartForItem: item.input.in_cart_item,
        hardMax: item.input.hard_max,
      });

      const level = stockLevel({
        remaining: effectiveRemaining(item.input),
        lowThreshold: item.input.low_threshold,
      });

      expect(addable, item.note).toBe(item.expect.max_addable);
      expect(level, item.note).toBe(item.expect.stock_level);
    });
  }

  /**
   * Sözleşmedeki alan İSTEĞE BAĞLI (`remaining_portions?`), yani eksik
   * gelebiliyor. Veri kümesi yalnız `null` taşıyor çünkü JSON'da `undefined`
   * yok; ikisinin AYNI ele alınması buranın işi.
   */
  test('eksik alan (undefined) da sınırsız sayılır', () => {
    expect(
      maxAddable({
        dayRemaining: undefined,
        itemRemaining: undefined,
        alreadyInCartForDay: 40,
        alreadyInCartForItem: 40,
        hardMax: DEFAULT_HARD_MAX,
      }),
    ).toBe(59);

    expect(stockLevel({ remaining: undefined })).toBe('unlimited');
  });
});
