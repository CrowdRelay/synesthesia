#!/usr/bin/env python3
"""Static mobile/Web renderer budgets for the production mask pipeline."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
quality = (ROOT / "scripts/app/quality_manager.gd").read_text()
mask = (ROOT / "scripts/render/reveal_mask.gd").read_text()
brush = (ROOT / "scripts/brush/brush_engine.gd").read_text()
stage = (ROOT / "scripts/render/room_stage.gd").read_text()
project = (ROOT / "project.godot").read_text()


def integer(source: str, pattern: str, label: str) -> int:
    match = re.search(pattern, source)
    if not match:
        raise SystemExit(f"SYNESTHESIA_PERF_BUDGET=FAIL reason=missing-{label}")
    return int(match.group(1))


def profile_value(name: str, key: str) -> int:
    block = re.search(rf'"{name}":\s*return\s*\{{(.*?)\n\s*\}}', quality, re.S)
    if not block:
        raise SystemExit(f"SYNESTHESIA_PERF_BUDGET=FAIL reason=profile-{name}")
    return integer(block.group(1), rf'"{key}":\s*(\d+)', f"{name}-{key}")


viewport_w = integer(project, r"size/viewport_width=(\d+)", "viewport-width")
viewport_h = integer(project, r"size/viewport_height=(\d+)", "viewport-height")
high_w = profile_value("high", "mask_width")
high_h = profile_value("high", "mask_height")
particles = profile_value("high", "particle_count")
history = integer(mask, r"MAX_STAMP_HISTORY:\s*int\s*=\s*(\d+)", "stamp-history")
max_stamps = integer(brush, r"MAX_STAMPS_PER_SAMPLE:\s*int\s*=\s*(\d+)", "stamps-per-sample")

checks = {
    "logical-pixels": viewport_w * viewport_h <= 540 * 960,
    "portrait": viewport_w * 16 == viewport_h * 9,
    "mask": high_w <= 360 and high_h <= 640,
    "particles": particles <= 72,
    "history": history <= 1200,
    "stamps": max_stamps <= 4,
    "upload-throttle": "texture_upload_hz" in quality and "upload_if_dirty" in stage,
    "no-history-redraw": "for segment in" not in stage and "draw_history" not in stage,
    "single-composite": "room_composite.gdshader" in stage and "visual_snow.gdshader" not in stage,
}
failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit(f"SYNESTHESIA_PERF_BUDGET=FAIL reasons={','.join(failed)}")

print(
    "SYNESTHESIA_PERF_BUDGET=PASS "
    f"logical_pixels={viewport_w * viewport_h} high_mask={high_w}x{high_h} "
    f"particles={particles} history={history} stamps_per_sample={max_stamps}"
)
