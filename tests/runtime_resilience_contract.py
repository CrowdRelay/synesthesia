#!/usr/bin/env python3
"""Principal-level runtime resilience contracts for adaptive quality and preload."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

adaptive = (ROOT / "scripts/app/adaptive_performance.gd").read_text()
for token in (
    "BAD_FRAME_EMA_MS",
    "HITCH_RATIO_BAD",
    "CHANGE_COOLDOWN_SECONDS",
    "MEMORY_GROWTH_SOFT_MB",
    "RESUME_DELTA_SECONDS",
    "func _reset_after_resume() -> void:",
    '"resume-warmup"',
    "func snapshot() -> Dictionary:",
    "_cooldown > 0.0",
    'return "frame-hitches"',
    'return "memory-pressure"',
):
    if token not in adaptive:
        failures.append(f"adaptive runtime contract missing: {token}")

preloader = (ROOT / "scripts/app/asset_preloader.gd").read_text()
audio = (ROOT / "scripts/audio_director.gd").read_text() + "\n" + (ROOT / "scripts/audio/audio_asset_runtime.gd").read_text()
for token in (
    "func wait_for_queued(",
    "await get_tree().process_frame",
    "blocking_takes",
    "max_block_ms",
    "func snapshot() -> Dictionary:",
    "critical_queued",
    "_has_in_progress(true)",
):
    if token not in preloader:
        failures.append(f"preloader observability contract missing: {token}")

main = "\n".join((ROOT / path).read_text() for path in ("scripts/main.gd", "scripts/app/main_room_flow.gd", "scripts/app/main_warmup_flow.gd"))
for token in (
    'diagnostics.configure(app.adaptive_performance, app.asset_preloader)',
    'await asset_preloader.wait_for_queued()',
):
    if token not in main:
        failures.append(f"main runtime wiring missing: {token}")

diagnostics = (ROOT / "scripts/app/diagnostics_overlay.gd").read_text()
ui_factory = (ROOT / "scripts/ui/ui_factory.gd").read_text()
lifecycle = (ROOT / "tests/lifecycle_smoke.gd").read_text()
for token in ("frame_ema_ms", "hitch_ratio", "blocking_takes", "max_block_ms"):
    if token not in diagnostics:
        failures.append(f"diagnostics metric missing: {token}")

if "func release_runtime_caches() -> void:" not in ui_factory:
    failures.append("UIFactory static resource cache has no explicit shutdown release")
if "UIFactory.release_runtime_caches()" not in lifecycle:
    failures.append("lifecycle smoke does not release UIFactory static resources")
if "UIFactory.release_runtime_caches()" not in main:
    failures.append("application shutdown does not release UIFactory static resources")


# Network clients must cap response buffers, and shutdown must never synchronously
# join an in-flight threaded resource load on the main thread.
reward_client = (ROOT / "scripts/reward_client.gd").read_text()
signup_client = (ROOT / "scripts/app/signal_signup_client.gd").read_text()
for label, source in (("reward", reward_client), ("signup", signup_client)):
    if "const MAX_RESPONSE_BYTES: int =" not in source or "body_size_limit = MAX_RESPONSE_BYTES" not in source:
        failures.append(f"{label} HTTP response body is not bounded")
drain_body = preloader.split("func drain() -> void:", 1)[1].split("func _exit_tree()", 1)[0]
if "THREAD_LOAD_IN_PROGRESS" in drain_body:
    failures.append("preloader drain synchronously joins in-flight threaded loads")
if "THREAD_LOAD_LOADED" not in drain_body:
    failures.append("preloader drain no longer consumes already-loaded resources")

for token in ("func take_if_ready(path: String) -> Resource:", "func is_queued(path: String) -> bool:"):
    if token not in preloader:
        failures.append(f"deferred preload API missing: {token}")
for token in ("_pending_excerpt_path", "_resolve_pending_excerpt()", "take_if_ready", "Deferred room music failed to preload", "if not _music_available and not _pending_excerpt_path.is_empty():"):
    if token not in audio:
        failures.append(f"deferred audio attachment missing: {token}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_RUNTIME_RESILIENCE=FAIL count={len(failures)}")

print("SYNESTHESIA_RUNTIME_RESILIENCE=PASS adaptive=frame-ema+hitches+cooldown+resume-guard memory=baseline+headroom preload=critical-only-transition-wait+deferred-audio+telemetry shutdown=static-cache-release")
