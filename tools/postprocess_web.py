#!/usr/bin/env python3
"""Post-process the Godot Web export for safe caching and installable preview."""
from __future__ import annotations

import hashlib
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
font_preload_tags = [
    '<link rel="preload" href="/fonts/SynesthesiaTitle.ttf" as="font" type="font/ttf" crossorigin>',
    '<link rel="preload" href="/fonts/SynesthesiaDisplay.ttf" as="font" type="font/ttf" crossorigin>',
]
boot_style_tag = '<link rel="stylesheet" href="/boot-shell.css">'
boot_script_tag = '<script src="/boot-shell.js"></script>'
register_tag = '<script src="/register-sw.js" defer></script>'
boot_markup = '''<div id="synesthesia-boot" role="status" aria-label="Ładowanie Synesthesii">
  <h1 class="synesthesia-boot__title">SYNESTHESIA</h1>
  <div class="synesthesia-boot__sub">VIRYA · ECHOES OF THE MODERN MIND</div>
  <div class="synesthesia-boot__door" aria-hidden="true">
    <video class="synesthesia-boot__eye-art" id="synesthesia-boot-eye" muted loop playsinline preload="none" poster="/menu-eye-poster.webp" tabindex="-1"></video>
  </div>
  <div class="synesthesia-boot__tagline">SZUKAJ · DOTKNIJ · ODSZUM</div>
  <div class="synesthesia-boot__render" id="synesthesia-boot-status">URUCHAMIAM DOŚWIADCZENIE</div>
  <button class="synesthesia-boot__retry" id="synesthesia-boot-retry" type="button">Wyczyść cache i uruchom ponownie</button>
</div>'''
if manifest_tag not in html:
    html = html.replace("</head>", f"  {manifest_tag}\n</head>")
if icon_tag not in html:
    html = html.replace("</head>", f"  {icon_tag}\n  {apple_icon_tag}\n</head>")
for preload_tag in font_preload_tags:
    if preload_tag not in html:
        html = html.replace("</head>", f"  {preload_tag}\n</head>")
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
    "description": "VIRYA Synesthesia V2 — interaktywny album, mikro-zagadki i reaktywny Sygnał.",
    "id": "/",
    "start_url": "/",
    "scope": "/",
    "display": "fullscreen",
    "orientation": "portrait",
    "background_color": "#030509",
    "theme_color": "#e73535",
    "lang": "pl",
    "categories": ["music", "entertainment", "games"],
    "icons": [
        {"src": "/icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any"},
        {"src": "/icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any maskable"},
        {"src": "/icon.svg", "sizes": "any", "type": "image/svg+xml", "purpose": "any"},
    ],
}
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, separators=(",", ":")))

static_shell_js = {"service-worker.js", "register-sw.js", "boot-shell.js"}
runtime_files = sorted(
    path for path in BUILD.iterdir()
    if path.is_file()
    and (
        path.suffix.lower() in {".pck", ".wasm"}
        or (path.suffix.lower() == ".js" and path.name not in static_shell_js)
    )
)
if not runtime_files:
    raise SystemExit("missing Web runtime files for cache fingerprint")

# The cache namespace represents the whole deployed surface, not only the engine
# runtime. Otherwise a new boot shell/icon/header can be served from the previous
# generation even when CI deployed the right files.
fingerprint_files = sorted(
    (path for path in BUILD.rglob("*") if path.is_file() and path.name != "asset-report.txt"),
    key=lambda path: path.relative_to(BUILD).as_posix(),
)
deploy_hash = hashlib.sha256()
deploy_hash.update(VERSION.encode())
for path in fingerprint_files:
    deploy_hash.update(path.relative_to(BUILD).as_posix().encode())
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            deploy_hash.update(chunk)
cache_id = f"{VERSION}-{deploy_hash.hexdigest()[:12]}"

for relative_path in ("service-worker.js", "boot-shell.js"):
    target = BUILD / relative_path
    source = target.read_text()
    if "__SYNESTHESIA_CACHE_ID__" not in source:
        raise SystemExit(f"missing cache id placeholder in {relative_path}")
    target.write_text(source.replace("__SYNESTHESIA_CACHE_ID__", cache_id))

sizes = []
for path in sorted(BUILD.rglob("*")):
    if path.is_file():
        sizes.append((path.stat().st_size, path.relative_to(BUILD).as_posix()))
report = BUILD / "asset-report.txt"
report.write_text("\n".join(f"{size}\t{name}" for size, name in sizes) + "\n")
print(
    f"SYNESTHESIA_WEB_POSTPROCESS=PASS version={VERSION} cache={cache_id} "
    f"runtime_files={len(runtime_files)} fingerprint_files={len(fingerprint_files)} files={len(sizes)}"
)
