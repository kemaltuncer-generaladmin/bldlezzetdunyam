<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services\Geocoding;

use RuntimeException;

/**
 * Sağlayıcıya ulaşılamadı, zaman aşımına uğradı ya da anlaşılmaz bir yanıt
 * döndü.
 *
 * `ApiException` DEĞİL ve bilerek: `ApiException` istemciye gösterilecek bir
 * hatadır, bu ise İÇERİDE YUTULAN bir arızadır. `AddressLookup` bunu
 * yakalar, günlüğe yazar ve boş sonuç döner — sözleşme
 * (`docs/openapi.yaml` §/addresses/suggest) sağlayıcı arızasında `200` +
 * boş `data` istiyor. Dışarıdaki bir servisin kendi sipariş akışımızı
 * durdurabilmesi, öneri gibi bir kolaylık için ödenecek bedelden çok daha
 * pahalı.
 */
final class GeocoderUnavailable extends RuntimeException
{
}
