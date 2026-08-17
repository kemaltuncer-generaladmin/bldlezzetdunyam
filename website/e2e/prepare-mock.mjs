/**
 * `npm run build`'DEN ÖNCE koşan tek adım — `playwright.config.ts` çağırıyor.
 *
 * Tarif `open-ordering.mjs` içinde ve testlerle ORTAK; burada yalnız
 * çalıştırılabilir giriş var. Ayrı dosya olmasının sebebi o modülün başındaki
 * notta: Playwright modülü CommonJS'e çevirdiği için `import.meta` ile
 * "doğrudan mı çalıştırıldım" kontrolü yapılamıyor.
 */
import { openOrdering } from './open-ordering.mjs';

await openOrdering();
