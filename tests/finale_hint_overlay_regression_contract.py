#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

finale = read("scripts/ui/signal_finale_card.gd")
fallback = read("scripts/ui/signal_finale_fallback_card.gd")
reward = read("scripts/app/main_reward_flow.gd")
room_flow = read("scripts/app/main_room_flow.gd")
hud = read("scripts/ui/app_hud.gd")
toast = read("scripts/ui/hud_toast_controller.gd")
builder = read("scripts/ui/mobile_instruction_builder.gd")
layout = read("scripts/ui/hud_layout_flow.gd")
finale_layout = read("scripts/ui/signal_finale_layout.gd")

# Mobile finale must open with the actionable form in the first scroll viewport.
assert 'app._layout.move_child(app._form, 0)' in finale_layout
assert 'app._layout.move_child(app._visual, 1)' in finale_layout
assert 'call_deferred("_scroll_to_start")' in finale_layout
assert 'func is_ready_for_input() -> bool:' in finale
assert 'FINAŁ · SYGNAŁ DOTARŁ · 5 PŁYT' in finale

# A decorative/runtime failure can never leave only the finale animation.
transition_to_reward = room_flow.split("func _transition_to_reward", 1)[1]
assert transition_to_reward.index("app._show_reward_panel()") < transition_to_reward.index("await app.transition_director.travel_in()")
assert "if app.reward_panel != null and is_instance_valid(app.reward_panel):" in reward
assert 'SIGNAL_FINALE_FALLBACK_PATH' in reward
assert 'call_deferred("_verify_reward_panel_ready")' in reward
assert 'func _reward_panel_visibly_ready()' in reward
assert 'app.reward_panel.modulate.a >= 0.94' in reward
assert 'func _force_reward_panel_visible()' in reward
assert 'func _install_reward_fallback' in reward
assert 'SignalFinaleFallbackCard' in reward
assert 'func is_ready_for_input() -> bool:' in fallback
assert 'DOŁĄCZ DO LOSOWANIA 5 PŁYT' in fallback

# Hint text replacement is complete/atomic: keep all gesture segments and never
# leave a stale detail label from the previous interaction state.
assert 'var parts := normalized.split(" · ", false)' in builder
assert 'detail_parts.append' in builder
assert 'var detail := " · ".join(detail_parts)' in builder
assert 'mobile_instruction_detail_label.queue_redraw()' in builder
assert 'MobileInstructionBuilder.set_text(self, instruction_label.text)' in hud
assert '.replace(" · ", "\\n")' not in hud

# Popups are short, serialized and input-transparent. Hover dim is detected
# manually, so recursive mouse handling stays disabled and clicks reach gameplay.
assert 'const HOLD_SECONDS: float = 1.55' in toast
assert 'if _tween != null and _tween.is_valid()' in toast
assert 'if app.toast_panel.visible and normalized == _last_text' in toast
assert 'var panel: Control = app.toast_panel as Control' in toast
assert 'var mouse_position: Vector2 = app.get_viewport().get_mouse_position()' in toast
assert 'var hovered: bool = panel.get_global_rect().has_point(mouse_position)' in toast
assert 'var target: float = HOVER_ALPHA if hovered else 1.0' in toast
assert 'const HOVER_ALPHA: float = 0.18' in toast
assert 'mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED' in builder
assert 'app.toast_panel.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED' in layout

print("SYNESTHESIA_FINALE_HINT_OVERLAY=PASS finale=form-first+fallback hints=atomic+serialized popup=1.55s+hover-dim+click-through")
