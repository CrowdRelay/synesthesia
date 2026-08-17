#!/usr/bin/env python3
"""The finale's Signal CTA must never become a dead end.

Connecting a finished run to Signal is the game's primary conversion path. The
button was disabled whenever the server had not confirmed completion, which
meant finishing the album while CrowdRelay was unreachable permanently removed
the only route into Signal, under a label claiming a link was still in progress.

The run is durable locally and the server path is idempotent, so an unconfirmed
completion is always a retry. The dangerous shape is an *allowlist* of failing
operations: the first version of the fix enumerated three, and missed start_run
and complete_album, which are exactly the operations that fail when the backend
is down. Restoring the CTA has to be the default so a newly added operation
cannot silently strand the finale.
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
    flow = read("scripts/app/main_reward_flow.gd")
    card = read("scripts/ui/signal_finale_card.gd")
    fallback = read("scripts/ui/signal_finale_fallback_card.gd")
    shared = read("scripts/ui/signal_cta_state.gd")

    handler = flow.split("func _on_reward_request_failed(", 1)
    if len(handler) != 2:
        failures.append("the reward failure handler is missing")
    else:
        body = handler[1].split("\nfunc ", 1)[0]
        # Only the genuinely unrelated operations may be special-cased; every
        # other failure must restore the CTA.
        if "_link_state.mark_failed(" not in body:
            failures.append("a failed Signal link must leave the finale CTA retryable")
        if re.search(r'operation in \[', body):
            failures.append(
                "the CTA must not depend on an allowlist of operations; start_run and "
                "complete_album are exactly what fail when the backend is down"
            )
        for required in ("enter_draw", "leaderboard_"):
            if required not in body:
                failures.append(f"unrelated failure path {required!r} must stay separated")

    # The latch has to outlive a panel swap: the degraded fallback card can
    # replace the finale after the failure has already been reported.
    link_state = read("scripts/app/signal_link_state.gd")
    if "SignalLinkState" not in flow or "func apply(" not in link_state:
        failures.append("the link failure must be latched outside any single panel")
    if flow.count("_link_state.apply(") < 2:
        failures.append(
            "the latched failure must be re-applied when a panel is installed, "
            "including the degraded fallback card"
        )
    if "_link_state.clear()" not in flow:
        failures.append("a server-confirmed completion must clear the latch")

    # Both finale surfaces present this CTA and must share one rule.
    if "SignalCtaState" not in card or "SignalCtaState" not in fallback:
        failures.append("both finale cards must resolve the CTA through SignalCtaState")
    resolve = shared.split("static func resolve(", 1)
    if len(resolve) != 2:
        failures.append("SignalCtaState.resolve is missing")
    else:
        body = resolve[1]
        if '"disabled": true' not in body:
            failures.append("SignalCtaState must still model the in-flight disabled state")
        # The only disabled state is "in flight and not yet retryable".
        if body.count('"disabled": true') != 1:
            failures.append("the CTA may only be disabled while a link attempt is in flight")

    for name, source in (("finale card", card), ("fallback card", fallback)):
        if "set_signal_link_retryable" not in source:
            failures.append(f"{name} must accept a retryable link state")
        if "signal_link_retry_requested" not in source:
            failures.append(f"{name} must be able to request a retry")

    if "func _retry_signal_link(" not in flow:
        failures.append("a retry must re-enter the idempotent run/completion path")

    if failures:
        for failure in failures:
            print(f"SIGNAL_FINALE_CTA_CONTRACT=FAIL {failure}", file=sys.stderr)
        return 1
    print(
        "SIGNAL_FINALE_CTA_CONTRACT=PASS default=retryable latch=survives-panel-swap "
        "rule=shared disabled=in-flight-only"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
