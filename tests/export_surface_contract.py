#!/usr/bin/env python3
"""Production export must not ship test/tool GDScript while retaining game resources."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
text = (ROOT / 'export_presets.cfg').read_text()
failures: list[str] = []

presets = re.split(r'(?m)^\[preset\.\d+\]\s*$', text)[1:]
if len(presets) < 3:
    failures.append(f'expected >=3 export presets, got {len(presets)}')
for index, block in enumerate(presets[:3]):
    name_match = re.search(r'(?m)^name="([^"]+)"$', block)
    name = name_match.group(1) if name_match else f'preset-{index}'
    if 'export_filter="all_resources"' not in block:
        failures.append(f'{name}: export mode drifted from all_resources')
    filter_match = re.search(r'(?m)^exclude_filter="([^"]*)"$', block)
    value = filter_match.group(1) if filter_match else ''
    for required in ('tests/*', 'tools/*'):
        if required not in value:
            failures.append(f'{name}: production export still includes {required}')

if failures:
    for failure in failures:
        print(f'FAIL: {failure}')
    raise SystemExit(f'SYNESTHESIA_EXPORT_SURFACE=FAIL count={len(failures)}')

print('SYNESTHESIA_EXPORT_SURFACE=PASS runtime=game-only tests=excluded tools=excluded platforms=3')
