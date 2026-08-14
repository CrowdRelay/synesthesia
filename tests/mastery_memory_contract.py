from pathlib import Path

root = Path(__file__).resolve().parents[1]
metrics = (root / 'scripts/app/progress_metrics.gd').read_text()
flow = (root / 'scripts/app/main_room_flow.gd').read_text()
base = (root / 'scripts/rooms/behavior_base.gd').read_text()
stage = (root / 'scripts/render/room_stage.gd').read_text()
store = (root / 'scripts/progress_store.gd').read_text()

for token in ('static func room_mastery(', 'static func record_room_mastery(', 'best_room_mastery', 'mastery_average'):
    assert token in metrics, token
assert 'best_room_mastery' in store
assert '"max_assist_level"' not in metrics[metrics.index('static func room_mastery('):metrics.index('static func record_room_mastery(')], 'accessibility assist must not lower mastery'
for token in ('set_resonance_memory', 'resonance_memory_strength', 'reveal_strength + resonance_memory_strength'):
    assert token in base, token
assert 'func set_resonance_memory(memory: Dictionary)' in stage
assert 'EchoArchive.latest_echo' in flow and 'app.room.set_resonance_memory' in flow
assert flow.index('app.call_deferred("_preload_next_room")') > flow.index('app.restoring_progress = false'), 'next-room I/O must start after current-room restore'
assert 'REZONANS %s · %d/100' in metrics
print('MASTERY_MEMORY_CONTRACT=PASS mastery=persistent-local echo_memory=mechanical-positive prefetch=post-restore')
