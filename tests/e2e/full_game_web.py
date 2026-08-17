#!/usr/bin/env python3
"""Black-box Synesthesia Web journey.

The driver reads only the same semantic hint targets rendered by the game when
?virya_e2e=1 is present. It still performs real pointer gestures on the Godot
canvas; there is no completion/state mutation hook. Production runs are marked
synthetic by the normal public run API and are excluded from business metrics.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import pathlib
import shutil
import sys
import time
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from playwright.sync_api import Page, sync_playwright

ROOM_TOTAL = 11
DEFAULT_TIMEOUT_MS = 45_000
ARTIFACT_ROOT = pathlib.Path(os.getenv("SYNESTHESIA_E2E_ARTIFACTS", "build/e2e-web"))


def with_e2e_query(url: str) -> str:
    parts = urlsplit(url)
    query = dict(parse_qsl(parts.query, keep_blank_values=True))
    query["virya_e2e"] = "1"
    query["source"] = "synthetic-e2e"
    return urlunsplit((parts.scheme, parts.netloc, parts.path, urlencode(query), parts.fragment))


def browser_path() -> str | None:
    override = os.getenv("SYNESTHESIA_E2E_BROWSER")
    if override:
        return override
    for candidate in ("google-chrome", "google-chrome-stable", "chromium", "chromium-browser"):
        found = shutil.which(candidate)
        if found:
            return found
    return None


def state(page: Page, kind: str | None = None):
    return page.evaluate(
        """kind => {
          const events = window.__viryaSynE2EEvents || [];
          for (let i=events.length-1; i>=0; --i) {
            if (!kind || events[i].kind === kind) return events[i];
          }
          return null;
        }""",
        kind,
    )


def wait_state(page: Page, kind: str, predicate=None, timeout_ms=DEFAULT_TIMEOUT_MS):
    deadline = time.monotonic() + timeout_ms / 1000
    latest = None
    while time.monotonic() < deadline:
        latest = state(page, kind)
        if latest is not None and (predicate is None or predicate(latest)):
            return latest
        page.wait_for_timeout(120)
    raise AssertionError(f"timeout waiting for e2e state kind={kind}; latest={latest!r}")


def canvas_box(page: Page):
    canvas = page.locator("canvas").first
    canvas.wait_for(state="visible", timeout=DEFAULT_TIMEOUT_MS)
    box = canvas.bounding_box()
    if not box or box["width"] < 100 or box["height"] < 100:
        raise AssertionError(f"invalid Godot canvas box: {box!r}")
    return box


def normalized_point(box, x: float, y: float):
    return box["x"] + max(0.02, min(0.98, x)) * box["width"], box["y"] + max(0.02, min(0.98, y)) * box["height"]


def click_rect(page: Page, event: dict, key: str):
    rect = event[key]
    vw = max(1.0, float(event.get("viewportWidth", 1)))
    vh = max(1.0, float(event.get("viewportHeight", 1)))
    box = canvas_box(page)
    x = box["x"] + (float(rect["x"]) + float(rect["w"]) / 2) / vw * box["width"]
    y = box["y"] + (float(rect["y"]) + float(rect["h"]) / 2) / vh * box["height"]
    page.mouse.click(x, y)


def drag(page: Page, start, end, duration_ms=500, steps=14):
    page.mouse.move(*start)
    page.mouse.down()
    for i in range(1, steps + 1):
        t = i / steps
        page.mouse.move(start[0] + (end[0] - start[0]) * t, start[1] + (end[1] - start[1]) * t)
        page.wait_for_timeout(max(5, duration_ms // steps))
    page.mouse.up()


def perform_target(page: Page, event: dict, target: dict, peer_target: dict | None):
    box = canvas_box(page)
    x, y = normalized_point(box, float(target.get("x", 0.5)), float(target.get("y", 0.5)))
    kind = str(target.get("kind", "tap"))
    if kind in ("tap", "press"):
        page.mouse.click(x, y)
    elif kind == "hold":
        page.mouse.move(x, y); page.mouse.down(); page.wait_for_timeout(950); page.mouse.up()
    elif kind in ("drag", "target"):
        if peer_target is not None:
            end = normalized_point(box, float(peer_target.get("x", 0.5)), float(peer_target.get("y", 0.5)))
        else:
            end = normalized_point(box, min(0.92, float(target.get("x", 0.5)) + 0.18), max(0.10, float(target.get("y", 0.5)) - 0.10))
        drag(page, (x, y), end, 700)
    elif kind in ("drag_up", "swipe", "release"):
        drag(page, (x, y), normalized_point(box, float(target.get("x", 0.5)), max(0.08, float(target.get("y", 0.5)) - 0.36)), 420)
    elif kind == "drag_horizontal":
        start = normalized_point(box, max(0.10, float(target.get("x", 0.5)) - 0.28), float(target.get("y", 0.5)))
        end = normalized_point(box, min(0.90, float(target.get("x", 0.5)) + 0.28), float(target.get("y", 0.5)))
        drag(page, start, end, 650)
    elif kind == "pull":
        vx, vy = float(target.get("x", 0.5)) - 0.5, float(target.get("y", 0.5)) - 0.5
        length = math.hypot(vx, vy) or 1.0
        end = normalized_point(box, float(target.get("x", 0.5)) + vx / length * 0.34, float(target.get("y", 0.5)) + vy / length * 0.34)
        drag(page, (x, y), end, 850)
    elif kind == "tune":
        page.mouse.move(x, y); page.mouse.down()
        for dx in (-0.14, 0.16, -0.10, 0.12):
            page.mouse.move(*normalized_point(box, float(target.get("x", 0.5)) + dx, float(target.get("y", 0.5))), steps=8)
        page.mouse.up()
    elif kind == "swirl":
        radius = min(box["width"], box["height"]) * 0.11
        page.mouse.move(x + radius, y); page.mouse.down()
        for i in range(1, 29):
            angle = 2 * math.pi * i / 28
            page.mouse.move(x + math.cos(angle) * radius, y + math.sin(angle) * radius)
            page.wait_for_timeout(18)
        page.mouse.up()
    else:
        page.mouse.click(x, y)


def reveal_sweep(page: Page):
    box = canvas_box(page)
    # Real brush input: a bounded serpentine sweep. Semantic mechanics still
    # have to be completed through hint targets before reveal progress can win.
    for row in (0.24, 0.40, 0.56, 0.72, 0.84):
        drag(page, normalized_point(box, 0.12, row), normalized_point(box, 0.88, row), 260, 18)


def complete_room(page: Page, expected_room: str | None, artifact_dir: pathlib.Path):
    previous_completion_count = page.evaluate("(window.__viryaSynE2EEvents || []).filter(x => x.kind === 'completion').length")
    deadline = time.monotonic() + 75
    iterations = 0
    seen_room = expected_room
    while time.monotonic() < deadline:
        completion = state(page, "completion")
        completion_count = page.evaluate("(window.__viryaSynE2EEvents || []).filter(x => x.kind === 'completion').length")
        if completion is not None and completion_count > previous_completion_count:
            return completion, seen_room
        room = state(page, "room")
        if room and room.get("interactionEnabled"):
            seen_room = room.get("roomId") or seen_room
            targets = room.get("targets") or []
            target_peer = next((t for t in targets if t.get("kind") == "target"), None)
            for target in targets[:4]:
                perform_target(page, room, target, target_peer if target is not target_peer else None)
            reveal_sweep(page)
            iterations += 1
            page.wait_for_timeout(160)
        else:
            page.wait_for_timeout(180)
        if iterations > 40:
            break
    screenshot = artifact_dir / f"failure-room-{seen_room or 'unknown'}.png"
    page.screenshot(path=str(screenshot), full_page=True)
    raise AssertionError(f"room did not complete through real gestures: {seen_room!r}; screenshot={screenshot}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--viewport", default="390x844")
    parser.add_argument("--reload-after-room", type=int, default=3)
    args = parser.parse_args()
    width, height = [int(v) for v in args.viewport.lower().split("x", 1)]
    artifact_dir = ARTIFACT_ROOT / f"{width}x{height}"
    artifact_dir.mkdir(parents=True, exist_ok=True)
    target_url = with_e2e_query(args.url)
    executable = browser_path()
    console_errors: list[str] = []
    page_errors: list[str] = []
    bad_responses: list[str] = []

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, executable_path=executable, args=["--no-sandbox"] if executable else [])
        context = browser.new_context(viewport={"width": width, "height": height}, device_scale_factor=1, locale="pl-PL")
        page = context.new_page()
        page.add_init_script("""
          window.__viryaSynE2EEvents=[]; window.__viryaSynGameplay=[];
          window.addEventListener('synesthesia:e2e-state', e => window.__viryaSynE2EEvents.push(e.detail));
          window.addEventListener('synesthesia:gameplay-metric', e => window.__viryaSynGameplay.push(e.detail));
        """)
        page.on("console", lambda msg: console_errors.append(msg.text) if msg.type == "error" else None)
        page.on("pageerror", lambda error: page_errors.append(str(error)))
        def response_guard(response):
            if response.status >= 400 and not response.url.endswith("/favicon.ico"):
                bad_responses.append(f"{response.status} {response.url}")
        page.on("response", response_guard)

        started = time.monotonic()
        response = page.goto(target_url, wait_until="domcontentloaded", timeout=DEFAULT_TIMEOUT_MS)
        if response is not None and response.status >= 400:
            raise AssertionError(f"initial navigation HTTP {response.status}")
        menu = wait_state(page, "menu", timeout_ms=DEFAULT_TIMEOUT_MS)
        menu_ready_ms = int((time.monotonic() - started) * 1000)
        if menu_ready_ms > 20_000:
            raise AssertionError(f"menu-ready regression: {menu_ready_ms}ms > 20000ms")
        page.screenshot(path=str(artifact_dir / "00-menu.png"), full_page=True)
        click_rect(page, menu, "continueRect")

        completed_rooms: list[str] = []
        for index in range(ROOM_TOTAL):
            previous_room_id = completed_rooms[-1] if completed_rooms else None
            room = wait_state(
                page,
                "room",
                lambda v: bool(v.get("interactionEnabled"))
                and (previous_room_id is None or str(v.get("roomId", "")) != previous_room_id),
                timeout_ms=DEFAULT_TIMEOUT_MS,
            )
            room_id = str(room.get("roomId", f"room-{index+1}"))
            completion, actual_room = complete_room(page, room_id, artifact_dir)
            actual_room = actual_room or room_id
            completed_rooms.append(actual_room)
            page.screenshot(path=str(artifact_dir / f"{index+1:02d}-{actual_room}-complete.png"), full_page=True)
            click_rect(page, completion, "continueRect")

            if index + 1 == args.reload_after_room and index + 1 < ROOM_TOTAL:
                # Crash/reload-style continuity check. A fresh document must
                # recover through the normal menu and resume the next room.
                page.reload(wait_until="domcontentloaded", timeout=DEFAULT_TIMEOUT_MS)
                menu = wait_state(page, "menu", timeout_ms=DEFAULT_TIMEOUT_MS)
                click_rect(page, menu, "continueRect")
                resumed = wait_state(page, "room", lambda v: bool(v.get("interactionEnabled")), timeout_ms=DEFAULT_TIMEOUT_MS)
                if resumed.get("roomId") in completed_rooms:
                    raise AssertionError(f"save/resume returned to completed room: {resumed.get('roomId')}")

        finale = wait_state(page, "finale", lambda v: bool(v.get("ready")), timeout_ms=DEFAULT_TIMEOUT_MS)
        page.screenshot(path=str(artifact_dir / "99-finale.png"), full_page=True)
        if finale.get("fallback"):
            raise AssertionError("finale reached only through fallback card")
        finale_actions = wait_state(page, "finale_actions", timeout_ms=DEFAULT_TIMEOUT_MS)
        for key in ("signalRect", "claimRect"):
            rect = finale_actions.get(key) or {}
            if float(rect.get("w", 0)) < 44 or float(rect.get("h", 0)) < 44:
                raise AssertionError(f"finale CTA is not touch-safe: {key}={rect}")
            if float(rect.get("x", -1)) < 0 or float(rect.get("y", -1)) < 0:
                raise AssertionError(f"finale CTA begins outside viewport: {key}={rect}")
            if float(rect.get("x", 0)) + float(rect.get("w", 0)) > float(finale_actions.get("viewportWidth", width)) + 1:
                raise AssertionError(f"finale CTA overflows viewport horizontally: {key}={rect}")
        if finale_actions.get("signalDisabled"):
            raise AssertionError(f"Signal conversion CTA remained disabled at finale: {finale_actions}")

        metrics = page.evaluate("window.__viryaSynGameplay || []")
        audio_events = page.evaluate("(window.__viryaSynE2EEvents || []).filter(x => x.kind === 'audio')")
        room_metrics = [m for m in metrics if m.get("metricKey") == "gameplay_room_completed_ms"]
        if len(completed_rooms) != ROOM_TOTAL:
            raise AssertionError(f"expected {ROOM_TOTAL} completed rooms across reload, got {len(completed_rooms)}")
        expected_metrics_after_reload = ROOM_TOTAL - args.reload_after_room if 0 < args.reload_after_room < ROOM_TOTAL else ROOM_TOTAL
        if len(room_metrics) != expected_metrics_after_reload:
            raise AssertionError(
                f"expected {expected_metrics_after_reload} post-reload room completion metrics, got {len(room_metrics)}"
            )
        if not any(m.get("metricKey") == "gameplay_journey_completed_ms" for m in metrics):
            raise AssertionError("journey completion telemetry event missing")
        if not audio_events:
            raise AssertionError("audio E2E state was never emitted")
        latest_audio = audio_events[-1]
        if latest_audio.get("suspended"):
            raise AssertionError(f"audio remained suspended at finale: {latest_audio}")
        if not latest_audio.get("noiseReady"):
            raise AssertionError(f"room noise asset was not ready: {latest_audio}")
        if not latest_audio.get("musicAvailable"):
            raise AssertionError(f"release excerpt was not available: {latest_audio}")
        if float(latest_audio.get("musicDb", -60.0)) <= -59.5:
            raise AssertionError(f"release excerpt stayed effectively silent: {latest_audio}")

        # Give retry-capable API requests a bounded window to settle before
        # judging the network. Synthetic run endpoints must still exercise prod.
        page.wait_for_timeout(1200)
        browser.close()

    report = {
        "url": target_url,
        "viewport": [width, height],
        "menuReadyMs": menu_ready_ms,
        "rooms": completed_rooms,
        "audioEvents": len(audio_events),
        "latestAudio": latest_audio,
        "finaleActions": finale_actions,
        "consoleErrors": console_errors,
        "pageErrors": page_errors,
        "httpErrors": bad_responses,
    }
    (artifact_dir / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    allow_api_errors = os.getenv("SYNESTHESIA_E2E_ALLOW_API_ERRORS") == "1"
    effective_http_errors = [value for value in bad_responses if not (allow_api_errors and "/v1/public/synesthesia/" in value)]
    if page_errors or console_errors or effective_http_errors:
        raise AssertionError(f"runtime diagnostics not clean: {json.dumps(report, ensure_ascii=False)}")
    print(f"SYNESTHESIA_FULL_GAME_E2E=PASS rooms={len(completed_rooms)} viewport={width}x{height} menu_ready_ms={menu_ready_ms}")
    print("SYNESTHESIA_SAVE_RESUME_E2E=PASS")
    print("SYNESTHESIA_FINALE_E2E=PASS fallback=false")
    print("SYNESTHESIA_SIGNAL_CONVERSION_E2E=PASS cta=visible+enabled synthetic_handoff=disabled")
    print(f"SYNESTHESIA_AUDIO_STATE_E2E=PASS events={len(audio_events)} music_db={float(latest_audio.get('musicDb', -60.0)):.1f}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"SYNESTHESIA_FULL_GAME_E2E=FAIL error={exc}", file=sys.stderr)
        raise
