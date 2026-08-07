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
icon_tag = '<link rel="icon" href="/icon.svg" type="image/svg+xml">'
apple_icon_tag = '<link rel="apple-touch-icon" href="/icon-192.png">'
boot_style_tag = '<link rel="stylesheet" href="/boot-shell.css">'
boot_script_tag = '<script src="/boot-shell.js"></script>'
register_tag = '<script src="/register-sw.js" defer></script>'
boot_markup = '''<div id="synesthesia-boot" role="status" aria-label="Ładowanie Synesthesii">
  <h1 class="synesthesia-boot__title">SYNESTHESIA</h1>
  <div class="synesthesia-boot__sub">VIRYA · ECHOES OF THE MODERN MIND</div>
  <div class="synesthesia-boot__door" aria-hidden="true">
    <div class="synesthesia-boot__eye">
      <div class="synesthesia-boot__brain"></div>
      <i class="synesthesia-boot__node synesthesia-boot__node--a"></i>
      <i class="synesthesia-boot__node synesthesia-boot__node--b"></i>
      <i class="synesthesia-boot__node synesthesia-boot__node--c"></i>
      <i class="synesthesia-boot__node synesthesia-boot__node--d"></i>
    </div>
  </div>
  <div class="synesthesia-boot__render">ADAPTIVE NATIVE</div>
</div>'''
if manifest_tag not in html:
    html = html.replace("</head>", f"  {manifest_tag}\n</head>")
if icon_tag not in html:
    html = html.replace("</head>", f"  {icon_tag}\n  {apple_icon_tag}\n</head>")
if boot_style_tag not in html:
    html = html.replace("</head>", f"  {boot_style_tag}\n  {boot_script_tag}\n</head>")
if 'id="synesthesia-boot"' not in html:
    html = html.replace("<body>", f"<body>\n{boot_markup}", 1)
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
        {"src": "/icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any"},
        {"src": "/icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any maskable"},
        {"src": "/icon.svg", "sizes": "any", "type": "image/svg+xml", "purpose": "any"},
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
