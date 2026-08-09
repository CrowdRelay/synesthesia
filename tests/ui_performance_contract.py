#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

def text(rel: str) -> str:
    return (ROOT / rel).read_text(errors="replace")

video = text("scripts/render/room_video_layer.gd")
for token in (
    "set_process(false)",
    "visible = true\n    set_process(true)",
    "visible = false\n    set_process(false)",
):
    if token not in video:
        failures.append(f"video idle-processing contract missing: {token!r}")

door = text("scripts/app/door_transition_layer.gd")
for token in ("visibility_changed.connect(_sync_processing)", "var active: bool = is_visible_in_tree()", "set_process(active)"):
    if token not in door:
        failures.append(f"door transition idle-processing contract missing: {token}")

fx = text("scripts/render/interaction_fx_layer.gd")
for token in ("set_process(false)", "set_process(true)\n    queue_redraw()"):
    if token not in fx:
        failures.append(f"interaction FX wake/sleep contract missing: {token!r}")

motif = text("scripts/ui/door_eye_motif.gd")
for token in ('redraw_hz: float = 60.0 if _profile == "splash" else (24.0 if _video_is_active() else 36.0)', 'set_process(is_visible_in_tree() and not _reduced_motion)'):
    if token not in motif:
        failures.append(f"eye redraw/process budget missing: {token}")


finale = text("scripts/ui/echoes_finale_background.gd")
for token in ("visibility_changed.connect(_sync_processing)", "set_process(active)", "_video_layer.set_cinematic(active, false)", "_video_layer.set_cinematic(is_visible_in_tree(), false)"):
    if token not in finale:
        failures.append(f"finale hidden-processing contract missing: {token}")

main = text("scripts/main.gd")
boot = text("scripts/ui/boot_sequence.gd")
if "boot.released.connect(_show_experience_intro)" not in main or "released.emit()" not in boot:
    failures.append("startup still overlaps boot/menu animated eye layers")
if 'return _profile == "menu" and not _reduced_motion' not in motif:
    failures.append("splash still opens the authored Theora decoder before the first menu frame")

stage = text("scripts/render/room_stage.gd")
for token in (
    "next_cinematic_mix",
    "next_brush_energy",
    "is_equal_approx(next_cinematic_mix, _cinematic_mix)",
    "is_equal_approx(next_brush_energy, _brush_energy)",
):
    if token not in stage:
        failures.append(f"room stage idle shader-write gate missing: {token}")

surface = text("scripts/app/native_experience_surface.gd")
if "    size = viewport_size\n    position = Vector2.ZERO" in surface:
    failures.append("native full-rect root is still manually resized; GUI hit testing can desync")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_UI_PERFORMANCE=FAIL count={len(failures)}")

print("SYNESTHESIA_UI_PERFORMANCE=PASS idle-video=sleep idle-transition=sleep idle-fx=sleep finale=visibility-gated eye=24fps-video/36fps-static startup=zero-video-decoders native-hit-test=anchor-owned")
