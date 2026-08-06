#!/usr/bin/env python3
"""Write a deterministic production asset report."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "asset-report.txt"
rows: list[str] = []
for group, pattern in (
    ("room-scene", "assets/rooms/vertical/*-scene.webp"),
    ("room-subject", "assets/rooms/vertical/*-subject.webp"),
    ("room-foreground", "assets/rooms/vertical/*-foreground.webp"),
    ("room-background", "assets/rooms/vertical/*-bg.webp"),
    ("audio", "assets/audio/*"),
):
    for path in sorted(ROOT.glob(pattern)):
        if path.is_file():
            rows.append(f"{group}\t{path.relative_to(ROOT).as_posix()}\t{path.stat().st_size}")
excluded_parts = {'.git', '.godot', 'build', '.cache', '.synesthesia-backups', '__pycache__'}
rows.append(f"total\t.\t{sum(p.stat().st_size for p in ROOT.rglob('*') if p.is_file() and not any(part in excluded_parts for part in p.relative_to(ROOT).parts) and p.name not in {'asset-report.txt', 'PACKAGE_CHECKSUMS.txt'})}")
OUTPUT.write_text("\n".join(rows) + "\n")
print(f"SYNESTHESIA_ASSET_REPORT=PASS entries={len(rows)-1} output={OUTPUT.relative_to(ROOT)}")
