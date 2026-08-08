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
RUST_WEB_REQUIRED="${SYNESTHESIA_RUST_WEB_REQUIRED:-1}"
RUST_NATIVE_TOOLCHAIN="${SYNESTHESIA_RUST_NATIVE_TOOLCHAIN:-1.97.1}"
RUST_WEB_TOOLCHAIN="${SYNESTHESIA_RUST_WEB_TOOLCHAIN:-nightly}"
EMSDK_VERSION="${SYNESTHESIA_EMSDK_VERSION:-3.1.74}"
EMSDK_DIR="${EMSDK_DIR:-$CACHE_DIR/emsdk-$EMSDK_VERSION}"

check_sha256() {
  local expected="$1"
  local file="$2"
  local actual

  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$file" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  else
    printf 'ERROR: neither sha256sum nor shasum is available\n' >&2
    return 1
  fi

  [[ "$actual" == "$expected" ]] || {
    printf 'ERROR: checksum mismatch for %s\nexpected=%s\nactual=%s\n'       "$file" "$expected" "$actual" >&2
    return 1
  }
}

run_godot_checked() {
  local label="$1"
  local expected_marker="$2"
  shift 2
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
  if [[ -n "$expected_marker" ]] && ! grep -Fq "$expected_marker" "$log"; then
    printf 'ERROR: Godot command %s did not emit required marker: %s\n' "$label" "$expected_marker" >&2
    rm -f "$log"
    return 1
  fi
  rm -f "$log"
}

ensure_rustup() {
  if command -v rustup >/dev/null 2>&1; then
    return
  fi
  command -v curl >/dev/null 2>&1 || { echo 'ERROR: curl is required to install rustup' >&2; exit 1; }
  curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error https://sh.rustup.rs \
    | sh -s -- -y --profile minimal --default-toolchain "$RUST_NATIVE_TOOLCHAIN"
  # shellcheck disable=SC1090
  source "$HOME/.cargo/env"
}

ensure_emsdk() {
  if command -v emcc >/dev/null 2>&1 && command -v em++ >/dev/null 2>&1; then
    return
  fi
  command -v git >/dev/null 2>&1 || { echo 'ERROR: git is required to bootstrap emsdk' >&2; exit 1; }
  local py
  py="$(command -v python3 || true)"
  [[ -n "$py" ]] || { echo 'ERROR: Python 3.10+ is required for emsdk' >&2; exit 1; }
  "$py" - <<'PY'
import sys
if sys.version_info < (3, 10):
    raise SystemExit(f"ERROR: emsdk requires Python >=3.10, got {sys.version.split()[0]}")
PY
  if [[ ! -x "$EMSDK_DIR/emsdk" ]]; then
    rm -rf "$EMSDK_DIR"
    git clone --depth 1 https://github.com/emscripten-core/emsdk.git "$EMSDK_DIR"
  fi
  export EMSDK_PYTHON="$py"
  export EMSDK_QUIET=1
  "$EMSDK_DIR/emsdk" install "$EMSDK_VERSION"
  "$EMSDK_DIR/emsdk" activate "$EMSDK_VERSION"
  set +u
  # shellcheck disable=SC1091
  source "$EMSDK_DIR/emsdk_env.sh" >/dev/null
  set -u
  command -v emcc >/dev/null 2>&1 || { echo 'ERROR: emsdk activation did not expose emcc' >&2; exit 1; }
}

ensure_rust_web_toolchain() {
  ensure_rustup
  rustup toolchain install "$RUST_NATIVE_TOOLCHAIN" --profile minimal >/dev/null
  rustup toolchain install "$RUST_WEB_TOOLCHAIN" --profile minimal --component rust-src >/dev/null
  rustup target add wasm32-unknown-emscripten --toolchain "$RUST_WEB_TOOLCHAIN" >/dev/null
  ensure_emsdk
  emcc --version | head -n 1
  cargo "+$RUST_WEB_TOOLCHAIN" --version
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
export GODOT_BIN

case "$(uname -s)" in
  Darwin)
    GODOT_DATA_DIR="${GODOT_DATA_DIR:-$HOME/Library/Application Support/Godot}"
    ;;
  *)
    GODOT_DATA_DIR="${GODOT_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/godot}"
    ;;
esac

