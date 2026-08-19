#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/config/toolchains.env"

AAB_PATH="${SYNESTHESIA_AAB_PATH:-$ROOT/build/android/synesthesia-release.aab}"
GODOT_CACHE_DIR="${GODOT_CACHE_DIR:-$HOME/.cache/synesthesia/godot-$GODOT_VERSION}"
GODOT_BIN="${GODOT_BIN:-}"
ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
VERSION_CODE="${SYNESTHESIA_ANDROID_VERSION_CODE:-}"
KEYSTORE_PATH="${ANDROID_RELEASE_KEYSTORE_PATH:-}"
KEYSTORE_USER="${ANDROID_RELEASE_KEYSTORE_USER:-}"
KEYSTORE_PASSWORD="${ANDROID_RELEASE_KEYSTORE_PASSWORD:-}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'ERROR: required command not found: %s\n' "$1" >&2
    exit 1
  }
}

check_sha256() {
  local expected="$1" file="$2" actual
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$file" | awk '{print $1}')"
  else
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  fi
  [[ "$actual" == "$expected" ]] || {
    printf 'ERROR: checksum mismatch for %s\nexpected=%s\nactual=%s\n' "$file" "$expected" "$actual" >&2
    exit 1
  }
}

write_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1"
  else
    shasum -a 256 "$1"
  fi
}

require_cmd curl
require_cmd unzip
require_cmd keytool
require_cmd cargo
require_cmd rustup

