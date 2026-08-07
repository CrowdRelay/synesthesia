#!/usr/bin/env python3
"""Static release-candidate contracts for 0.11 production polish."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []


def require(path: str, *tokens: str) -> str:
    target = ROOT / path
    if not target.is_file():
        failures.append(f"missing {path}")
        return ""
    text = target.read_text(errors="replace")
    for token in tokens:
        if token not in text:
            failures.append(f"{path}: missing contract token {token!r}")
    return text


mask = require(
    "scripts/render/reveal_mask.gd",
    'STATE_FORMAT: String = "png-mask-v2"',
    "PackedByteArray",
    "save_png_to_buffer",
    "raw_to_base64",
    "base64_to_raw",
    "MAX_ENCODED_STATE_CHARS",
    "MAX_PNG_STATE_BYTES",
)
for forbidden in ("_history", "_image.set_pixel"):
    if forbidden in mask:
        failures.append(f"reveal mask resurrected forbidden {forbidden}")

stage = require(
    "scripts/render/room_stage.gd",
    "set_runtime_budget",
    'set_shader_parameter("completion_reveal"',
    'set_shader_parameter("brush_energy"',
    "asset_source.take",
    "interaction_fx.spawn",
)
shader = require(
    "shaders/room_composite.gdshader",
    "completion_reveal",
    "film_grain_strength",
    "subject_lift",
    "runtime_scale",
)
preloader = require(
    "scripts/app/asset_preloader.gd",
    "MAX_QUEUED",
    "load_threaded_request",
    "load_threaded_get",
    "_prune_finished_failures",
)
adaptive = require(
    "scripts/app/adaptive_performance.gd",
    "MEMORY_SOFT_MB",
    '"frame-pressure"',
    '"sustained-pressure"',
    '"recovery"',
)
audio = require(
    "scripts/audio_director.gd",
    "_last_filter_hz",
    "_last_reverb_wet",
    "MIN_FILTER_HZ",
    "MAX_FILTER_HZ",
)
main = require(
    "scripts/main.gd",
    "SettingsCardScript",
    "settings_dirty",
    "save_timer.stop()",
    "NOTIFICATION_WM_GO_BACK_REQUEST",
    "_handle_back_request",
    "room.free()",
    "audio_director.free()",
    "ChapterCardScript",
    "CompletionCardScript",
)
settings = require(
    "scripts/ui/settings_card.gd",
    "OBRAZ I RUCH",
    "DŹWIĘK I DOTYK",
    "brak stroboskopu",
    "quality_cycle_requested",
)
hud = require(
    "scripts/ui/app_hud.gd",
    "set_painting",
    "update_discovery",
    "update_act",
    "get_display_safe_area",
    "tylko muzyka",
)
require("scripts/ui/chapter_card.gd", "Zacznij odkrywać", "99% OTWIERA DRZWI")
require("scripts/ui/completion_card.gd", "SZUM 0% · MUZYKA 100%", "Zostań i słuchaj")

memory = require("tools/memory_budget.py", "stdlib-webp", "MAX_CURRENT_PLUS_NEXT")
if "PIL" in memory or "pillow" in memory.lower():
    failures.append("memory budget must remain stdlib-only")
for path in ("validate.sh", ".github/workflows/ci.yml"):
    require(path, "python3 tools/memory_budget.py", "python3 tests/production_polish_contract.py")

if len(main.splitlines()) > 950:
    failures.append(f"main controller grew above 950 lines: {len(main.splitlines())}")
if len(stage.splitlines()) > 560:
    failures.append(f"room stage grew above 560 lines: {len(stage.splitlines())}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_PRODUCTION_POLISH=FAIL count={len(failures)}")

print(
    "SYNESTHESIA_PRODUCTION_POLISH=PASS "
    "persistence=png-mask-v2 adaptive=on preload=consumed "
    "ux=focus+chapter+completion+settings+mobile-back"
)
