#!/usr/bin/env python3
"""Post-process the Godot Web export for safe caching and installable preview."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build" / "web"
VERSION = (ROOT / "VERSION").read_text().strip()

index_path = BUILD / "index.html"
if not index_path.is_file():
    raise SystemExit("missing build/web/index.html")

html = index_path.read_text()
manifest_tag = '<link rel="manifest" href="/manifest.webmanifest">'
register_tag = '<script src="/register-sw.js" defer></script>'
if manifest_tag not in html:
    html = html.replace("</head>", f"  {manifest_tag}\n</head>")
if register_tag not in html:
    html = html.replace("</body>", f"  {register_tag}\n</body>")
index_path.write_text(html)

manifest_path = BUILD / "manifest.webmanifest"
manifest = {
    "name": "VIRYA: Synestezja",
    "short_name": "Synestezja",
    "description": "Interaktywne doświadczenie albumu VIRYA.",
    "id": "/",
    "start_url": "/",
    "scope": "/",
    "display": "fullscreen",
    "orientation": "portrait",
    "background_color": "#080c14",
    "theme_color": "#111a2a",
    "lang": "pl",
    "categories": ["music", "entertainment", "games"],
    "icons": [
        {
            "src": "/icon.svg",
            "sizes": "any",
            "type": "image/svg+xml",
            "purpose": "any maskable",
        }
    ],
}
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, separators=(",", ":")))

service_worker_path = BUILD / "service-worker.js"
service_worker = service_worker_path.read_text()
service_worker = service_worker.replace("__SYNESTHESIA_VERSION__", VERSION)
service_worker_path.write_text(service_worker)

sizes = []
for path in sorted(BUILD.rglob("*")):
    if path.is_file():
        sizes.append((path.stat().st_size, path.relative_to(BUILD).as_posix()))
report = BUILD / "asset-report.txt"
report.write_text("\n".join(f"{size}\t{name}" for size, name in sizes) + "\n")
print(f"SYNESTHESIA_WEB_POSTPROCESS=PASS version={VERSION} files={len(sizes)}")
