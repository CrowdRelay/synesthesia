#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
python3 scripts/check-ci-policy.py

# Fast preflight for gameplay/mobile/hot-path contracts during development
./scripts/validate-fast.sh

# One canonical, platform-independent gate set. Native/Web/Android builders add
# their own engine/toolchain/export proofs after this script succeeds.
./scripts/prepare-bundled-fonts.sh
python3 tools/source_hygiene.py
python3 -m compileall -q tests tools

python3 tests/static_validate.py
python3 tests/adaptive_viewport_contract.py
python3 tests/boot_visual_continuity_contract.py
python3 tools/perf_budget.py
python3 tools/memory_budget.py
python3 tools/audio_mix_budget.py
python3 tests/room_pipeline_contract.py
python3 tests/visual_snapshot_contract.py
python3 tests/new_release_pack_contract.py
python3 tests/production_polish_contract.py
python3 tests/interactive_album_contract.py
python3 tests/interaction_guidance_contract.py
python3 tests/room_mechanics_v2_contract.py
python3 tests/technophobia_vertical_slice_contract.py
python3 tests/full_room_gameplay_contract.py
python3 tests/room_asset_slots_contract.py
python3 tests/menu_soundscape_contract.py
python3 tests/rust_hybrid_contract.py
python3 tests/gesture_semantics_contract.py
python3 tests/startup_latency_contract.py
python3 tests/runtime_resilience_contract.py
python3 tests/runtime_hot_path_contract.py
python3 tests/room_preload_cache_contract.py
python3 tests/save_state_cache_contract.py
python3 tests/save_reliability_contract.py
python3 tests/service_worker_consistency_contract.py
python3 tests/release_hardening_v3_contract.py
python3 tests/web_cache_fingerprint_contract.py
python3 tests/web_bundle_budget_contract.py
python3 tests/player_experience_evolution_contract.py
python3 tests/ecosystem_v4_player_context_contract.py
python3 tests/application_lifecycle_contract.py
python3 tests/source_hygiene_contract.py
python3 tests/export_surface_contract.py
python3 tests/build_cache_contract.py
python3 tests/godot_runtime_path_contract.py
python3 tests/ci_cache_contract.py
python3 tests/release_pipeline_contract.py
python3 tests/font_supply_chain_contract.py
python3 tests/toolchain_pin_contract.py
python3 tests/rust_architecture_doc_contract.py
python3 tests/sensory_room_contract.py
python3 tests/door_transition_contract.py
python3 tests/cinematic_video_contract.py
python3 tests/presentation_contract.py
python3 tests/post_reveal_living_contract.py
python3 tests/post_reveal_gameplay_v8_contract.py
python3 tests/room_signature_grammar_v9_contract.py
python3 tests/living_rooms_v4_contract.py
python3 tests/virya_world_contract.py
python3 tests/gamefeel_v5_contract.py
python3 tests/rum_contract.py
python3 tests/comic_skin_contract.py
python3 tests/ui_input_contract.py
python3 tests/finale_settings_startup_regression_contract.py
python3 tests/ui_performance_contract.py
python3 tests/ui_scale_flow_contract.py
python3 tests/ui_quality_polish_contract.py
python3 tests/mobile_feedback_contract.py
python3 tests/mobile_clarity_contract.py
python3 tests/mobile_product_readability_contract.py
python3 tests/interaction_assist_readability_contract.py
python3 tests/signal_design_system_contract.py
python3 tests/game_feel_v3_contract.py
python3 tests/gameplay_telemetry_contract.py
python3 tests/synesthesia_v2_art_contract.py
python3 tests/android_pipeline_contract.py
python3 tests/godot_log_gate_contract.py
python3 tests/netlify_artifact_deploy_contract.py
python3 tests/validation_entrypoint_contract.py
python3 tools/asset_report.py

printf '%s\n' 'SYNESTHESIA_SOURCE_VALIDATION=PASS contracts=canonical'
