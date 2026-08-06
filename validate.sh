#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd -P)"
cd "$ROOT"

python3 -m compileall -q tests tools
python3 tests/static_validate.py
python3 tools/perf_budget.py
python3 tools/audio_mix_budget.py
python3 tests/room_pipeline_contract.py
python3 tests/visual_snapshot_contract.py
python3 tests/new_release_pack_contract.py
python3 tools/asset_report.py

GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "SYNESTHESIA_GODOT_RUNTIME=SKIPPED reason=godot-not-installed"
  exit 0
fi

run_godot_checked() {
  local label="$1"
  shift
  local log_file
  log_file="$(mktemp "${TMPDIR:-/tmp}/synesthesia-${label}.XXXXXX.log")"
  set +e
  "$GODOT_BIN" "$@" 2>&1 | tee "$log_file"
  local status=${PIPESTATUS[0]}
  set -e
  if (( status != 0 )); then
    echo "SYNESTHESIA_GODOT_RUNTIME=FAIL stage=$label exit_code=$status" >&2
    rm -f "$log_file"
    return "$status"
  fi
  if grep -E '(^|[[:space:]])(SCRIPT ERROR:|ERROR:|Parse Error:|Compile Error:|Failed loading resource:|Warning treated as error)' "$log_file" >/dev/null; then
    echo "SYNESTHESIA_GODOT_RUNTIME=FAIL stage=$label reason=godot-error-log" >&2
    rm -f "$log_file"
    return 1
  fi
  rm -f "$log_file"
}

run_godot_checked import --headless --editor --path "$ROOT" --quit
run_godot_checked validation --headless --path "$ROOT" --script res://tests/validate_project.gd

echo "SYNESTHESIA_GODOT_RUNTIME=PASS"
