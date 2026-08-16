#!/usr/bin/env python3
"""Static mobile/Web renderer budgets for the production mask-v2 pipeline."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
quality = (ROOT / "scripts/app/quality_manager.gd").read_text()
mask = (ROOT / "scripts/render/reveal_mask.gd").read_text()
brush = (ROOT / "scripts/brush/brush_engine.gd").read_text()
stage = (ROOT / "scripts/render/room_stage.gd").read_text()
visual_setup = (ROOT / "scripts/render/room_visual_setup.gd").read_text()
renderer = stage + "\n" + visual_setup
shader = (ROOT / "shaders/room_composite.gdshader").read_text()
project = (ROOT / "project.godot").read_text()
native_surface = (ROOT / "scripts/app/native_experience_surface.gd").read_text()


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
max_stamps = integer(brush, r"MAX_STAMPS_PER_SAMPLE:\s*int\s*=\s*(\d+)", "stamps-per-sample")

checks = {
    "bootstrap-pixels": viewport_w * viewport_h <= 1080 * 1920,
    "portrait-bootstrap": viewport_w * 16 == viewport_h * 9,
    "native-stretch-disabled": 'stretch/mode="disabled"' in project,
    "native-responsive-surface": "PHONE_ASPECT_CUTOFF" in native_surface and "get_content_surface" in native_surface,
    "mask": high_w <= 360 and high_h <= 640,
    "particles": particles <= 72,
    "stamps": max_stamps <= 4,
    "raster-state": 'STATE_FORMAT: String = "png-mask-v2"' in mask,
    "no-stamp-history": "MAX_STAMP_HISTORY" not in mask and "_history" not in mask,
    "buffer-first-mask": "_alpha[index] = value" in mask and "_image.set_pixel" not in mask,
    "upload-throttle": "texture_upload_hz" in quality and "upload_if_dirty" in stage,
    "adaptive-runtime": "set_runtime_budget" in stage and "runtime_scale" in shader,
    "no-history-redraw": "for segment in" not in stage and "draw_history" not in stage,
    "single-composite": "room_composite.gdshader" in renderer and "visual_snow.gdshader" not in renderer,
    "cinematic-gpu-reveal": "completion_reveal" in shader and "completion_origin" in shader,
}
failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit(f"SYNESTHESIA_PERF_BUDGET=FAIL reasons={','.join(failed)}")

print(
    "SYNESTHESIA_PERF_BUDGET=PASS "
    f"bootstrap_pixels={viewport_w * viewport_h} adaptive_native=on high_mask={high_w}x{high_h} "
    f"particles={particles} stamps_per_sample={max_stamps} persistence=png-mask-v2 adaptive=on"
)
