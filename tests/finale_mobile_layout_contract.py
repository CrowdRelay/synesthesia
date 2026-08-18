from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
layout = (ROOT / "scripts/ui/signal_finale_layout.gd").read_text()
card = (ROOT / "scripts/ui/signal_finale_card.gd").read_text()
fallback = (ROOT / "scripts/ui/signal_finale_fallback_card.gd").read_text()

def require(text: str, needle: str) -> None:
    assert needle in text, needle

for token in (
    "static func _available_size(app: Control)",
    "var available: Vector2 = app.size",
    "static func _local_safe_insets",
    "var horizontal: float = maxf(base_margin, maxf(safe.x, safe.z))",
    "var left: float = horizontal",
    "var right: float = horizontal",
    "var usable_width: float = maxf(1.0, available.x - left - right)",
    "var usable_height: float = maxf(1.0, available.y - top - bottom)",
    "var width: float = minf(1120.0 * app._ui_scale, usable_width)",
    "var height: float = minf(820.0 * app._ui_scale, usable_height)",
):
    require(layout, token)
assert "maxf(320.0 * app._ui_scale" not in layout
assert "maxf(500.0 * app._ui_scale" not in layout

for token in (
    "static func prepare_scroll_content(root: Node)",
    "control.mouse_force_pass_scroll_events = true",
    "control.mouse_filter = Control.MOUSE_FILTER_PASS",
    "button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART",
    "button.clip_text = true",
    "control.custom_minimum_size.x = 0.0",
):
    require(layout, token)

for token in (
    "_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED",
    "_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO",
    "_scroll.scroll_deadzone = SignalFinaleLayout.MOBILE_SCROLL_DEADZONE_PX",
    "SignalFinaleLayout.prepare_scroll_content(_layout)",
    "_scroll.ensure_control_visible(_email)",
):
    require(card, token)

for token in (
    "var _scroll: ScrollContainer",
    "_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED",
    "_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO",
    "_scroll.scroll_deadzone = SignalFinaleLayout.MOBILE_SCROLL_DEADZONE_PX",
    "SignalFinaleLayout.prepare_scroll_content(_layout)",
    "func _notification(what: int)",
    "_scroll.ensure_control_visible(_email)",
):
    require(fallback, token)
assert "panel.offset_top = -260.0" not in fallback
assert "panel.offset_bottom = 260.0" not in fallback

def bounded_panel(w: float, h: float, scale: float, l: float, t: float, r: float, b: float):
    usable_w = max(1.0, w - l - r)
    usable_h = max(1.0, h - t - b)
    return min(1120.0 * scale, usable_w), min(820.0 * scale, usable_h), usable_w, usable_h

for case in (
    (360.0, 740.0, 0.95, 12.0, 24.0, 12.0, 28.0),
    (412.0, 915.0, 0.95, 12.0, 28.0, 12.0, 34.0),
    (1080.0, 2400.0, 2.0, 24.0, 72.0, 24.0, 84.0),
):
    pw, ph, uw, uh = bounded_panel(*case)
    assert 0.0 < pw <= uw
    assert 0.0 < ph <= uh

def panel_gaps(w: float, h: float, scale: float, safe_x: float, safe_z: float):
    """Mirror _panel_rect's horizontal maths and return the two visible gaps."""
    base = min(max(min(w, h) * 0.025, 12.0), 28.0 * scale)
    horizontal = max(base, safe_x, safe_z)
    usable_w = max(1.0, w - horizontal * 2.0)
    width = min(1120.0 * scale, usable_w)
    x = horizontal + max(0.0, (usable_w - width) * 0.5)
    return x, w - (x + width)

# A centred card must read as centred. Taking left and right independently made
# left_gap - right_gap equal safe.x - safe.z exactly, so a one-sided cutout or
# gesture inset shoved the whole finale sideways on device.
for w, h, scale, safe_x, safe_z in (
    (360.0, 740.0, 0.95, 0.0, 0.0),
    (412.0, 915.0, 0.95, 48.0, 0.0),    # cutout on the left only
    (915.0, 412.0, 0.95, 0.0, 44.0),    # landscape, gesture inset on the right
    (1080.0, 2400.0, 2.0, 33.0, 11.0),  # both present, different sizes
):
    left_gap, right_gap = panel_gaps(w, h, scale, safe_x, safe_z)
    assert abs(left_gap - right_gap) < 0.01, (w, h, safe_x, safe_z, left_gap, right_gap)
    assert left_gap >= max(safe_x, safe_z) - 0.01, (w, h, safe_x, safe_z, left_gap)

print("SYNESTHESIA_FINALE_MOBILE_LAYOUT=PASS width=bounded touch=scrollable fallback=responsive")
