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

# Context refresh must not reuse the original completion idempotency response;
# otherwise returning from My Signal can keep replaying linked_to_fan=false.
assert "func refresh_completion_context" in reward
assert "synesthesia-completion-context-%s-%s" in reward
assert '"complete_album", "completion_context_refresh"' in reward
assert "refresh_completion_context" in reward_flow
assert "signal_context_refresh_requested" in finale
assert "PO POWROCIE: SPRAWDŹ POŁĄCZENIE" in finale

# Finale explains the exact opt-in path and blocks publication for incomplete timing.
assert "RANKING · 1) połącz ten przebieg" in finale
assert "OPUBLIKUJ MÓJ PB W TOP 10" in leaderboard
assert "BRAK PEŁNEGO POMIARU" in leaderboard
assert "is_publish_eligible" in leaderboard
assert "is_leaderboard_publish_eligible" in reward_flow
assert "CZAS RANKINGOWY · NIEPEŁNY POMIAR" in summary

print("SYNESTHESIA_FINALE_TIMING_SIGNAL_FLOW=PASS timing=11of11 signal=fresh-context leaderboard=explicit-opt-in")
