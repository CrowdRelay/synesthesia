#!/usr/bin/env python3
from __future__ import annotations
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
failures=[]
path=ROOT/'data/room_asset_slots.json'
if not path.is_file(): failures.append('missing room_asset_slots.json')
else:
 data=json.loads(path.read_text())
 rooms=data.get('rooms',{})
 if len(rooms)!=11: failures.append(f'asset slots rooms={len(rooms)} expected=11')
 if data.get('version') != 2: failures.append('asset slot schema must be V2')
 if data.get('style') != 'virya-signal-v2-moodboard-locked': failures.append('asset slot style must be moodboard-locked V2')
 for rid, slots in rooms.items():
  if not isinstance(slots,list) or len(slots)<4: failures.append(f'{rid}: needs >=4 prop/fx slots')
 rules=data.get('rules',{})
 for key in ('master_min','runtime_budget_per_room_kib','visual_language','faces'):
  if key not in rules: failures.append(f'missing rule {key}')
if not (ROOT/'assets/props/README.md').is_file(): failures.append('missing assets/props/README.md')
if not (ROOT/'docs/FULL_ROOM_GAMEPLAY.md').is_file(): failures.append('missing docs/FULL_ROOM_GAMEPLAY.md')
if failures:
 [print('FAIL:',x) for x in failures]
 raise SystemExit(f'SYNESTHESIA_ROOM_ASSET_SLOTS=FAIL count={len(failures)}')
print('SYNESTHESIA_ROOM_ASSET_SLOTS=PASS rooms=11 style=virya-signal-v2 props=layered budget=bounded')
