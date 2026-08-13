#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd -P)"
cd "$ROOT"

# Keep source-level gates identical across local, CI and Android builders.
if [[ "${SYNESTHESIA_SKIP_SOURCE_VALIDATION:-0}" != "1" ]]; then
  ./scripts/validate-source.sh
fi

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

# A source-only checkout may inherit .godot/extension_list.cfg from an earlier
# native build even after the generated descriptor was removed. Purge only that
# stale registration; a present generated descriptor remains untouched so native
# Rust runtime validation still works after ./scripts/build-rust-native.sh host.
if [[ ! -f "$ROOT/synesthesia_rust.gdextension" ]]; then
  ./scripts/build-rust-native.sh disable >/dev/null
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
    # Godot 4.7.1 still leaves three zero-ref threaded-loader bookkeeping
    # objects, but product-owned audio/resources must be fully released.
    gate_args+=(--allow-471-shutdown-noise --max-objectdb 3 --max-resources 0)
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
run_godot_checked font-glyphs "SYNESTHESIA_FONT_GLYPHS=PASS" 0 --headless --path "$ROOT" --script res://tests/font_glyph_smoke.gd
run_godot_checked gdscript-parse "SYNESTHESIA_GDSCRIPT_PARSE=PASS" 0 --headless --path "$ROOT" --script res://tests/gdscript_parse_smoke.gd
run_godot_checked validation "SYNESTHESIA_VALIDATION=PASS" 0 --headless --path "$ROOT" --script res://tests/validate_project.gd
# Godot 4.7.1 can emit bounded shutdown-only ObjectDB/Resource diagnostics
# after a successful --script smoke run. The log gate allows only that exact
# post-PASS signature, only on 4.7.1, and only for its three zero-ref objects.
run_godot_checked lifecycle "SYNESTHESIA_LIFECYCLE_SMOKE=PASS" 1 --headless --path "$ROOT" --script res://tests/lifecycle_smoke.gd

echo "SYNESTHESIA_GODOT_RUNTIME=PASS"
