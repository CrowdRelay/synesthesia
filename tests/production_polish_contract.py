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

stage = require(
    "scripts/render/room_stage.gd",
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
    "CACHE_MODE_IGNORE",
    "load_threaded_get",
    "_prune_finished_failures",
    "func drain()",
)
adaptive = require(
    "scripts/app/adaptive_performance.gd",
    "MEMORY_SOFT_MB",
    '"frame-pressure"',
    '"sustained-pressure"',
    '"recovery"',
)
audio = require(
    "scripts/audio_director.gd",
    "_last_filter_hz",
    "_last_reverb_wet",
    "MIN_FILTER_HZ",
    "MAX_FILTER_HZ",
)
main = require(
    "scripts/main.gd",
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
hud = require(
    "scripts/ui/app_hud.gd",
    "set_painting",
    "update_discovery",
    "update_act",
    "get_display_safe_area",
    "HeaderRow",
    "size_flags_stretch_ratio = 1.18",
    "size_flags_stretch_ratio = 0.82",
    "tylko muzyka",
)
require("scripts/ui/chapter_card.gd", "MALUJ OD RAZU", "_timer.wait_time = 3.6", "MOUSE_FILTER_IGNORE")
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
require("tests/cinematic_video_contract.py", "SYNESTHESIA_CINEMATIC_VIDEO=PASS", "clips=12", "lazy=load+unload")
require("tests/presentation_contract.py", "SYNESTHESIA_PRESENTATION=PASS", "menu=door-eye+signal", "chapter=nonblocking", "hud=two-panel+content")
require("scripts/render/room_video_layer.gd", "VideoStreamPlayer.new()", "VideoStreamTheora.new()", "theora.file = _video_path", "_player.stream = null", "entry_strength")

memory = require("tools/memory_budget.py", "stdlib-webp", "MAX_CURRENT_PLUS_NEXT")
if "PIL" in memory or "pillow" in memory.lower():
    failures.append("memory budget must remain stdlib-only")
require("validate.sh", "python3 tools/memory_budget.py", "python3 tests/production_polish_contract.py", "tests/cinematic_video_contract.py", "tests/presentation_contract.py", "lifecycle_smoke.gd")
require(".github/workflows/ci.yml", "python3 tools/memory_budget.py", "python3 tests/production_polish_contract.py", "tests/cinematic_video_contract.py", "tests/presentation_contract.py")

if len(main.splitlines()) > 980:
    failures.append(f"main controller grew above 980 lines: {len(main.splitlines())}")
if len(stage.splitlines()) > 620:
    failures.append(f"room stage grew above 620 lines: {len(stage.splitlines())}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_PRODUCTION_POLISH=FAIL count={len(failures)}")

print(
    "SYNESTHESIA_PRODUCTION_POLISH=PASS "
    "persistence=png-mask-v2 adaptive=on preload=consumed "
    "ux=adaptive-menu+nonblocking-chapter+completion+door-eye+echoes-finale+mobile-back"
)
