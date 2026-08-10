#!/usr/bin/env python3
"""Contract for exploration-first Technophobia vertical slice."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

behavior_path = ROOT / "scripts/rooms/behaviors/technophobia.gd"
behavior = behavior_path.read_text(errors="replace") if behavior_path.is_file() else ""
for token in (
    "CABLE_PLUGS",
    '"cables_unplugged"',
    '"active_cable"',
    '"breaker_off"',
    '"signal_tune"',
    '"signal_locked"',
    '"press":',
    '"drag":',
    '"release":',
    '"hold":',
    '"cable_unplug"',
    '"breaker"',
    '"signal_lock"',
    "CABLE_RELEASE_DISTANCE",
    "_render_cables",
    "_render_breaker",
    "_render_tuner",
    "captures_pointer_at",
):
    if token not in behavior:
        failures.append(f"technophobia behavior missing {token}")

manifest = json.loads((ROOT / "data/releases/technophobia/manifest.json").read_text())
micro = manifest.get("room", {}).get("micro_interactions", {})
if micro.get("version") != 1:
    failures.append("technophobia micro_interactions.version must equal 1")
steps = micro.get("steps", [])
if [step.get("id") for step in steps if isinstance(step, dict)] != ["cables", "breaker", "tuner"]:
    failures.append("technophobia micro interaction chain must be cables -> breaker -> tuner")
if len(micro.get("discoverables", [])) != 3:
    failures.append("technophobia must expose three discoverable echoes")

for rel, tokens in {
    "scripts/audio_director.gd": ("cable_unplug", "breaker-off.wav", "signal-lock.wav"),
    "scripts/haptics.gd": ('"cable_unplug"', '"breaker"', '"signal_lock"'),
    "scripts/render/interaction_fx_layer.gd": ("_draw_unplug_sparks", "_draw_breaker_pulse", "_draw_signal_lock"),
    "scripts/ui/app_hud.gd": ("func update_instruction", "SZUKAJ ŹRÓDEŁ SZUMU"),
    "scripts/render/room_stage.gd": ("func get_interaction_hint",),
    "scripts/render/room_interaction_flow.gd": ("prop_capture", "captures_pointer_at"),
    "scripts/rooms/behavior_base.gd": ("func captures_pointer_at",),
}.items():
    text = (ROOT / rel).read_text(errors="replace")
    for token in tokens:
        if token not in text:
            failures.append(f"{rel}: missing {token}")

for rel in (
    "assets/audio/sfx/cable-unplug.wav",
    "assets/audio/sfx/cable-snap.wav",
    "assets/audio/sfx/breaker-off.wav",
    "assets/audio/sfx/signal-lock.wav",
):
    path = ROOT / rel
    if not path.is_file() or path.stat().st_size < 8_000:
        failures.append(f"missing/too-small tactile SFX: {rel}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_TECHNOPHOBIA_VERTICAL_SLICE=FAIL count={len(failures)}")

print(
    "SYNESTHESIA_TECHNOPHOBIA_VERTICAL_SLICE=PASS "
    "loop=discover+pull+hold+tune feedback=visual+audio+haptic echoes=3"
)
