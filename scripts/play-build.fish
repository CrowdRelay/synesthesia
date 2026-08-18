#!/usr/bin/env fish

set ROOT (git rev-parse --show-toplevel 2>/dev/null)
or begin
    echo "ERROR: not inside a git repository" >&2
    exit 1
end

cd "$ROOT"; or exit 1

set CONFIG "export_presets.cfg"
set PRESET "Android Release"
set AAB "build/android/synesthesia-release.aab"
set KEYSTORE "$HOME/.config/virya/play-signing/synesthesia-upload.jks"

#
# PRESET
#

test -f "$CONFIG"; or begin
    echo "ERROR: missing $CONFIG" >&2
    exit 1
end

grep -Fq 'name="Android Release"' "$CONFIG"
or begin
    echo "ERROR: missing Android Release preset"
    echo "Release build fix has not landed yet."
    exit 1
end

grep -Fq 'gradle_build/use_gradle_build=true' "$CONFIG"
or begin
    echo "ERROR: Android Release must use Gradle"
    exit 1
end

grep -Fq 'gradle_build/export_format=1' "$CONFIG"
or begin
    echo "ERROR: Android Release is not configured for AAB"
    exit 1
end

grep -Fq 'gradle_build/target_sdk="36"' "$CONFIG"
or begin
    echo "ERROR: Android Release targetSdk must be 36"
    exit 1
end

grep -Fq 'package/unique_name="music.virya.synesthesia"' "$CONFIG"
or begin
    echo "ERROR: wrong Android package ID"
    exit 1
end

#
# JAVA / ANDROID
#

set -l JAVA17 ""

