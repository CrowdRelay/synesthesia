#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
# shellcheck disable=SC1091
source "$ROOT/config/toolchains.env"
NATIVE="$ROOT/native"
DESCRIPTOR="$ROOT/synesthesia_rust.gdextension"
EXTENSION_LIST="$ROOT/.godot/extension_list.cfg"
MODE="${1:-host}"
PROFILE="${SYNESTHESIA_RUST_PROFILE:-release}"
WEB_TOOLCHAIN="${SYNESTHESIA_RUST_WEB_TOOLCHAIN:-$RUST_WEB_TOOLCHAIN}"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

install_descriptor() {
  cp "$NATIVE/synesthesia_rust.gdextension.template" "$DESCRIPTOR"
  mkdir -p "$(dirname "$EXTENSION_LIST")"
  if [[ ! -f "$EXTENSION_LIST" ]] || ! grep -Fxq 'res://synesthesia_rust.gdextension' "$EXTENSION_LIST"; then
    printf '%s\n' 'res://synesthesia_rust.gdextension' >> "$EXTENSION_LIST"
  fi
}

sign_macos_dylib_for_local_godot() {
  local dylib="$1"
  [[ "$(uname -s)" == "Darwin" ]] || return 0
  require codesign

  # Rust/ld may leave a linker/ad-hoc signature that macOS refuses to map into
  # the signed Godot process. Re-seal the final copied dylib explicitly for
  # local execution, then verify it before Godot ever sees the descriptor.
  codesign --force --sign - --timestamp=none "$dylib"
  codesign --verify --strict --verbose=2 "$dylib"
  printf 'SYNESTHESIA_RUST_NATIVE_CODESIGN=PASS identity=adhoc library=%s\n' "${dylib#$ROOT/}"
}

cargo_profile_args() {
  if [[ "$PROFILE" == "release" ]]; then
    printf '%s\n' '--release'
  fi
}

resolve_godot_bin() {
  local candidate="${GDRUST_GODOT_BIN:-${GODOT4_BIN:-${GODOT_BIN:-}}}"
  if [[ -z "$candidate" ]]; then
    if command -v godot >/dev/null 2>&1; then
      candidate="$(command -v godot)"
    elif command -v Godot >/dev/null 2>&1; then
      candidate="$(command -v Godot)"
    elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
      candidate="/Applications/Godot.app/Contents/MacOS/Godot"
    fi
  fi
  [[ -n "$candidate" && -x "$candidate" ]] || {
    echo "Godot executable required for Rust Web api-custom; set GDRUST_GODOT_BIN or GODOT_BIN" >&2
    exit 1
  }
  printf '%s\n' "$candidate"
}

build_host() {
  require cargo
  local os arch target_dir source destination
  os="$(uname -s)"
  arch="$(uname -m)"
  target_dir="$NATIVE/target/$PROFILE"
  local cargo_args=(build --manifest-path "$NATIVE/Cargo.toml" --package synesthesia-gdext)
  if [[ "$PROFILE" == "release" ]]; then cargo_args+=(--release); fi
  cargo "${cargo_args[@]}"

  case "$os:$arch" in
    Darwin:arm64)
      source="$target_dir/libsynesthesia_gdext.dylib"
      destination="$NATIVE/bin/macos-arm64/$PROFILE/libsynesthesia_gdext.dylib"
      ;;
    Darwin:x86_64)
      source="$target_dir/libsynesthesia_gdext.dylib"
      destination="$NATIVE/bin/macos-x86_64/$PROFILE/libsynesthesia_gdext.dylib"
      ;;
    Linux:x86_64)
      source="$target_dir/libsynesthesia_gdext.so"
      destination="$NATIVE/bin/linux-x86_64/$PROFILE/libsynesthesia_gdext.so"
      ;;
    *)
      echo "unsupported host for automatic GDExtension packaging: $os/$arch" >&2
      exit 1
      ;;
  esac
  mkdir -p "$(dirname "$destination")"
  cp "$source" "$destination"
  sign_macos_dylib_for_local_godot "$destination"
  install_descriptor
  echo "SYNESTHESIA_RUST_NATIVE=PASS target=host profile=$PROFILE library=${destination#$ROOT/}"
}

