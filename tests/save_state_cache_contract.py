#!/usr/bin/env python3
from pathlib import Path
s=Path('scripts/render/reveal_mask.gd').read_text()
required=[
    'var _revision: int = 0',
    'var _cached_revision: int = -1',
    'func _ensure_export_cache() -> void:',
    'if _cached_revision == _revision and not _cached_state.is_empty():',
    'func state_encode_count() -> int:',
    '_mark_changed()',
    'return _cached_png_bytes',
    '_cached_revision = _revision',
    '_cached_png_bytes = png.size()',
    'if reusable_png:',
    'var reusable_png: bool = (',
]
missing=[item for item in required if item not in s]
# Two direct save_png calls are not acceptable anymore: encoding belongs only to the cache fill.
if s.count('save_png_to_buffer()') != 1:
    missing.append(f'png-encode-sites={s.count("save_png_to_buffer()")}/1')
if missing:
    raise SystemExit('SYNESTHESIA_SAVE_STATE_CACHE=FAIL missing=' + ','.join(missing))
print('SYNESTHESIA_SAVE_STATE_CACHE=PASS mask=revisioned png=encode-on-change+restore-reuse estimate=no-reencode')
