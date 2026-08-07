#!/usr/bin/env python3
"""`build/web` çıktısını localhost'ta sunar.

## Neden `python -m http.server` yetmiyor?

Uygulama `go_router` kullanıyor ve web'de yol tabanlı adresler üretiyor
(`/menu`, `/orders/12`). Düz dosya sunucusu bu yollarda `404` döner çünkü
diskte öyle bir dosya yok. Tek sayfa uygulamalarında istek karşılığı bulunmayan
her yol `index.html`'e düşmeli; yönlendirmeyi uygulamanın kendisi yapar.

## Bu ne DEĞİL?

Üretim sunucusu değil. `musteriapp` Android ve iOS'a çıkar (`docs/07` §1);
web hedefi yalnızca uygulamayı cihaz/emülatör olmadan görebilmek için var ve
`musteriapp/web/` bilinçli olarak `.gitignore`'da.

Kullanım:

    flutter build web --release --dart-define=BLD_API_BASE_URL=http://localhost:8080/api
    python3 tool/serve_web.py            # http://127.0.0.1:8090
    python3 tool/serve_web.py 9000       # başka port
"""

from __future__ import annotations

import os
import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "build" / "web"


class SpaHandler(SimpleHTTPRequestHandler):
    """Dosyası olmayan yolları `index.html`'e düşürür."""

    def send_head(self):  # noqa: D102 — üst sınıfın sözleşmesi
        path = Path(self.translate_path(self.path))
        # Dizin isteklerinde üst sınıf zaten index.html arıyor; yalnızca
        # var olmayan DOSYA yollarını çeviriyoruz.
        if not path.exists() and not self.path.startswith("/assets"):
            self.path = "/index.html"
        return super().send_head()

    def end_headers(self):
        # Geliştirme sunucusu: tarayıcı eski derlemeyi tutmasın.
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        # Her varlık isteği için satır basmak konsolu okunmaz yapıyor;
        # yalnızca hatalar önemli.
        if args and str(args[1]).startswith(("4", "5")):
            super().log_message(fmt, *args)


def main() -> int:
    if not ROOT.is_dir():
        print(f"HATA: {ROOT} yok. Önce `flutter build web` çalıştırın.", file=sys.stderr)
        return 1

    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8090
    os.chdir(ROOT)
    handler = partial(SpaHandler, directory=str(ROOT))

    with ThreadingHTTPServer(("127.0.0.1", port), handler) as httpd:
        print(f"musteriapp → http://127.0.0.1:{port}  (durdurmak için Ctrl+C)")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