build_android() {
  require cargo
  if ! (cd "$NATIVE" && cargo ndk --version >/dev/null 2>&1); then
    echo "cargo-ndk is required for Android Rust builds: cargo install cargo-ndk --locked" >&2
    exit 1
  fi
  local output="$NATIVE/android-out/$PROFILE"
  rm -rf "$output"
  mkdir -p "$output"
  local args=(-t arm64-v8a -o "$output" build --manifest-path "$NATIVE/Cargo.toml" --package synesthesia-gdext)
  if [[ "$PROFILE" == "release" ]]; then args+=(--release); fi
  (cd "$NATIVE" && cargo ndk "${args[@]}")
  local source="$output/arm64-v8a/libsynesthesia_gdext.so"
  if [[ ! -f "$source" ]]; then
    source="$(find "$output" -type f -name 'libsynesthesia_gdext.so' -print -quit)"
  fi
  [[ -n "$source" && -f "$source" ]] || { echo "Android Rust library was not produced" >&2; exit 1; }
  local destination="$NATIVE/bin/android-arm64/$PROFILE/libsynesthesia_gdext.so"
  mkdir -p "$(dirname "$destination")"
  cp "$source" "$destination"
  install_descriptor
  echo "SYNESTHESIA_RUST_NATIVE=PASS target=android-arm64 profile=$PROFILE library=${destination#$ROOT/}"
}

build_web() {
  require cargo
  require rustup
  require emcc
  require em++

  if ! rustup toolchain list | grep -Eq "^${WEB_TOOLCHAIN}([^-]|-.*-.*)?"; then
    rustup toolchain install "$WEB_TOOLCHAIN" --profile minimal
  fi
  rustup component add rust-src --toolchain "$WEB_TOOLCHAIN" >/dev/null
  rustup target add wasm32-unknown-emscripten --toolchain "$WEB_TOOLCHAIN" >/dev/null

  local godot_bin
  godot_bin="$(resolve_godot_bin)"
  export GDRUST_GODOT_BIN="$godot_bin"

  # bindgen is a host build dependency but generates headers for the Web target.
  # On Linux it otherwise discovers /usr/include and mixes glibc with Emscripten.
  local emscripten_sysroot=""
  if [[ -n "${EMSDK:-}" && -d "$EMSDK/upstream/emscripten/cache/sysroot/include" ]]; then
    emscripten_sysroot="$EMSDK/upstream/emscripten/cache/sysroot"
  else
    local emcc_dir
    emcc_dir="$(cd "$(dirname "$(command -v emcc)")" && pwd -P)"
    if [[ -d "$emcc_dir/cache/sysroot/include" ]]; then
      emscripten_sysroot="$emcc_dir/cache/sysroot"
    fi
  fi
  [[ -n "$emscripten_sysroot" ]] || {
    echo "Emscripten sysroot not found after emcc activation" >&2
    exit 1
  }
  export BINDGEN_EXTRA_CLANG_ARGS="--target=wasm32-unknown-emscripten --sysroot=$emscripten_sysroot"
  export C_INCLUDE_PATH="$emscripten_sysroot/include${C_INCLUDE_PATH:+:$C_INCLUDE_PATH}"
  printf 'SYNESTHESIA_RUST_WEB_SYSROOT=PASS path=%s\n' "$emscripten_sysroot"

  local cargo_args=(
    "+$WEB_TOOLCHAIN" build
    -Zbuild-std
    --manifest-path "$NATIVE/Cargo.toml"
    --package synesthesia-gdext
    --target wasm32-unknown-emscripten
    --features nothreads
  )
  if [[ "$PROFILE" == "release" ]]; then cargo_args+=(--release); fi
  cargo "${cargo_args[@]}"

  local source="$NATIVE/target/wasm32-unknown-emscripten/$PROFILE/synesthesia_gdext.wasm"
  [[ -s "$source" ]] || { echo "Rust WebAssembly GDExtension was not produced: $source" >&2; exit 1; }
  local destination="$NATIVE/bin/web/$PROFILE/synesthesia_gdext.wasm"
  mkdir -p "$(dirname "$destination")"
  cp "$source" "$destination"
  install_descriptor
  echo "SYNESTHESIA_RUST_WEB=PASS target=wasm32-unknown-emscripten profile=$PROFILE threads=off library=${destination#$ROOT/}"
}

disable_native() {
  rm -f "$DESCRIPTOR"
  if [[ -f "$EXTENSION_LIST" ]]; then
    grep -Fxv 'res://synesthesia_rust.gdextension' "$EXTENSION_LIST" > "$EXTENSION_LIST.tmp" || true
    mv "$EXTENSION_LIST.tmp" "$EXTENSION_LIST"
  fi
  echo "SYNESTHESIA_RUST_NATIVE=DISABLED"
}

case "$MODE" in
  host) build_host ;;
  android|android-arm64) build_android ;;
  web|web-wasm) build_web ;;
  all)
    build_host
    build_web
    ;;
  disable) disable_native ;;
  check)
    require cargo
    cargo fmt --manifest-path "$NATIVE/Cargo.toml" --all -- --check
    cargo test --manifest-path "$NATIVE/Cargo.toml" --package synesthesia-core
    cargo check --manifest-path "$NATIVE/Cargo.toml" --package synesthesia-gdext
    cargo clippy --manifest-path "$NATIVE/Cargo.toml" --workspace --all-targets -- -D warnings
    ;;
  *)
    echo "usage: $0 [host|android-arm64|web|all|check|disable]" >&2
    exit 2
    ;;
esac
