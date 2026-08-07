#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

GODOT_VERSION="4.7.1-stable"
GODOT_RELEASE_VERSION="4.7.1.stable"
GODOT_EDITOR_SHA256="c7ff14fd28472c8d4f193043de30278dcf7e5241a1dcf7566b02e27addaa33ba"
GODOT_TEMPLATES_SHA256="86409db6200b6f8fd3230989c2d2002851f3dd18acf11d7bdbafddf5a0dd0f72"
GODOT_CACHE_DIR="${GODOT_CACHE_DIR:-$HOME/.cache/synesthesia/godot-$GODOT_VERSION}"
GODOT_BIN="${GODOT_BIN:-}"
ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
APK_PATH="${SYNESTHESIA_APK_PATH:-$ROOT/build/android/synesthesia-debug.apk}"
BUILD_TOOLS_VERSION="35.0.1"
PLATFORM_VERSION="android-35"
NDK_VERSION="28.1.13356709"
CMAKE_VERSION="3.10.2.4988404"

check_sha256() {
  local expected="$1"
  local file="$2"
  printf '%s  %s\n' "$expected" "$file" | sha256sum --check --strict
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'ERROR: required command not found: %s\n' "$1" >&2
    exit 1
  }
}

require_cmd curl
require_cmd unzip
require_cmd sha256sum
require_cmd keytool

if [[ -z "$ANDROID_HOME" ]]; then
  printf 'ERROR: ANDROID_HOME/ANDROID_SDK_ROOT is not set. Run android-actions/setup-android in CI or install Android SDK locally.\n' >&2
  exit 1
fi
if [[ ! -d "$ANDROID_HOME" ]]; then
  printf 'ERROR: Android SDK directory does not exist: %s\n' "$ANDROID_HOME" >&2
  exit 1
fi
if [[ -z "${JAVA_HOME:-}" || ! -x "${JAVA_HOME}/bin/java" ]]; then
  printf 'ERROR: JAVA_HOME must point to JDK 17.\n' >&2
  exit 1
fi
java_major="$(${JAVA_HOME}/bin/java -version 2>&1 | sed -n '1s/.*version "\([0-9][0-9]*\).*/\1/p')"
if [[ "$java_major" != "17" ]]; then
  printf 'ERROR: Android pipeline requires JDK 17; got major=%s JAVA_HOME=%s\n' "${java_major:-unknown}" "$JAVA_HOME" >&2
  exit 1
fi

sdkmanager_bin="$(command -v sdkmanager || true)"
if [[ -z "$sdkmanager_bin" && -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]]; then
  sdkmanager_bin="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
fi
if [[ -z "$sdkmanager_bin" ]]; then
  printf 'ERROR: sdkmanager not found after Android SDK setup.\n' >&2
  exit 1
fi

if [[ "${SYNESTHESIA_SKIP_ANDROID_SDK_INSTALL:-0}" != "1" ]]; then
  yes | "$sdkmanager_bin" --sdk_root="$ANDROID_HOME" --licenses >/dev/null 2>&1 || true
  "$sdkmanager_bin" --sdk_root="$ANDROID_HOME" \
    "platform-tools" \
    "build-tools;$BUILD_TOOLS_VERSION" \
    "platforms;$PLATFORM_VERSION" \
    "cmdline-tools;latest" \
    "cmake;$CMAKE_VERSION" \
    "ndk;$NDK_VERSION" >/dev/null
fi

mkdir -p "$GODOT_CACHE_DIR"
if [[ -z "$GODOT_BIN" ]]; then
  archive="$GODOT_CACHE_DIR/editor.zip"
  GODOT_BIN="$GODOT_CACHE_DIR/Godot_v${GODOT_VERSION}_linux.x86_64"
  if [[ ! -x "$GODOT_BIN" ]]; then
    curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --retry-all-errors \
      --output "$archive" \
      "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
    check_sha256 "$GODOT_EDITOR_SHA256" "$archive"
    unzip -q -o "$archive" -d "$GODOT_CACHE_DIR"
    chmod +x "$GODOT_BIN"
  fi
fi
[[ -x "$GODOT_BIN" ]] || { printf 'ERROR: Godot binary is not executable: %s\n' "$GODOT_BIN" >&2; exit 1; }

TEMPLATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$GODOT_RELEASE_VERSION"
if [[ ! -f "$TEMPLATE_DIR/android_debug.apk" || ! -f "$TEMPLATE_DIR/android_release.apk" ]]; then
  template_archive="$GODOT_CACHE_DIR/templates.tpz"
  unpack_dir="$GODOT_CACHE_DIR/templates-unpack"
  curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --retry-all-errors \
    --output "$template_archive" \
    "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"
  check_sha256 "$GODOT_TEMPLATES_SHA256" "$template_archive"
  rm -rf "$unpack_dir"
  mkdir -p "$unpack_dir" "$TEMPLATE_DIR"
  unzip -q "$template_archive" -d "$unpack_dir"
  cp -R "$unpack_dir/templates/." "$TEMPLATE_DIR/"
fi

