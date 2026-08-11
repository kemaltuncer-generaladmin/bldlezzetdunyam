<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Middleware;

use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * BBD Store webhook imzası — `X-BBD-Signature` (K-16).
 *
 * NEDEN TOKEN DEĞİL İMZA: BBD ayrı bir sunucudaki ayrı bir proje ve
 * arada paylaşılan tek şey bir sır. Sabit bir Bearer token, her istekte
 * ağdan geçen ve loglara düşen bir parola demekti; HMAC imzası sırrı hiç
 * göndermez ve gövdenin de değişmediğini kanıtlar.
 *
 * HAM GÖVDE ÜZERİNDE hesaplanıyor, ayrıştırılmış diziden yeniden
 * serileştirilmiş JSON üzerinde değil: boşluk ve anahtar sırası imzayı
 * değiştirir ve iki taraf asla tutturamaz.
 *
 * `hash_equals` KULLANILIYOR, `===` DEĞİL: eşitlik karşılaştırması ilk
 * farklı baytta duruyor ve süre farkından imza tahmin edilebiliyor.
 */
class VerifyBbdSignature
{
    public function handle(Request $request, Closure $next): Response
    {
        $secret = (string) env('BBD_WEBHOOK_SECRET', '');

        // SIR TANIMLI DEĞİLSE UÇ KAPALIDIR. Boş sırla imza doğrulamak,
        // herkesin geçebildiği bir kapı demek olurdu.
        if ($secret === '') {
            return $this->reject('BBD entegrasyonu yapılandırılmamış.');
        }

        $provided = (string) $request->header('X-BBD-Signature', '');
        $expected = 'sha256='.hash_hmac('sha256', $request->getContent(), $secret);

        if ($provided === '' || !hash_equals($expected, $provided)) {
            return $this->reject('İmza doğrulanamadı.');
        }

        return $next($request);
    }

    private function reject(string $message): JsonResponse
    {
        // Sözleşmedeki hata biçimi (`docs/03` §1.3). Hangi sebepten
        // reddedildiği AYRINTILANDIRILMIYOR: "sır tanımsız" ile "imza
        // yanlış" ayrımı, saldırgana yapılandırma bilgisi verir.
        return new JsonResponse([
            'error' => [
                'code' => 'UNAUTHENTICATED',
                'message' => $message,
                'details' => new \stdClass(),
            ],
        ], 401);
    }
}
