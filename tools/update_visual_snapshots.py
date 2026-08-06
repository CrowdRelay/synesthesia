#!/usr/bin/env python3
"""Refresh intentional visual asset hashes after an approved art pass."""
from __future__ import annotations
import hashlib, json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
patterns = (
    "assets/rooms/vertical/*-scene.webp",
    "assets/rooms/vertical/*-bg.webp",
    "assets/rooms/vertical/*-subject.webp",
    "assets/rooms/vertical/*-foreground.webp",
)
result: dict[str, str] = {}
for pattern in patterns:
    for path in sorted(ROOT.glob(pattern)):
        result[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
out = ROOT / "tests" / "visual_snapshots.json"
out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(f"SYNESTHESIA_VISUAL_SNAPSHOTS_UPDATED={len(result)} output={out.relative_to(ROOT)}")
