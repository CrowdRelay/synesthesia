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

check_sha256() {
  local expected="$1"
  local file="$2"
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s  %s\n' "$expected" "$file" | sha256sum --check --strict
  else
    local actual
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
    [[ "$actual" == "$expected" ]] || {
      printf 'ERROR: checksum mismatch for %s\n' "$file" >&2
      return 1
    }
  fi
}

run_godot_checked() {
  local label="$1"
  shift
  local log
  log="$(mktemp "${TMPDIR:-/tmp}/synesthesia-godot.XXXXXX.log")"
  if ! "$GODOT_BIN" "$@" 2>&1 | tee "$log"; then
    printf 'ERROR: Godot command failed: %s\n' "$label" >&2
    rm -f "$log"
    return 1
  fi
  if grep -Eiq '(^|[[:space:]])(SCRIPT ERROR:|ERROR:|Parse Error:|Compile Error:|Failed loading resource:|Warning treated as error)' "$log"; then
    printf 'ERROR: Godot emitted a fatal diagnostic: %s\n' "$label" >&2
    rm -f "$log"
    return 1
  fi
  rm -f "$log"
}

if [[ -z "$GODOT_BIN" ]]; then
  if command -v godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot)"
  elif command -v Godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v Godot)"
  else
    mkdir -p "$CACHE_DIR"
    archive="$CACHE_DIR/editor.zip"
    GODOT_BIN="$CACHE_DIR/Godot_v${GODOT_VERSION}_linux.x86_64"
    if [[ ! -x "$GODOT_BIN" ]]; then
      curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --retry-all-errors \
        --output "$archive" \
        "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
      check_sha256 "$GODOT_EDITOR_SHA256" "$archive"
      unzip -q -o "$archive" -d "$CACHE_DIR"
      chmod +x "$GODOT_BIN"
    fi
  fi
fi

[[ -x "$GODOT_BIN" ]] || {
  printf 'ERROR: Godot binary is not executable: %s\n' "$GODOT_BIN" >&2
  exit 1
}

TEMPLATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$GODOT_RELEASE_VERSION"
if [[ ! -f "$TEMPLATE_DIR/web_release.zip" ]]; then
  mkdir -p "$CACHE_DIR/templates-unpack" "$TEMPLATE_DIR"
  template_archive="$CACHE_DIR/templates.tpz"
  curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --retry-all-errors \
    --output "$template_archive" \
    "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"
  check_sha256 "$GODOT_TEMPLATES_SHA256" "$template_archive"
  rm -rf "$CACHE_DIR/templates-unpack"/*
  unzip -q "$template_archive" -d "$CACHE_DIR/templates-unpack"
  cp -R "$CACHE_DIR/templates-unpack/templates/." "$TEMPLATE_DIR/"
fi

./scripts/prepare-bundled-fonts.sh
python3 -m compileall -q tests tools
python3 tests/static_validate.py
python3 tests/adaptive_viewport_contract.py
python3 tools/perf_budget.py
python3 tools/audio_mix_budget.py
python3 tests/room_pipeline_contract.py
python3 tests/visual_snapshot_contract.py
python3 tests/new_release_pack_contract.py
python3 tools/asset_report.py
rm -rf build/web
mkdir -p build/web
run_godot_checked import --headless --editor --path "$ROOT" --quit
run_godot_checked runtime-validation --headless --path "$ROOT" --script res://tests/validate_project.gd
run_godot_checked web-export --headless --path "$ROOT" --export-release Web build/web/index.html
cp -R web/. build/web/
mkdir -p build/web/fonts
cp assets/fonts/generated/SynesthesiaTitle.ttf build/web/fonts/
cp assets/fonts/generated/SynesthesiaDisplay.ttf build/web/fonts/
cp assets/fonts/generated/OFL-Knewave.txt build/web/fonts/
cp assets/fonts/generated/OFL-BebasNeue.txt build/web/fonts/
cp assets/icon.svg assets/icon-192.png assets/icon-512.png build/web/
python3 tools/postprocess_web.py
test -s build/web/index.html
test -s build/web/manifest.webmanifest
test -s build/web/service-worker.js
printf 'SYNESTHESIA_WEB_BUILD=PASS output=%s\n' "$ROOT/build/web"
