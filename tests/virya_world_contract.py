#!/usr/bin/env python3
"""Static contract for Virya worldbuilding and art-direction scaffolding."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

required_files = [
    ROOT / "data/virya_world.json",
    ROOT / "scripts/app/virya_world.gd",
]
for path in required_files:
    if not path.is_file():
        failures.append(f"missing {path.relative_to(ROOT)}")

world = {}
world_path = ROOT / "data/virya_world.json"
if world_path.is_file():
    world = json.loads(world_path.read_text())
    if not isinstance(world.get("characters"), list) or len(world["characters"]) < 4:
        failures.append("virya_world requires at least four character archetypes")
    if not isinstance(world.get("room_mapping"), dict) or len(world["room_mapping"]) != 11:
        failures.append("virya_world room mapping must cover 11 rooms")

for manifest_path in sorted((ROOT / "data/releases").glob("*/manifest.json")):
    data = json.loads(manifest_path.read_text())
    identity = data.get("virya_identity")
    rid = data.get("release_id", manifest_path.parent.name)
    if not isinstance(identity, dict):
        failures.append(f"{rid}: missing virya_identity")
        continue
    for key in (
        "character_id",
        "focus_title",
        "member_role",
        "story_role",
        "future_costume_hook",
        "hero_moment",
        "wow_upgrade",
        "band_integration",
    ):
        if not str(identity.get(key, "")).strip():
            failures.append(f"{rid}: virya_identity.{key} must be non-empty")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_VIRYA_WORLD=FAIL count={len(failures)}")

print(
    "SYNESTHESIA_VIRYA_WORLD=PASS "
    "archetypes=4 rooms=11"
)
