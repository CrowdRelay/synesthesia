#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
metrics = (ROOT / "scripts/ui/ui_metrics.gd").read_text(errors="replace")
factory = (ROOT / "scripts/ui/ui_factory.gd").read_text(errors="replace")
finale = (ROOT / "scripts/ui/signal_finale_card.gd").read_text(errors="replace")
router = (ROOT / "scripts/input/interaction_router.gd").read_text(errors="replace")
interaction = (ROOT / "scripts/render/room_interaction_flow.gd").read_text(errors="replace")
hud = (ROOT / "scripts/ui/hud_layout_flow.gd").read_text(errors="replace")
app_hud = (ROOT / "scripts/ui/app_hud.gd").read_text(errors="replace")
composite = (ROOT / "shaders/room_composite.gdshader").read_text(errors="replace")
failures: list[str] = []

for token in (
    "MIN_SCALE: float = 0.95",
    "MAX_SCALE: float = 2.0",
    "PORTRAIT_CONTENT_BOOST: float = 1.30",
    "MIN_LABEL_FONT_SIZE: int = 10",
    "MIN_INTERACTIVE_FONT_SIZE: int = 12",
):
    if token not in metrics:
        failures.append(f"ui_metrics.gd: missing mobile density guard {token}")

for token in (
    "field.focus_mode = Control.FOCUS_ALL",
    "field.mouse_default_cursor_shape = Control.CURSOR_IBEAM",
    "field.virtual_keyboard_show_on_focus = true",
    "field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS",
    "Generic actions follow the same clean sans-serif vocabulary as Virya/Signal",
    "Content headings stay neutral for ecosystem consistency",
):
    if token not in factory:
        failures.append(f"ui_factory.gd: missing ecosystem/input guard {token}")

for token in (
    "_scroll.follow_focus = true",
    "_scroll.scroll_deadzone = 18",
    '_email.name = "RewardEmail"',
    "_email.gui_input.connect(_on_email_gui_input)",
    "_email.focus_entered.connect(_on_email_focus_entered)",
    "_email.grab_focus()",
    "_scroll.ensure_control_visible(_email)",
    'eyebrow.add_theme_font_size_override("font_size", 11)',
    '_body.add_theme_font_size_override("font_size", 13)',
    'form_title.add_theme_font_size_override("font_size", 12)',
    'note.add_theme_font_size_override("font_size", 12)',
):
    if token not in finale:
        failures.append(f"signal_finale_card.gd: missing mobile/finale fix {token}")

for token in ("touch_origin: Vector2", "touch.position - touch_origin", "drag.position - touch_origin"):
    if token not in router:
        failures.append(f"interaction_router.gd: missing cover-fit touch mapping {token}")

for token in ("app.get_global_rect().position", "* (1.0 - app.current_progress) * 1.8"):
    if token not in interaction:
        failures.append(f"room_interaction_flow.gd: missing mobile interaction/readability guard {token}")

for token in ("PORTRAIT_HEADER_HEIGHT: float = 172.0", "PORTRAIT_PANEL_HEIGHT: float = 152.0", "34.0 if portrait else 22.0", "MobileInstructionPanel", "app.bottom_margin.visible = not portrait", "UiMetrics.safe_insets(viewport_size)", "app.toast_panel.offset_bottom = app.mobile_instruction_panel.offset_top"):
    if token not in hud:
        failures.append(f"hud_layout_flow.gd: missing portrait hint sizing {token}")
scale_flow = hud[hud.index("func _apply_ui_scale"):hud.index("func _build_header_row")]
if scale_flow.index("_layout_story_overlays()") > scale_flow.index("_apply_mobile_safe_area()"):
    failures.append("hud_layout_flow.gd: safe area must be applied after overlay layout")

for token in ("mobile_instruction_panel.modulate.a = 1.0", "mobile_alpha: float = 0.38 if value", "UIFactory.product_surface_style(_accent, true)", "update_resonance_chain", "update_echo_count"):
    if token not in app_hud:
        failures.append(f"app_hud.gd: missing mobile instruction lifecycle {token}")

for token in ("clamp(static_alpha, 0.0, 0.28)", "float reveal_lift", "0.026 * grain_strength", "uniform float display_clarity", "mix(1.0, 0.72, display_clarity)"):
    if token not in composite:
        failures.append(f"room_composite.gdshader: missing mobile reveal readability {token}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_MOBILE_FEEDBACK=FAIL count={len(failures)}")

print("SYNESTHESIA_MOBILE_FEEDBACK=PASS typography=ecosystem-boundary mobile=larger touch=email-focus-safe finale=readable")
