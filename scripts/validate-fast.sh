#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
export PYTHONDONTWRITEBYTECODE=1
PYCACHE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/synesthesia-pycache.XXXXXX")"
cleanup_pycache() { rm -rf "$PYCACHE_DIR"; }
trap cleanup_pycache EXIT

./scripts/prepare-bundled-fonts.sh
python3 tools/source_hygiene.py
PYTHONPYCACHEPREFIX="$PYCACHE_DIR" python3 -m compileall -q tests tools scripts/run-contracts.py
python3 scripts/run-contracts.py --jobs "${SYNESTHESIA_CONTRACT_JOBS:-4}" \
  tests/static_validate.py \
  tests/adaptive_viewport_contract.py \
  tools/perf_budget.py \
  tests/room_pipeline_contract.py \
  tests/interaction_guidance_contract.py \
  tests/room_mechanics_v2_contract.py \
  tests/technophobia_vertical_slice_contract.py \
  tests/ward_interaction_alignment_contract.py \
  tests/ward_haptics_contract.py \
  tests/full_room_gameplay_contract.py \
  tests/gesture_semantics_contract.py \
  tests/runtime_hot_path_contract.py \
  tests/runtime_loader_deadline_contract.py \
  tests/player_experience_evolution_contract.py \
  tests/ui_input_contract.py \
  tests/finale_settings_startup_regression_contract.py \
  tests/finale_hint_overlay_regression_contract.py \
  tests/ui_performance_contract.py \
  tests/ui_scale_flow_contract.py \
  tests/mobile_feedback_contract.py \
  tests/mobile_clarity_contract.py \
  tests/mobile_product_readability_contract.py \
  tests/mobile_game_next_level_contract.py \
  tests/interaction_assist_readability_contract.py \
  tests/gameplay_telemetry_contract.py \
  tests/v1_game_loop_contract.py \
  tests/mobile_speedrun_feedback_contract.py \
  tests/leaderboard_player_feedback_contract.py \
  tests/finale_timing_signal_flow_contract.py \
  tests/reward_client_reliability_contract.py \
  tests/finale_scroll_and_native_signal_contract.py \
  tests/v2_gameplay_polish_contract.py \
  tests/mastery_memory_contract.py

printf '%s\n' 'SYNESTHESIA_FAST_VALIDATION=PASS scope=gameplay+mobile+hot-path+reward-reliability+source execution=parallel'
