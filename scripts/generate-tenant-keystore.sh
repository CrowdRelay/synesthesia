#!/usr/bin/env bash
# Generate an Android signing keystore for a tenant's Synesthesia app.
#
# Usage:
#   bash scripts/generate-tenant-keystore.sh --tenant future-metal
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

TENANT=""
KEYSTORE_PASSWORD=""
ALIAS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant) TENANT="$2"; shift 2 ;;
    --password) KEYSTORE_PASSWORD="$2"; shift 2 ;;
    --alias) ALIAS="$2"; shift 2 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$TENANT" ]] || { echo "ERROR: --tenant is required" >&2; exit 2; }
ALIAS="${ALIAS:-${TENANT}-synesthesia-upload}"
if [[ -z "$KEYSTORE_PASSWORD" ]]; then
  KEYSTORE_PASSWORD="$(python3 -c "import secrets, string; print(''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(32)))")"
fi

OUTPUT_DIR="$ROOT/build/tenant-keys"
mkdir -p "$OUTPUT_DIR"

KEYSTORE_PATH="$OUTPUT_DIR/${TENANT}-synesthesia-upload.jks"
SECRETS_FILE="$OUTPUT_DIR/${TENANT}-synesthesia-secrets.env"

echo "KEYSTORE_GEN=START tenant=$TENANT alias=$ALIAS"

keytool -genkeypair \
  -keystore "$KEYSTORE_PATH" \
  -storepass "$KEYSTORE_PASSWORD" \
  -alias "$ALIAS" \
  -keyalg EC \
  -keysize 256 \
  -validity 10950 \
  -dname "CN=${TENANT} Synesthesia Upload, O=CrowdRelay, C=PL" \
  -storetype JKS

echo "KEYSTORE_GEN=DONE path=$KEYSTORE_PATH"

KEYSTORE_B64="$(base64 -i "$KEYSTORE_PATH" | tr -d '\n')"

cat > "$SECRETS_FILE" <<EOF
# GitHub repository secrets for ${TENANT} Synesthesia app
ANDROID_KEYSTORE_BASE64=${KEYSTORE_B64}
ANDROID_KEY_ALIAS=${ALIAS}
ANDROID_KEY_PASSWORD=${KEYSTORE_PASSWORD}
EOF
chmod 600 "$SECRETS_FILE"

echo ""
echo "KEYSTORE_GEN=SUCCESS"
echo "Keystore:     $KEYSTORE_PATH"
echo "Secrets file: $SECRETS_FILE"
echo ""
echo "Add the three secrets to GitHub (repo settings → secrets → actions)."
