#!/usr/bin/env python3
"""Every scrollable menu must scroll under a finger, on Web and on Android.

Godot's ScrollContainer only handles InputEventMouseButton and
InputEventMouseMotion — it does NOT handle InputEventScreenTouch or
InputEventScreenDrag directly. Touch scrolling works exclusively through
emulated mouse events (Input.set_emulate_mouse_from_touch). The project
keeps emulate_mouse_from_touch=false in project.godot (to avoid double
events in the room interaction router) and toggles it at runtime: ON when
menus are open, OFF during gameplay.

Each menu ScrollContainer must:
  - set scroll_deadzone (so taps click buttons but drags scroll)
  - have its content buttons set to MOUSE_FILTER_PASS (via enable_touch_scroll
    or prepare_scroll_content) so emulated mouse events propagate to the
    ScrollContainer instead of being consumed by the buttons.

The runtime toggle lives in room_stage.gd:set_interaction_enabled() and
main.gd:_ready().
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

failures: list[str] = []

# Runtime emulation toggle: ON in menu mode, OFF during gameplay.
main_gd = (ROOT / "scripts/main.gd").read_text()
if "Input.set_emulate_mouse_from_touch(true)" not in main_gd:
    failures.append("main.gd: must enable emulate_mouse_from_touch in _ready (menu mode at boot)")

room_stage = (ROOT / "scripts/render/room_stage.gd").read_text()
if "set_emulate_mouse_from_touch" not in room_stage:
    failures.append("room_stage.gd: must toggle emulate_mouse_from_touch in set_interaction_enabled")
if "not value" not in room_stage.split("set_emulate_mouse_from_touch")[1].split("\n")[0]:
    failures.append("room_stage.gd: emulate_mouse_from_touch must be 'not value' (on when interaction off)")

# The old custom helper must be gone — it bypassed Godot's built-in scrolling
# and never worked on real touch devices.
if (ROOT / "scripts/ui/touch_scroll.gd").exists():
    failures.append("scripts/ui/touch_scroll.gd: should be deleted (replaced by built-in scrolling)")

# enable_touch_scroll must exist in ui_factory.gd.
ui_factory = (ROOT / "scripts/ui/ui_factory.gd").read_text()
if "static func enable_touch_scroll(root: Node) -> void:" not in ui_factory:
    failures.append("ui_factory.gd: missing enable_touch_scroll static function")
if "MOUSE_FILTER_PASS" not in ui_factory.split("enable_touch_scroll")[1].split("\n\n")[0]:
    failures.append("ui_factory.gd: enable_touch_scroll must set MOUSE_FILTER_PASS on buttons/LineEdit")
if "scroll.scroll_deadzone = 12" not in ui_factory:
    failures.append("ui_factory.gd: modal_content must set scroll_deadzone = 12")

# Each menu must set scroll_deadzone and call enable_touch_scroll (or
# prepare_scroll_content for finale cards that already use it).
# Menus that use UIFactory.modal_content() get scroll_deadzone from that
# function, so they only need enable_touch_scroll on their content.
direct_scroll_menus = {
    "scripts/ui/experience_intro_card.gd": "enable_touch_scroll",
    "scripts/ui/settings_card.gd": "enable_touch_scroll",
    "scripts/ui/album_archive_card.gd": "enable_touch_scroll",
    "scripts/ui/signal_finale_card.gd": "prepare_scroll_content",
    "scripts/ui/signal_finale_fallback_card.gd": "prepare_scroll_content",
}
modal_menus = {
    "scripts/ui/confirm_card.gd": "enable_touch_scroll",
}

for rel, touch_token in direct_scroll_menus.items():
    path = ROOT / rel
    if not path.exists():
        failures.append(f"{rel}: file not found")
        continue
    text = path.read_text()
    if "ScrollContainer.new()" not in text:
        failures.append(f"{rel}: expected a menu ScrollContainer")
    if "touch_scroll.gd" in text:
        failures.append(f"{rel}: still references the deleted touch_scroll.gd helper")
    if "scroll_deadzone" not in text and "MOBILE_SCROLL_DEADZONE_PX" not in text:
        failures.append(f"{rel}: ScrollContainer has no scroll_deadzone set")
    if touch_token not in text:
        failures.append(f"{rel}: missing {touch_token} call for touch scroll")

for rel, touch_token in modal_menus.items():
    path = ROOT / rel
    if not path.exists():
        failures.append(f"{rel}: file not found")
        continue
    text = path.read_text()
    if "modal_content" not in text:
        failures.append(f"{rel}: expected to use UIFactory.modal_content for scrolling")
    if "touch_scroll.gd" in text:
        failures.append(f"{rel}: still references the deleted touch_scroll.gd helper")
    if touch_token not in text:
        failures.append(f"{rel}: missing {touch_token} call for touch scroll")

# Finale layout deadzone must be 12 (matching other menus).
finale_layout = (ROOT / "scripts/ui/signal_finale_layout.gd").read_text()
if "MOBILE_SCROLL_DEADZONE_PX: int = 12" not in finale_layout:
    failures.append("signal_finale_layout.gd: MOBILE_SCROLL_DEADZONE_PX must be 12")

if failures:
    for failure in failures:
        print(f"ERROR: {failure}")
    raise SystemExit(1)

print("SYNESTHESIA_MENU_TOUCH_SCROLL=PASS menus=%d emulation=runtime_toggle deadzone=12" % (len(direct_scroll_menus) + len(modal_menus)))
