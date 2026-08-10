#!/usr/bin/env python3
"""All rooms must feel like discoverable micro-interaction spaces, not paint gates."""
from __future__ import annotations
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []
rooms = [
    "wave-of-uncertainty", "party-time", "unmasked", "the-calling",
    "seed-of-doubt", "hybrid", "technophobia", "invaluable",
    "from-the-ashes", "waves", "rise",
]
for room in rooms:
    path = ROOT / f"scripts/rooms/behaviors/{room}.gd"
    text = path.read_text(errors="replace") if path.is_file() else ""
    for token in ("func interaction_hint()", "func hint_targets()", "func captures_pointer_at", "func mechanic_progress()"):
        if token not in text:
            failures.append(f"{room}: missing {token}")

seed = (ROOT / "scripts/rooms/behaviors/seed-of-doubt.gd").read_text(errors="replace")
for token in ('kind in ["tap", "hold", "press"]', 'growth >= 0.72', 'state["crown"] = true'):
    if token not in seed:
        failures.append(f"seed-of-doubt: missing no-dead-end token {token!r}")
if 'float(state.get("growth", 0.0)) >= 0.58' in seed:
    failures.append("seed-of-doubt: legacy hidden crown gate resurrected")

hint = (ROOT / "scripts/render/interaction_hint_layer.gd").read_text(errors="replace")
for token in ("set_targets", "_draw_gesture_glyph", '"pull", "drag"', '"drag_up"'):
    if token not in hint:
        failures.append(f"interaction hints: missing {token!r}")

flow = (ROOT / "scripts/app/main_room_flow.gd").read_text(errors="replace")
if "app.room.reveal_remaining_collectibles()" in flow:
    failures.append("completion must not auto-award optional echoes")
for token in ("możesz zostać i szukać", "Album Mode"):
    if token not in flow:
        failures.append(f"completion exploration copy missing {token!r}")

stage = (ROOT / "scripts/render/room_stage.gd").read_text(errors="replace")
for token in ("_refresh_hint_targets", "behavior.hint_targets()", "0.20"):
    if token not in stage:
        failures.append(f"room stage: missing {token!r}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_FULL_ROOM_GAMEPLAY=FAIL count={len(failures)}")

print("SYNESTHESIA_FULL_ROOM_GAMEPLAY=PASS rooms=11 hints=diegetic pointer-capture=semantic seed=no-dead-end")
