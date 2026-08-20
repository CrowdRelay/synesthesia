#!/usr/bin/env python3
"""Keep room affordances on the authored psychiatric-ward compositions."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

required = {
    "scripts/rooms/behaviors/party-time.gd": (
        '"point": _art_point(BALLOONS[index]) + _offset(index)',
        "var membrane_norm := (_art_point(BALLOONS[index]) + _offset(index))",
    ),
    "scripts/rooms/behaviors/unmasked.gd": (
        '"point": _art_offset_point(MASKS[index]',
        "var mask_norm := _art_offset_point(MASKS[index]",
    ),
    "scripts/rooms/behaviors/the-calling.gd": (
        '"point": _art_point(CORE_POINT)',
        '"point": _art_offset_point(NODE_START, _node_position())',
        "var art_core := _art_point(CORE_POINT)",
    ),
    "scripts/rooms/behaviors/seed-of-doubt.gd": (
        '"point": _art_point(SEED_POINT)',
        "_art_lerp_point(SEED_POINT, Vector2(0.50, 0.30), growth)",
        "var art_seed := _art_point(SEED_POINT)",
    ),
    "scripts/rooms/behaviors/hybrid.gd": (
        '"point": _art_point(OPPONENT)',
        "var art_opponent: Vector2 = _art_point(OPPONENT)",
    ),
    "scripts/rooms/behaviors/technophobia.gd": (
        '"point": _art_point(CABLE_PLUGS[index])',
        '"point": _art_point(BREAKER_TARGET)',
        '"point": _art_point(TUNER_TARGET)',
        "_px(_art_point(SCREEN_TARGETS[index]), viewport_size)",
    ),
    "scripts/rooms/behaviors/invaluable.gd": (
        '"point": _art_offset_point(MIRRORS[index]',
        "var mirror_norm: Vector2 = _art_offset_point(MIRRORS[index]",
    ),
    "scripts/rooms/behaviors/from-the-ashes.gd": (
        '"point": _art_point(CENTER)',
        "var art_center := _art_point(Vector2(0.50, 0.48))",
    ),
    "scripts/rooms/behaviors/waves.gd": (
        '"point": _art_point(SECOND)',
        "_art_lerp_point(FIRST, Vector2(0.47, 0.58), closeness)",
        "var first_norm := _art_lerp_point(FIRST",
    ),
    "scripts/rooms/behaviors/rise.gd": (
        '"point": _art_point(Vector2(0.50, 0.20))',
        '"point": _art_point(Vector2(0.50, 0.54))',
        "var art_light := _art_point(Vector2(0.50, 0.20))",
    ),
}

for rel, tokens in required.items():
    source = (ROOT / rel).read_text(errors="replace")
    for token in tokens:
        if token not in source:
            failures.append(f"{rel}: missing {token}")

base = (ROOT / "scripts/rooms/behavior_base.gd").read_text(errors="replace")
for token in (
    '"technophobia": [',
    "const ART_WARP_RADIUS: float = 0.30",
    "const MOBILE_FORGIVENESS_BONUS: float = 0.08",
    "func _art_offset_point",
    "func _art_lerp_point",
    "var weighted_offset := Vector2.ZERO",
    "var point_as_logic: Vector2 = _logic_point(point)",
    'if OS.has_feature("mobile"):',
):
    if token not in base:
        failures.append(f"behavior_base.gd: missing {token}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_WARD_INTERACTION_ALIGNMENT=FAIL count={len(failures)}")

print("SYNESTHESIA_WARD_INTERACTION_ALIGNMENT=PASS rooms=10 hints=art-space hotspots=continuous-warp mobile=forgiving technophobia=full-wall")
