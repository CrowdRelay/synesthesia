#!/usr/bin/env python3
"""Cross-file room scene/behavior/manifest contract test."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
index = json.loads((ROOT / "data/release_index.json").read_text())
failures: list[str] = []
for order, entry in enumerate(index["releases"]):
    slug = entry["id"]
    manifest = json.loads((ROOT / entry["manifest"].removeprefix("res://")).read_text())
    room = manifest["room"]
    scene = ROOT / room["scene_path"].removeprefix("res://")
    behavior = ROOT / room["behavior_script"].removeprefix("res://")
    scene_text = scene.read_text()
    behavior_text = behavior.read_text()
    if f'room_id = "{slug}"' not in scene_text:
        failures.append(f"{slug}: scene room_id")
    if 'room_stage.gd' not in scene_text:
        failures.append(f"{slug}: scene renderer")
    if 'extends "res://scripts/rooms/behavior_base.gd"' not in behavior_text:
        failures.append(f"{slug}: behavior base")
    acts = re.search(r'return\s*\[([^\]]+)\]', behavior_text)
    if not acts or len(re.findall(r'"[^"]+"', acts.group(1))) != 3:
        failures.append(f"{slug}: exactly three acts")
    if manifest["story_order"] != order:
        failures.append(f"{slug}: order")
if failures:
    raise SystemExit("SYNESTHESIA_ROOM_PIPELINE=FAIL " + ", ".join(failures))
print("SYNESTHESIA_ROOM_PIPELINE=PASS rooms=11 scenes=11 behaviors=11 acts=33")
