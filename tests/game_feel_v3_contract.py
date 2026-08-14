#!/usr/bin/env python3
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]
fail=[]
def req(path,*tokens):
    p=ROOT/path
    if not p.is_file(): fail.append(f'missing {path}'); return ''
    text=p.read_text(errors='replace')
    for t in tokens:
        if t not in text: fail.append(f'{path}: missing {t!r}')
    return text

req('scripts/render/world_micro_fx_layer.gd','technophobia','unmasked','invaluable','seed','party','ashes','calling','waves','hybrid','rise','_draw_tech','_draw_glass')
req('scripts/render/room_visual_setup.gd','WorldMicroFxLayerScript','WorldMicroFX')
req('scripts/render/room_stage.gd','world_micro_fx.set_progress','world_micro_fx.set_pointer','world_micro_fx.set_cinematic')
req('scripts/audio_director.gd','_semantic_clearance','cable_unplug','signal_lock','echo_complete','music_ratio','noise_ratio')
req('scripts/ui/signal_resonance_ritual.gd','REZONANS · 4 SYGNAŁY · 1 TOŻSAMOŚĆ','SIGNAL COMPLETE','completed.emit()')
req('scripts/ui/signal_finale_card.gd','SignalResonanceRitual','_on_ritual_completed','_form.visible = true','_claim.disabled = not server_completed or not _ritual_complete','_claim.disabled = not value or not _ritual_complete')
req('scripts/app/echo_archive.gd','source_role','echo_type','reward_hint')
req('scripts/app/main_room_flow.gd','ECHA 3/3 · pełna pamięć pokoju','echo_complete')
req('scripts/ui/album_archive_card.gd','EchoCodexMemory')
for mp in sorted((ROOT/'data/releases').glob('*/manifest.json')):
    d=json.loads(mp.read_text())
    for c in d.get('collectibles',[]):
        for k in ('source','source_role','echo_type','reward_hint'):
            if not str(c.get(k,'')).strip(): fail.append(f'{d.get("release_id")}: echo missing {k}')
if fail:
    print('\n'.join('FAIL: '+x for x in fail)); raise SystemExit(f'SYNESTHESIA_GAME_FEEL_V3=FAIL count={len(fail)}')
print('SYNESTHESIA_GAME_FEEL_V3=PASS microfx=11 semantic-audio=on echo-codex=rich finale=resonance-ritual')
