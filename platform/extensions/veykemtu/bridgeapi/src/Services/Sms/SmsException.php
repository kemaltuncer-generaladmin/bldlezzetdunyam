<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services\Sms;

use RuntimeException;

/** SMS gönderilemedi — sağlayıcı hatası, ağ hatası ya da eksik yapılandırma. */
class SmsException extends RuntimeException {}
