#!/usr/bin/env python3
"""Approved V4 room-identity + living-world regression contract."""
from __future__ import annotations
import hashlib, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
fail=[]

V3_SCENES={
'party-time':'8de69653c0f33e4cdd28035d4e2b9483f0af03b5f0f879e9980366a8d52f17f2',
'the-calling':'8a1bf0e4faae457efe3f6665332d1f0e99881da50b9d743a9e8b4571787fccf6',
'waves':'e3f7a0d318e2b9b6c748ec0c5fabd0f995e0e3ac4267f6476a292bb2d7f20c6b',
'rise':'62ad653c63197835729b013abb6cd7d6cb31ea3a2193cb9f9b08a9f3a984db3a',
'hybrid':'96673c77f791f3faaaa5c007e7a319c85e257eeec240b33040d853581167d07e',
'from-the-ashes':'a3dab1927c02378a06fe762bd0c7b8955d9e5cbd79bd634bd90a3538558399c2',
}

signatures=set()
for mp in sorted((ROOT/'data/releases').glob('*/manifest.json')):
    d=json.loads(mp.read_text())
    rid=d['release_id']; art=d['room'].get('art_direction',{})
    sig=str(art.get('room_signature','')).strip(); motion=str(art.get('ambient_motion','')).strip()
    if not sig or not motion or art.get('living_world_version') not in ['v4','v5','v6-post-reveal']:
        fail.append(f'{rid}: missing V4 room signature / ambient motion metadata')
    if sig in signatures: fail.append(f'{rid}: duplicate room signature {sig!r}')
    signatures.add(sig)
    if rid in V3_SCENES:
        p=ROOT/str(art.get('scene_image','')).removeprefix('res://')
        digest=hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else ''
        if digest==V3_SCENES[rid]: fail.append(f'{rid}: V3 scene resurrected')

checks={
'scripts/rooms/behaviors/party-time.gd':['_draw_membrane','_draw_burst','POWŁOKI DRŻĄ'],
'scripts/rooms/behaviors/the-calling.gd':['_draw_signal_node','RDZEŃ STOŁU','resonance ritual'],
'scripts/rooms/behaviors/waves.gd':['_draw_resonance','_draw_bridge_wave','DRUGA FALA'],
'scripts/rooms/behaviors/rise.gd':['Ascension is environmental','ascending motes'],
'scripts/render/world_micro_fx_layer.gd':['_draw_party','_draw_calling','_draw_waves','_draw_rise','_draw_hybrid','_draw_ashes'],
'scripts/render/room_video_layer.gd':['PROCEDURAL_LIVING_STYLES','must not repaint old props'],
'scripts/render/room_stage.gd':['idle_breath'],
'scripts/audio_director.gd':['resonance-lock.wav'],
'tools/build_v4_room_art.py':['SYNESTHESIA_V4_ART_BUILD=PASS','sensory membranes','resonance vessel'],
}
for rel,tokens in checks.items():
    p=ROOT/rel
    if not p.is_file(): fail.append(f'missing {rel}'); continue
    text=p.read_text(errors='replace')
    for token in tokens:
        if token not in text: fail.append(f'{rel}: missing {token!r}')

calling=(ROOT/'scripts/rooms/behaviors/the-calling.gd').read_text(errors='replace')
waves=(ROOT/'scripts/rooms/behaviors/waves.gd').read_text(errors='replace')
rise=(ROOT/'scripts/rooms/behaviors/rise.gd').read_text(errors='replace')
for forbidden,text,label in [
    ('_draw_goblet',calling,'calling literal goblet'),
    ('KIELICH',calling,'calling goblet copy'),
    ('func _draw_presence',waves,'waves stick presence'),
    ('canvas.draw_circle(person',rise,'rise stick figure'),
]:
    if forbidden in text: fail.append(f'{label} resurrected')

if len(signatures)!=11: fail.append(f'room signatures must be unique for 11 rooms, got {len(signatures)}')
if fail:
    print('\n'.join('FAIL: '+x for x in fail))
    raise SystemExit(f'SYNESTHESIA_LIVING_ROOMS_V4=FAIL count={len(fail)}')
print('SYNESTHESIA_LIVING_ROOMS_V4=PASS rooms=11 signatures=unique rebuilt=6 ambient=per-room legacy-video=isolated')
