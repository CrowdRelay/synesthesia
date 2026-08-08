#!/usr/bin/env python3
"""Bound build caches to reusable inputs, never compiled target trees."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []
web = (ROOT / "scripts/build-web-preview.sh").read_text()
plugin = (ROOT / "netlify/plugins/synesthesia-build-cache/index.js").read_text()
netlify = (ROOT / "netlify.toml").read_text()

for token in (
    "SYNESTHESIA_GODOT_EDITOR_CACHE=HIT",
    "WEB_TEMPLATE_NAMES=(web_dlink_nothreads_debug.zip web_dlink_nothreads_release.zip)",
    "verify_web_template_manifest",
    "write_web_template_manifest",
    'unzip -p "$template_archive" "templates/$template_name"',
    'mkdir -p "$CACHE_DIR" "$TEMPLATE_DIR"',
    'rm -f "$template_archive"',
    "tools/web_bundle_budget.py",
):
    if token not in web:
        failures.append(f"Web build cache contract missing: {token}")

for token in ("editor.zip", "web_dlink_nothreads_debug.zip", "web_dlink_nothreads_release.zip", ".synesthesia-web-templates.sha256"):
    if token not in plugin:
        failures.append(f"Netlify cache missing selected input: {token}")
for forbidden in ("native/target", "templates.tpz", "emsdk"):
    if forbidden in plugin:
        failures.append(f"Netlify cache must not retain heavy tree: {forbidden}")
for token in ("onEnd", "verifiedEditor", "verifiedTemplates", "SYNESTHESIA_NETLIFY_CACHE=CHECKPOINT"):
    if token not in plugin:
        failures.append(f"Netlify verified checkpoint cache missing: {token}")
if './netlify/plugins/synesthesia-build-cache' not in netlify:
    failures.append("local Netlify bounded-cache plugin is not enabled")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_BUILD_CACHE=FAIL count={len(failures)}")

print("SYNESTHESIA_BUILD_CACHE=PASS netlify=verified-checkpoint+2-web-templates target=uncached full-template-archive=ephemeral")
