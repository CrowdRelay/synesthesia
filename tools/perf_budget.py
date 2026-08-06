#!/usr/bin/env python3
"""Guard the mobile rendering budget against accidental regressions."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "scripts" / "paint_room.gd").read_text()


def constant(name: str) -> float:
    match = re.search(rf"(?m)^const {re.escape(name)}: (?:int|float) = ([0-9.]+)$", SOURCE)
    if not match:
        raise SystemExit(f"missing performance constant: {name}")
    return float(match.group(1))


grid_width = int(constant("GRID_WIDTH"))
grid_height = int(constant("GRID_HEIGHT"))
max_segments = int(constant("MAX_SEGMENTS"))
active_hz = constant("ACTIVE_REDRAW_HZ")
calm_hz = constant("CALM_IDLE_REDRAW_HZ")
reduced_hz = constant("REDUCED_MOTION_REDRAW_HZ")

failures: list[str] = []
if max_segments > 600:
    failures.append(f"MAX_SEGMENTS={max_segments} exceeds mobile budget 600")
if active_hz > 60.0:
    failures.append(f"ACTIVE_REDRAW_HZ={active_hz} exceeds 60")
if calm_hz > 30.0:
    failures.append(f"CALM_IDLE_REDRAW_HZ={calm_hz} exceeds 30")
if reduced_hz > 12.0:
    failures.append(f"REDUCED_MOTION_REDRAW_HZ={reduced_hz} exceeds 12")
if "for x in range(GRID_WIDTH + 1)" not in SOURCE:
    failures.append("VSS cells are not run-length merged")
if "MAX_BRUSH_STAMPS_PER_SEGMENT: int = 3" not in SOURCE:
    failures.append("brush stamp budget must remain capped at 3")
if "coverage_changed_now" not in SOURCE:
    failures.append("coverage updates are not batched per stroke")

if failures:
    for failure in failures:
        print(f"ERROR: {failure}")
    raise SystemExit(1)

legacy_vss_draws = grid_width * grid_height
optimized_empty_room_draws = grid_height * 2
legacy_stroke_draws = 1500 * 4
optimized_stroke_draws = max_segments * 9
print(
    "SYNESTHESIA_PERF_BUDGET=PASS "
    f"vss_empty_draws={legacy_vss_draws}->{optimized_empty_room_draws} "
    f"stroke_draw_budget={legacy_stroke_draws}->{optimized_stroke_draws} "
    f"idle_hz={calm_hz:g} reduced_hz={reduced_hz:g}"
)
