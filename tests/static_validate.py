#!/usr/bin/env python3
"""Fast offline contract checks for the Synestezja vertical slice."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED_FILES = [
    "project.godot",
    "scenes/main.tscn",
    "scripts/main.gd",
    "scripts/paint_room.gd",
    "scripts/audio_director.gd",
    "scripts/haptics.gd",
    "shaders/visual_snow.gdshader",
    "data/release_index.json",
    "data/releases/prototype/manifest.json",
]
REQUIRED_MANIFEST_KEYS = {
    "schema_version",
    "release_id",
    "room",
    "sensory",
    "collectibles",
}


def fail(message: str, failures: list[str]) -> None:
    failures.append(message)


def load_json(relative_path: str, failures: list[str]) -> dict:
    path = ROOT / relative_path
    try:
        value = json.loads(path.read_text())
    except Exception as exc:  # validation should report every issue at once
        fail(f"invalid JSON {relative_path}: {exc}", failures)
        return {}
    if not isinstance(value, dict):
        fail(f"JSON root must be an object: {relative_path}", failures)
        return {}
    return value


def validate() -> list[str]:
    failures: list[str] = []
    for relative in REQUIRED_FILES:
        if not (ROOT / relative).is_file():
            fail(f"missing file: {relative}", failures)

    index = load_json("data/release_index.json", failures)
    manifest = load_json("data/releases/prototype/manifest.json", failures)

    if index:
        releases = index.get("releases")
        if not isinstance(releases, list) or not releases:
            fail("release index must contain at least one release", failures)
        else:
            ids = {item.get("id") for item in releases if isinstance(item, dict)}
            if index.get("active_release") not in ids:
                fail("active_release must reference an indexed release", failures)
            for item in releases:
                if not isinstance(item, dict):
                    fail("release index entry must be an object", failures)
                    continue
                manifest_ref = item.get("manifest", "")
                if not isinstance(manifest_ref, str) or not manifest_ref.startswith("res://"):
                    fail("release manifest path must use res://", failures)
                    continue
                local = ROOT / manifest_ref.removeprefix("res://")
                if not local.is_file():
                    fail(f"indexed manifest missing: {manifest_ref}", failures)

    if manifest:
        missing = REQUIRED_MANIFEST_KEYS - manifest.keys()
        if missing:
            fail(f"manifest missing keys: {sorted(missing)}", failures)
        if manifest.get("schema_version") != 1:
            fail("prototype schema_version must equal 1", failures)

        room = manifest.get("room", {})
        threshold = room.get("completion_coverage") if isinstance(room, dict) else None
        if not isinstance(threshold, (int, float)) or not 0.1 <= float(threshold) <= 0.9:
            fail("completion_coverage must be between 0.1 and 0.9", failures)

        sensory = manifest.get("sensory", {})
        if not isinstance(sensory, dict):
            fail("sensory must be an object", failures)
        else:
            ceiling = sensory.get("safe_audio_ceiling_db")
            if not isinstance(ceiling, (int, float)) or float(ceiling) > -3.0:
                fail("safe_audio_ceiling_db must be <= -3 dB", failures)
            for key in ("visual_snow_calm", "visual_snow_full"):
                value = sensory.get(key)
                if not isinstance(value, (int, float)) or not 0.0 <= float(value) <= 0.12:
                    fail(f"{key} must be in safe prototype range 0..0.12", failures)
            for key in ("haptics_calm", "haptics_full"):
                value = sensory.get(key)
                if not isinstance(value, (int, float)) or not 0.0 <= float(value) <= 0.65:
                    fail(f"{key} must be in range 0..0.65", failures)

        collectibles = manifest.get("collectibles")
        if not isinstance(collectibles, list) or len(collectibles) != 3:
            fail("prototype must contain exactly three collectibles", failures)
        else:
            seen: set[str] = set()
            for item in collectibles:
                if not isinstance(item, dict):
                    fail("collectible must be an object", failures)
                    continue
                item_id = item.get("id")
                if not isinstance(item_id, str) or not item_id or item_id in seen:
                    fail("collectible ids must be non-empty and unique", failures)
                else:
                    seen.add(item_id)
                position = item.get("position")
                if (
                    not isinstance(position, list)
                    or len(position) != 2
                    or any(not isinstance(v, (int, float)) or not 0.0 <= float(v) <= 1.0 for v in position)
                ):
                    fail(f"collectible {item_id!r} position must be normalized", failures)

    source_text = "\n".join(
        path.read_text(errors="replace")
        for folder in (ROOT / "scripts", ROOT / "shaders")
        for path in folder.rglob("*")
        if path.is_file()
    )
    if "Input.vibrate_handheld" not in source_text:
        fail("haptics contract is missing", failures)

    project_config = (ROOT / "project.godot").read_text()
    if "pointing/emulate_touch_from_mouse=true" in project_config or "pointing/emulate_mouse_from_touch=true" in project_config:
        fail("touch and mouse emulation must stay disabled to prevent duplicate strokes", failures)
    bus_layout = (ROOT / "default_bus_layout.tres").read_text()
    for bus_name in ("Music", "Room", "Sensory", "UI"):
        if f'&"{bus_name}"' not in bus_layout:
            fail(f"missing audio bus: {bus_name}", failures)
    if "Uspokój pokój" not in source_text:
        fail("immediate calming control is missing", failures)
    if re.search(r"https?://", source_text, flags=re.IGNORECASE):
        fail("runtime core must remain network-free in the first slice", failures)
    for forbidden in ("analytics", "telemetry", "tracking_id", "admob"):
        if forbidden in source_text.lower():
            fail(f"forbidden first-slice dependency: {forbidden}", failures)

    audio_source = (ROOT / "scripts/audio_director.gd").read_text()
    frequencies = [float(value) for value in re.findall(r"TAU_F \* ([0-9]+(?:\.[0-9]+)?)", audio_source)]
    if frequencies and max(frequencies) > 1000.0:
        fail("procedural prototype contains an unnecessarily high tone", failures)

    return failures


def main() -> int:
    failures = validate()
    if failures:
        for item in failures:
            print(f"ERROR: {item}", file=sys.stderr)
        print(f"SYNESTHESIA_STATIC_VALIDATION=FAIL count={len(failures)}")
        return 1
    print("SYNESTHESIA_STATIC_VALIDATION=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
