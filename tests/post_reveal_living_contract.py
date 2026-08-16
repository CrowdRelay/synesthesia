#!/usr/bin/env python3
"""Contracts for the permanent post-reveal living-room state."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

runtime = ROOT / "scripts/render/post_reveal_living_runtime.gd"
world = ROOT / "scripts/render/world_micro_fx_layer.gd"
shader = ROOT / "shaders/room_composite.gdshader"
setup = ROOT / "scripts/render/room_visual_setup.gd"
for p in (runtime, world, shader, setup):
    if not p.is_file():
        failures.append(f"missing {p.relative_to(ROOT)}")

runtime_text = runtime.read_text(errors="replace") if runtime.is_file() else ""
world_text = world.read_text(errors="replace") if world.is_file() else ""
shader_text = shader.read_text(errors="replace") if shader.is_file() else ""
setup_text = setup.read_text(errors="replace") if setup.is_file() else ""

for token in ("settle_delay", "living_strength", "_instant_restore", "reduced_motion", "target_fps", "set_target_fps", "func set_revealed", "set_process(false)"):
    if token not in runtime_text:
        failures.append(f"post reveal runtime missing {token}")
for token in ("set_living_strength", "set_target_fps", '"calling"', '"party"', '"unmasked"', '"waves"', '"uncertainty"'):
    if token not in world_text:
        failures.append(f"world micro FX missing {token}")
for token in ("living_strength", "living_time", "Calling: candles + living liquid surface", "Party: slow specular sweeps", "Waves: rain/window light"):
    if token not in shader_text:
        failures.append(f"room composite missing {token}")
for token in ("PostRevealLivingRuntimeScript", "post_reveal_runtime.configure(room_data)"):
    if token not in setup_text:
        failures.append(f"room visual setup missing {token}")

profiles: set[str] = set()
for manifest in sorted((ROOT / "data/releases").glob("*/manifest.json")):
    data = json.loads(manifest.read_text())
    room = data.get("room", {})
    cfg = room.get("living_state", {})
    rid = str(data.get("release_id", manifest.parent.name))
    if not isinstance(cfg, dict) or not cfg.get("enabled"):
        failures.append(f"{rid}: living_state must be enabled")
        continue
    effects = cfg.get("effects", [])
    if not isinstance(effects, list) or len(effects) < 4:
        failures.append(f"{rid}: needs at least four living effects")
    strength = float(cfg.get("strength", 0.0))
    if not 0.60 <= strength <= 0.95:
        failures.append(f"{rid}: living strength outside 0.60..0.95")
    delay = float(cfg.get("settle_delay", 0.0))
    if not 1.5 <= delay <= 2.6:
        failures.append(f"{rid}: settle delay outside 1.5..2.6")
    target_fps = float(cfg.get("target_fps", 0.0))
    if not 12.0 <= target_fps <= 30.0:
        failures.append(f"{rid}: living target_fps outside 12..30")
    profiles.add(str(cfg.get("profile", "")))

if len(profiles) != 11:
    failures.append(f"living profiles must remain unique by room style count=11 got={len(profiles)}")

for slug in ("unmasked", "the-calling", "waves"):
    data = json.loads((ROOT / "data/releases" / slug / "manifest.json").read_text())
    art = data["room"]["art_direction"]
    if art.get("asset_generation") != "post-reveal-v6-master":
        failures.append(f"{slug}: new v6 master not wired")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_POST_REVEAL_LIVING=FAIL count={len(failures)}")

print("SYNESTHESIA_POST_REVEAL_LIVING=PASS rooms=11 hero=settle living=permanent paced=manifest-fps uncertainty=waves invaluable=glass-sweep")
