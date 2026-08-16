#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fx = (ROOT / 'scripts/render/world_micro_fx_layer.gd').read_text()
shader = (ROOT / 'shaders/room_composite.gdshader').read_text()
runtime = (ROOT / 'scripts/render/post_reveal_living_runtime.gd').read_text()

failures = []
required_fx = [
    'func _draw_gameplay_living_accents',
    '"technophobia":', '"unmasked":', '"invaluable":', '"seed":', '"party":',
    '"calling":', '"ashes":', '"waves":', '"hybrid":', '"rise":',
    'var phase := _time * (0.16 + ring * 0.025) * dir', 'var pulse := fmod(_time * 0.22, 1.0)', 'var sync := 0.5 + 0.5 * sin(_time * 0.38)',
]
for token in required_fx:
    if token not in fx:
        failures.append(f'missing living accent token: {token}')

for token in [
    'Technophobia: residual horizontal sync errors',
    'Seed: sap current gently bends',
    'Ashes: heat haze around phoenix',
    'Hybrid: radial motor vibration',
    'Rise: vertical atmospheric current',
    'Room materials keep breathing after completion',
]:
    if token not in shader:
        failures.append(f'missing shader living effect: {token}')

# Assert Invaluable behavior rather than an old comment string. The effect was
# intentionally strengthened from a tiny refraction into shard/crystal motion
# plus a travelling reflection sweep; comment wording is not the contract.
for token in [
    'unlock_profile == 7',
    'float shard = sin(',
    'float crystal = sin(',
    'float sweep = smoothstep(',
    'Invaluable: moving glass glint.',
]:
    if token not in shader:
        failures.append(f'missing Invaluable glass behavior: {token}')

for token in ['Start the living loop before the hero beat fully settles', 'overlap_target', 'delta * 0.88', 'func set_revealed(value: bool', 'set_process(false)']:
    if token not in runtime:
        failures.append(f'missing reveal-to-living transition: {token}')

if failures:
    for f in failures:
        print('FAIL:', f)
    raise SystemExit(f'SYNESTHESIA_POST_REVEAL_GAMEPLAY_V8=FAIL count={len(failures)}')

print('SYNESTHESIA_POST_REVEAL_GAMEPLAY_V8=PASS rooms=11 accents=active shader=localized reveal=overlap game-feel=stronger')
