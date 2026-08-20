#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
python3 scripts/check-ci-policy.py

# Gameplay/mobile/hot-path invariants are owned by the fast gate and are not
# re-run here. Extra independent contracts run in one bounded parallel batch.
./scripts/validate-fast.sh
python3 scripts/run-contracts.py --jobs "${SYNESTHESIA_CONTRACT_JOBS:-4}" \
  tests/boot_visual_continuity_contract.py \
  tests/finale_mobile_layout_contract.py \
  tests/e2e_semantic_feed_contract.py \
  tests/signal_finale_cta_contract.py \
  tools/memory_budget.py \
  tools/audio_mix_budget.py \
  tests/visual_snapshot_contract.py \
  tests/production_polish_contract.py \
  tests/interactive_album_contract.py \
  tests/room_asset_slots_contract.py \
  tests/menu_soundscape_contract.py \
  tests/rust_hybrid_contract.py \
  tests/startup_latency_contract.py \
  tests/runtime_resilience_contract.py \
  tests/room_preload_cache_contract.py \
  tests/save_state_cache_contract.py \
  tests/save_reliability_contract.py \
  tests/service_worker_consistency_contract.py \
  tests/release_hardening_v3_contract.py \
  tests/web_cache_fingerprint_contract.py \
  tests/web_bundle_budget_contract.py \
  tests/web_cold_load_payload_contract.py \
  tests/ecosystem_v4_player_context_contract.py \
  tests/application_lifecycle_contract.py \
  tests/source_hygiene_contract.py \
  tests/export_surface_contract.py \
  tests/build_cache_contract.py \
  tests/godot_runtime_path_contract.py \
  tests/ci_cache_contract.py \
  tests/release_pipeline_contract.py \
  tests/google_play_production_contract.py \
  tests/font_supply_chain_contract.py \
  tests/toolchain_pin_contract.py \
  tests/rust_architecture_doc_contract.py \
  tests/sensory_room_contract.py \
  tests/door_transition_contract.py \
  tests/cinematic_video_contract.py \
  tests/ecosystem_visual_convergence_contract.py \
  tests/presentation_contract.py \
  tests/rum_contract.py \
  tests/android_pipeline_contract.py \
  tests/netlify_artifact_deploy_contract.py \
  tests/production_e2e_contract.py \
  tests/validation_entrypoint_contract.py
# These two contracts are intentionally isolated: release-pack copies a source
# tree and the Godot log gate performs filesystem-heavy fixture work. Running
# them beside the read-only scanners creates avoidable I/O contention in CI.
python3 tests/new_release_pack_contract.py
python3 tests/godot_log_gate_contract.py
python3 tools/asset_report.py
printf '%s\n' 'SYNESTHESIA_SOURCE_VALIDATION=PASS contracts=canonical execution=parallel'