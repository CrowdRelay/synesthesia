#!/usr/bin/env python3
"""Static release-candidate contracts for 0.12 adaptive-native production polish."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []


def require(path: str, *tokens: str) -> str:
    target = ROOT / path
    if not target.is_file():
        failures.append(f"missing {path}")
        return ""
    text = target.read_text(errors="replace")
    for token in tokens:
        if token not in text:
            failures.append(f"{path}: missing contract token {token!r}")
    return text

def require_group(paths: tuple[str, ...], *tokens: str) -> str:
    chunks: list[str] = []
    for path in paths:
        target = ROOT / path
        if not target.is_file():
            failures.append(f"missing {path}")
            continue
        chunks.append(target.read_text(errors="replace"))
    text = "\n".join(chunks)
    for token in tokens:
        if token not in text:
            failures.append(f"{'+'.join(paths)}: missing contract token {token!r}")
    return text


mask = require(
    "scripts/render/reveal_mask.gd",
    'STATE_FORMAT: String = "png-mask-v2"',
    "PackedByteArray",
    "save_png_to_buffer",
    "raw_to_base64",
    "base64_to_raw",
    "MAX_ENCODED_STATE_CHARS",
    "MAX_PNG_STATE_BYTES",
)
for forbidden in ("_history", "_image.set_pixel"):
    if forbidden in mask:
        failures.append(f"reveal mask resurrected forbidden {forbidden}")

stage = require_group(
    ("scripts/render/room_stage.gd", "scripts/render/room_visual_setup.gd", "scripts/render/room_interaction_flow.gd", "scripts/render/room_state_flow.gd"),
    "set_runtime_budget",
    'set_shader_parameter("completion_reveal"',
    'set_shader_parameter("brush_energy"',
    "asset_source.take",
    "interaction_fx.spawn",
)
shader = require(
    "shaders/room_composite.gdshader",
    "completion_reveal",
    "film_grain_strength",
    "subject_lift",
    "runtime_scale",
)
preloader = require(
    "scripts/app/asset_preloader.gd",
    "MAX_QUEUED",
    "load_threaded_request",
    "CACHE_MODE_REUSE",
    "load_threaded_get",
    "_prune_finished_failures",
    "func drain()",
)
adaptive = require(
    "scripts/app/adaptive_performance.gd",
    "MEMORY_SOFT_MB",
    '"frame-pressure"',
    '"frame-hitches"',
    '"memory-pressure"',
    '"stable-recovery"',
    "CHANGE_COOLDOWN_SECONDS",
)
audio = require(
    "scripts/audio_director.gd",
    "_last_filter_hz",
    "_last_reverb_wet",
    "MIN_FILTER_HZ",
    "MAX_FILTER_HZ",
)
main = require_group(
    ("scripts/main.gd", "scripts/app/main_room_flow.gd", "scripts/app/main_settings_flow.gd", "scripts/app/main_reward_flow.gd"),
    "SettingsCardScript",
    "settings_dirty",
    "save_timer.stop()",
    "NOTIFICATION_WM_GO_BACK_REQUEST",
    "_handle_back_request",
    "room.free()",
    "audio_director.free()",
    "ChapterCardScript",
    "CompletionCardScript",
    "_confirm_reset_album",
    "reset_local_journey",
    "asset_preloader.drain()",
    "travel_out",
    "SignalFinaleCardScript",
)
settings = require(
    "scripts/ui/settings_card.gd",
    "OBRAZ I RUCH",
    "DŹWIĘK I DOTYK",
    "POSTĘP LOKALNY",
    "reset_album_requested",
    "brak stroboskopu",
    "quality_cycle_requested",
    "horizontal_scroll_mode = 0",
)
hud = require_group(
    ("scripts/ui/app_hud.gd", "scripts/ui/hud_layout_flow.gd", "scripts/ui/ui_metrics.gd"),
    "set_painting",
    "update_discovery",
    "update_act",
    "get_display_safe_area",
    "HeaderRow",
    "size_flags_stretch_ratio = 1.18",
    "size_flags_stretch_ratio = 0.82",
    "tylko muzyka",
)
require("scripts/ui/chapter_card.gd", "ROZEJRZYJ SIĘ", "_timer.wait_time = 4.4", "MOUSE_FILTER_IGNORE")
require("scripts/ui/confirm_card.gd", "signal confirmed", "signal cancelled", "UIFactory.modal_content")
require("scripts/ui/completion_card.gd", "DRZWI OTWARTE", "Zostań i słuchaj")
require("scripts/ui/signal_finale_card.gd", "Sygnał dotarł.", "ECHOES OF THE MODERN MIND", "DOŁĄCZ DO LOSOWANIA 5 PŁYT", "DoorEyeMotif")
require("scripts/ui/echoes_finale_background.gd", "echoes-finale.webp", "echoes_finale.gdshader")
require("scripts/app/transition_director.gd", "travel_out", "travel_in", "DoorTransitionLayerScript")
require("scripts/render/room_dressing_layer.gd", "_draw_chamber_shell", "_draw_open_doorway")
require("scripts/audio_director.gd", "BALLOON_POP_PATH", "play_interaction_sfx", "music_ratio", "noise_ratio")

require("scripts/ui/ui_factory.gd", "ScrollContainer.SCROLL_MODE_DISABLED", "content.custom_minimum_size")
require("run-macos.sh", "--headless --editor", "--reset", "required_audio")
require("scripts/progress_store.gd", "reset_local_journey", "server_recorded_room_ids", "server_album_completed")
require("scripts/audio_director.gd", "ResourceLoader.exists", "func _exit_tree()")
require("tests/lifecycle_smoke.gd", "SYNESTHESIA_LIFECYCLE_SMOKE=PASS", "preloader.drain()")
require("tests/sensory_room_contract.py", "SYNESTHESIA_SENSORY_ROOMS=PASS", "ambience=11", "doors=hinge+supersonic")
require("tests/door_transition_contract.py", "SYNESTHESIA_DOOR_TRANSITION=PASS", "door=hinged", "no-room-stretch")
require("tests/cinematic_video_contract.py", "SYNESTHESIA_CINEMATIC_VIDEO=PASS", "clips=1", "decoder=finale-lazy")
require("tests/presentation_contract.py", "SYNESTHESIA_PRESENTATION=PASS", "menu=door-eye+signal", "chapter=nonblocking", "hud=receding-signal-instrument")
require("scripts/render/room_video_layer.gd", "VideoStreamPlayer.new()", "VideoStreamTheora.new()", "theora.file = _video_path", "_player.stream = null", "entry_strength")

memory = require("tools/memory_budget.py", "stdlib-webp", "MAX_CURRENT_PLUS_NEXT")
if "PIL" in memory or "pillow" in memory.lower():
    failures.append("memory budget must remain stdlib-only")
require("scripts/validate-source.sh", "python3 tools/memory_budget.py", "python3 tests/production_polish_contract.py", "tests/cinematic_video_contract.py", "tests/presentation_contract.py")
require("validate.sh", "./scripts/validate-source.sh", "lifecycle_smoke.gd")
require(".github/workflows/ci.yml", "./scripts/validate-source.sh")

for gd_path in sorted((ROOT / "scripts").rglob("*.gd")):
    lines = len(gd_path.read_text(errors="replace").splitlines())
    if lines > 420:
        failures.append(f"production GDScript grew above 420 lines: {gd_path.relative_to(ROOT)}={lines}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_PRODUCTION_POLISH=FAIL count={len(failures)}")

print(
    "SYNESTHESIA_PRODUCTION_POLISH=PASS "
    "persistence=png-mask-v2 adaptive=on preload=consumed "
    "ux=adaptive-menu+nonblocking-chapter+completion+door-eye+echoes-finale+mobile-back"
)
