#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

def read(rel: str) -> str:
    return (ROOT / rel).read_text(errors="replace")

def require(rel: str, *tokens: str) -> None:
    text = read(rel)
    for token in tokens:
        if token not in text:
            failures.append(f"{rel}: missing {token}")

require(
    "scripts/ui/ui_factory.gd",
    "SystemFont.new()",
    "BUNDLED_TITLE_FONT_PATH",
    "BUNDLED_DISPLAY_FONT_PATH",
    "_load_bundled_font",
    '"Impact"',
    "static func apply_title_font(control: Control)",
    '"DIN Condensed"',
    "font.font_weight = 900",
    "font.font_stretch = 76",
    "font.font_stretch = 74",
    "control.alignment = HORIZONTAL_ALIGNMENT_LEFT",
    "Generic actions follow the same clean sans-serif vocabulary as Virya/Signal",
    "Content headings stay neutral for ecosystem consistency",
)

factory = read("scripts/ui/ui_factory.gd")
menu_button = factory[factory.find("static func menu_button"):factory.find("static func _button_style")]
generic_button = factory[factory.find("static func button("):factory.find("static func heading(")]
content_heading = factory[factory.find("static func heading("):factory.find("static func body(")]
if "apply_display_font(control)" in menu_button or "apply_display_font(control)" in generic_button:
    failures.append("ui_factory.gd: generic actions must keep the neutral ecosystem font")
if "apply_title_font(label)" in content_heading:
    failures.append("ui_factory.gd: content headings must not reuse the identity title font")
button_style = factory[factory.find("static func _button_style"):factory.find("static func panel_style")]
if "20.0,\n        9.0,\n        16.0" in button_style:
    failures.append("ui_factory.gd: asymmetric legacy button content margins returned")

completion = read("scripts/ui/completion_card.gd")
for token in (
    "mouse_filter = Control.MOUSE_FILTER_IGNORE",
    "_next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER",
    "_stay_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER",
    '_heading.text = "Zostań w echu — gdy poczujesz przejście, rusz dalej"',
):
    if token not in completion:
        failures.append(f"completion_card.gd: missing polish {token}")
if "DoorEyeMotif" in completion:
    failures.append("completion_card.gd: decorative blinking eye returned to bottom CTA sheet")

require(
    "scripts/ui/app_hud.gd",
    "_apply_mobile_safe_area()",
)
require(
    "scripts/ui/hud_layout_flow.gd",
    "app.settings_button.custom_minimum_size = Vector2(48.0, 48.0)",
    "UiMetrics.safe_insets(viewport_size)",
)

require(
    "scripts/ui/settings_card.gd",
    '_close_x.name = "CloseSettingsX"',
    '_close_x.tooltip_text = "Wróć do malowania"',
    "_close_x.custom_minimum_size = Vector2(56.0, 56.0) * _ui_scale",
    "_close_x.mouse_filter = Control.MOUSE_FILTER_STOP",
    "_close_x.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED",
    "_close_x.focus_mode = Control.FOCUS_ALL",
    "_close_x.z_index = 100",
    "add_child(_close_x)",
    "UiMetrics.safe_insets(viewport)",
    "_close_x.pressed.connect",
)
settings = read("scripts/ui/settings_card.gd")
if "panel.add_child(_close_x)" in settings or "scroll.add_child(_close_x)" in settings:
    failures.append("settings_card.gd: close X must remain a root-level sibling outside scroll/panel input")

require(
    "scripts/ui/door_eye_motif.gd",
    "show_behind_parent = true",
    'MENU_EYE_POSTER_PATH',
    'func arm_authored_animation(restart: bool = true) -> void:',
    "func restart_authored_animation() -> void:",
    '_video_player.stop()',
    '_video_player.play()',
)
require(
    "scripts/ui/boot_sequence.gd",
    'BootAuthoredEye',
    '_motif.arm_authored_animation(true)',
    'UIFactory.apply_display_font(_title)',
    'NASŁUCHUJ  ·  DOTKNIJ  ·  ODSŁOŃ',
)
intro = read("scripts/ui/experience_intro_card.gd")
for token in ('_motif.configure(_accent, "menu", Color("ef6fbd"))',):
    if token not in intro:
        failures.append(f"experience_intro_card.gd: missing lazy eye setup {token}")
if '_motif.call_deferred("restart_authored_animation")' in intro:
    failures.append("experience_intro_card.gd: menu must not force authored decoder restart on first presentation")


require(
    "scripts/ui/hud_layout_flow.gd",
    "UIFactory.apply_title_font(app.title_label)",
    "UIFactory.apply_display_font(app.counter_label)",
    "UIFactory.apply_display_font(app.progress_label)",
    "UIFactory.apply_display_font(app.instruction_label)",
    "UIFactory.apply_display_font(app.act_banner_label)",
)

require(
    "scripts/app/door_transition_layer.gd",
    "First-person framing",
    "var base_height: float = h * (0.90 if h >= w else 0.86)",
    "pow(approach, 1.55)",
)


require(
    "scripts/ui/experience_intro_card.gd",
    'eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT',
    'title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT',
    '_content_root.add_child(eyebrow)',
    '_content_root.add_child(title)',
)

require(
    "scripts/ui/completion_card.gd",
    '_ui_scale = minf(UiMetrics.scale_for_viewport(viewport), 1.45)',
    'var width: float = clampf(viewport.x * 0.88, 320.0, 760.0)',
    '_next_button.custom_minimum_size = Vector2(280.0, 54.0)',
    '_stay_button.custom_minimum_size = Vector2(220.0, 40.0)',
    'custom minimum sizes\n    # are never multiplied twice',
)

if (ROOT / "assets/comic").exists() and any(p.is_file() for p in (ROOT / "assets/comic").rglob("*")):
    failures.append("legacy comic assets must not return; Signal V2 uses flat product surfaces")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_UI_QUALITY_POLISH=FAIL count={len(failures)}")

print("SYNESTHESIA_UI_QUALITY_POLISH=PASS buttons=left-rail+no-black-rails type=condensed-signal+clean-title completion=clean-cta settings=x eye=pingpong-authored-loop doors=first-person menu-header=left-rail completion=balanced")
