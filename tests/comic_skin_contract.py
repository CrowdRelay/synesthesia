#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

assets = {
    "assets/comic/panel_comic.webp": 90_000,
    "assets/comic/panel_compact.webp": 45_000,
    "assets/comic/button_comic.webp": 25_000,
    "assets/comic/input_comic.webp": 25_000,
    "assets/comic/door_eye_comic.webp": 180_000,
    "assets/comic/paper_grain.webp": 40_000,
}
total_bytes = 0
for rel, max_bytes in assets.items():
    path = ROOT / rel
    if not path.is_file():
        failures.append(f"missing comic skin asset: {rel}")
        continue
    size = path.stat().st_size
    total_bytes += size
    if size <= 0 or size > max_bytes:
        failures.append(f"comic skin asset outside budget: {rel}={size} > {max_bytes}")

if total_bytes > 350_000:
    failures.append(f"comic skin pack too large: {total_bytes} > 350000")

for rel in assets:
    path = ROOT / rel
    for parent in path.parents:
        if parent == ROOT:
            break
        if (parent / ".gdignore").is_file():
            failures.append(f"comic skin asset is hidden from Godot importer by {parent.relative_to(ROOT)}/.gdignore: {rel}")

ui = (ROOT / "scripts/ui/ui_factory.gd").read_text(errors="replace")
for token in (
    "StyleBoxTexture.new()",
    "COMIC_PANEL_TEXTURE",
    "COMIC_BUTTON_TEXTURE",
    "COMIC_INPUT_TEXTURE",
    "texture_margin_left",
    "modulate_color",
    "control.mouse_filter = Control.MOUSE_FILTER_STOP",
):
    if token not in ui:
        failures.append(f"UIFactory comic skin token missing: {token}")
for token in (
    'COMIC_PANEL_TEXTURE_PATH',
    'res://assets/comic/',
    'ResourceLoader.exists(path)',
    'var resource: Resource = load(path)',
):
    if token not in ui:
        failures.append(f"UIFactory runtime texture loading token missing: {token}")
if 'preload("res://assets/comic/' in ui or 'res://assets/ui/comic/' in ui:
    failures.append("UIFactory must not preload raw comic images or place them below assets/ui/.gdignore")

motif = (ROOT / "scripts/ui/door_eye_motif.gd").read_text(errors="replace")
for token in (
    "DOOR_EYE_TEXTURE_PATH",
    "MENU_EYE_POSTER_PATH",
    "var base_texture: Texture2D",
    "draw_texture_rect(base_texture",
    "_draw_textured_eye_animation",
    "_draw_texture_glitch",
    "_sync_processing",
    "redraw_hz",
    "mouse_filter = Control.MOUSE_FILTER_IGNORE",
):
    if token not in motif:
        failures.append(f"door-eye material/animation token missing: {token}")
for token in (
    'DOOR_EYE_TEXTURE_PATH',
    'res://assets/comic/door_eye_comic.webp',
    'ResourceLoader.exists(DOOR_EYE_TEXTURE_PATH)',
    'load(DOOR_EYE_TEXTURE_PATH)',
):
    if token not in motif:
        failures.append(f"door-eye runtime texture loading token missing: {token}")
if 'preload("res://assets/comic/' in motif or 'res://assets/ui/comic/' in motif:
    failures.append("door-eye must not preload raw image or live below assets/ui/.gdignore")
expected_glitch_call = "draw_texture_rect_region(texture, dest, src, Color(1.0, 1.0, 1.0, 0.30 + _glitch * 0.34))"
if expected_glitch_call not in motif:
    failures.append("door-eye glitch draw_texture_rect_region signature is not Godot 4.x texture-first order")

intro = (ROOT / "scripts/ui/experience_intro_card.gd").read_text(errors="replace")
for token in (
    "mouse_filter = Control.MOUSE_FILTER_STOP",
    "mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED",
    "dim.mouse_filter = Control.MOUSE_FILTER_IGNORE",
    "_panel.mouse_filter = Control.MOUSE_FILTER_PASS",
    "_scroll.mouse_filter = Control.MOUSE_FILTER_PASS",
    "_action_column.mouse_filter = Control.MOUSE_FILTER_PASS",
):
    if token not in intro:
        failures.append(f"menu input ownership token missing: {token}")

boot = (ROOT / "scripts/ui/boot_sequence.gd").read_text(errors="replace")
for token in (
    "mouse_filter = Control.MOUSE_FILTER_IGNORE",
    "mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED",
    "focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED",
):
    if token not in boot:
        failures.append(f"boot overlay does not release input before fade: {token}")

surface = (ROOT / "scripts/app/native_experience_surface.gd").read_text(errors="replace")
if "size = viewport_size\n    position = Vector2.ZERO" in surface:
    failures.append("native surface still writes size/position against full-rect anchors")

# assets/ui is intentionally .gdignore'd, so keeping comic art there silently
# prevents Godot from importing it even though source-level tests can see it.
ignored_comic_dir = ROOT / "assets/ui/comic"
if ignored_comic_dir.exists() and any(ignored_comic_dir.iterdir()):
    failures.append("assets/ui/comic must stay empty/nonexistent because assets/ui/.gdignore hides it from Godot")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_COMIC_SKIN=FAIL count={len(failures)}")

print(
    "SYNESTHESIA_COMIC_SKIN=PASS "
    f"assets=6 bytes={total_bytes} format=webp runtime-load=import-safe nine-slice=texture menu-input=modal-chain-safe eye=bitmap+blink+glitch"
)
