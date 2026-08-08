#!/usr/bin/env python3
"""Godot runtime template discovery uses the engine's real per-user data dir."""
from pathlib import Path
import os
import subprocess

ROOT = Path(__file__).resolve().parents[1]
helper = ROOT / "scripts/godot-runtime-data-dir.sh"
failures: list[str] = []

if not helper.is_file():
    failures.append("scripts/godot-runtime-data-dir.sh missing")
else:
    env = os.environ.copy()
    env["HOME"] = "/opt/buildhome"
    linux = subprocess.check_output([str(helper), "Linux"], env=env, text=True).strip()
    if linux != "/opt/buildhome/.local/share/godot":
        failures.append(f"Netlify/Linux Godot data dir drift: {linux}")

    env["HOME"] = "/Users/synesthesia"
    mac = subprocess.check_output([str(helper), "Darwin"], env=env, text=True).strip()
    if mac != "/Users/synesthesia/Library/Application Support/Godot":
        failures.append(f"macOS Godot data dir drift: {mac}")

for rel in ("scripts/build-web-preview.sh", "scripts/build-android-apk.sh", "scripts/build-linux-release.sh"):
    text = (ROOT / rel).read_text()
    if "godot-runtime-data-dir.sh" not in text:
        failures.append(f"{rel} bypasses canonical Godot runtime data-dir helper")

web = (ROOT / "scripts/build-web-preview.sh").read_text()
for token in (
    'CACHE_TEMPLATE_DIR="${SYNESTHESIA_WEB_TEMPLATE_CACHE_DIR:-$CACHE_DIR/web-templates/$GODOT_RELEASE_VERSION}"',
    'RUNTIME_TEMPLATE_DIR="$GODOT_RUNTIME_DATA_DIR/export_templates/$GODOT_RELEASE_VERSION"',
    "install_web_templates_for_godot",
    "SYNESTHESIA_GODOT_TEMPLATE_INSTALL=PASS",
):
    if token not in web:
        failures.append(f"Web runtime template install contract missing: {token}")
for forbidden in ("export XDG_DATA_HOME=", "SYNESTHESIA_XDG_DATA_HOME", 'GODOT_DATA_DIR="${GODOT_DATA_DIR'):
    if forbidden in web:
        failures.append(f"Web builder must not rely on shell-only Godot path relocation: {forbidden}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_GODOT_RUNTIME_PATH=FAIL count={len(failures)}")

print("SYNESTHESIA_GODOT_RUNTIME_PATH=PASS linux=home-local-share macos=application-support cache=separate")
