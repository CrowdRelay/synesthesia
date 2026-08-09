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
    '"Chalkduster"',
    "static func apply_title_font(control: Control)",
    '"DIN Condensed"',
    "font.font_weight = 900",
    "font.font_stretch = 76",
    "font.font_stretch = 82",
    "control.alignment = HORIZONTAL_ALIGNMENT_CENTER",
    "apply_display_font(control)",
    "apply_title_font(label)",
)

factory = read("scripts/ui/ui_factory.gd")
button_style = factory[factory.find("static func _button_style"):factory.find("static func panel_style")]
if "20.0,\n        9.0,\n        16.0" in button_style:
    failures.append("ui_factory.gd: asymmetric legacy button content margins returned")

completion = read("scripts/ui/completion_card.gd")
for token in (
    "mouse_filter = Control.MOUSE_FILTER_IGNORE",
    "_next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER",
    "_stay_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER",
    '_heading.text = "Zostań i słuchaj — kiedy chcesz, idź dalej"',
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
    "var max_safe_inset: int = maxi(48, roundi(64.0 * app._ui_scale))",
)

require(
    "scripts/ui/settings_card.gd",
    'close_x.name = "CloseSettingsX"',
    'close_x.tooltip_text = "Wróć do malowania"',
    "close_x.pressed.connect",
)

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
    'UIFactory.apply_title_font(_title)',
    'OTWÓRZ  ·  ODKRYJ  ·  POCZUJ',
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
    'eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER',
    'title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER',
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

button_asset = ROOT / "assets/comic/button_comic.webp"
if not button_asset.is_file() or button_asset.stat().st_size < 4_000 or button_asset.stat().st_size > 30_000:
    failures.append("assets/comic/button_comic.webp: missing or outside lightweight comic-button budget")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_UI_QUALITY_POLISH=FAIL count={len(failures)}")

print("SYNESTHESIA_UI_QUALITY_POLISH=PASS buttons=centered+no-black-rails type=poster-display+punk-title completion=clean-cta settings=x eye=pingpong-authored-loop doors=first-person menu-header=centered completion=balanced")
