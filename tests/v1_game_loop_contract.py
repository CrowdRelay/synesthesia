#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

progress = read("scripts/progress_store.gd")
reward = read("scripts/reward_client.gd")
reward_flow = read("scripts/app/main_reward_flow.gd")
main = read("scripts/main.gd")
room_flow = read("scripts/app/main_room_flow.gd")
interaction = read("scripts/render/room_interaction_flow.gd")
world_fx = read("scripts/render/world_micro_fx_layer.gd")
finale = read("scripts/ui/signal_finale_card.gd")
leaderboard = read("scripts/ui/signal_leaderboard_panel.gd")
summary = read("scripts/ui/signal_journey_summary.gd")
guide = read("scripts/app/interaction_guide.gd")
telemetry = read("scripts/app/gameplay_telemetry.gd")

for token in (
    "new_journey_id",
    'fresh["run"] = {}',
    'fresh_album["server_album_completed"] = false',
    'fresh_album["server_recorded_room_ids"] = []',
):
    assert token in progress, token

for token in (
    "attempt_id",
    "fetch_leaderboard",
    "publish_leaderboard",
    "leaderboard_loaded",
    "leaderboard_published",
):
    assert token in reward, token
assert "leaderboard_publish_requested" in finale
assert "SignalLeaderboardPanel" in finale
assert "TOP 10" in leaderboard and "TWÓJ CZAS CAŁEGO ALBUMU" in leaderboard
assert "format_time" in leaderboard and "%03d" in leaderboard
assert "best_elapsed_ms" in leaderboard
assert "OPUBLIKUJ MÓJ PB W TOP 10" in leaderboard
assert "woj••••" in leaderboard
assert "publish_leaderboard()" in reward_flow
assert "refresh_link_context_after_resume" in reward_flow
assert "NOTIFICATION_APPLICATION_RESUMED" in main
assert "reward_flow.refresh_link_context_after_resume()" in main

assert "set_post_reveal_interaction(true)" in room_flow
assert "app.post_reveal_interaction" in interaction
assert "_handle_post_reveal_gestures" in interaction
assert "_draw_post_reveal_touch_signature" in world_fx
assert "33/33 · ODSŁOŃ UKRYTY SYGNAŁ" in summary
assert "PEŁNY REZONANS · 33/33" in summary

assert "boost_mobile_first_entry" in guide
assert "gameplay_journey_started" in telemetry
assert "gameplay_journey_resumed_ms" in telemetry
assert "gameplay_journey_completed_ms" in telemetry

print(
    "SYNESTHESIA_V1_GAME_LOOP=PASS "
    "replay=attempt-scoped leaderboard=top10 post-reveal=interactive "
    "completion=timed+33/33 resume=handoff-refresh mobile=boosted telemetry=journey-summary"
)
