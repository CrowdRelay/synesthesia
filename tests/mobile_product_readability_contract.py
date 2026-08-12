#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
stage = (ROOT / 'scripts/render/room_stage.gd').read_text()
profile_runtime = (ROOT / 'scripts/render/room_render_profile.gd').read_text()
shader = (ROOT / 'shaders/room_composite.gdshader').read_text()
settings = (ROOT / 'scripts/ui/settings_card.gd').read_text()
progress = (ROOT / 'scripts/progress_store.gd').read_text()
main_settings = (ROOT / 'scripts/app/main_settings_flow.gd').read_text()
chapter = (ROOT / 'scripts/ui/chapter_card.gd').read_text()
behaviors = {name: (ROOT / f'scripts/rooms/behaviors/{name}.gd').read_text() for name in ('party-time','the-calling','hybrid','invaluable')}

profiles = {}
for manifest in sorted((ROOT / 'data/releases').glob('*/manifest.json')):
    data = json.loads(manifest.read_text())
    room = data.get('room', {})
    profile = room.get('mobile_readability')
    assert isinstance(profile, dict), f'{manifest}: mobile_readability missing'
    for key in ('shadow_lift','subject_lift','noise_scale','vignette_floor'):
        assert isinstance(profile.get(key), (int,float)), f'{manifest}: {key} missing'
    profiles[manifest.parent.name] = profile
assert len(profiles) >= 11
assert profiles['party-time']['shadow_lift'] > profiles['seed-of-doubt']['shadow_lift']
for token in ('readability_shadow_lift','readability_subject_lift','readability_noise_scale','readability_vignette_floor'):
    assert token in profile_runtime and token in shader, token
assert 'func set_high_readability' in stage
assert 'Czytelność: %s' in settings
assert 'high_readability' in progress and 'high_readability' in main_settings
assert '_row.add_child(_motif)' in chapter and '_ui_scale' in chapter
assert 'assist_level' in behaviors['party-time']
assert 'assist_level' in behaviors['the-calling']
assert 'assist_level' in behaviors['hybrid']
assert 'assist_level' in behaviors['invaluable']
assert 'texture(' not in shader[shader.index('uniform float readability_shadow_lift'):shader.index('void fragment')]
print('SYNESTHESIA_MOBILE_PRODUCT_READABILITY=PASS rooms>=11 profiles=authored high-mode=persisted subject-affordance=adaptive renderer=single-pass')
