#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

layer = (ROOT / "scripts/app/door_transition_layer.gd").read_text(errors="replace")
director = (ROOT / "scripts/app/transition_director.gd").read_text(errors="replace")

required_layer = [
    "set_door_open_mix",
    "set_approach_mix",
    "set_warp_mix",
    "set_flash_mix",
    "_draw_hinged_door",
    "draw_colored_polygon",
    "cos(angle)",
    "_draw_supersonic_tunnel",
    "streak_count",
    "camera_scale",
]
required_director = [
    "DOOR_OPEN_STREAM",
    "TELEPORT_STREAM",
    'Callable(door_layer, "set_door_open_mix")',
    'Callable(door_layer, "set_approach_mix")',
    'Callable(door_layer, "set_warp_mix")',
    'Callable(door_layer, "set_flash_mix")',
    "TRANS_EXPO",
]

for token in required_layer:
    if token not in layer:
        failures.append(f"door layer missing {token!r}")
for token in required_director:
    if token not in director:
        failures.append(f"transition director missing {token!r}")

# Regression gate: the previous transition was two rectangles sliding inward
# from the sides. It must not come back.
for forbidden in ("half_width", "Two real door leaves", "w - half_width"):
    if forbidden in layer:
        failures.append(f"sliding-panel transition resurrected {forbidden!r}")

# The transition must never animate the room itself.
for forbidden in ('tween_property(host, "scale"', 'tween_property(room', 'room.scale'):
    if forbidden in director:
        failures.append(f"transition is stretching the room: {forbidden!r}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_DOOR_TRANSITION=FAIL count={len(failures)}")

print("SYNESTHESIA_DOOR_TRANSITION=PASS door=hinged camera=supersonic warp=radial no-room-stretch")
