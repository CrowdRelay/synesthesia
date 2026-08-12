#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
telemetry = (ROOT / "scripts/app/gameplay_telemetry.gd").read_text()
flow = (ROOT / "scripts/app/main_room_flow.gd").read_text()
main = (ROOT / "scripts/main.gd").read_text()
hud = (ROOT / "scripts/ui/app_hud.gd").read_text()
feedback = (ROOT / "scripts/app/player_feedback_bridge.gd").read_text()
rum = (ROOT / "web/rum.js").read_text()

for token in (
    'const SAMPLE_RATE := 0.05', 'const MAX_QUEUE := 4', 'func begin_room',
    'func complete_room', 'func abandon_room', 'first_success_ms', 'miss_count',
    'hint_count', 'max_assist_level', 'quality_min_scale', 'credentials',
):
    if token == 'credentials':
        assert 'credentials: "omit"' in rum
    else:
        assert token in telemetry, token
for forbidden in ('user_id', 'email', 'fingerprint', 'device_id', 'advertising_id', 'localStorage', 'sessionStorage'):
    assert forbidden not in telemetry and forbidden not in rum, forbidden
assert 'gameplay_telemetry.begin_room' in flow
assert 'gameplay_telemetry.complete_room' in flow
assert 'gameplay_telemetry.abandon_room' in flow
assert 'gameplay_telemetry.note_quality_scale' in main
assert '_hud.note_success()' in feedback
assert 'synesthesia:gameplay-metric' in rum
assert '`${key}:${roomId}`' in rum
assert 'note_miss' not in telemetry and 'note_interaction' not in telemetry
print('SYNESTHESIA_GAMEPLAY_TELEMETRY=PASS sample=5% summary=room-only identity=none queue<=4 per-room-dedupe=true')
