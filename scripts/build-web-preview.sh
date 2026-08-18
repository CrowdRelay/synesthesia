#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/config/toolchains.env"
CACHE_DIR="${GODOT_CACHE_DIR:-$ROOT/.cache/godot-$GODOT_VERSION}"
GODOT_BIN="${GODOT_BIN:-}"
RUST_WEB_REQUIRED="${SYNESTHESIA_RUST_WEB_REQUIRED:-1}"
RUST_NATIVE_TOOLCHAIN="${SYNESTHESIA_RUST_NATIVE_TOOLCHAIN:-$RUST_NATIVE_TOOLCHAIN}"
RUST_WEB_TOOLCHAIN="${SYNESTHESIA_RUST_WEB_TOOLCHAIN:-$RUST_WEB_TOOLCHAIN}"
EMSDK_VERSION="${SYNESTHESIA_EMSDK_VERSION:-$EMSDK_VERSION}"
EMSDK_DIR="${EMSDK_DIR:-$CACHE_DIR/emsdk-$EMSDK_VERSION}"

calculate_sha256() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    printf 'ERROR: neither sha256sum nor shasum is available\n' >&2
    return 1
  fi
}

check_sha256() {
  local expected="$1"
  local file="$2"
  local actual
  actual="$(calculate_sha256 "$file")"
  [[ "$actual" == "$expected" ]] || {
    printf 'ERROR: checksum mismatch for %s\nexpected=%s\nactual=%s\n' "$file" "$expected" "$actual" >&2
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
  local cached_emsdk_head=""
  if [[ -x "$EMSDK_DIR/emsdk" && -d "$EMSDK_DIR/.git" ]]; then
    cached_emsdk_head="$(git -C "$EMSDK_DIR" rev-parse HEAD 2>/dev/null || true)"
  fi
  if [[ "$cached_emsdk_head" != "$EMSDK_MANAGER_COMMIT" ]]; then
    if [[ -n "$cached_emsdk_head" ]]; then
      printf 'SYNESTHESIA_EMSDK_MANAGER=REFRESH expected=%s actual=%s\n' \
        "$EMSDK_MANAGER_COMMIT" "$cached_emsdk_head"
    fi
    rm -rf "$EMSDK_DIR"
    git clone --depth 1 --branch "$EMSDK_VERSION" https://github.com/emscripten-core/emsdk.git "$EMSDK_DIR"
  fi
  local emsdk_head
  emsdk_head="$(git -C "$EMSDK_DIR" rev-parse HEAD)"
  [[ "$emsdk_head" == "$EMSDK_MANAGER_COMMIT" ]] || {
    printf 'ERROR: emsdk manager drift for %s: expected=%s actual=%s\n' \
      "$EMSDK_VERSION" "$EMSDK_MANAGER_COMMIT" "$emsdk_head" >&2
    exit 1
  }
  printf 'SYNESTHESIA_EMSDK_MANAGER=PASS version=%s commit=%s\n' "$EMSDK_VERSION" "$emsdk_head"
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

# Fail source contracts before downloading Godot/templates/toolchains.
if [[ "${SYNESTHESIA_SKIP_SOURCE_VALIDATION:-0}" != "1" ]]; then
  ./scripts/validate-source.sh
fi

# Cheap deterministic size gate before Godot/templates/Rust. This protects GitHub
# runner minutes from source/runtime growth that can be known without exporting.
python3 tools/web_bundle_budget.py --preflight

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
      if [[ ! -s "$archive" ]]; then
        curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --retry-all-errors \
          --output "$archive" \
          "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
      else
        printf 'SYNESTHESIA_GODOT_EDITOR_CACHE=HIT archive=%s\n' "$archive"
      fi
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

# Keep the bounded download cache separate from Godot's runtime install path.
# The engine's own diagnostic is authoritative here: on Linux CI Godot 4.7.1
# resolves templates from $HOME/.local/share/godot/export_templates regardless
# of a private shell-only GODOT_DATA_DIR. Cache two verified
# Web templates under the repository, then atomically install copies where the
# running editor actually looks for them.
GODOT_RUNTIME_DATA_DIR="$(./scripts/godot-runtime-data-dir.sh)"
RUNTIME_TEMPLATE_DIR="$GODOT_RUNTIME_DATA_DIR/export_templates/$GODOT_RELEASE_VERSION"
CACHE_TEMPLATE_DIR="${SYNESTHESIA_WEB_TEMPLATE_CACHE_DIR:-$CACHE_DIR/web-templates/$GODOT_RELEASE_VERSION}"
WEB_TEMPLATE_MANIFEST="$CACHE_TEMPLATE_DIR/.synesthesia-web-templates.sha256"
WEB_TEMPLATE_NAMES=(web_dlink_nothreads_debug.zip web_dlink_nothreads_release.zip)

calculate_template_set_sha() {
  local dir="$1"
  local name
  for name in "${WEB_TEMPLATE_NAMES[@]}"; do
    [[ -s "$dir/$name" ]] || return 1
    printf '%s  %s\n' "$(calculate_sha256 "$dir/$name")" "$name"
  done
}

verify_web_template_manifest_at() {
  local dir="$1"
  local manifest="$2"
  [[ -s "$manifest" ]] || return 1
  local expected name actual count=0
  while read -r expected name; do
    [[ -n "$expected" && -n "$name" ]] || continue
    case "$name" in
      web_dlink_nothreads_debug.zip|web_dlink_nothreads_release.zip) ;;
      *) return 1 ;;
    esac
    [[ -s "$dir/$name" ]] || return 1
    actual="$(calculate_sha256 "$dir/$name")"
    [[ "$actual" == "$expected" ]] || return 1
    count=$((count + 1))
  done < "$manifest"
  [[ "$count" == "2" ]]
}