[[ -n "$ANDROID_HOME" && -d "$ANDROID_HOME" ]] || {
  echo 'ERROR: ANDROID_HOME/ANDROID_SDK_ROOT is not configured' >&2
  exit 1
}
[[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/java" ]] || {
  echo 'ERROR: JAVA_HOME must point to JDK 17' >&2
  exit 1
}
java_major="$($JAVA_HOME/bin/java -version 2>&1 | sed -n '1s/.*version "\([0-9][0-9]*\).*/\1/p')"
[[ "$java_major" == "17" ]] || {
  printf 'ERROR: Android Play pipeline requires JDK 17; got %s\n' "${java_major:-unknown}" >&2
  exit 1
}

[[ -n "$VERSION_CODE" && "$VERSION_CODE" =~ ^[0-9]+$ ]] || {
  echo 'ERROR: SYNESTHESIA_ANDROID_VERSION_CODE must be a positive integer' >&2
  exit 1
}
(( VERSION_CODE >= 1 && VERSION_CODE <= 2100000000 )) || {
  echo 'ERROR: Android versionCode is outside Google Play range' >&2
  exit 1
}
[[ -s "$KEYSTORE_PATH" ]] || { echo 'ERROR: Android release keystore is missing' >&2; exit 1; }
[[ -n "$KEYSTORE_USER" ]] || { echo 'ERROR: Android release keystore user is missing' >&2; exit 1; }
[[ -n "$KEYSTORE_PASSWORD" ]] || { echo 'ERROR: Android release keystore password is missing' >&2; exit 1; }

grep -Fq 'name="Android Release"' export_presets.cfg
grep -Fq 'gradle_build/use_gradle_build=true' export_presets.cfg
grep -Fq 'gradle_build/export_format=1' export_presets.cfg
grep -Fq 'gradle_build/target_sdk="36"' export_presets.cfg
grep -Fq 'package/unique_name="music.virya.synesthesia"' export_presets.cfg

sdkmanager_bin="$(command -v sdkmanager || true)"
if [[ -z "$sdkmanager_bin" && -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]]; then
  sdkmanager_bin="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
fi
[[ -n "$sdkmanager_bin" ]] || { echo 'ERROR: sdkmanager not found' >&2; exit 1; }
license_answers="$(printf 'y\n%.0s' {1..100})"
"$sdkmanager_bin" --sdk_root="$ANDROID_HOME" --licenses <<<"$license_answers" >/dev/null
"$sdkmanager_bin" --sdk_root="$ANDROID_HOME" \
  'platform-tools' \
  "build-tools;$ANDROID_BUILD_TOOLS_VERSION" \
  'platforms;android-36' \
  'cmdline-tools;latest' \
  "cmake;$ANDROID_CMAKE_VERSION" \
  "ndk;$ANDROID_NDK_VERSION" >/dev/null

export ANDROID_HOME ANDROID_SDK_ROOT
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$ANDROID_NDK_VERSION"
export NDK_HOME="$ANDROID_NDK_HOME"
[[ -d "$ANDROID_NDK_HOME" ]] || { echo 'ERROR: configured NDK is missing' >&2; exit 1; }

mkdir -p "$GODOT_CACHE_DIR"
if [[ -z "$GODOT_BIN" ]]; then
  archive="$GODOT_CACHE_DIR/editor.zip"
  GODOT_BIN="$GODOT_CACHE_DIR/Godot_v${GODOT_VERSION}_linux.x86_64"
  if [[ ! -x "$GODOT_BIN" ]]; then
    if [[ ! -s "$archive" ]]; then
      curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --retry-all-errors \
        --output "$archive" \
        "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
    fi
    check_sha256 "$GODOT_EDITOR_SHA256" "$archive"
    unzip -q -o "$archive" -d "$GODOT_CACHE_DIR"
    chmod +x "$GODOT_BIN"
  fi
fi
[[ -x "$GODOT_BIN" ]] || { echo 'ERROR: Godot editor is not executable' >&2; exit 1; }

GODOT_DATA_DIR="$(./scripts/godot-runtime-data-dir.sh)"
TEMPLATE_DIR="$GODOT_DATA_DIR/export_templates/$GODOT_RELEASE_VERSION"
if [[ ! -f "$TEMPLATE_DIR/android_debug.apk" || ! -f "$TEMPLATE_DIR/android_release.apk" ]]; then
  template_archive="$GODOT_CACHE_DIR/templates.tpz"
  if [[ ! -s "$template_archive" ]]; then
    curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --retry-all-errors \
      --output "$template_archive" \
      "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"
  fi
  check_sha256 "$GODOT_TEMPLATES_SHA256" "$template_archive"
  mkdir -p "$TEMPLATE_DIR"
  for template_name in android_debug.apk android_release.apk; do
    unzip -p "$template_archive" "templates/$template_name" > "$TEMPLATE_DIR/$template_name.tmp"
    test -s "$TEMPLATE_DIR/$template_name.tmp"
    mv "$TEMPLATE_DIR/$template_name.tmp" "$TEMPLATE_DIR/$template_name"
  done
  [[ "${CI:-}" == 'true' ]] && rm -f "$template_archive"
fi

if ! (cd native && cargo ndk --version 2>/dev/null) | grep -Fq "cargo-ndk $CARGO_NDK_VERSION"; then
  cargo install cargo-ndk --locked --version "$CARGO_NDK_VERSION"
fi
rustup toolchain install "$RUST_NATIVE_TOOLCHAIN" --profile minimal
rustup target add aarch64-linux-android --toolchain "$RUST_NATIVE_TOOLCHAIN"
export RUSTUP_TOOLCHAIN="$RUST_NATIVE_TOOLCHAIN"

# Validate the exact source tree before mutating the release preset.
./scripts/build-rust-native.sh disable >/dev/null
export SYNESTHESIA_GODOT_LOG_DIR="${SYNESTHESIA_GODOT_LOG_DIR:-$ROOT/build/ci-logs}"
mkdir -p "$SYNESTHESIA_GODOT_LOG_DIR"
validation_log="$(mktemp "${TMPDIR:-/tmp}/synesthesia-play-validation.XXXXXX.log")"
set +e
SYNESTHESIA_SKIP_SOURCE_VALIDATION=1 GODOT_BIN="$GODOT_BIN" ./validate.sh 2>&1 | tee "$validation_log"
validation_status=${PIPESTATUS[0]}
set -e
if (( validation_status != 0 )) || ! grep -q '^SYNESTHESIA_GODOT_RUNTIME=PASS$' "$validation_log"; then
  rm -f "$validation_log"
  echo 'ERROR: shared Synesthesia validation failed before Play export' >&2
  exit 1
fi
rm -f "$validation_log"

SYNESTHESIA_RUST_PROFILE=release ./scripts/build-rust-native.sh android-arm64

preset_backup="$(mktemp "${TMPDIR:-/tmp}/synesthesia-play-presets.XXXXXX")"
cp export_presets.cfg "$preset_backup"
restore_preset() {
  cp "$preset_backup" export_presets.cfg
  rm -f "$preset_backup"
}
trap restore_preset EXIT

python3 - "$VERSION_CODE" <<'PY'
from pathlib import Path
import re, sys
value = int(sys.argv[1])
p = Path('export_presets.cfg')
s = p.read_text()
start = s.index('[preset.3.options]')
head, tail = s[:start], s[start:]
tail, count = re.subn(r'(?m)^version/code=\d+$', f'version/code={value}', tail, count=1)
if count != 1:
    raise SystemExit('Android Release version/code not found')
p.write_text(head + tail)
PY

VERSION_NAME="$(awk '/\[preset\.3\.options\]/{p=1;next} p && /^version\/name=/{gsub(/^version\/name="|"$/,""); print; exit}' export_presets.cfg)"
[[ -n "$VERSION_NAME" ]] || { echo 'ERROR: Android Release version/name not found' >&2; exit 1; }

# Keep Godot editor settings isolated from developer state.
export XDG_CONFIG_HOME="${SYNESTHESIA_GODOT_CONFIG_HOME:-$ROOT/build/.ci/config}"
mkdir -p "$XDG_CONFIG_HOME/godot"
cat > "$XDG_CONFIG_HOME/godot/editor_settings-4.7.tres" <<SETTINGS
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/java_sdk_path = "$JAVA_HOME"
SETTINGS

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE_PATH"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$KEYSTORE_USER"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$KEYSTORE_PASSWORD"

if [[ ! -d android/build ]]; then
  "$GODOT_BIN" --headless --path "$ROOT" --install-android-build-template
fi

mkdir -p "$(dirname "$AAB_PATH")"
rm -f "$AAB_PATH" "$AAB_PATH.sha256"
"$GODOT_BIN" --headless --path "$ROOT" --export-release 'Android Release' "$AAB_PATH"
[[ -s "$AAB_PATH" ]] || { echo 'ERROR: Godot did not produce release AAB' >&2; exit 1; }

unzip -tq "$AAB_PATH" >/dev/null
"$JAVA_HOME/bin/jarsigner" -verify "$AAB_PATH" >/dev/null
unzip -Z1 "$AAB_PATH" | grep -q 'libsynesthesia_gdext\.so$' || {
  echo 'ERROR: Rust GDExtension missing from AAB' >&2
  exit 1
}
python3 scripts/check-android-elf-alignment.py "$AAB_PATH" "$ANDROID_NDK_HOME"
write_sha256 "$AAB_PATH" > "$AAB_PATH.sha256"

printf 'SYNESTHESIA_PLAY_AAB=PASS package=music.virya.synesthesia versionName=%s versionCode=%s bytes=%s sha256=%s\n' \
  "$VERSION_NAME" "$VERSION_CODE" "$(wc -c < "$AAB_PATH" | tr -d ' ')" "$(cut -d' ' -f1 < "$AAB_PATH.sha256")"
printf 'SIGNATURE=PASS\nRUST_GDEXTENSION=PASS\nPAGE_SIZE_16K=PASS\nBUILD=PASS\nAAB=%s\n' "$AAB_PATH"
