#!/usr/bin/env bash
# Build a tenant-branded Synesthesia Android AAB.
#
# Fetches the tenant config from the control plane, patches export_presets.cfg
# with the tenant package name and app name, generates branded icons + boot
# splash from the tenant palette, builds the Rust native extension, then
# exports the Android AAB via Godot headless.
#
# The original export_presets.cfg is backed up and restored after the build.
#
# Usage:
#   bash scripts/build-tenant-app.sh \
#       --tenant virya \
#       --control-plane-url https://control.virya.music \
#       --token $CONTROL_PLANE_ADMIN_TOKEN \
#       --version 2.0.0 \
#       --version-code 26
#
# Outputs:
#   build/tenant-apps/{slug}-synesthesia-{version}.aab
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/config/toolchains.env"

TENANT=""
CONTROL_PLANE_URL=""
TOKEN=""
VERSION=""
VERSION_CODE=""
GODOT_BIN="${GODOT_BIN:-}"
PUBLISH="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant) TENANT="$2"; shift 2 ;;
    --control-plane-url) CONTROL_PLANE_URL="$2"; shift 2 ;;
    --token) TOKEN="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --version-code) VERSION_CODE="$2"; shift 2 ;;
    --godot-bin) GODOT_BIN="$2"; shift 2 ;;
    --publish) PUBLISH="true"; shift ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$TENANT" ]] || { echo "ERROR: --tenant is required" >&2; exit 2; }
[[ -n "$CONTROL_PLANE_URL" ]] || { echo "ERROR: --control-plane-url is required" >&2; exit 2; }
[[ -n "$TOKEN" ]] || { echo "ERROR: --token is required" >&2; exit 2; }
[[ -n "$VERSION" ]] || { echo "ERROR: --version is required" >&2; exit 2; }
[[ -n "$VERSION_CODE" ]] || { echo "ERROR: --version-code is required" >&2; exit 2; }
[[ -n "$GODOT_BIN" ]] || { echo "ERROR: --godot-bin or GODOT_BIN env var is required" >&2; exit 2; }

CONFIG_FILE="$ROOT/build/tenant-apps/${TENANT}-config.json"
CONFIG_DIR="$(dirname "$CONFIG_FILE")"
mkdir -p "$CONFIG_DIR"

echo "TENANT_BUILD=FETCH tenant=$TENANT url=$CONTROL_PLANE_URL"
python3 "$ROOT/tools/fetch-tenant-config.py" \
  --tenant "$TENANT" \
  --control-plane-url "$CONTROL_PLANE_URL" \
  --token "$TOKEN" \
  --output "$CONFIG_FILE"

PACKAGE_ID="$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['packageId'])")"
APP_NAME="$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['appName'])")"

echo "TENANT_BUILD=CONFIG package=$PACKAGE_ID app=\"$APP_NAME\""

# Generate tenant-branded icons + boot splash
echo "TENANT_BUILD=BRANDING"
python3 "$ROOT/tools/generate-tenant-branding.py" \
  --config "$CONFIG_FILE" \
  --output-dir "$ROOT/assets/branding/tenant"

# Back up export_presets.cfg
PRESETS="$ROOT/export_presets.cfg"
BACKUP="$PRESETS.bak"
cp "$PRESETS" "$BACKUP"
trap 'cp "$BACKUP" "$PRESETS"; rm -f "$BACKUP"; echo "TENANT_BUILD=RESTORE export_presets.cfg restored"' EXIT

# Patch export_presets.cfg: package name, app name, version
# We use Python to safely patch the Godot preset file
python3 -c "
import re
source = open('$PRESETS').read()
# Patch all Android presets' package/unique_name
source = re.sub(
    r'package/unique_name=\"[^\"]*\"',
    'package/unique_name=\"$PACKAGE_ID\"',
    source,
)
# Patch all Android presets' package/name
source = re.sub(
    r'package/name=\"[^\"]*\"',
    'package/name=\"$APP_NAME\"',
    source,
)
# Patch version/code
source = re.sub(
    r'version/code=\d+',
    'version/code=$VERSION_CODE',
    source,
)
# Patch version/name
source = re.sub(
    r'version/name=\"[^\"]*\"',
    'version/name=\"$VERSION\"',
    source,
)
open('$PRESETS', 'w').write(source)
print('TENANT_BUILD=PATCH export_presets.cfg patched')
"

# Build the Rust native extension
echo "TENANT_BUILD=RUST_NATIVE"
bash "$ROOT/scripts/build-rust-native.sh"

# Export the Android AAB via Godot headless
echo "TENANT_BUILD=GODOT_EXPORT"
export_dir="$ROOT/build/tenant-apps"
mkdir -p "$export_dir"

"$GODOT_BIN" --headless --export-release "Android Release" "$export_dir/${TENANT}-synesthesia-${VERSION}.aab"

AAB_DEST="$export_dir/${TENANT}-synesthesia-${VERSION}.aab"
[[ -s "$AAB_DEST" ]] || { echo "ERROR: AAB was not produced at $AAB_DEST" >&2; exit 1; }

echo "TENANT_BUILD=AAB_DONE dest=$AAB_DEST bytes=$(stat -f%z "$AAB_DEST" 2>/dev/null || stat -c%s "$AAB_DEST")"

if [[ "$PUBLISH" == "true" ]]; then
  echo "TENANT_BUILD=PUBLISH_START package=$PACKAGE_ID"
  echo "ERROR: publishing is not yet implemented in this script. Use the Google Play Console." >&2
  exit 3
fi

echo "TENANT_BUILD=SUCCESS tenant=$TENANT package=$PACKAGE_ID version=$VERSION"
