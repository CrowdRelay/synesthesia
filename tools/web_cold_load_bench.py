#!/usr/bin/env python3
"""LOCAL-ONLY web cold/warm load benchmark for build/web (untracked).

Serves the built artifact, drives headless Chromium through a real cold load
(empty cache, fresh context) and a warm reload, and reports milestone timings
from PerformanceResourceTiming plus the game's own boot-shell events.
"""
from __future__ import annotations

import http.server
import json
import functools
import pathlib
import socketserver
import sys
import time

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parents[1]
BUILD = ROOT / "build" / "web"
PORT = 8123
URL = f"http://127.0.0.1:{PORT}/?virya_e2e=1&source=synthetic-e2e"


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(BUILD), **kwargs)

    def log_message(self, *args):  # silence
        pass

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()


MILESTONES_JS = """
() => {
  const nav = performance.getEntriesByType('navigation')[0] || {};
  const res = performance.getEntriesByType('resource').map(r => ({
    name: r.name.split('/').pop(), bytes: r.encodedBodySize || r.transferSize,
    decoded: r.decodedBodySize, dur: Math.round(r.duration), start: Math.round(r.startTime),
  })).sort((a,b) => b.start - a.start);
  const interactive = window.__synesthesiaInteractiveMs ?? null;
  return {
    domInteractive: Math.round(nav.domInteractive || 0),
    domComplete: Math.round(nav.domComplete || 0),
    loadEventEnd: Math.round(nav.loadEventEnd || 0),
    resources: res.slice(0, 12),
    totalTransferBytes: performance.getEntriesByType('resource').reduce((s,r)=>s+(r.encodedBodySize||r.transferSize||0),0),
    synesthesiaInteractiveMs: interactive,
  };
}
"""


def run_case(browser, label: str, warm: bool) -> dict:
    context = browser.new_context(
        viewport={"width": 412, "height": 915}, device_scale_factor=2,
        is_mobile=True, has_touch=True,
    )
    page = context.new_page()
    console_errors: list[str] = []
    page.on("console", lambda m: console_errors.append(m.text) if m.type == "error" else None)
    page.add_init_script("""
      window.__viryaSynE2EEvents=[];
      window.addEventListener('synesthesia:e2e-state', e => window.__viryaSynE2EEvents.push(e.detail));
      window.__synesthesiaInteractiveMs = null;
      window.addEventListener('synesthesia:interactive', () => {
        window.__synesthesiaInteractiveMs = Math.round(performance.now());
      }, { once: true });
    """)
    marks: dict[str, float] = {}
    t_start = time.monotonic()
    page.goto(URL, wait_until="commit", timeout=60_000)

    # engine canvas appears once the runtime boots
    page.wait_for_selector("canvas", state="attached", timeout=120_000)
    marks["canvas_attached_ms"] = round((time.monotonic() - t_start) * 1000)

    deadline = time.monotonic() + 180
    menu_seen_at = None
    while time.monotonic() < deadline:
        seen = page.evaluate(
            "() => (window.__viryaSynE2EEvents || []).some(e => e.kind === 'menu')")
        if seen:
            menu_seen_at = (time.monotonic() - t_start) * 1000
            break
        page.wait_for_timeout(100)
    marks["menu_interactive_ms"] = round(menu_seen_at) if menu_seen_at else -1
    perf = page.evaluate(MILESTONES_JS)
    result = {"label": label, "marks": marks, "perf": perf,
              "console_errors": console_errors[:8]}
    context.close()
    return result


def main() -> int:
    with socketserver.TCPServer(("127.0.0.1", PORT), Handler) as httpd:
        httpd.allow_reuse_address = True
        import threading
        t = threading.Thread(target=httpd.serve_forever, daemon=True)
        t.start()

        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            results = []
            for i in range(3):
                results.append(run_case(browser, f"cold-{i+1}", warm=False))
            results.append(run_case(browser, "warm-reload (fresh ctx, browser cache)", warm=True))
            browser.close()
        httpd.shutdown()
    for r in results:
        print(json.dumps(r, indent=1)[:1400])
        print("---")
    return 0


if __name__ == "__main__":
    sys.exit(main())
