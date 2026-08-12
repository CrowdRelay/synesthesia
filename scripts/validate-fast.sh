#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

./scripts/prepare-bundled-fonts.sh
python3 tools/source_hygiene.py
python3 -m compileall -q tests tools
python3 tests/static_validate.py
python3 tests/adaptive_viewport_contract.py
python3 tools/perf_budget.py
python3 tests/room_pipeline_contract.py
python3 tests/interaction_guidance_contract.py
python3 tests/room_mechanics_v2_contract.py
python3 tests/technophobia_vertical_slice_contract.py
python3 tests/full_room_gameplay_contract.py
python3 tests/gesture_semantics_contract.py
python3 tests/runtime_hot_path_contract.py
python3 tests/player_experience_evolution_contract.py
python3 tests/ui_input_contract.py
python3 tests/ui_performance_contract.py
python3 tests/ui_scale_flow_contract.py
python3 tests/mobile_feedback_contract.py
python3 tests/mobile_clarity_contract.py
python3 tests/mobile_product_readability_contract.py
python3 tests/gameplay_telemetry_contract.py

printf '%s\n' 'SYNESTHESIA_FAST_VALIDATION=PASS scope=gameplay+mobile+hot-path+source'