TEMPLATE_DIR="$GODOT_DATA_DIR/export_templates/$GODOT_RELEASE_VERSION"
if [[ ! -f "$TEMPLATE_DIR/web_release.zip" || ! -f "$TEMPLATE_DIR/web_dlink_nothreads_release.zip" ]]; then
  mkdir -p "$CACHE_DIR/templates-unpack" "$TEMPLATE_DIR"
  template_archive="$CACHE_DIR/templates.tpz"

  if [[ ! -s "$template_archive" ]]; then
    curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --retry-all-errors \
      --output "$template_archive" \
      "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"
  else
    printf 'SYNESTHESIA_GODOT_TEMPLATE_CACHE=HIT archive=%s\n' "$template_archive"
  fi

  if ! check_sha256 "$GODOT_TEMPLATES_SHA256" "$template_archive"; then
    printf 'ERROR: cached Godot export template archive failed checksum: %s\n' "$template_archive" >&2
    exit 1
  fi

  rm -rf "$CACHE_DIR/templates-unpack"
  mkdir -p "$CACHE_DIR/templates-unpack"
  unzip -q "$template_archive" -d "$CACHE_DIR/templates-unpack"
  cp -R "$CACHE_DIR/templates-unpack/templates/." "$TEMPLATE_DIR/"
fi
[[ -f "$TEMPLATE_DIR/web_dlink_nothreads_release.zip" ]] || {
  echo 'ERROR: Godot Web dynamic-link nothreads export template is missing' >&2
  exit 1
}

./scripts/prepare-bundled-fonts.sh
python3 -m compileall -q tests tools
python3 tests/static_validate.py
python3 tests/adaptive_viewport_contract.py
python3 tools/perf_budget.py
python3 tools/audio_mix_budget.py
python3 tests/room_pipeline_contract.py
python3 tests/visual_snapshot_contract.py
python3 tests/new_release_pack_contract.py
python3 tests/rust_hybrid_contract.py
python3 tools/asset_report.py

# First validate the portable fallback with no generated extension state. This
# prevents a stale local dylib/so from making a clean checkout look healthy.
./scripts/build-rust-native.sh disable >/dev/null
run_godot_checked import "" --headless --editor --path "$ROOT" --quit
run_godot_checked runtime-validation "SYNESTHESIA_VALIDATION=PASS" --headless --path "$ROOT" --script res://tests/validate_project.gd

if [[ "$RUST_WEB_REQUIRED" == "1" ]]; then
  ensure_rust_web_toolchain

  # Godot's Linux/macOS editor loads the host extension while preparing/exporting
  # the Web target, so build a debug host library for a real engine smoke first.
  RUSTUP_TOOLCHAIN="$RUST_NATIVE_TOOLCHAIN" SYNESTHESIA_RUST_PROFILE=debug ./scripts/build-rust-native.sh host
  run_godot_checked rust-import "" --headless --editor --path "$ROOT" --quit
  run_godot_checked rust-runtime-validation "SYNESTHESIA_RUST_RUNTIME=PASS backend=native" \
    --headless --path "$ROOT" --script res://tests/validate_project.gd

  GDRUST_GODOT_BIN="$GODOT_BIN" SYNESTHESIA_RUST_PROFILE=release \
    SYNESTHESIA_RUST_WEB_TOOLCHAIN="$RUST_WEB_TOOLCHAIN" ./scripts/build-rust-native.sh web
else
  echo 'SYNESTHESIA_RUST_WEB=DISABLED reason=explicit-emergency-fallback'
fi

rm -rf build/web
mkdir -p build/web
run_godot_checked web-export "" --headless --path "$ROOT" --export-release Web build/web/index.html

if [[ "$RUST_WEB_REQUIRED" == "1" ]]; then
  rust_wasm="$(find build/web -type f -name 'synesthesia_gdext.wasm' -print -quit)"
  [[ -n "$rust_wasm" && -s "$rust_wasm" ]] || {
    echo 'ERROR: Web export completed without synesthesia_gdext.wasm' >&2
    exit 1
  }
  printf 'SYNESTHESIA_RUST_WEB_EXPORT=PASS wasm=%s bytes=%s\n' \
    "${rust_wasm#$ROOT/}" "$(wc -c < "$rust_wasm" | tr -d ' ')"
fi

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
printf 'SYNESTHESIA_WEB_BUILD=PASS output=%s rust=%s threads=off\n' "$ROOT/build/web" "$RUST_WEB_REQUIRED"
