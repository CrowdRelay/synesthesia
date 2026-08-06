#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
python3 "$ROOT/tests/static_validate.py"
python3 "$ROOT/tools/perf_budget.py"

GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "SYNESTHESIA_GODOT_RUNTIME=SKIPPED reason=godot-not-installed"
  exit 0
fi

log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT

set +e
"$GODOT_BIN" --headless --path "$ROOT" --script res://tests/validate_project.gd 2>&1 | tee "$log_file"
status=${PIPESTATUS[0]}
set -e

if (( status != 0 )); then
  echo "SYNESTHESIA_GODOT_RUNTIME=FAIL exit_code=$status" >&2
  exit "$status"
fi

if grep -E '(^|[[:space:]])(SCRIPT ERROR:|ERROR:|Parse Error:|Compile Error:|Failed loading resource:|Warning treated as error)' "$log_file" >/dev/null; then
  echo "SYNESTHESIA_GODOT_RUNTIME=FAIL reason=godot-error-log" >&2
  exit 1
fi

echo "SYNESTHESIA_GODOT_RUNTIME=PASS"