verify_web_template_manifest() {
  verify_web_template_manifest_at "$CACHE_TEMPLATE_DIR" "$WEB_TEMPLATE_MANIFEST"
}

write_web_template_manifest() {
  local tmp="${WEB_TEMPLATE_MANIFEST}.tmp"
  mkdir -p "$CACHE_TEMPLATE_DIR"
  calculate_template_set_sha "$CACHE_TEMPLATE_DIR" > "$tmp"
  mv "$tmp" "$WEB_TEMPLATE_MANIFEST"
}

migrate_previous_template_cache() {
  verify_web_template_manifest && return 0
  local candidate candidate_manifest name
  for candidate in \
    "$CACHE_DIR/godot-data/godot/export_templates/$GODOT_RELEASE_VERSION" \
    "$CACHE_DIR/godot-data/export_templates/$GODOT_RELEASE_VERSION"; do
    candidate_manifest="$candidate/.synesthesia-web-templates.sha256"
    if verify_web_template_manifest_at "$candidate" "$candidate_manifest"; then
      mkdir -p "$CACHE_TEMPLATE_DIR"
      for name in "${WEB_TEMPLATE_NAMES[@]}"; do
        cp "$candidate/$name" "$CACHE_TEMPLATE_DIR/$name"
      done
      cp "$candidate_manifest" "$WEB_TEMPLATE_MANIFEST"
      verify_web_template_manifest || {
        echo 'ERROR: migrated Web template cache failed verification' >&2
        exit 1
      }
      printf 'SYNESTHESIA_WEB_TEMPLATE_CACHE=MIGRATED source=%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

install_web_templates_for_godot() {
  verify_web_template_manifest || {
    echo 'ERROR: refusing to install unverified Web templates into Godot data directory' >&2
    exit 1
  }
  mkdir -p "$RUNTIME_TEMPLATE_DIR"
  local name source target tmp source_sha target_sha
  for name in "${WEB_TEMPLATE_NAMES[@]}"; do
    source="$CACHE_TEMPLATE_DIR/$name"
    target="$RUNTIME_TEMPLATE_DIR/$name"
    source_sha="$(calculate_sha256 "$source")"
    if [[ -s "$target" ]]; then
      target_sha="$(calculate_sha256 "$target")"
      if [[ "$source_sha" == "$target_sha" ]]; then
        continue
      fi
    fi
    tmp="${target}.tmp"
    rm -f "$tmp"
    cp "$source" "$tmp"
    [[ "$(calculate_sha256 "$tmp")" == "$source_sha" ]] || {
      echo "ERROR: Web template copy failed verification: $name" >&2
      rm -f "$tmp"
      exit 1
    }
    mv "$tmp" "$target"
  done
  for name in "${WEB_TEMPLATE_NAMES[@]}"; do
    [[ -s "$RUNTIME_TEMPLATE_DIR/$name" ]] || {
      echo "ERROR: Godot runtime Web template missing after install: $RUNTIME_TEMPLATE_DIR/$name" >&2
      exit 1
    }
    [[ "$(calculate_sha256 "$RUNTIME_TEMPLATE_DIR/$name")" == "$(calculate_sha256 "$CACHE_TEMPLATE_DIR/$name")" ]] || {
      echo "ERROR: Godot runtime Web template checksum differs from verified cache: $name" >&2
      exit 1
    }
  done
  printf 'SYNESTHESIA_GODOT_TEMPLATE_INSTALL=PASS runtime=%s cache=%s files=2\n' \
    "$RUNTIME_TEMPLATE_DIR" "$CACHE_TEMPLATE_DIR"
}

mkdir -p "$CACHE_DIR" "$CACHE_TEMPLATE_DIR"
migrate_previous_template_cache || true

web_templates_ready=0
if verify_web_template_manifest; then
  web_templates_ready=1
  printf 'SYNESTHESIA_WEB_TEMPLATE_CACHE=HIT verified=manifest path=%s\n' "$CACHE_TEMPLATE_DIR"
else
  # Never normalize a corrupt manifest into a new baseline.
  rm -f "$CACHE_TEMPLATE_DIR/web_dlink_nothreads_debug.zip" \
    "$CACHE_TEMPLATE_DIR/web_dlink_nothreads_release.zip" "$WEB_TEMPLATE_MANIFEST"
fi

if [[ "$web_templates_ready" != "1" ]]; then
  template_archive="$CACHE_DIR/templates.tpz"
  if [[ ! -s "$template_archive" ]]; then
    curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --retry-all-errors \
      --output "$template_archive" \
      "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"
  else
    printf 'SYNESTHESIA_GODOT_TEMPLATE_CACHE=HIT archive=%s\n' "$template_archive"
  fi
  check_sha256 "$GODOT_TEMPLATES_SHA256" "$template_archive"

  # Stream only the two Web entries; never inflate the ~1.2 GiB pack.
  for template_name in "${WEB_TEMPLATE_NAMES[@]}"; do
    target_template="$CACHE_TEMPLATE_DIR/$template_name"
    tmp_template="${target_template}.tmp"
    rm -f "$tmp_template"
    unzip -p "$template_archive" "templates/$template_name" > "$tmp_template"
    [[ -s "$tmp_template" ]] || {
      printf 'ERROR: expected Godot Web template missing from archive: %s\n' "$template_name" >&2
      rm -f "$tmp_template"
      exit 1
    }
    mv "$tmp_template" "$target_template"
  done
  write_web_template_manifest
  verify_web_template_manifest || {
    echo 'ERROR: selected Web templates failed post-extraction integrity verification' >&2
    exit 1
  }
  if [[ "${NETLIFY:-}" == "true" ]]; then
    rm -f "$template_archive"
  fi
fi

# Install before Rust/Web compilation so a path/configuration error fails in
# seconds instead of after a multi-minute wasm32-unknown-emscripten build.
install_web_templates_for_godot

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
# Keep the Godot editor out of the export output. Without this marker the editor
# imports the multi-MiB build artifacts as project assets and writes .import
# sidecars back into the directory that ships to Netlify.
printf '' > build/.gdignore
install_web_templates_for_godot
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
cp assets/fonts/generated/OFL-NewRocker.txt build/web/fonts/
cp assets/fonts/generated/OFL-BebasNeue.txt build/web/fonts/
cp assets/icon.svg assets/icon-192.png assets/icon-512.png build/web/
cp assets/branding/menu-eye-poster.webp assets/branding/menu-eye-boot-loop.mp4 build/web/
python3 tools/postprocess_web.py
python3 tools/web_bundle_budget.py
test -s build/web/index.html
test -s build/web/manifest.webmanifest
test -s build/web/service-worker.js
printf 'SYNESTHESIA_WEB_BUILD=PASS output=%s rust=%s threads=off\n' "$ROOT/build/web" "$RUST_WEB_REQUIRED"
