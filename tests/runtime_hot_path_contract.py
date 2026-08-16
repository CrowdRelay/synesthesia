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
hints=text('scripts/render/interaction_hint_layer.gd')
waves=text('scripts/rooms/behaviors/waves.gd')

checks={
    'local pointer mirror': 'var _active_points: Dictionary = {}' in router,
    'input route avoids merge temporaries': '.merge(' not in router and '{"handled": false, "gestures": []' not in router,
    'idle gesture tick gate': 'func needs_tick() -> bool:' in router and 'interaction_router.needs_tick()' in stage,
    'no callv event hot path': '.callv(' not in backend and '_events(_backend.call(&"pointer_move"' in backend,
    'behavior idle gate': 'behavior.needs_tick()' in stage and 'func needs_tick() -> bool:' in base,
    'party sleeps at rest': 'state["motion_active"] = still_moving' in party and 'burst_ages' in party and 'return false' in party,
    'hybrid bounded duel tick': 'duel_elapsed' in hybrid and ' < 3.0)' in hybrid,
    'audio control cadence': 'const CONTROL_INTERVAL: float = 1.0 / 60.0' in audio and '_control_accumulator' in audio,
    'adaptive sleeps off gameplay': 'func set_suspended(value: bool)' in adaptive and 'set_process(profile_name == "balanced" and not value)' in adaptive,
    'rust compact pointer storage': 'pointers: Vec<PointerSlot>' in rust and 'Vec::with_capacity(2)' in rust,
    'rust duplicate pointer regression': 'repeated_pointer_down_replaces_slot_without_growing_active_set' in rust,
    'transition sfx preloaded': all(token in transition for token in ('DOOR_CLOSE_STREAM: AudioStream = preload', 'DOOR_OPEN_STREAM: AudioStream = preload', 'TELEPORT_STREAM: AudioStream = preload')),
    'reduced atmosphere sleeps': 'set_process(not reduced_motion)' in atmosphere,
    'reduced dressing sleeps': '_sync_processing()' in dressing and 'set_process(is_visible_in_tree() and not _reduced_motion)' in dressing,
    'dressing setters avoid redundant churn': dressing.count('is_equal_approx(next, _') >= 3 and 'if _reduced_motion == value:' in dressing,
    'room stage has no duplicate visual preloads': all(token not in text('scripts/render/room_stage.gd') for token in ('AtmosphereLayerScript', 'InteractionFxLayerScript', 'RoomDressingLayerScript', 'RoomVideoLayerScript', 'InteractionHintLayerScript', 'CompositeShader')),
    'mask grain profile hoisted': 'var grain_mode: int = _grain_mode(profile)' in reveal and 'func _grain(x: int, y: int, seed: int, mode: int)' in reveal,
    'mask grain dead hash removed': reveal.find('match mode:') < reveal.find('var base: float = _hash01(x, y, seed)'),
    'hint refresh sleeps while inactive': 'hint_layer.is_active()' in stage,
    'hint targets avoid deep-copy churn': 'duplicate(true)' not in hints,
    'waves bridge buffer reused': 'var _bridge_points: PackedVector2Array' in waves and '_bridge_points[i] = p' in waves,
    'waves render literals hoisted': 'const RESONANCE_HEIGHTS' in waves,
    'ambient fx hidden and reduced idle sleeps': 'visibility_changed.connect(_sync_processing)' in text('scripts/render/world_micro_fx_layer.gd') and 'interaction_energy <= 0.01 and cinematic <= 0.01' in text('scripts/render/world_micro_fx_layer.gd'),
    'ambient fx setters avoid redundant churn': text('scripts/render/world_micro_fx_layer.gd').count('is_equal_approx(next,') >= 4,
    'post reveal runtime sleeps before reveal': 'func set_revealed(value: bool' in text('scripts/render/post_reveal_living_runtime.gd') and 'set_process(false)' in text('scripts/render/post_reveal_living_runtime.gd'),
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
