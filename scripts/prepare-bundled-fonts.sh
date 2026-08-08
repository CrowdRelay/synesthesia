#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
OUT="$ROOT/assets/fonts/generated"
mkdir -p "$OUT"

fetch() {
  local url="$1"
  local dst="$2"
  if [[ -s "$dst" ]]; then
    return 0
  fi
  curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --retry-all-errors \
    --output "$dst.tmp" "$url"
  mv "$dst.tmp" "$dst"
}

# Godot SystemFont is not implemented by the Web export. Keep source control
# binary-free, but fetch redistributable OFL faces before import/export so Web,
# Android and desktop builds render the same typography.
fetch \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/knewave/Knewave-Regular.ttf" \
  "$OUT/SynesthesiaTitle.ttf"
fetch \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/bebasneue/BebasNeue-Regular.ttf" \
  "$OUT/SynesthesiaDisplay.ttf"
fetch \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/knewave/OFL.txt" \
  "$OUT/OFL-Knewave.txt"
fetch \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/bebasneue/OFL.txt" \
  "$OUT/OFL-BebasNeue.txt"

printf 'SYNESTHESIA_FONTS=PASS title=Knewave display=BebasNeue mode=build-fetched-ofl\n'
