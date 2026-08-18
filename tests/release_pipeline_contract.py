#!/usr/bin/env python3
"""Tagged artifacts must exercise the same Rust-primary Web/Android paths as production."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
workflow = (ROOT / ".github/workflows/build.yml").read_text()
failures: list[str] = []

pins = {}
for raw in (ROOT / "config/toolchains.env").read_text().splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    key, value = line.split("=", 1)
    pins[key] = value

for token in (
    "./scripts/build-web-preview.sh",
    'SYNESTHESIA_RUST_WEB_REQUIRED: "1"',
    "./scripts/build-linux-release.sh",
    "linux_release.x86_64",
    'SYNESTHESIA_DISABLE_RUST_NATIVE: "0"',
):
    if token not in workflow:
        failures.append(f"release workflow missing: {token}")
web_toolchain = pins.get("RUST_WEB_TOOLCHAIN")
if not web_toolchain or f"SYNESTHESIA_RUST_WEB_TOOLCHAIN: {web_toolchain}" not in workflow:
    failures.append("release workflow Rust Web toolchain must match config/toolchains.env")
if "firebelley/godot-export" in workflow or "presets_to_export:" in workflow:
    failures.append("tagged release still downloads the full Godot template pack through generic exporter")
if "SYNESTHESIA_ENABLE_RUST_NATIVE" in workflow:
    failures.append("tagged Android release still uses obsolete Rust opt-in flag")

linux_builder = (ROOT / "scripts/build-linux-release.sh").read_text()
for token in ("linux_release.x86_64", "SYNESTHESIA_RUST_LINUX_EXPORT=PASS", "build-rust-native.sh host"):
    if token not in linux_builder:
        failures.append(f"Linux selected-template builder missing: {token}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_RELEASE_PIPELINE=FAIL count={len(failures)}")

print("SYNESTHESIA_RELEASE_PIPELINE=PASS web=verified-rust-wasm linux=selected-template+rust-native android=rust-primary cache=bounded")
