#!/usr/bin/env python3
"""Producer/consumer contract for the semantic E2E target feed.

Dynamic rooms (Party Time membranes) mutate their remaining hint targets the
moment one is confirmed, and then keep moving them under physics. Two separate
defects made the full-game Web E2E fail on such a room, and both are the kind
that come back silently:

* Producer: the periodic republish was gated on the *visual assist overlay*
  being active, so with hints off the semantic feed only emitted at room
  configure time and on a confirmed special event. Remaining targets drifted for
  seconds with nothing republished.
* Consumer: the driver read one room snapshot and then replayed up to four
  gestures from it, aiming at coordinates that had already moved.

The fix is state synchronisation on both sides, never a sleep or a room-specific
retry, so this contract also refuses the usual regressions back into timing
hacks.
"""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def main() -> int:
    failures: list[str] = []

    stage = read("scripts/render/room_stage.gd")
    probe = read("scripts/app/web_e2e_probe.gd")
    driver = read("tests/e2e/full_game_web.py")

    # Producer: the republish cadence must not depend only on the assist overlay.
    flow = read("scripts/render/room_interaction_flow.gd")
    process_body = stage.split("func _process(", 1)[1].split("\nfunc ", 1)[0]
    if "tick_target_republish" not in process_body:
        failures.append("room_stage._process must drive the semantic republish cadence")
    cadence = flow.split("func tick_target_republish(", 1)
    if len(cadence) != 2:
        failures.append("the semantic republish cadence must be an explicit named step")
    else:
        body = cadence[1].split("\nfunc ", 1)[0]
        if "WebE2EProbe.enabled()" not in body or "_refresh_hint_targets()" not in body:
            failures.append(
                "semantic republish must also run while the E2E probe observes, not only "
                "while the visual assist overlay is active"
            )

    # Producer: dynamic mechanics must republish immediately on a confirmed event.
    special = flow.split("func _on_runtime_special(", 1)[1].split("\nfunc ", 1)[0]
    if "_refresh_hint_targets()" not in special:
        failures.append(
            "a confirmed special interaction must republish semantic targets before the "
            "next consumer gesture"
        )

    # Producer: the enabled() flag is resolved once, never per frame.
    if "_enabled_cache" not in probe:
        failures.append(
            "WebE2EProbe.enabled() must cache its query-flag lookup; it sits on the "
            "per-frame publish path and each call is a synchronous JS round trip"
        )

    # Consumer: the completion detector reads the event discriminator `kind`.
    if "x.kind === 'completion'" not in driver:
        failures.append("completion detection must use the `kind` discriminator")
    if re.search(r"\.phase\s*===", driver):
        failures.append("the retired `phase` discriminator must not come back")

    # Consumer: gestures act on freshly re-read state, not one stale snapshot.
    complete_room = driver.split("def complete_room(", 1)[1].split("\ndef ", 1)[0]
    if "for target in targets[:4]" in complete_room:
        failures.append(
            "complete_room must not replay a batch of gestures from a single "
            "pre-gesture snapshot; dynamic targets move between gestures"
        )
    gesture_loop = complete_room.split("for slot in range(", 1)
    if len(gesture_loop) != 2 or 'state(page, "room")' not in gesture_loop[1].split("reveal_sweep")[0]:
        failures.append(
            "complete_room must re-read the freshest published room state before each "
            "gesture"
        )
    # A fixed gesture budget starves reveal-driven rooms that publish a single
    # target: each extra gesture costs the deadline roughly a second, and the
    # reveal sweep is what actually advances their coverage.
    if "for slot in range(4)" in complete_room:
        failures.append(
            "the per-iteration gesture budget must follow the published target count, "
            "not a fixed four"
        )
    if "budget = min(4, len(" not in complete_room:
        failures.append("complete_room must bound its gesture budget by the published targets")

    # Consumer: no room-specific special-casing, and no sleep-based stabilisation.
    for room_name in ("party-time", "party_time", "wave-of-uncertainty"):
        if room_name in driver:
            failures.append(f"the driver must stay room-agnostic: found {room_name!r}")
    if re.search(r"time\.sleep\(", driver):
        failures.append("the driver must synchronise on observable state, not time.sleep")

    if failures:
        for failure in failures:
            print(f"E2E_SEMANTIC_FEED_CONTRACT=FAIL {failure}", file=sys.stderr)
        return 1
    print(
        "E2E_SEMANTIC_FEED_CONTRACT=PASS producer=cadence+confirmed-event "
        "consumer=fresh-per-gesture discriminator=kind sleeps=none"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
