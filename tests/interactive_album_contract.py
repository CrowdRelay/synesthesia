#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

def text(path: str) -> str:
    return (ROOT / path).read_text(errors="replace")

def require(path: str, *tokens: str) -> str:
    source = text(path)
    for token in tokens:
        if token not in source:
            failures.append(f"{path}: missing {token!r}")
    return source

router = require(
    "scripts/input/interaction_router.gd",
    '"tap"', '"hold"', '"drag"', '"swipe"', '"release"', '"two_finger"',
    "TAP_MAX_MS", "HOLD_MS", "SWIPE_DISTANCE", "route_input", "advance", "single_pointer",
)
runtime = require(
    "scripts/input/room_interaction_runtime.gd",
    "handle_gestures", "handle_paint", "special_interaction", "feedback", "reveal_changed",
)
stage = require("scripts/render/room_interaction_flow.gd", '_handle_gestures(routed["gestures"])')
if "func _handle_gestures(gestures: Array[Dictionary])" in stage:
    failures.append("RoomStage gesture boundary must accept untyped Array from routed Dictionary")
if "func handle_gestures(gestures: Array[Dictionary]" in runtime:
    failures.append("RoomInteractionRuntime gesture boundary must accept untyped Array from routed Dictionary")
if "gesture_value if gesture_value is Dictionary else {}" not in runtime:
    failures.append("RoomInteractionRuntime must validate gesture elements after untyped boundary")
require(
    "scripts/rooms/behavior_base.gd",
    "func on_gesture", "func interaction_hint", "_interaction_event", "_distance_to_segment",
)

room_expectations = {
    "wave-of-uncertainty": ["on_gesture", 'kind == "drag"', 'kind == "swipe"', "calmness"],
    "party-time": ["on_gesture", '"tap":', '"drag":', '"swipe":', "velocities"],
    "unmasked": ["on_gesture", 'kind == "tap"', 'kind == "drag"', 'kind == "swipe"', "removed"],
    "the-calling": ["on_gesture", 'kind == "hold"', 'kind == "drag"', 'kind == "release"', '"pour"'],
    "seed-of-doubt": ["on_gesture", 'kind == "hold"', 'kind == "drag"', '"root"', "growth"],
    "hybrid": ["on_gesture", 'kind == "hold"', 'kind in ["release", "swipe"]', '"aim"', '"duel"'],
    "technophobia": ["on_gesture", '"tap":', '"two_finger":', "signal_tune", "screens"],
    "invaluable": ["on_gesture", 'kind == "tap"', 'kind == "swipe"', "shattered"],
    "from-the-ashes": ["on_gesture", 'kind == "drag"', 'kind == "swipe"', '"ember"', '"phoenix"'],
    "waves": ["on_gesture", 'kind == "hold"', 'kind == "two_finger"', "closeness"],
    "rise": ["on_gesture", 'kind == "tap"', 'kind == "hold"', 'kind == "swipe"', "final_gesture"],
}
for room, tokens in room_expectations.items():
    require(f"scripts/rooms/behaviors/{room}.gd", "func interaction_hint", *tokens)

audio = require(
    "scripts/audio_director.gd",
    "INTERACTION_BLOOM", "_interaction_bloom_target", "_interaction_bloom_smoothed",
    '"pour"', '"root"', '"aim"', '"ember"',
)
if "_interaction_bloom_smoothed * 2.4" not in audio or "reactive_mix" not in audio:
    failures.append("reactive audio does not modulate music/filter from semantic events")

require(
    "scripts/haptics.gd",
    '"pour"', '"root"', '"aim"', '"ember"', "_pulse_after_delay",
)

hud = require(
    "scripts/ui/app_hud.gd",
    'progress_label.text = "SZUM"', 'progress_label.text = "SYGNAŁ"',
    'progress_label.text = "MUZYKA"', "_interaction_prompt", "ŚLAD DŁONI %s · GŁÓWNY RYTUAŁ ROZPRASZA SZUM",
)
if "%d%% ·" in hud:
    failures.append("production HUD still exposes numeric/debug reveal percentages")

require("scripts/progress_store.gd", '"echo_archive": {}')
require("scripts/app/echo_archive.gd", "remember", "found_at_unix")
require(
    "scripts/ui/album_archive_card.gd",
    "KORYTARZ", "Album Mode", "ECHA %d/%d", "PackedStringArray", "room_requested", "WRÓĆ DO FINAŁU",
)
album_mode = require(
    "scripts/app/album_mode_controller.gd",
    "is_listening", "show_archive", "enter_room", "AlbumModeCorridorButton", "corridor_requested",
    "AlbumModeCaptureButton", "ZAPISZ KADR", "I FOUND THE SIGNAL", "JavaScriptBridge.eval",
    "JSON.stringify(room_name)", "JSON.stringify(download_name)",
)
if "a.download = 'virya-synesthesia-%s.png';" in album_mode:
    failures.append("album-mode Web capture interpolates an unescaped release id into JavaScript")
main = "\n".join(
    text(path) for path in (
        "scripts/main.gd",
        "scripts/app/main_room_flow.gd",
        "scripts/app/main_settings_flow.gd",
        "scripts/app/main_reward_flow.gd",
        "scripts/app/main_runtime_flow.gd",
    )
)
for token in (
    "ALBUM_MODE_PATH", "EchoArchive.remember", "album_mode_controller.is_listening()",
    "album_mode_controller.show_archive", "album_mode_controller.enter_room",
    "transition_director.set_memory_count", "album_mode_controller.is_listening():\n        return",
):
    if token not in main:
        failures.append(f"main orchestration missing {token!r}")
READABILITY_SOFT_BUDGET = 420
READABILITY_HARD_BUDGET = 460
for path in ("scripts/main.gd", "scripts/app/main_room_flow.gd", "scripts/app/main_settings_flow.gd", "scripts/app/main_reward_flow.gd"):
    lines = len(text(path).splitlines())
    if lines > READABILITY_HARD_BUDGET:
        failures.append(
            f"orchestration module exceeded hard readability cap: "
            f"{path}={lines}/{READABILITY_HARD_BUDGET}"
        )
    elif lines > READABILITY_SOFT_BUDGET:
        print(
            f"WARN: orchestration module above soft readability budget: "
            f"{path}={lines} soft={READABILITY_SOFT_BUDGET} "
            f"hard={READABILITY_HARD_BUDGET}"
        )

require(
    "scripts/app/door_transition_layer.gd",
    "set_memory_count", "_draw_corridor_memory", 'Color("b91346"', 'Color("72d79a"',
    'Color("ffd56d"',
)
require(
    "scripts/ui/echoes_finale_background.gd",
    "_draw_memory_constellation", "range(11)", 'Color("71dcff"',
)
require(
    "scripts/ui/signal_finale_card.gd",
    "album_mode_requested", "ALBUM MODE · KORYTARZ",
    "FALA · KONFETTI · MASKA · WINO · KORZEŃ",
)
require(
    "scripts/ui/experience_intro_card.gd",
    "album_mode_requested", "ALBUM MODE · KORYTARZ",
    "Dotykaj znaków, prowadź światło i budź echa",
)

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_INTERACTIVE_ALBUM=FAIL count={len(failures)}")

print("SYNESTHESIA_INTERACTIVE_ALBUM=PASS gestures=6 rooms=11 reactive-audio=semantic haptics=semantic echoes=persistent album-mode=11 corridor=memory finale=constellation")
