#!/usr/bin/env python3
"""Keep Rust and GDScript gesture semantics aligned at the coarse FFI boundary."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
rust = (ROOT / "native/synesthesia-core/src/lib.rs").read_text()
gd = (ROOT / "scripts/input/interaction_router.gd").read_text()
failures: list[str] = []

for token in (
    "let displacement = state.start.distance(point);",
    "let path_distance = state.distance.max(displacement);",
    "displacement >= SWIPE_DISTANCE",
    "scribble_without_displacement_is_not_a_swipe",
):
    if token not in rust:
        failures.append(f"Rust gesture contract missing: {token}")

for token in (
    "var displacement: float = start.distance_to(current)",
    "var path_distance: float = maxf(float(state.get(\"distance\", 0.0)), displacement)",
    "displacement >= SWIPE_DISTANCE",
    "path_distance <= TAP_DISTANCE",
):
    if token not in gd:
        failures.append(f"GDScript fallback contract missing: {token}")

if "path_distance >= SWIPE_DISTANCE" in rust or "path_distance >= SWIPE_DISTANCE" in gd:
    failures.append("scribble path distance must never classify a swipe")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_GESTURE_SEMANTICS=FAIL count={len(failures)}")

print("SYNESTHESIA_GESTURE_SEMANTICS=PASS swipe=net-displacement tap=travelled-path rust-gdscript=parity")
