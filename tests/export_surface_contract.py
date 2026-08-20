#!/usr/bin/env python3
"""Production export must ship only active runtime art and game resources."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
text = (ROOT / 'export_presets.cfg').read_text()
failures: list[str] = []

presets = re.split(r'(?m)^\[preset\.\d+\]\s*$', text)[1:]
if len(presets) < 4:
    failures.append(f'expected >=4 export presets, got {len(presets)}')
for index, block in enumerate(presets[:4]):
    name_match = re.search(r'(?m)^name="([^"]+)"$', block)
    name = name_match.group(1) if name_match else f'preset-{index}'
    if 'export_filter="all_resources"' not in block:
        failures.append(f'{name}: export mode drifted from all_resources')
    filter_match = re.search(r'(?m)^exclude_filter="([^"]*)"$', block)
    value = filter_match.group(1) if filter_match else ''
    for required in (
        'tests/*',
        'tools/*',
        'assets/branding/boot-splash*',
        'assets/rooms/vertical/*-bg.webp',
        'assets/rooms/vertical/*-subject.webp',
        'assets/rooms/vertical/*-foreground.webp',
    ):
        if required not in value:
            failures.append(f'{name}: production export still includes {required}')
    if 'assets/branding/menu-eye-*' in value:
        failures.append(f'{name}: reduced-motion menu fallback must remain exportable')

if failures:
    for failure in failures:
        print(f'FAIL: {failure}')
    raise SystemExit(f'SYNESTHESIA_EXPORT_SURFACE=FAIL count={len(failures)}')

print('SYNESTHESIA_EXPORT_SURFACE=PASS runtime=scene-image-only retired-room-layers=excluded menu-fallback=preserved tests=excluded tools=excluded platforms=4')
