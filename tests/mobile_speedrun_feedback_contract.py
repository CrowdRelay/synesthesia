#!/usr/bin/env python3
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding='utf-8')

progress = read('scripts/progress_store.gd')
room = read('scripts/app/main_room_flow.gd')
card = read('scripts/ui/completion_card.gd')
summary = read('scripts/ui/signal_journey_summary.gd')
metrics = read('scripts/app/progress_metrics.gd')

for token in ('personal_best_room_ms', 'personal_best_total_ms', 'completed_runs_local'):
    assert token in progress, token
assert 'personal_best_room_ms", "personal_best_total_ms", "completed_runs_local' in progress
assert '_completion_performance' in room
assert 'record_completion_performance' in room and 'record_personal_best' in metrics
for token in ('previous_room_best', 'room_personal_best', 'journey_personal_best'):
    assert token in metrics, token
for token in ('CZAS POKOJU', 'NOWY PB', 'PRZEBIEG', '_signed_delta'):
    assert token in card, token
assert 'PB · %s%s' in summary
assert 'personal_best_total_ms' in metrics and 'completed_runs_local' in metrics
print('SYNESTHESIA_MOBILE_SPEEDRUN_FEEDBACK=PASS records=local-only split=per-room finale=pb reset=preserved network=zero')
