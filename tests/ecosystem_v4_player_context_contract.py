from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def read(p): return (ROOT/p).read_text(encoding='utf-8')
guide=read('scripts/app/interaction_guide.gd')
base=read('scripts/rooms/behavior_base.gd')
flow=read('scripts/app/main_room_flow.gd')
metrics=read('scripts/app/progress_metrics.gd')
finale=read('scripts/ui/signal_finale_card.gd')
reward=read('scripts/reward_client.gd')
reward_flow=read('scripts/app/main_reward_flow.gd')
assert 'assist_level_changed' in guide
for level in ('_miss_count >= 6','_miss_count >= 4','_miss_count >= 2'):
    assert level in guide
assert '[1.12, 1.18, 1.25, 1.32]' in base
assert 'latest_echo' in flow and 'ECHO Z POPRZEDNIEGO POKOJU' in flow
assert 'journey_marks' in metrics and 'PEŁNY REZONANS' in metrics
assert 'ŚLADY · %s' in finale
assert 'album_recorded(context: Dictionary)' in reward
assert '#handoff=' in finale and 'fan_session' not in finale.lower()
assert 'reward_client.complete_album' in reward_flow and 'Reward entry durably links the run' in reward_flow
print('SYNESTHESIA_ECOSYSTEM_V4=PASS assist=adaptive-reversible memory=echo-continuity finale=journey-marks handoff=fragment-only')
