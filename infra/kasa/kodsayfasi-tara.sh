#!/usr/bin/env bash
# ESC/POS kod sayfası tarayıcı — Türkçe karakterlerin hangi `ESC t n`
# değeriyle doğru bastığını bulur.
#
# NEDEN GEREKLİ: ESC/POS kod sayfası numaraları standart DEĞİLDİR. Doküman
# PC857 için `ESC t 13` diyordu; sahadaki yazıcıda (0483:5720 aaaait Printer)
# o değer Türkçe harfleri boşluk olarak bastı. Doğru değer bu betikle
# bulundu: n = 29.
#
# Yazıcı değişirse bu betiği tekrar çalıştırın ve çıkan fişte hangi satırın
# doğru olduğuna bakın, sonra değeri şuraya yazın:
#   packages/core/lib/src/escpos/  (kod)
#   docs/05-mutfakapp.md §5.2      (doküman)
#
# Kullanım:  ./kodsayfasi-tara.sh [cihaz] [baslangic] [bitis]
set -euo pipefail

DEV="${1:-/dev/thermal0}"
FROM="${2:-0}"
TO="${3:-47}"

if [ ! -w "$DEV" ]; then
  echo "HATA: $DEV yazılabilir değil." >&2
  echo "udev kuralı kurulu mu? infra/kasa/99-thermal-printer.rules" >&2
  exit 1
fi

{
  printf '\x1B\x40'
  printf '\x1B\x61\x01KOD SAYFASI TARAMASI\n'
  printf 'dogru satir: cgiosu CGIOSU\n\x1B\x61\x00'
  printf -- '--------------------------------\n'
  for n in $(seq "$FROM" "$TO"); do
    printf '\x1B\x74'
    printf "$(printf '\\x%02X' "$n")"
    printf 'n=%02d ' "$n"
    # PC857 düzenindeki Türkçe baytlar: ç ğ ı ö ş ü / Ç Ğ İ Ö Ş Ü
    printf '\x87\xA7\x8D\x94\x9F\x81 \x80\xA6\x98\x99\x9E\x9A\n'
  done
  printf -- '--------------------------------\n'
  printf 'Dogru n degerini not edin.\n\n\n\n'
  printf '\x1D\x56\x42\x00'
} > "$DEV"

echo "Tarama gönderildi ($DEV, n=$FROM..$TO). Fişte doğru satırı bulun."
