#!/usr/bin/env python3
"""Offline contracts for the complete VIRYA: Synestezja album experience."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_ORDER = [
    "wave-of-uncertainty",
    "party-time",
    "unmasked",
    "the-calling",
    "seed-of-doubt",
    "hybrid",
    "technophobia",
    "invaluable",
    "from-the-ashes",
    "waves",
    "rise",
]
EXPECTED_STYLES = {
    "wave-of-uncertainty": "uncertainty",
    "party-time": "party",
    "unmasked": "unmasked",
    "the-calling": "calling",
    "seed-of-doubt": "seed",
    "hybrid": "hybrid",
    "technophobia": "technophobia",
    "invaluable": "invaluable",
    "from-the-ashes": "ashes",
    "waves": "waves",
    "rise": "rise",
}
REQUIRED_FILES = [
    "project.godot",
    "export_presets.cfg",
    "netlify.toml",
    "run-macos.sh",
    "scripts/build-web-preview.sh",
    "scenes/main.tscn",
    "scripts/main.gd",
    "scripts/paint_room.gd",
    "scripts/audio_director.gd",
    "scripts/haptics.gd",
    "scripts/progress_store.gd",
    "scripts/reward_client.gd",
    "shaders/visual_snow.gdshader",
    "data/release_index.json",
    "web/reward/index.html",
    "web/_headers",
    ".github/workflows/ci.yml",
    ".github/workflows/build.yml",
    ".github/workflows/deploy-web.yml",
]
MANIFEST_KEYS = {"schema_version", "release_id", "room", "sensory", "collectibles", "audio"}


def fail(message: str, failures: list[str]) -> None:
    failures.append(message)


def load_json(path: Path, failures: list[str]) -> dict:
    try:
        value = json.loads(path.read_text())
    except Exception as exc:
        fail(f"invalid JSON {path.relative_to(ROOT)}: {exc}", failures)
        return {}
    if not isinstance(value, dict):
        fail(f"JSON root must be an object: {path.relative_to(ROOT)}", failures)
        return {}
    return value


def validate_manifest(path: Path, expected_id: str, failures: list[str]) -> None:
    manifest = load_json(path, failures)
    if not manifest:
        return
    missing = MANIFEST_KEYS - manifest.keys()
    if missing:
        fail(f"{expected_id}: manifest missing keys {sorted(missing)}", failures)
    if manifest.get("schema_version") != 3:
        fail(f"{expected_id}: schema_version must equal 3", failures)
    if manifest.get("release_id") != expected_id:
        fail(f"{expected_id}: release_id mismatch", failures)

    room = manifest.get("room")
    if not isinstance(room, dict):
        fail(f"{expected_id}: room must be an object", failures)
        room = {}
    if room.get("visual_style") != EXPECTED_STYLES[expected_id]:
        fail(f"{expected_id}: unexpected visual_style", failures)
    threshold = room.get("completion_coverage")
    if not isinstance(threshold, (int, float)) or not 0.25 <= float(threshold) <= 0.70:
        fail(f"{expected_id}: completion_coverage must be in 0.25..0.70", failures)
    reveal_at = room.get("cinematic_reveal_at")
    if not isinstance(reveal_at, (int, float)) or abs(float(reveal_at) - 0.99) > 0.0001:
        fail(f"{expected_id}: cinematic_reveal_at must equal 0.99", failures)

    sensory = manifest.get("sensory")
    if not isinstance(sensory, dict):
        fail(f"{expected_id}: sensory must be an object", failures)
        sensory = {}
    ceiling = sensory.get("safe_audio_ceiling_db")
    if not isinstance(ceiling, (int, float)) or float(ceiling) > -6.0:
        fail(f"{expected_id}: safe audio ceiling must be <= -6 dB", failures)
    for key in ("visual_snow_calm", "visual_snow_full"):
        value = sensory.get(key)
        if not isinstance(value, (int, float)) or not 0.0 <= float(value) <= 0.12:
            fail(f"{expected_id}: {key} outside 0..0.12", failures)
    for key in ("haptics_calm", "haptics_full"):
        value = sensory.get(key)
        if not isinstance(value, (int, float)) or not 0.0 <= float(value) <= 0.65:
            fail(f"{expected_id}: {key} outside 0..0.65", failures)

    collectibles = manifest.get("collectibles")
    if not isinstance(collectibles, list) or len(collectibles) != 3:
        fail(f"{expected_id}: room must have exactly three traces", failures)
    else:
        seen: set[str] = set()
        for item in collectibles:
            if not isinstance(item, dict):
                fail(f"{expected_id}: trace must be an object", failures)
                continue
            item_id = item.get("id")
            if not isinstance(item_id, str) or not item_id or item_id in seen:
                fail(f"{expected_id}: trace ids must be unique", failures)
            else:
                seen.add(item_id)
            position = item.get("position")
            if not isinstance(position, list) or len(position) != 2 or any(
                not isinstance(v, (int, float)) or not 0.0 <= float(v) <= 1.0 for v in position
            ):
                fail(f"{expected_id}: invalid trace position for {item_id!r}", failures)

    audio = manifest.get("audio")
    if not isinstance(audio, dict):
        fail(f"{expected_id}: audio must be an object", failures)
        return
    excerpt = audio.get("completion_excerpt")
    if not isinstance(excerpt, str) or not excerpt.startswith("res://assets/audio/"):
        fail(f"{expected_id}: invalid completion excerpt path", failures)
        return
    excerpt_path = ROOT / excerpt.removeprefix("res://")
    if not excerpt_path.is_file():
        fail(f"{expected_id}: completion excerpt is missing", failures)
    elif not 50_000 <= excerpt_path.stat().st_size <= 2_000_000:
        fail(f"{expected_id}: completion excerpt must stay between 50 KB and 2 MB", failures)


def validate() -> list[str]:
    failures: list[str] = []
    for relative in REQUIRED_FILES:
        if not (ROOT / relative).is_file():
            fail(f"missing file: {relative}", failures)

    version = (ROOT / "VERSION").read_text().strip() if (ROOT / "VERSION").is_file() else ""
    if version != "0.6.1":
        fail("VERSION must equal 0.6.1", failures)
    project = (ROOT / "project.godot").read_text()
    if 'config/version="0.6.1"' not in project:
        fail("project.godot version must equal 0.6.1", failures)

    index = load_json(ROOT / "data/release_index.json", failures)
    releases = index.get("releases") if index else None
    if not isinstance(releases, list):
        fail("release index must contain a releases array", failures)
        releases = []
    ids = [entry.get("id") for entry in releases if isinstance(entry, dict)]
    if ids != EXPECTED_ORDER:
        fail(f"album order mismatch: {ids}", failures)
    if index.get("active_release") != EXPECTED_ORDER[0]:
        fail("active_release must be Wave of Uncertainty", failures)
    reward = index.get("reward")
    if not isinstance(reward, dict) or not reward.get("enabled"):
        fail("reward flow must be enabled", failures)
    elif reward.get("api_url") != "https://signal-api.virya.music":
        fail("reward API must use signal-api.virya.music", failures)

    for entry in releases:
        if not isinstance(entry, dict):
            fail("release index entry must be an object", failures)
            continue
        release_id = entry.get("id")
        manifest_ref = entry.get("manifest")
        if release_id not in EXPECTED_ORDER:
            continue
        if not isinstance(manifest_ref, str) or not manifest_ref.startswith("res://"):
            fail(f"{release_id}: manifest path must use res://", failures)
            continue
        path = ROOT / manifest_ref.removeprefix("res://")
        if not path.is_file():
            fail(f"{release_id}: indexed manifest missing", failures)
            continue
        validate_manifest(path, release_id, failures)

    export_presets = (ROOT / "export_presets.cfg").read_text()
    for preset_name in ('name="Linux"', 'name="Web"', 'name="Android Debug"'):
        if preset_name not in export_presets:
            fail(f"missing export preset: {preset_name}", failures)
    for permission in ('permissions/vibrate=true', 'permissions/internet=true'):
        if permission not in export_presets:
            fail(f"Android export missing {permission}", failures)
    if 'package/unique_name="music.virya.synesthesia"' not in export_presets:
        fail("unexpected Android package identifier", failures)
    if 'variant/thread_support=false' not in export_presets:
        fail("Web preview must remain single-threaded", failures)

    bus_layout = (ROOT / "default_bus_layout.tres").read_text()
    if '[gd_resource type="AudioBusLayout" format=3]' not in bus_layout:
        fail("audio bus layout must declare AudioBusLayout", failures)
    for bus_name in ("Music", "Room", "Sensory", "UI"):
        if f'&"{bus_name}"' not in bus_layout:
            fail(f"missing audio bus: {bus_name}", failures)

    scripts = {path.name: path.read_text(errors="replace") for path in (ROOT / "scripts").glob("*.gd")}
    all_source = "\n".join(scripts.values()) + (ROOT / "shaders/visual_snow.gdshader").read_text()
    for contract in (
        "Input.vibrate_handheld",
        "FINAL_REVEAL_RATIO: float = 0.99",
        "set_cinematic_reveal(true)",
        "set_door_open(true)",
        "claim_reward",
        "HTTPRequest",
    ):
        if contract not in all_source:
            fail(f"runtime contract missing: {contract}", failures)
    main_source = scripts.get("main.gd", "")
    if "var restored: bool = false" not in main_source:
        fail("room restoration must use explicit bool typing", failures)
    if 'album_state.get("room_elapsed_ms", {})' not in main_source:
        fail("offline room completion sync must preserve elapsed time", failures)
    for forbidden in (
        "var room: SynesthesiaPaintRoom",
        "var audio_director: SynesthesiaAudioDirector",
        "var haptics: SynesthesiaHaptics",
    ):
        if forbidden in main_source:
            fail(f"main scene must not depend on editor class cache: {forbidden}", failures)

    paint_source = scripts.get("paint_room.gd", "")
    custom_draw_helpers = re.findall(r"(?m)^func (draw_[A-Za-z0-9_]+)\(", paint_source)
    if custom_draw_helpers:
        fail(
            "custom draw_* helpers collide with CanvasItem methods: "
            + ", ".join(sorted(custom_draw_helpers)),
            failures,
        )
    for visual_contract in (
        '_draw_party_scene', '_draw_unmasked_scene', '_draw_calling_scene', '_draw_seed_scene',
        '_draw_hybrid_scene', '_draw_technophobia_scene', '_draw_invaluable_scene',
        '_draw_ashes_scene', '_draw_waves_scene', '_draw_rise_scene', '_draw_unrevealed_vss',
    ):
        if visual_contract not in paint_source:
            fail(f"missing room renderer: {visual_contract}", failures)
    for text_contract in ("ZZZ", "_draw_venetian_mask", "pop_balloons", "crack_mirrors", "western_duel"):
        if text_contract not in paint_source:
            fail(f"missing interaction contract: {text_contract}", failures)

    haptics_source = scripts.get("haptics.gd", "")
    for method in ("special", "cinematic_reveal", "door_open"):
        if f"func {method}" not in haptics_source:
            fail(f"missing haptic pattern: {method}", failures)

    web_build = (ROOT / "scripts/build-web-preview.sh").read_text()
    for contract in (
        "86409db6200b6f8fd3230989c2d2002851f3dd18acf11d7bdbafddf5a0dd0f72",
        "SCRIPT ERROR:",
        "runtime-validation",
    ):
        if contract not in web_build:
            fail(f"verified web build contract missing: {contract}", failures)
    deploy_workflow = (ROOT / ".github/workflows/deploy-web.yml").read_text()
    if "netlify-cli@27.0.1" not in deploy_workflow:
        fail("Netlify CLI must remain version-pinned", failures)
    scaffold = (ROOT / "tools/new_release_pack.py").read_text()
    if '"schema_version": 3' not in scaffold or '"cinematic_reveal_at": 0.99' not in scaffold:
        fail("new room scaffold must use schema v3 and the 99% reveal", failures)

    reward_page = (ROOT / "web/reward/index.html").read_text()
    if "signal-api.virya.music/v1/public/synesthesia/reward-claims/confirm" not in reward_page:
        fail("reward page must post directly to CrowdRelay", failures)
    if "history.replaceState" not in reward_page:
        fail("reward page must remove the token from the visible URL", failures)

    if any(term in all_source.lower() for term in ("analytics", "admob", "tracking_id")):
        fail("analytics and ad dependencies remain forbidden", failures)
    audio_source = scripts.get("audio_director.gd", "")
    frequencies = [float(value) for value in re.findall(r"TAU_F \* ([0-9]+(?:\.[0-9]+)?)", audio_source)]
    if frequencies and max(frequencies) > 1000.0:
        fail("procedural soundscape contains an unnecessarily high tone", failures)

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
