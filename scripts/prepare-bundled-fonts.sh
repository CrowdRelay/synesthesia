#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
OUT="$ROOT/assets/fonts/generated"
mkdir -p "$OUT"

sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    printf '%s\n' 'ERROR: sha256sum or shasum is required to verify bundled fonts.' >&2
    return 1
  fi
}

verify_sha256() {
  local expected="$1"
  local file="$2"
  local actual
  actual="$(sha256_file "$file")"
  [[ "$actual" == "$expected" ]] || {
    printf 'ERROR: SHA-256 mismatch for %s\nexpected=%s\nactual=%s\n' \
      "$file" "$expected" "$actual" >&2
    return 1
  }
}

fetch_verified() {
  local url="$1"
  local dst="$2"
  local expected="$3"

  if [[ -s "$dst" ]]; then
    if verify_sha256 "$expected" "$dst"; then
      printf 'SYNESTHESIA_FONT_CACHE=HIT file=%s\n' "${dst#$ROOT/}"
      return 0
    fi
    printf 'SYNESTHESIA_FONT_CACHE=INVALID file=%s action=refetch\n' "${dst#$ROOT/}" >&2
    rm -f "$dst"
  fi

  local tmp="$dst.tmp.$$"
  trap 'rm -f "$tmp"' RETURN
  curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --retry-all-errors \
    --output "$tmp" "$url"
  verify_sha256 "$expected" "$tmp"
  mv "$tmp" "$dst"
  trap - RETURN
}

# Godot SystemFont is not implemented by the Web export. Keep source control
# binary-free, but fetch redistributable OFL faces before import/export so Web,
# Android and desktop builds render the same typography. The content hashes are
# pinned so a mutable upstream branch can never silently change release output.
fetch_verified \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/knewave/Knewave-Regular.ttf" \
  "$OUT/SynesthesiaTitle.ttf" \
  "ed3bac761d755b89ab3082c844d4a623d63c7d6eef85d22ba1fb6c680e6a4436"
fetch_verified \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/bebasneue/BebasNeue-Regular.ttf" \
  "$OUT/SynesthesiaDisplay.ttf" \
  "08e4623805102d819f58601e46e345648846075e363b2ceb23313c2d1c83ec73"
fetch_verified \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/knewave/OFL.txt" \
  "$OUT/OFL-Knewave.txt" \
  "14b3fbd06078a869cf2ba96e6dacb852d373703c86ca7ad54a4cdd6e20fbab19"
fetch_verified \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/bebasneue/OFL.txt" \
  "$OUT/OFL-BebasNeue.txt" \
  "72082f6cb4d04be2ecf7cc7d9e1e7d73787f0af8a5a278a47cade70c16b78341"

printf 'SYNESTHESIA_FONTS=PASS title=Knewave display=BebasNeue mode=sha256-pinned-ofl\n'
