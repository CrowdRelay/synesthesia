#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

GODOT_VERSION="4.7.1-stable"
GODOT_RELEASE_VERSION="4.7.1.stable"
GODOT_EDITOR_SHA256="c7ff14fd28472c8d4f193043de30278dcf7e5241a1dcf7566b02e27addaa33ba"
GODOT_TEMPLATES_SHA256="86409db6200b6f8fd3230989c2d2002851f3dd18acf11d7bdbafddf5a0dd0f72"
CACHE_DIR="${GODOT_CACHE_DIR:-$ROOT/.cache/godot-$GODOT_VERSION}"
GODOT_BIN="${GODOT_BIN:-}"
OUTPUT="${SYNESTHESIA_LINUX_OUTPUT:-$ROOT/build/linux/synesthesia.x86_64}"

check_sha256() {
  local expected="$1"
  local file="$2"
  local actual
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$file" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  else
    echo 'ERROR: neither sha256sum nor shasum is available' >&2
    return 1
  fi
  [[ "$actual" == "$expected" ]] || {
    printf 'ERROR: checksum mismatch for %s\nexpected=%s\nactual=%s\n' "$file" "$expected" "$actual" >&2
    return 1
  }
}

write_sha256() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file"
  else
    shasum -a 256 "$file"
  fi
}

if [[ "${SYNESTHESIA_SKIP_SOURCE_VALIDATION:-0}" != "1" ]]; then
  ./scripts/validate-source.sh
fi

# Rust-primary Linux output can only be built natively on the supported release
# runner. Do not silently export a GDScript-only Linux artifact from macOS.
[[ "$(uname -s):$(uname -m)" == "Linux:x86_64" ]] || {
  echo 'ERROR: Rust-primary Linux release requires a Linux x86_64 build host' >&2
  exit 1
}

mkdir -p "$CACHE_DIR"
archive="$CACHE_DIR/editor.zip"
if [[ -z "$GODOT_BIN" ]]; then
  cached_bin="$CACHE_DIR/Godot_v${GODOT_VERSION}_linux.x86_64"
  if [[ -x "$cached_bin" ]]; then
    GODOT_BIN="$cached_bin"
  elif command -v godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot)"
  else
    if [[ ! -s "$archive" ]]; then
      curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --retry-all-errors \
        --output "$archive" \
        "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
    fi
    check_sha256 "$GODOT_EDITOR_SHA256" "$archive"
    unzip -q -o "$archive" -d "$CACHE_DIR"
    chmod +x "$cached_bin"
    GODOT_BIN="$cached_bin"
  fi
fi
[[ -x "$GODOT_BIN" ]] || { printf 'ERROR: Godot binary is not executable: %s\n' "$GODOT_BIN" >&2; exit 1; }
export GODOT_BIN

TEMPLATE_DIR="$(./scripts/godot-runtime-data-dir.sh Linux)/export_templates/$GODOT_RELEASE_VERSION"
LINUX_TEMPLATE="$TEMPLATE_DIR/linux_release.x86_64"
if [[ ! -s "$LINUX_TEMPLATE" ]]; then
  mkdir -p "$TEMPLATE_DIR"
  template_archive="$CACHE_DIR/templates.tpz"
  if [[ ! -s "$template_archive" ]]; then
    curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --retry-all-errors \
      --output "$template_archive" \
      "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"
  else
    printf 'SYNESTHESIA_GODOT_TEMPLATE_CACHE=HIT archive=%s\n' "$template_archive"
  fi
  check_sha256 "$GODOT_TEMPLATES_SHA256" "$template_archive"
  tmp_template="${LINUX_TEMPLATE}.tmp"
  rm -f "$tmp_template"
  unzip -p "$template_archive" templates/linux_release.x86_64 > "$tmp_template"
  [[ -s "$tmp_template" ]] || { echo 'ERROR: Linux release template missing from Godot archive' >&2; rm -f "$tmp_template"; exit 1; }
  mv "$tmp_template" "$LINUX_TEMPLATE"
fi
printf 'SYNESTHESIA_LINUX_TEMPLATE=PASS scope=release-x86_64 bytes=%s\n' "$(wc -c < "$LINUX_TEMPLATE" | tr -d ' ')"

SYNESTHESIA_RUST_PROFILE=release ./scripts/build-rust-native.sh host

rm -rf "$(dirname "$OUTPUT")"
mkdir -p "$(dirname "$OUTPUT")"
"$GODOT_BIN" --headless --path "$ROOT" --export-release Linux "$OUTPUT"
[[ -s "$OUTPUT" ]] || { printf 'ERROR: Godot did not produce Linux binary: %s\n' "$OUTPUT" >&2; exit 1; }

rust_entry="$(find "$(dirname "$OUTPUT")" -type f -name 'libsynesthesia_gdext.so' -print -quit)"
[[ -n "$rust_entry" && -s "$rust_entry" ]] || {
  echo 'ERROR: Linux export completed without libsynesthesia_gdext.so' >&2
  exit 1
}
write_sha256 "$OUTPUT" > "${OUTPUT}.sha256"
printf 'SYNESTHESIA_RUST_LINUX_EXPORT=PASS library=%s\n' "${rust_entry#$ROOT/}"
printf 'SYNESTHESIA_LINUX_BUILD=PASS output=%s bytes=%s sha256=%s rust=1\n' \
  "$OUTPUT" "$(wc -c < "$OUTPUT" | tr -d ' ')" "$(cut -d' ' -f1 < "${OUTPUT}.sha256")"