if brew list --formula openjdk@17 >/dev/null 2>&1
    set JAVA17 (brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home
else
    set JAVA17 (/usr/libexec/java_home -v 17 2>/dev/null)
end

if test -z "$JAVA17"; or not test -x "$JAVA17/bin/java"
    echo "ERROR: JDK 17 not found" >&2
    echo "Install with: brew install openjdk@17" >&2
    exit 1
end

set -gx JAVA_HOME "$JAVA17"

set -l JAVA_MAJOR ("$JAVA_HOME/bin/java" -version 2>&1 | string match -r 'version "[0-9]+' | string replace 'version "' '')

if test "$JAVA_MAJOR" != "17"
echo "ERROR: Synesthesia requires JDK 17" >&2
"$JAVA_HOME/bin/java" -version
exit 1
end

echo "JAVA_HOME=$JAVA_HOME"
"$JAVA_HOME/bin/java" -version

set -gx ANDROID_HOME "$HOME/Library/Android/sdk"
set -gx ANDROID_SDK_ROOT "$ANDROID_HOME"

test -d "$ANDROID_HOME/platforms/android-36"
or begin
    echo "ERROR: Android API 36 missing"
    exit 1
end

#
# PINNED NDK FROM REPO
#

set NDK_VERSION \
    (grep '^ANDROID_NDK_VERSION=' config/toolchains.env | cut -d= -f2)

test -n "$NDK_VERSION"
or begin
    echo "ERROR: ANDROID_NDK_VERSION missing from config/toolchains.env"
    exit 1
end

set -gx ANDROID_NDK_HOME "$ANDROID_HOME/ndk/$NDK_VERSION"
set -gx NDK_HOME "$ANDROID_NDK_HOME"

test -d "$ANDROID_NDK_HOME"
or begin
    echo "ERROR: required NDK missing: $NDK_VERSION"
    echo "Install it with sdkmanager: ndk;$NDK_VERSION"
    exit 1
end

#
# GODOT
#

if command -q godot
    set GODOT (command -v godot)
else if command -q godot4
    set GODOT (command -v godot4)
else if test -x /Applications/Godot.app/Contents/MacOS/Godot
    set GODOT /Applications/Godot.app/Contents/MacOS/Godot
else
    echo "ERROR: Godot editor not found"
    exit 1
end

set -l GODOT_ACTUAL ($GODOT --version | string trim)
set -l GODOT_EXPECTED (grep '^GODOT_RELEASE_VERSION=' config/toolchains.env | cut -d= -f2)

test -n "$GODOT_EXPECTED"
or begin
    echo "ERROR: GODOT_RELEASE_VERSION missing from config/toolchains.env" >&2
    exit 1
end

string match -q "$GODOT_EXPECTED*" "$GODOT_ACTUAL"
or begin
    echo "ERROR: Godot editor/export-template version mismatch" >&2
    echo "EXPECTED=$GODOT_EXPECTED" >&2
    echo "ACTUAL=$GODOT_ACTUAL" >&2
    exit 1
end

echo "GODOT=$GODOT_ACTUAL"

#
# RELEASE SIGNING
#

test -s "$KEYSTORE"
or begin
    echo "ERROR: Synesthesia upload keystore missing:"
    echo "$KEYSTORE"
    exit 1
end

set KEY_PASSWORD \
    (security find-generic-password \
        -a "$USER" \
        -s "virya.synesthesia.upload" \
        -w 2>/dev/null)

test -n "$KEY_PASSWORD"
or begin
    echo "ERROR: signing password not found in macOS Keychain"
    exit 1
end

set -gx GODOT_ANDROID_KEYSTORE_RELEASE_PATH "$KEYSTORE"
set -gx GODOT_ANDROID_KEYSTORE_RELEASE_USER "upload"
set -gx GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD "$KEY_PASSWORD"

#
# VERSION BUMP
#

set OLD_CODE \
    (grep -m1 '^version/code=' "$CONFIG" | cut -d= -f2)

string match -qr '^[0-9]+$' "$OLD_CODE"
or begin
    echo "ERROR: invalid version/code: $OLD_CODE"
    exit 1
end

set NEW_CODE (math "$OLD_CODE + 1")

set BACKUP (mktemp -t synesthesia-export-presets)
cp "$CONFIG" "$BACKUP"
or exit 1

# fish_exit daje nam rollback także przy większości przerw/faili.
set -g __SYN_PLAY_CONFIG "$CONFIG"
set -g __SYN_PLAY_BACKUP "$BACKUP"
set -g __SYN_PLAY_KEEP 0

function __syn_play_cleanup --on-event fish_exit
    if test "$__SYN_PLAY_KEEP" != "1"
        if test -f "$__SYN_PLAY_BACKUP"
            cp "$__SYN_PLAY_BACKUP" "$__SYN_PLAY_CONFIG"
            echo
            echo "VERSION_CODE=RESTORED"
        end
    end

    test -f "$__SYN_PLAY_BACKUP"; and rm -f "$__SYN_PLAY_BACKUP"
end

python3 -c '
from pathlib import Path
import re, sys

p = Path(sys.argv[1])
code = int(sys.argv[2])

s = p.read_text()
s, count = re.subn(
    r"(?m)^version/code=\d+$",
    f"version/code={code}",
    s
)

if count < 1:
    raise SystemExit("version/code not found")

p.write_text(s)
' "$CONFIG" "$NEW_CODE"

or exit 1

set VERSION_NAME \
    (grep -m1 '^version/name=' "$CONFIG" | cut -d= -f2- | string trim -c '"')

echo
echo "PLAY_VERSION=$VERSION_NAME"
echo "VERSION_CODE=$OLD_CODE -> $NEW_CODE"

#
# SOURCE + RUST GATES
#

echo
echo "=== SOURCE VALIDATION ==="

./scripts/validate-source.sh
or exit 1

set RUST_NATIVE_TOOLCHAIN (grep '^RUST_NATIVE_TOOLCHAIN=' config/toolchains.env | cut -d= -f2)

test -n "$RUST_NATIVE_TOOLCHAIN"; or begin
echo "ERROR: RUST_NATIVE_TOOLCHAIN missing from config/toolchains.env" >&2
exit 1
end

command -q rustup; or begin
echo "ERROR: rustup not found" >&2
exit 1
end

if not rustup toolchain list | string match -qr "^$RUST_NATIVE_TOOLCHAIN"
echo "Installing Rust toolchain $RUST_NATIVE_TOOLCHAIN..."
rustup toolchain install "$RUST_NATIVE_TOOLCHAIN" --profile minimal
or exit 1
end

if not rustup target list --installed --toolchain "$RUST_NATIVE_TOOLCHAIN" | grep -qx "aarch64-linux-android"
echo "Installing aarch64-linux-android for Rust $RUST_NATIVE_TOOLCHAIN..."
rustup target add aarch64-linux-android --toolchain "$RUST_NATIVE_TOOLCHAIN"
or exit 1
end

set -gx RUSTUP_TOOLCHAIN "$RUST_NATIVE_TOOLCHAIN"

echo "RUST_TOOLCHAIN=$RUST_NATIVE_TOOLCHAIN"
echo "RUST_TARGET=aarch64-linux-android"

echo
echo "=== RUST ANDROID ARM64 ==="

env SYNESTHESIA_RUST_PROFILE=release \
    ./scripts/build-rust-native.sh android-arm64
or exit 1

#
# LOCAL GRADLE TEMPLATE
#

set GIT_EXCLUDE (git rev-parse --git-path info/exclude)

if not grep -qxF '/android/' "$GIT_EXCLUDE" 2>/dev/null
    echo '/android/' >> "$GIT_EXCLUDE"
end

set INSTALL_ARGS

if not test -d android/build
    echo
    echo "ANDROID_GRADLE_TEMPLATE=INSTALL"
    set INSTALL_ARGS --install-android-build-template
end

#
# AAB
#

mkdir -p build/android
rm -f "$AAB" "$AAB.sha256"

echo
echo "=== PLAY AAB BUILD ==="

"$GODOT" \
    --headless \
    --path "$ROOT" \
    $INSTALL_ARGS \
    --export-release "$PRESET" \
    "$ROOT/$AAB"

or exit 1

test -s "$AAB"
or begin
    echo "ERROR: Godot did not produce AAB"
    exit 1
end

#
# VERIFY
#

echo
echo "=== VERIFY AAB ==="

unzip -tq "$AAB"
or begin
    echo "ERROR: invalid AAB ZIP"
    exit 1
end

"$JAVA_HOME/bin/jarsigner" -verify "$AAB" >/dev/null
or begin
    echo "ERROR: AAB signature verification failed"
    exit 1
end

unzip -Z1 "$AAB" | grep -q 'libsynesthesia_gdext\.so$'
or begin
    echo "ERROR: Rust GDExtension missing from AAB"
    exit 1
end

python3 scripts/check-android-elf-alignment.py "$AAB" "$ANDROID_NDK_HOME"
or begin
    echo "ERROR: one or more arm64 native libraries are not 16 KiB page compatible" >&2
    exit 1
end

#
# SUCCESS — keep bumped code
#

set -g __SYN_PLAY_KEEP 1

echo
echo "=== PLAY BUILD READY ==="
echo "package=music.virya.synesthesia"
echo "versionName=$VERSION_NAME"
echo "versionCode=$NEW_CODE"

ls -lh "$AAB"

echo
echo "=== SHA256 ==="

shasum -a 256 "$AAB" | tee "$AAB.sha256"

echo
echo "SIGNATURE=PASS"
echo "RUST_GDEXTENSION=PASS"
echo "PAGE_SIZE_16K=PASS"
echo "BUILD=PASS"
echo "AAB=$ROOT/$AAB"

set -e KEY_PASSWORD