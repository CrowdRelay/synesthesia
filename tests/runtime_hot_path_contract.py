#!/usr/bin/env python3
from pathlib import Path

failures=[]

def text(path): return Path(path).read_text()

router=text('scripts/input/interaction_router.gd')
backend=text('scripts/native/rust_gesture_backend.gd')
stage=text('scripts/render/room_stage.gd')+'\n'+text('scripts/render/room_interaction_flow.gd')
base=text('scripts/rooms/behavior_base.gd')
party=text('scripts/rooms/behaviors/party-time.gd')
hybrid=text('scripts/rooms/behaviors/hybrid.gd')
audio=text('scripts/audio_director.gd')
adaptive=text('scripts/app/adaptive_performance.gd')
quality=text('scripts/app/quality_manager.gd')
main=text('scripts/main.gd')+'\n'+text('scripts/app/main_settings_flow.gd')
rust=text('native/synesthesia-core/src/lib.rs')

transition=text('scripts/app/transition_director.gd')
atmosphere=text('scripts/render/atmosphere_layer.gd')
dressing=text('scripts/render/room_dressing_layer.gd')
reveal=text('scripts/render/reveal_mask.gd')

checks={
    'local pointer mirror': 'var _active_points: Dictionary = {}' in router,
    'input route avoids merge temporaries': '.merge(' not in router and '{"handled": false, "gestures": []' not in router,
    'idle gesture tick gate': 'func needs_tick() -> bool:' in router and 'interaction_router.needs_tick()' in stage,
    'no callv event hot path': '.callv(' not in backend and '_events(_backend.call(&"pointer_move"' in backend,
    'behavior idle gate': 'behavior.needs_tick()' in stage and 'func needs_tick() -> bool:' in base,
    'party sleeps at rest': 'state["motion_active"] = still_moving' in party and 'return cinematic_active() or bool(state.get("motion_active", false))' in party,
    'hybrid bounded duel tick': 'duel_elapsed' in hybrid and ' < 3.0)' in hybrid,
    'audio control cadence': 'const CONTROL_INTERVAL: float = 1.0 / 60.0' in audio and '_control_accumulator' in audio,
    'adaptive sleeps off gameplay': 'func set_suspended(value: bool)' in adaptive and 'set_process(profile_name == "balanced" and not value)' in adaptive,
    'rust compact pointer storage': 'pointers: Vec<PointerSlot>' in rust and 'Vec::with_capacity(2)' in rust,
    'rust duplicate pointer regression': 'repeated_pointer_down_replaces_slot_without_growing_active_set' in rust,
    'transition sfx preloaded': all(token in transition for token in ('DOOR_CLOSE_STREAM: AudioStream = preload', 'DOOR_OPEN_STREAM: AudioStream = preload', 'TELEPORT_STREAM: AudioStream = preload')),
    'reduced atmosphere sleeps': 'set_process(not reduced_motion)' in atmosphere,
    'reduced dressing sleeps': 'set_process(not _reduced_motion)' in dressing,
    'mask grain profile hoisted': 'var grain_mode: int = _grain_mode(profile)' in reveal and 'func _grain(x: int, y: int, seed: int, mode: int)' in reveal,
    'mask grain dead hash removed': reveal.find('match mode:') < reveal.find('var base: float = _hash01(x, y, seed)'),
}
for name,ok in checks.items():
    if not ok: failures.append(name)

if 'return 60 if profile_name == "battery" else 0' not in quality:
    failures.append("battery profile does not cap high-refresh rendering at 60 FPS")
if "Engine.max_fps = QualityManager.frame_cap(quality_profile)" not in main or "Engine.max_fps = app.QualityManager.frame_cap(app.quality_profile)" not in main:
    failures.append("quality frame cap is not applied at boot and profile reload")

if failures:
    raise SystemExit('SYNESTHESIA_RUNTIME_HOT_PATH=FAIL missing=' + ','.join(failures))
print('SYNESTHESIA_RUNTIME_HOT_PATH=PASS gesture=idle-zero-ffi+no-merge-temp behaviors=sleep reduced=event-driven transition-sfx=preloaded mask-grain=hoisted audio<=60hz battery<=60fps rust=vec2')
