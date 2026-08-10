#!/usr/bin/env python3
"""Final room identity/motion grammar contract.

The goal is not to count particles. Every room must have one recognisable
signature, four-stage motion grammar, an art-first completed state, and an
explicit reduced-motion fallback while reusing the existing lightweight V6
living-world runtime.
"""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]
manifests=sorted((ROOT/'data/releases').glob('*/manifest.json'))
fail=[]
if len(manifests)!=11: fail.append(f'expected 11 release rooms, got {len(manifests)}')
profiles=set(); signatures=set(); heroes=set(); interactions=set()
for path in manifests:
    data=json.loads(path.read_text())
    room=data.get('room',{})
    art=room.get('art_direction',{})
    living=room.get('living_state',{})
    rid=path.parent.name
    profile=str(living.get('profile','')).strip()
    signature=str(living.get('signature_interaction','')).strip()
    grammar=living.get('motion_grammar',{})
    interaction=str(room.get('interaction','')).strip()
    if not profile or profile in profiles: fail.append(f'{rid}: missing/duplicate living profile {profile!r}')
    profiles.add(profile)
    if not signature or signature in signatures: fail.append(f'{rid}: missing/duplicate signature interaction {signature!r}')
    signatures.add(signature)
    if not interaction or interaction in interactions: fail.append(f'{rid}: missing/duplicate gameplay interaction {interaction!r}')
    interactions.add(interaction)
    required=['ambient','reactive','reveal','hero','settle','hud','reduced_motion']
    for key in required:
        if not str(grammar.get(key,'')).strip(): fail.append(f'{rid}: motion grammar missing {key}')
    hero=str(grammar.get('hero',''))
    if hero in heroes: fail.append(f'{rid}: duplicate hero beat {hero!r}')
    heroes.add(hero)
    if grammar.get('hud')!='art-first-auto-dim': fail.append(f'{rid}: completed HUD must be art-first-auto-dim')
    if grammar.get('reduced_motion')!='static-readable-low-energy': fail.append(f'{rid}: reduced-motion fallback is not explicit')
    if len(living.get('effects',[])) < 4: fail.append(f'{rid}: signature needs at least four low-cost living effects')
    if art.get('post_reveal') != 'hero -> settle -> living-loop': fail.append(f'{rid}: reveal grammar drifted')

runtime=(ROOT/'scripts/render/world_micro_fx_layer.gd').read_text()
for profile in profiles - {'uncertainty'}:
    if f'"{profile}"' not in runtime: fail.append(f'runtime missing explicit room profile: {profile}')
hud=(ROOT/'scripts/ui/app_hud.gd').read_text()
for token in ['artwork, not the instrument panel','tween_property(top_panel, "modulate:a", 0.18','subtitle_label.visible = false','palette_row.visible = false']:
    if token not in hud: fail.append(f'art-first completed HUD missing token: {token}')
post=(ROOT/'scripts/render/post_reveal_living_runtime.gd').read_text()
for token in ['hero beat','living loop','reduced_motion_strength','set_living_strength','set_target_fps']:
    if token not in post: fail.append(f'living runtime missing {token}')
if fail:
    print('SYNESTHESIA_SIGNATURE_GRAMMAR_V9=FAIL')
    for item in fail: print('-',item)
    raise SystemExit(1)
print('SYNESTHESIA_SIGNATURE_GRAMMAR_V9=PASS rooms=11 grammar=ambient+reactive+reveal+hero art-first-hud=true reduced-motion=explicit')
