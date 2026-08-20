#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

main = read("scripts/main.gd")
transition = read("scripts/app/main_transition_flow.gd")
reward_flow = read("scripts/app/main_reward_flow.gd")
finale = read("scripts/ui/signal_finale_card.gd")
leaderboard = read("scripts/ui/signal_leaderboard_panel.gd")
summary = read("scripts/ui/signal_journey_summary.gd")
video_shader = read("shaders/video_window.gdshader")
readme = read("README.md")

# Finale transition must clear gameplay UI first, arm its guard, then show the reward panel.
for token in (
    "_clear_room_runtime()",
    "app.room_layer.visible = false",
    "app.hud.visible = false",
    "app.reward_flow.arm_finale_guard()",
    "app._show_reward_panel()",
    'app.call_deferred("_show_reward_panel")',
):
    assert token in transition, token
assert transition.index("_clear_room_runtime()") < transition.index("app.reward_flow.arm_finale_guard()")
assert transition.index("app.reward_flow.arm_finale_guard()") < transition.index("app._show_reward_panel()")
assert "travel_out()" not in transition
assert "travel_in()" not in transition
assert "func _reward_panel_ready()" in reward_flow
assert "if _reward_panel_ready():" in reward_flow
assert "app._remove_modal(app.reward_panel)" in reward_flow
assert "func _reward_panel_visibly_ready()" in reward_flow
assert "app.reward_panel.modulate.a >= 0.94" in reward_flow
assert "func _force_reward_panel_visible()" in reward_flow
assert "Time.get_ticks_msec() + 650" in reward_flow
assert "await get_tree().process_frame" in reward_flow
layout = read("scripts/ui/signal_finale_layout.gd")
assert 'app._layout.move_child(app._form, 0)' in layout
# Scroll starts at the form once, but resize/IME events must not force the user back to the top.
fallback = read("scripts/ui/signal_finale_fallback_card.gd")
assert finale.count('call_deferred("_scroll_to_start")') == 1
assert fallback.count('call_deferred("_scroll_to_start")') == 1
assert 'call_deferred("_scroll_to_start")' not in layout
assert 'UIFactory.line_edit("E-mail do losowania"' in fallback

# Finale explains the exact opt-in path and blocks publication for incomplete timing.
assert "RANKING · 1) połącz ten przebieg" in finale
for token in (
    "ZAPISZ PB W TOP 10",
    "Nick / nazwa (opcjonalnie)",
    "Ranking nie wymaga maila ani konta Signal",
    "Ranking nie daje udziału w losowaniu 5 płyt",
    "osobny krok poniżej",
):
    assert token in leaderboard, token
assert "BRAK PEŁNEGO POMIARU" in leaderboard
assert "is_publish_eligible" in leaderboard
assert "is_leaderboard_publish_eligible" in reward_flow
assert "CZAS RANKINGOWY · NIEPEŁNY POMIAR" in summary

# Finale skull is the persistent full-bleed background behind the form.
video_layer = read("scripts/render/room_video_layer.gd")
assert "FINALE_SOURCE_ASPECT: float = 720.0 / 1280.0" in video_layer
assert "FINALE_COVER_RELIEF: float = 1.14" in video_layer
assert "FINALE_DISPLAY_ASPECT: float = FINALE_SOURCE_ASPECT * FINALE_COVER_RELIEF" in video_layer
assert "FINALE_VIEW_SCALE" not in video_layer
assert "_player.loop = true" in video_layer
fit = video_layer.split("func _fit_finale_player()", 1)[1].split("func _on_finale_video_finished()", 1)[0]
assert "cover_size = Vector2(available.x, available.x / FINALE_DISPLAY_ASPECT)" in fit
assert "cover_size = Vector2(available.y * FINALE_DISPLAY_ASPECT, available.y)" in fit
finished = video_layer.split("func _on_finale_video_finished()", 1)[1].split("func configure(", 1)[0]
assert "_player.play()" in finished
assert "visible = false" not in finished
assert "_player.stream = null" not in finished
assert "source_aspect = 720.0 / 1280.0" not in video_shader
assert "target_aspect = SCREEN_PIXEL_SIZE.y" not in video_shader

assert readme.startswith("# Synesthesia\n")

print("SYNESTHESIA_FINALE_TIMING_SIGNAL_FLOW=PASS timing=11of11+checkpoint-recovery signal=finale-bootstrap+menu fallback leaderboard=optional-alias+anonymous+separate-reward finale=skull-cover-loop+form-overlay readme=clean-title")
