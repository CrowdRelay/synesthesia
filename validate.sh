#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd -P)"
cd "$ROOT"

python3 -m compileall -q tests tools
python3 tests/static_validate.py
python3 tests/adaptive_viewport_contract.py
python3 tools/perf_budget.py
python3 tools/memory_budget.py
python3 tools/audio_mix_budget.py
python3 tests/room_pipeline_contract.py
python3 tests/visual_snapshot_contract.py
python3 tests/new_release_pack_contract.py
python3 tests/production_polish_contract.py
python3 tests/interactive_album_contract.py
python3 tests/interaction_guidance_contract.py
python3 tests/rust_hybrid_contract.py
python3 tests/sensory_room_contract.py
python3 tests/door_transition_contract.py
python3 tests/cinematic_video_contract.py
python3 tests/presentation_contract.py
python3 tests/comic_skin_contract.py
python3 tests/ui_input_contract.py
python3 tests/ui_performance_contract.py
python3 tests/ui_scale_flow_contract.py
python3 tests/ui_quality_polish_contract.py
python3 tests/android_pipeline_contract.py
python3 tests/godot_log_gate_contract.py
python3 tools/asset_report.py

GODOT_BIN="${GODOT_BIN:-godot}"
GODOT_LOG_DIR="${SYNESTHESIA_GODOT_LOG_DIR:-}"
if [[ -n "$GODOT_LOG_DIR" ]]; then
  mkdir -p "$GODOT_LOG_DIR"
fi

persist_godot_log() {
  local label="$1"
  local source="$2"
  if [[ -n "$GODOT_LOG_DIR" ]]; then
    cp "$source" "$GODOT_LOG_DIR/${label}.log"
  fi
}

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "SYNESTHESIA_GODOT_RUNTIME=SKIPPED reason=godot-not-installed"
  exit 0
fi

run_godot_checked() {
  local label="$1"
  local expected_marker="$2"
  local allow_shutdown_noise="$3"
  shift 3

  local log_file
  log_file="$(mktemp "${TMPDIR:-/tmp}/synesthesia-${label}.XXXXXX.log")"

  set +e
  "$GODOT_BIN" "$@" 2>&1 | tee "$log_file"
  local status=${PIPESTATUS[0]}
  set -e

  if (( status != 0 )); then
    echo "SYNESTHESIA_GODOT_RUNTIME=FAIL stage=$label exit_code=$status" >&2
    persist_godot_log "$label" "$log_file"
    rm -f "$log_file"
    return "$status"
  fi

  local gate_args=(
    python3 tools/godot_log_gate.py
    --stage "$label"
    --log "$log_file"
  )
  if [[ -n "$expected_marker" ]]; then
    gate_args+=(--expected-marker "$expected_marker")
  fi
  if [[ "$allow_shutdown_noise" == "1" ]]; then
    gate_args+=(--allow-471-shutdown-noise --max-objectdb 16 --max-resources 8)
  fi

  if ! "${gate_args[@]}"; then
    echo "SYNESTHESIA_GODOT_RUNTIME=FAIL stage=$label reason=godot-error-log" >&2
    persist_godot_log "$label" "$log_file"
    rm -f "$log_file"
    return 1
  fi

  persist_godot_log "$label" "$log_file"
  rm -f "$log_file"
}

run_godot_checked import "" 0 --headless --editor --path "$ROOT" --quit
run_godot_checked validation "SYNESTHESIA_VALIDATION=PASS" 0 --headless --path "$ROOT" --script res://tests/validate_project.gd
# Godot 4.7.1 can emit bounded shutdown-only ObjectDB/Resource diagnostics
# after a successful --script smoke run. The log gate allows only that exact
# post-PASS signature, only on 4.7.1, and only under a small numeric budget.
run_godot_checked lifecycle "SYNESTHESIA_LIFECYCLE_SMOKE=PASS" 1 --headless --path "$ROOT" --script res://tests/lifecycle_smoke.gd

echo "SYNESTHESIA_GODOT_RUNTIME=PASS"
