#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
metrics = (ROOT / "scripts/ui/ui_metrics.gd").read_text(errors="replace")
factory = (ROOT / "scripts/ui/ui_factory.gd").read_text(errors="replace")
finale = (ROOT / "scripts/ui/signal_finale_card.gd").read_text(errors="replace")
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

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_MOBILE_FEEDBACK=FAIL count={len(failures)}")

print("SYNESTHESIA_MOBILE_FEEDBACK=PASS typography=ecosystem-boundary mobile=larger touch=email-focus-safe finale=readable")