keystore_path="${ANDROID_DEBUG_KEYSTORE_PATH:-}"
keystore_user="${ANDROID_DEBUG_KEYSTORE_USER:-androiddebugkey}"
keystore_password="${ANDROID_DEBUG_KEYSTORE_PASSWORD:-android}"
if [[ -z "$keystore_path" ]]; then
  keystore_path="$ROOT/build/.ci/debug.keystore"
  mkdir -p "$(dirname "$keystore_path")"
  if [[ ! -f "$keystore_path" ]]; then
    keytool -genkeypair \
      -keystore "$keystore_path" \
      -storepass "$keystore_password" \
      -alias "$keystore_user" \
      -keypass "$keystore_password" \
      -keyalg RSA -keysize 2048 -validity 10000 \
      -dname "CN=Synesthesia Android Debug,O=VIRYA,C=PL" >/dev/null 2>&1
  fi
fi
[[ -s "$keystore_path" ]] || { printf 'ERROR: Android debug keystore missing: %s\n' "$keystore_path" >&2; exit 1; }

# Keep CI/export editor settings isolated from the developer's real Godot preferences.
export XDG_CONFIG_HOME="${SYNESTHESIA_GODOT_CONFIG_HOME:-$ROOT/build/.ci/config}"
settings_dir="$XDG_CONFIG_HOME/godot"
settings_file="$settings_dir/editor_settings-4.7.tres"
mkdir -p "$settings_dir"
cat > "$settings_file" <<SETTINGS
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/java_sdk_path = "$JAVA_HOME"
export/android/debug_keystore = "$keystore_path"
export/android/debug_keystore_user = "$keystore_user"
export/android/debug_keystore_pass = "$keystore_password"
SETTINGS
chmod 600 "$settings_file"

export ANDROID_HOME ANDROID_SDK_ROOT
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$keystore_path"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="$keystore_user"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="$keystore_password"

# Validate the exact source tree that will be exported. validate.sh runs Godot import + lifecycle smoke when GODOT_BIN is provided.
export SYNESTHESIA_GODOT_LOG_DIR="${SYNESTHESIA_GODOT_LOG_DIR:-$ROOT/build/ci-logs}"
mkdir -p "$SYNESTHESIA_GODOT_LOG_DIR"
validation_log="$(mktemp "${TMPDIR:-/tmp}/synesthesia-android-validation.XXXXXX.log")"
set +e
GODOT_BIN="$GODOT_BIN" ./validate.sh 2>&1 | tee "$validation_log"
validation_status=${PIPESTATUS[0]}
set -e
if (( validation_status != 0 )); then
  rm -f "$validation_log"
  printf 'ERROR: shared Synesthesia validation failed before Android export.\n' >&2
  exit "$validation_status"
fi
if ! grep -q '^SYNESTHESIA_GODOT_RUNTIME=PASS$' "$validation_log"; then
  rm -f "$validation_log"
  printf 'ERROR: shared validation exited cleanly without SYNESTHESIA_GODOT_RUNTIME=PASS.\n' >&2
  exit 1
fi
rm -f "$validation_log"

mkdir -p "$(dirname "$APK_PATH")"
rm -f "$APK_PATH" "${APK_PATH}.sha256"

preset_backup="$(mktemp "${TMPDIR:-/tmp}/synesthesia-export-presets.XXXXXX")"
cp export_presets.cfg "$preset_backup"
restore_preset() {
  cp "$preset_backup" export_presets.cfg
  rm -f "$preset_backup"
}
trap restore_preset EXIT

if [[ -n "${SYNESTHESIA_ANDROID_VERSION_CODE:-}" ]]; then
  python3 - "$SYNESTHESIA_ANDROID_VERSION_CODE" <<'PY'
from pathlib import Path
import re, sys
value = int(sys.argv[1])
if value <= 0:
    raise SystemExit("version code must be positive")
p = Path("export_presets.cfg")
s = p.read_text()
start = s.index('[preset.2.options]')
head, tail = s[:start], s[start:]
tail, count = re.subn(r'(?m)^version/code=\d+$', f'version/code={value}', tail, count=1)
if count != 1:
    raise SystemExit('Android version/code not found')
p.write_text(head + tail)
PY
fi

"$GODOT_BIN" --headless --path "$ROOT" --export-debug "Android Debug" "$APK_PATH"
[[ -s "$APK_PATH" ]] || { printf 'ERROR: Godot did not produce APK: %s\n' "$APK_PATH" >&2; exit 1; }

sha256sum "$APK_PATH" > "${APK_PATH}.sha256"
unzip -tq "$APK_PATH" >/dev/null

apksigner="$ANDROID_HOME/build-tools/$BUILD_TOOLS_VERSION/apksigner"
if [[ -x "$apksigner" ]]; then
  "$apksigner" verify --verbose --print-certs "$APK_PATH" >/dev/null
fi

aapt2="$ANDROID_HOME/build-tools/$BUILD_TOOLS_VERSION/aapt2"
if [[ -x "$aapt2" ]]; then
  "$aapt2" dump badging "$APK_PATH" > "${APK_PATH}.badging.txt"
  grep -q "package: name='music.virya.synesthesia'" "${APK_PATH}.badging.txt"
fi

printf 'SYNESTHESIA_ANDROID_APK=PASS output=%s bytes=%s sha256=%s\n' \
  "$APK_PATH" \
  "$(wc -c < "$APK_PATH" | tr -d ' ')" \
  "$(cut -d' ' -f1 < "${APK_PATH}.sha256")"
