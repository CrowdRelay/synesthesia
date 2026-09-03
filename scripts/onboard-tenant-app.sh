#!/usr/bin/env bash
# Onboard a tenant's Synesthesia mobile app end-to-end.
#
# This is the single script an operator runs to set up everything needed
# for a tenant's Google Play Synesthesia app. It:
#
#   1. Fetches the tenant config from the control plane
#   2. Generates an Android signing keystore
#   3. Prints a checklist of remaining manual steps (Firebase, Play Console)
#
# Prerequisites:
#   - keytool (comes with JDK)
#   - Python 3.12+ with Pillow (pip install Pillow)
#   - Godot 4.7 (for the actual build, run separately via CI)
#
# Usage:
#   bash scripts/onboard-tenant-app.sh \
#       --tenant future-metal \
#       --control-plane-url https://control.virya.music \
#       --token $CONTROL_PLANE_ADMIN_TOKEN \
#       --version 2.0.0 \
#       --version-code 1
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

TENANT=""
CONTROL_PLANE_URL=""
TOKEN=""
VERSION=""
VERSION_CODE=""
SET_GITHUB_SECRETS="false"
TRIGGER_BUILD="false"
SKIP_KEYSTORE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant) TENANT="$2"; shift 2 ;;
    --control-plane-url) CONTROL_PLANE_URL="$2"; shift 2 ;;
    --token) TOKEN="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --version-code) VERSION_CODE="$2"; shift 2 ;;
    --set-github-secrets) SET_GITHUB_SECRETS="true"; shift ;;
    --trigger-build) TRIGGER_BUILD="true"; shift ;;
    --skip-keystore) SKIP_KEYSTORE="true"; shift ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$TENANT" ]] || { echo "ERROR: --tenant is required" >&2; exit 2; }
[[ -n "$CONTROL_PLANE_URL" ]] || { echo "ERROR: --control-plane-url is required" >&2; exit 2; }
[[ -n "$TOKEN" ]] || { echo "ERROR: --token is required" >&2; exit 2; }
[[ -n "$VERSION" ]] || { echo "ERROR: --version is required" >&2; exit 2; }
[[ -n "$VERSION_CODE" ]] || { echo "ERROR: --version-code is required" >&2; exit 2; }

PACKAGE_ID="music.${TENANT}.synesthesia"
KEYSTORE_DIR="$ROOT/build/tenant-keys"
CONFIG_FILE="$KEYSTORE_DIR/${TENANT}-synesthesia-config.json"
mkdir -p "$KEYSTORE_DIR"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Tenant Synesthesia Onboarding: $TENANT"
echo "║  Package: $PACKAGE_ID"
echo "║  Version: $VERSION ($VERSION_CODE)"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ── Step 1: Fetch tenant config ──────────────────────────────────
echo "── Step 1/4: Fetch tenant config ──────────────────────────────"
python3 "$ROOT/tools/fetch-tenant-config.py" \
  --tenant "$TENANT" \
  --control-plane-url "$CONTROL_PLANE_URL" \
  --token "$TOKEN" \
  --output "$CONFIG_FILE"
echo "✓ Tenant config fetched"
echo ""

# ── Step 2: Generate keystore ────────────────────────────────────
if [[ "$SKIP_KEYSTORE" == "true" ]]; then
  echo "── Step 2/4: Skip keystore generation ────────────────────────"
else
  echo "── Step 2/4: Generate Android signing keystore ────────────────"
  if [[ -f "$KEYSTORE_DIR/${TENANT}-synesthesia-upload.jks" ]]; then
    echo "✓ Keystore already exists (skipping)"
  else
    bash "$ROOT/scripts/generate-tenant-keystore.sh" --tenant "$TENANT"
  fi
fi
echo ""

# ── Step 3: GitHub secrets ───────────────────────────────────────
if [[ "$SET_GITHUB_SECRETS" == "true" ]]; then
  echo "── Step 3/4: Set GitHub repository secrets ────────────────────"
  SECRETS_FILE="$KEYSTORE_DIR/${TENANT}-synesthesia-secrets.env"
  if command -v gh >/dev/null 2>&1; then
    while IFS='=' read -r key value; do
      [[ "$key" =~ ^# ]] && continue
      [[ -z "$key" || -z "$value" ]] && continue
      gh secret set "$key" --body "$value" 2>/dev/null && echo "  ✓ $key" || echo "  ✗ $key (failed)"
    done < "$SECRETS_FILE"
    echo "✓ GitHub secrets set"
  else
    echo "⚠️  gh CLI not found — set secrets manually from $SECRETS_FILE"
  fi
else
  echo "── Step 3/4: GitHub secrets (manual) ──────────────────────────"
  echo "Set these secrets in GitHub:"
  echo "  - ANDROID_KEYSTORE_BASE64"
  echo "  - ANDROID_KEY_ALIAS"
  echo "  - ANDROID_KEY_PASSWORD"
  echo "  (from $KEYSTORE_DIR/${TENANT}-synesthesia-secrets.env)"
fi
echo ""

# ── Step 4: Build + manual checklist ─────────────────────────────
if [[ "$TRIGGER_BUILD" == "true" ]]; then
  echo "── Step 4/4: Trigger CI build workflow ────────────────────────"
  if command -v gh >/dev/null 2>&1; then
    gh workflow run tenant-app-build.yml \
      --field tenant_slug="$TENANT" \
      --field version="$VERSION" \
      --field version_code="$VERSION_CODE"
    echo "✓ Workflow triggered"
  else
    echo "⚠️  gh CLI not found — trigger manually in GitHub Actions"
  fi
else
  echo "── Step 4/4: Build ────────────────────────────────────────────"
  echo "Trigger the build in GitHub Actions:"
  echo "  'Tenant App Build' → Run workflow"
  echo "  tenant_slug=$TENANT  version=$VERSION  version_code=$VERSION_CODE"
fi
echo ""

echo "── Manual checklist ───────────────────────────────────────────"
echo "  1. ☐ Create app in Google Play Console (package: $PACKAGE_ID)"
echo "  2. ☐ Upload AAB from CI artifact to Play Console"
echo "  3. ☐ Set Play Store URL in control plane:"
echo "     PATCH $CONTROL_PLANE_URL/api/v1/tenants/$TENANT/mobile-apps"
echo "     { \"synesthesiaPlayStoreUrl\": \"https://play.google.com/store/apps/details?id=$PACKAGE_ID\" }"
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Onboarding complete! Follow the checklist above.           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
