#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

metrics = read("scripts/app/progress_metrics.gd")
room_flow = read("scripts/app/main_room_flow.gd")
reward = read("scripts/reward_client.gd")
reward_flow = read("scripts/app/main_reward_flow.gd")
finale = read("scripts/ui/signal_finale_card.gd")
leaderboard = read("scripts/ui/signal_leaderboard_panel.gd")
summary = read("scripts/ui/signal_journey_summary.gd")
store = read("scripts/progress_store.gd")
main = read("scripts/main.gd")
signup = read("scripts/app/signal_signup_client.gd")
menu = read("scripts/ui/experience_intro_card.gd")
finale_bg = read("scripts/ui/echoes_finale_background.gd")
video_shader = read("shaders/room_video_postprocess.gdshader")
readme = read("README.md")

# Competitive time is only valid when every release has a positive active-play
# measurement; migrated/partial saves must never masquerade as a whole-album PB.
for token in (
    "timed_room_count",
    "has_complete_journey_timing",
    '"elapsed_ms": raw_elapsed_ms if timed_run_complete else 0',
    '"timed_run_complete": timed_run_complete',
    "validated_personal_best_total_ms",
    "stored < theoretical_floor",
):
    assert token in metrics, token
assert "journey_timed_complete" in room_flow
assert "app.room_elapsed_before_start_ms = elapsed_at_completion" in room_flow
assert room_flow.index("app.room_elapsed_before_start_ms = elapsed_at_completion") < room_flow.index("app._save_progress()")
assert "resume_room_timer(); app.hud.set_painting(true)" in room_flow
assert "if not app.restoring_progress and not app.completion_announced: resume_room_timer()" in room_flow
assert "func reconcile_album_timings" in store
assert "ProgressStoreScript.reconcile_album_timings(release_entries, album_state)" in main

# Context refresh is a read-only GET and carries no idempotency identity; it must
# never replay the original completion response or rotate the live handoff token.
assert "func refresh_completion_context" in reward
refresh = reward.split("func refresh_completion_context", 1)[1].split("func request_handoff", 1)[0]
assert '"method": "GET"' in refresh
assert '/context' in refresh
assert '"idempotency_key": ""' in refresh
assert '"complete_album", "recover_album", "completion_context_refresh", "handoff_issue"' in reward
assert "refresh_completion_context" in reward_flow
assert "signal_context_refresh_requested" in finale
assert "PO POWROCIE: SPRAWDŹ POŁĄCZENIE" in finale
assert "if app.reward_client == null:" in reward_flow and "app.reward_client.start_run()" in reward_flow
show_reward = reward_flow.split("func _show_reward_panel", 1)[1].split("func _refresh_leaderboard", 1)[0]
assert "if app.hud != null and is_instance_valid(app.hud):" in show_reward
assert show_reward.index("app.reward_panel.configure(") < show_reward.index("app.reward_client.start_run()")
assert "_sync_completed_rooms_to_server(next_room_index)" in reward_flow
assert "func _ensure_http" in signup and "not _ensure_http()" in signup
assert "OTWÓRZ MÓJ SYGNAŁ" in menu


# arm_finale_guard itself must construct the actionable UI before the
# watchdog timer; a stalled door/video transition may never be the first chance
# the player gets to see the form.
guard = reward_flow.split("func arm_finale_guard()", 1)[1].split("func _reward_panel_ready()", 1)[0]
assert "app.hud.visible = false" in guard
assert "app.room_layer.visible = false" in guard
assert "_show_reward_panel()" in guard
assert "_force_reward_panel_visible()" in guard
assert guard.index("app.room_layer.visible = false") < guard.index("_show_reward_panel()")
assert guard.index("_show_reward_panel()") < guard.index("get_tree().create_timer(0.80)")
assert guard.index("_force_reward_panel_visible()") < guard.index("get_tree().create_timer(0.80)")

# The final room has a terminal path before the ordinary CompletionCard guard.
# This prevents 11/11 from remaining in a live HUD/post-reveal room.
completion_gate = room_flow.split("func _show_completion_panel()", 1)[1].split("func _transition_to_room", 1)[0]
for token in (
    "if app.current_room_index + 1 >= app.release_entries.size():",
    "if app.transition_running: await get_tree().create_timer(1.20).timeout",
    "if app.transition_running: app.reward_flow.arm_finale_guard(); return",
    "_transition_to_reward(); return",
):
    assert token in completion_gate, token
assert completion_gate.index("if app.current_room_index + 1 >= app.release_entries.size():") < completion_gate.index("if app.completion_panel != null")
assert completion_gate.index("_transition_to_reward()") < completion_gate.index("if app.completion_panel != null")

# Final reward surface owns the screen: gameplay/HUD are retired first, then
# the persistent skull background and actionable Signal card are mounted.
# The room transition director must never animate over or hide the final form.
transition = room_flow.split("func _transition_to_reward", 1)[1]
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
assert "if _reward_panel_ready():" in show_reward
assert "app._remove_modal(app.reward_panel)" in show_reward
assert "func _reward_panel_visibly_ready()" in reward_flow
assert "app.reward_panel.modulate.a >= 0.94" in reward_flow
assert "func _force_reward_panel_visible()" in reward_flow
assert "Time.get_ticks_msec() + 650" in reward_flow
assert "await get_tree().process_frame" in reward_flow
layout = read("scripts/ui/signal_finale_layout.gd")
assert 'app._layout.move_child(app._form, 0)' in layout
assert 'app.call_deferred("_scroll_to_start")' in layout
fallback = read("scripts/ui/signal_finale_fallback_card.gd")
assert 'UIFactory.line_edit("E-mail do losowania"' in fallback

# Finale explains the exact opt-in path and blocks publication for incomplete timing.
assert "RANKING · 1) połącz ten przebieg" in finale
assert "OPUBLIKUJ MÓJ PB W TOP 10" in leaderboard
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

print("SYNESTHESIA_FINALE_TIMING_SIGNAL_FLOW=PASS timing=11of11+checkpoint-recovery signal=finale-bootstrap+menu fallback leaderboard=explicit-opt-in finale=skull-cover-loop+form-overlay readme=clean-title")
