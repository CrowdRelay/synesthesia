#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
python3 "$ROOT/tests/static_validate.py"

GODOT_BIN="${GODOT_BIN:-godot}"
if command -v "$GODOT_BIN" >/dev/null 2>&1; then
  "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/validate_project.gd
  echo "SYNESTHESIA_GODOT_RUNTIME=PASS"
else
  echo "SYNESTHESIA_GODOT_RUNTIME=SKIPPED reason=godot-not-installed"
fi
