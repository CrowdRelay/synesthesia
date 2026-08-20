#!/usr/bin/env python3
"""Keep mobile haptics semantic, bounded and room-aware."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
haptics = (ROOT / "scripts/haptics.gd").read_text(errors="replace")
bridge = (ROOT / "scripts/app/player_feedback_bridge.gd").read_text(errors="replace")
failures: list[str] = []

for token in (
    "var _last_confirmation_ms: int = 0",
    "var _semantic_quiet_until_ms: int = 0",
    "var minimum_interval: int = 62 if calm_mode else 44",
    "var amount := pow(clampf(strength, 0.0, 1.0), 1.18)",
    "func _style_gain() -> float:",
    '"uncertainty", "waves": return 0.78',
    '"technophobia": return 0.92',
    "_begin_semantic_pattern(118)",
    "generation == _pulse_generation",
):
    if token not in haptics:
        failures.append(f"haptics.gd: missing semantic/bounded guard {token}")

if "var interval := 76 if calm_mode else 52" in haptics:
    failures.append("legacy high-frequency motion buzz cadence returned")
if "Input.vibrate_handheld(42 if calm_mode else 58" in haptics:
    failures.append("legacy long duel buzz returned")

for token in (
    "_haptics.confirmation(felt_strength)",
    '_haptics.special("resonance_chain", _resonance_chain)',
    "room.interaction_motion.connect(_on_interaction_motion)",
):
    if token not in bridge:
        failures.append(f"feedback bridge lost semantic haptics routing: {token}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_WARD_HAPTICS=FAIL count={len(failures)}")

print("SYNESTHESIA_WARD_HAPTICS=PASS cadence=bounded confirmations=throttled rooms=profiled tails=generation-cancelled")
