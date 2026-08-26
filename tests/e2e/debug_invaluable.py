#!/usr/bin/env python3
"""LOCAL-ONLY debug driver: play to invaluable and log the full event stream."""
from __future__ import annotations

import json
import pathlib
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from full_game_web import (  # noqa: E402
    browser_path, click_rect, complete_room, perform_target, reveal_sweep,
    state, wait_state, with_e2e_query, DEFAULT_TIMEOUT_MS,
)
from playwright.sync_api import sync_playwright  # noqa: E402

URL = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8124/"
OUT = pathlib.Path("/tmp/syn_debug_invaluable.jsonl")


def main() -> int:
    executable = browser_path()
    log = OUT.open("w")
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, executable_path=executable,
                                    args=["--no-sandbox"] if executable else [])
        context = browser.new_context(viewport={"width": 390, "height": 844},
                                      device_scale_factor=1, locale="pl-PL")
        page = context.new_page()
        page.add_init_script("""
          window.__viryaSynE2EEvents=[]; window.__viryaSynGameplay=[];
          window.addEventListener('synesthesia:e2e-state', e => window.__viryaSynE2EEvents.push(e.detail));
        """)
        page.on("console", lambda m: log.write(json.dumps({"t": time.monotonic(), "console": m.type, "text": m.text[:200]}) + "\n"))
        page.goto(with_e2e_query(URL), wait_until="domcontentloaded", timeout=DEFAULT_TIMEOUT_MS)
        menu = wait_state(page, "menu")
        click_rect(page, menu, "continueRect")
        rooms_done = 0
        previous_room_id = None
        for index in range(11):
            room = wait_state(
                page, "room",
                lambda v: bool(v.get("interactionEnabled"))
                and (previous_room_id is None or str(v.get("roomId", "")) != previous_room_id),
                timeout_ms=DEFAULT_TIMEOUT_MS,
            )
            room_events = []
            completion, actual = complete_room_dbg(page, room_events, log)
            previous_room_id = actual
            rooms_done += 1
            click_rect(page, completion, "continueRect")
            for e in room_events:
                log.write(json.dumps({"t": time.monotonic(), "room": actual, **e}) + "\n")
            log.write(json.dumps({"t": time.monotonic(), "completed": actual}) + "\n")
            log.flush()
            if actual == "invaluable":
                print("reached+completed invaluable; full log at", OUT)
                break
        browser.close()
    log.close()
    return 0


def complete_room_dbg(page, room_events, log):
    """complete_room + capture every room_state published during the attempt."""
    import full_game_web as fgw
    import json as _json
    deadline = time.monotonic() + 75
    seen_room = None
    prev_completion = page.evaluate("(window.__viryaSynE2EEvents || []).filter(x => x.kind === 'completion').length")
    try:
        while time.monotonic() < deadline:
            completion = state(page, "completion")
            count = page.evaluate("(window.__viryaSynE2EEvents || []).filter(x => x.kind === 'completion').length")
            if completion is not None and count > prev_completion:
                return completion, seen_room
            room = state(page, "room")
            if room and room.get("interactionEnabled"):
                seen_room = room.get("roomId") or seen_room
                room_events.append({"phase": "published", "roomId": room.get("roomId"),
                                    "hint": room.get("hint"), "targets": room.get("targets"),
                                    "progress": room.get("progress")})
                budget = min(4, len(room.get("targets") or []))
                for slot in range(budget):
                    current = state(page, "room")
                    if not current or not current.get("interactionEnabled"):
                        break
                    targets = current.get("targets") or []
                    if not targets:
                        break
                    peer = next((t for t in targets if t.get("kind") == "target"), None)
                    target = targets[slot % len(targets)]
                    room_events.append({"phase": "gesture", "slot": slot, "kind": target.get("kind"),
                                        "point": [target.get("x"), target.get("y")]})
                    fgw.perform_target(page, current, target, peer if target is not peer else None)
                fgw.reveal_sweep(page, room)
                page.wait_for_timeout(160)
            else:
                page.wait_for_timeout(180)
    finally:
        for e in room_events[-80:]:
            log.write(_json.dumps({"t": time.monotonic(), "room": seen_room, **e}) + "\n")
        log.flush()
    raise AssertionError(f"debug: room {seen_room} did not complete")


if __name__ == "__main__":
    raise SystemExit(main())
