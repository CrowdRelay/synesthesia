#!/usr/bin/env python3
"""Bound build caches to reusable verified inputs, never runtime/compiled trees."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []
web = (ROOT / "scripts/build-web-preview.sh").read_text()
plugin = (ROOT / "netlify/plugins/synesthesia-build-cache/index.js").read_text()
netlify = (ROOT / "netlify.toml").read_text()

for token in (
    "SYNESTHESIA_GODOT_EDITOR_CACHE=HIT",
    "WEB_TEMPLATE_NAMES=(web_dlink_nothreads_debug.zip web_dlink_nothreads_release.zip)",
    "verify_web_template_manifest_at",
    "write_web_template_manifest",
    'unzip -p "$template_archive" "templates/$template_name"',
    'CACHE_TEMPLATE_DIR="${SYNESTHESIA_WEB_TEMPLATE_CACHE_DIR:-$CACHE_DIR/web-templates/$GODOT_RELEASE_VERSION}"',
    'GODOT_RUNTIME_DATA_DIR="$(./scripts/godot-runtime-data-dir.sh)"',
    "install_web_templates_for_godot",
    "SYNESTHESIA_GODOT_TEMPLATE_INSTALL=PASS",
    'rm -f "$template_archive"',
    "tools/web_bundle_budget.py",
):
    if token not in web:
        failures.append(f"Web build cache contract missing: {token}")

for token in (
    "editor.zip",
    "web-templates",
    "web_dlink_nothreads_debug.zip",
    "web_dlink_nothreads_release.zip",
    ".synesthesia-web-templates.sha256",
):
    if token not in plugin:
        failures.append(f"Netlify cache missing selected input: {token}")
for forbidden in ("native/target", "templates.tpz", "emsdk", ".local/share/godot"):
    if forbidden in plugin:
        failures.append(f"Netlify cache must not retain heavy/runtime tree: {forbidden}")
for token in (
    "onEnd",
    "verifiedEditor",
    "verifiedTemplates",
    "verifiedTemplatesAt",
    "migrateLegacyTemplates",
    "SYNESTHESIA_NETLIFY_CACHE=MIGRATED",
    "SYNESTHESIA_NETLIFY_CACHE=CHECKPOINT",
    'path.join(cacheRoot, "web-templates", RELEASE)',
):
    if token not in plugin:
        failures.append(f"Netlify verified checkpoint cache missing: {token}")
if './netlify/plugins/synesthesia-build-cache' not in netlify:
    failures.append("local Netlify bounded-cache plugin is not enabled")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_BUILD_CACHE=FAIL count={len(failures)}")

print("SYNESTHESIA_BUILD_CACHE=PASS netlify=verified-selected-inputs runtime-install=separate target=uncached")
