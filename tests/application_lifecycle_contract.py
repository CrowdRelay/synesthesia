#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / 'scripts/main.gd').read_text()
guard = (ROOT / 'scripts/app/menu_runtime_guard.gd').read_text()
audio = (ROOT / 'scripts/audio_director.gd').read_text()
adaptive = (ROOT / 'scripts/app/adaptive_performance.gd').read_text()
failures: list[str] = []

for item in (
    'NOTIFICATION_APPLICATION_PAUSED',
    'MenuRuntimeGuard.suspend_for_background(experience_surface, ui_root, room_layer, audio_director, adaptive_performance)',
    'NOTIFICATION_APPLICATION_RESUMED',
    'MenuRuntimeGuard.resume_from_background(experience_surface, ui_root, room_layer, audio_director, adaptive_performance)',
):
    if item not in main:
        failures.append(f'main lifecycle wiring missing: {item}')

for item in (
    'static func suspend_for_background',
    'static func resume_from_background',
    '_background_experience_mode',
    '_background_ui_mode',
    '_background_room_mode',
    'experience_surface.process_mode = Node.PROCESS_MODE_DISABLED',
    'ui_root.process_mode = Node.PROCESS_MODE_DISABLED',
    'experience_surface.process_mode = _background_experience_mode',
    'ui_root.process_mode = _background_ui_mode',
):
    if item not in guard:
        failures.append(f'background root freeze contract missing: {item}')

if '_control_accumulator = 0.0' not in audio or 'set_process(not value)' not in audio:
    failures.append('audio resume/control reset contract missing')
if 'func set_suspended(value: bool)' not in adaptive or '_reset_after_resume()' not in adaptive:
    failures.append('adaptive resume warmup contract missing')
if len(main.splitlines()) > 980:
    failures.append(f'main-lines={len(main.splitlines())}>980')

if failures:
    for failure in failures:
        print(f'FAIL: {failure}')
    raise SystemExit(f'SYNESTHESIA_APP_LIFECYCLE=FAIL count={len(failures)}')

print(f'SYNESTHESIA_APP_LIFECYCLE=PASS background=visual-roots+room+audio+adaptive-state-preserved main_lines={len(main.splitlines())}')
