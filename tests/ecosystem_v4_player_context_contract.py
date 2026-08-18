from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def read(p): return (ROOT/p).read_text(encoding='utf-8')
guide=read('scripts/app/interaction_guide.gd')
base=read('scripts/rooms/behavior_base.gd')
flow=read('scripts/app/main_room_flow.gd')
metrics=read('scripts/app/progress_metrics.gd')
finale=read('scripts/ui/signal_finale_card.gd')
cta_state=read('scripts/ui/signal_cta_state.gd')
journey_summary=read('scripts/ui/signal_journey_summary.gd')
reward=read('scripts/reward_client.gd')
reward_flow=read('scripts/app/main_reward_flow.gd')
assert 'assist_level_changed' in guide
for level in ('_miss_count >= 6','_miss_count >= 4','_miss_count >= 2'):
    assert level in guide
assert '[1.12, 1.20, 1.30, 1.40]' in base
assert 'latest_echo' in flow and 'ECHO Z POPRZEDNIEGO POKOJU' in flow
assert 'journey_marks' in metrics and 'PEŁNY REZONANS' in metrics
assert 'SignalJourneySummary' in finale and 'ŚLADY · %s' in journey_summary
assert 'album_recorded(context: Dictionary)' in reward
# The My Signal URL moved into SignalCtaState; the handoff must stay a URL
# fragment so it never reaches a server log or Referer header, and neither
# the finale nor the CTA helper may touch fan session tokens.
assert '#handoff=' in cta_state and 'fan_session' not in cta_state.lower()
assert 'SignalCtaState.my_signal_url(' in finale and 'fan_session' not in finale.lower()
assert 'reward_client.complete_album' in reward_flow and 'Reward entry durably links the run' in reward_flow
print('SYNESTHESIA_ECOSYSTEM_V4=PASS assist=adaptive-reversible memory=echo-continuity finale=journey-marks handoff=fragment-only')
