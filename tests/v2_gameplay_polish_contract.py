#!/usr/bin/env python3
"""Regression contract for the Synesthesia V2 game-feel/replay/readability pass."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

def text(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def require(path: str, *tokens: str) -> None:
    source = text(path)
    for token in tokens:
        if token not in source:
            failures.append(f"{path}: missing {token!r}")

require(
    "scripts/app/room_timing_runtime.gd",
    "func pause()",
    "func resume()",
    "personal_best_act_splits_ms",
    "show_split_delta",
    "replay_mode",
)
require(
    "scripts/app/transition_director.gd",
    "set_replay_mode",
    "0.58 if _replay_mode else 1.0",
)
require(
    "scripts/rooms/behaviors/technophobia.gd",
    "_resisted_cable_point",
    "tension_bucket",
    "snap_time",
    "cable_snap",
    "cable_unplug",
)
require(
    "scripts/haptics.gd",
    '"cable_tension"',
    "var bucket",
    "tension",
)
require(
    "shaders/room_composite.gdshader",
    "readability_highlight_lift",
    "readable_mids",
    "readable_highlights",
)
require(
    "scripts/render/interaction_fx_layer.gd",
    "set_runtime_scale",
    "semantic_echo",
    "_draw_root_burst",
    "_draw_droplets",
)
require(
    "scripts/app/player_feedback_bridge.gd",
    "_resonance_chain",
    "felt_strength",
)
require(
    "scripts/render/room_state_flow.gd",
    "semantic_ready_collectibles",
    "legacy_semantic_save",
)

room_tokens = {
    "invaluable.gd": ("mirror_offsets", "_shift_mirror"),
    "unmasked.gd": ("delta * 0.58",),
    "party-time.gd": ("_push_neighbors_from_burst",),
    "seed-of-doubt.gd": ("growth_bias_x",),
    "from-the-ashes.gd": ("speed_gain",),
    "the-calling.gd": ("target_pull",),
    "hybrid.gd": ("aim >= 0.82", "delta * 0.48"),
}
for file_name, tokens in room_tokens.items():
    require(f"scripts/rooms/behaviors/{file_name}", *tokens)

release_root = ROOT / "data" / "releases"
manifests = sorted(release_root.glob("*/manifest.json"))
if len(manifests) != 11:
    failures.append(f"expected 11 manifests, found {len(manifests)}")
semantic_echoes = 0
for manifest_path in manifests:
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    room = data.get("room", {})
    readability = room.get("mobile_readability", {})
    living = room.get("living_state", {})
    if not 0.0 < float(readability.get("highlight_lift", 0.0)) <= 1.0:
        failures.append(f"{manifest_path.parent.name}: missing selective highlight lift")
    if living.get("layers") != ["ambient", "reactive", "semantic_burst"]:
        failures.append(f"{manifest_path.parent.name}: living layers incomplete")
    if float(living.get("anti_static_seconds", 99.0)) > 3.0:
        failures.append(f"{manifest_path.parent.name}: anti-static cadence too slow")
    collectibles = data.get("collectibles", [])
    if len(collectibles) >= 3 and collectibles[2].get("semantic_kind"):
        semantic_echoes += 1
if semantic_echoes != 11:
    failures.append(f"semantic echoes authored for {semantic_echoes}/11 rooms")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_V2_GAMEPLAY_POLISH=FAIL count={len(failures)}")

print(
    "SYNESTHESIA_V2_GAMEPLAY_POLISH=PASS "
    "timer=active-play replay=fast+splits material=resistance readability=selective "
    "living=3-layer semantic-echoes=11 adaptive-fx=true"
)
