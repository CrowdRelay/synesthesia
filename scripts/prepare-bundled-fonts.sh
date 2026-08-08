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
# Android and desktop builds render the same typography.
#
# New Rocker is used for titles because it keeps the hand-drawn/heavy character
# while shipping Latin Extended glyphs (including Polish). Google Fonts exposes
# its immutable Git blob id; verify that content id after download so a mutable
# branch can never silently change release output.

git_blob_sha1() {
  local file="$1"
  python3 - "$file" <<'PYHASH'
import hashlib
from pathlib import Path
import sys
path = Path(sys.argv[1])
data = path.read_bytes()
h = hashlib.sha1()
h.update(f"blob {len(data)}\0".encode())
h.update(data)
print(h.hexdigest())
PYHASH
}

fetch_verified_git_blob() {
  local url="$1"
  local dst="$2"
  local expected_blob="$3"

  if [[ -s "$dst" ]]; then
    local existing
    existing="$(git_blob_sha1 "$dst")"
    if [[ "$existing" == "$expected_blob" ]]; then
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
  local actual
  actual="$(git_blob_sha1 "$tmp")"
  [[ "$actual" == "$expected_blob" ]] || {
    printf 'ERROR: Git blob mismatch for %s\nexpected=%s\nactual=%s\n' \
      "$dst" "$expected_blob" "$actual" >&2
    return 1
  }
  mv "$tmp" "$dst"
  trap - RETURN
}

fetch_verified_git_blob \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/newrocker/NewRocker-Regular.ttf" \
  "$OUT/SynesthesiaTitle.ttf" \
  "2b7993d3c19d303b4f05b06983479e415972f93a"
fetch_verified \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/bebasneue/BebasNeue-Regular.ttf" \
  "$OUT/SynesthesiaDisplay.ttf" \
  "08e4623805102d819f58601e46e345648846075e363b2ceb23313c2d1c83ec73"
fetch_verified_git_blob \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/newrocker/OFL.txt" \
  "$OUT/OFL-NewRocker.txt" \
  "60e277905418d159e4b90f57773754e9fb909df2"
fetch_verified \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/bebasneue/OFL.txt" \
  "$OUT/OFL-BebasNeue.txt" \
  "72082f6cb4d04be2ecf7cc7d9e1e7d73787f0af8a5a278a47cade70c16b78341"

printf 'SYNESTHESIA_FONTS=PASS title=NewRocker display=BebasNeue mode=content-pinned-ofl latin-ext=required\n'
