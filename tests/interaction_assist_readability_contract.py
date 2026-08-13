#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
hint = (ROOT / "scripts/render/interaction_hint_layer.gd").read_text()
stage = (ROOT / "scripts/render/room_stage.gd").read_text()
profile = (ROOT / "scripts/render/room_render_profile.gd").read_text()
shader = (ROOT / "shaders/room_composite.gdshader").read_text()

assert "func is_active()" in hint
assert "func set_assist_level(value: int)" in hint
assert 'has_method("is_active")' in stage and 'has_method("set_assist_level")' in stage
assert "readability_local_contrast" in profile and "readability_local_contrast" in shader
assert "chroma_delta" in shader
for manifest in sorted((ROOT / "data/releases").glob("*/manifest.json")):
    data = json.loads(manifest.read_text())
    profiles = []
    def walk(value):
        if isinstance(value, dict):
            if isinstance(value.get("mobile_readability"), dict): profiles.append(value["mobile_readability"])
            for child in value.values(): walk(child)
        elif isinstance(value, list):
            for child in value: walk(child)
    walk(data)
    assert len(profiles) == 1, manifest
    value = profiles[0].get("local_contrast")
    assert isinstance(value, (int, float)) and 0.0 <= value <= 1.0, manifest
print("INTERACTION_ASSIST_READABILITY=PASS")
