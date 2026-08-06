#!/usr/bin/env python3
"""Detect missing, stale or accidentally modified production room plates."""
from __future__ import annotations
import hashlib, json, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
SNAPSHOT = ROOT / "tests" / "visual_snapshots.json"
expected = json.loads(SNAPSHOT.read_text())
failures: list[str] = []
actual_paths = set()
for pattern in (
    "assets/rooms/vertical/*-scene.webp",
    "assets/rooms/vertical/*-bg.webp",
    "assets/rooms/vertical/*-subject.webp",
    "assets/rooms/vertical/*-foreground.webp",
):
    for path in ROOT.glob(pattern):
        rel = path.relative_to(ROOT).as_posix()
        actual_paths.add(rel)
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if expected.get(rel) != digest:
            failures.append(f"visual snapshot mismatch: {rel}")
for rel in sorted(set(expected) - actual_paths):
    failures.append(f"visual snapshot file missing: {rel}")
for rel in sorted(actual_paths - set(expected)):
    failures.append(f"visual snapshot not registered: {rel}")
if failures:
    for failure in failures:
        print(f"FAIL: {failure}", file=sys.stderr)
    print(f"SYNESTHESIA_VISUAL_SNAPSHOTS=FAIL count={len(failures)}", file=sys.stderr)
    raise SystemExit(1)
print(f"SYNESTHESIA_VISUAL_SNAPSHOTS=PASS files={len(actual_paths)}")
