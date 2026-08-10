#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

def source(rel: str) -> str:
    return (ROOT / rel).read_text(errors="replace")

def require(rel: str, *tokens: str) -> None:
    text = source(rel)
    for token in tokens:
        if token not in text:
            failures.append(f"{rel}: missing {token}")

require(
    "scripts/ui/ui_metrics.gd",
    "REFERENCE_VIEWPORT: Vector2 = Vector2(540.0, 960.0)",
    "MAX_SCALE: float = 2.0",
    "PORTRAIT_CONTENT_BOOST: float = 1.15",
    "PORTRAIT_ASPECT_THRESHOLD: float = 0.82",
    "LOCAL_DEBUG_MIN_SCALE: float = 1.30",
    "static func scale_for_viewport",
    "static func apply_tree",
    "min_height: float = 44.0 * content_scale",
    'OS.get_environment("SYNESTHESIA_LOCAL_DEBUG") == "1"',
)

require(
    "scripts/main.gd",
    "DebugProfile.fit_macos_window_to_screen()",
    "func _enter_main_menu_mode() -> void:",
    "SoundscapeRuntime.suspend_for_menu",
    "func _resume_room_runtime() -> void:",
    "SoundscapeRuntime.resume_room",
)

require(
    "scripts/app/main_room_flow.gd",
    'if app.experience_intro_panel == null:\n            app.call_deferred("_show_completion_panel")',
    "app.reward_panel != null or app.experience_intro_panel != null or not app.room_layer.visible",
)


require(
    "scripts/app/soundscape_runtime.gd",
    "MenuRuntimeGuard.suspend(room_layer, room, hud, audio_director, transition_director, adaptive_performance)",
    "MenuRuntimeGuard.resume(room_layer, hud, audio_director, adaptive_performance)",
    "soundscape.enter_menu()",
    "soundscape.leave_soundscape()",
)

require(
    "scripts/app/menu_runtime_guard.gd",
    "hud.suspend_for_menu()",
    "room_layer.process_mode = Node.PROCESS_MODE_DISABLED",
    "audio_director.set_suspended(true)",
    "adaptive_performance.set_suspended(true)",
    "transition_director.force_idle()",
    "room_layer.process_mode = Node.PROCESS_MODE_INHERIT",
    "hud.resume_for_room()",
    "audio_director.set_suspended(false)",
    "adaptive_performance.set_suspended(false)",
)

main = source("scripts/main.gd")
room_flow = source("scripts/app/main_room_flow.gd")
if "app.reward_panel != null or app.experience_intro_panel != null or not app.room_layer.visible" not in room_flow:
    failures.append("main_room_flow.gd: delayed completion card can resurrect above the main menu")
if "panel.hide(); panel.queue_free()" not in main:
    failures.append("main.gd: modal removal is not visually immediate before deferred queue_free")
stay_start = main.find("completion_panel.stay_requested.connect")
stay_end = main.find("func _transition_to_room", stay_start)
stay_block = main[stay_start:stay_end]
if "_remove_modal(completion_panel)" in stay_block:
    failures.append("main.gd: listen mode still removes the persistent DALEJ completion card")

require(
    "scripts/ui/app_hud.gd",
    "func suspend_for_menu() -> void:",
    "func resume_for_room() -> void:",
    "func clear_transient_overlays() -> void:",
    "if text_value.is_empty() or not visible:",
    "_layout_flow._apply_ui_scale()",
)
require(
    "scripts/ui/hud_layout_flow.gd",
    "UiMetrics.apply_tree(app, app._ui_scale)",
)

require(
    "scripts/ui/completion_card.gd",
    "func _enter_listen_mode() -> void:",
    '_heading.text = "Zostań i słuchaj — kiedy chcesz, idź dalej"',
    "_stay_button.visible = false",
    "_next_button.pressed.connect",
)

require(
    "scripts/audio_director.gd",
    "func set_suspended(value: bool) -> void:",
    "set_process(not value)",
    "player.stream_paused = value",
)

require(
    "scripts/render/room_stage.gd",
    "DebugProfile.tune_debug_brush(brush)",
)

require(
    "scripts/app/debug_profile.gd",
    'OS.get_environment("SYNESTHESIA_LOCAL_DEBUG") == "1"',
    "FHD_PORTRAIT: Vector2i = Vector2i(1080, 1920)",
    "DisplayServer.screen_get_usable_rect(screen)",
    "DisplayServer.window_set_size(target_size)",
    "DisplayServer.window_set_position(target_position)",
    "DEBUG_BRUSH_MULTIPLIER: float = 2.25",
)

require(
    "run-macos.sh",
    "SYNESTHESIA_LOCAL_DEBUG=1 exec",
)

require(
    "scripts/ui/door_eye_motif.gd",
    'MENU_EYE_VIDEO_PATH: String = "res://assets/branding/signal-glyph-loop.ogv"',
    "var theora := VideoStreamTheora.new()",
    "theora.file = MENU_EYE_VIDEO_PATH",
    "func restart_authored_animation() -> void:",
    "show_behind_parent = true",
    "if video_active:",
    "_draw_brain_pulses",
)

video = ROOT / "assets/branding/signal-glyph-loop.ogv"
if not video.is_file() or video.stat().st_size < 60_000 or video.stat().st_size > 500_000:
    failures.append("assets/branding/signal-glyph-loop.ogv: missing or outside 60..500 KB V2 menu animation budget")

for rel in (
    "scripts/ui/experience_intro_card.gd",
    "scripts/ui/app_hud.gd",
    "scripts/ui/completion_card.gd",
    "scripts/ui/chapter_card.gd",
    "scripts/ui/settings_card.gd",
    "scripts/ui/signal_finale_card.gd",
):
    if "UiMetrics" not in source(rel):
        failures.append(f"{rel}: native FHD UI density helper not applied")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_UI_SCALE_FLOW=FAIL count={len(failures)}")

print("SYNESTHESIA_UI_SCALE_FLOW=PASS native-ui=adaptive menu=isolated room=paused listen=next debug-window=max-height debug-ui>=1.30x debug-brush=2.25x portal=authored-video+procedural-fx+deferred-start")
