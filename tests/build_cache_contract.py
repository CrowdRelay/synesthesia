#!/usr/bin/env python3
"""Keep production Web builds cached in CI and impossible in Netlify/deploy."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []
web = (ROOT / "scripts/build-web-preview.sh").read_text()
deploy = (ROOT / ".github/workflows/deploy-web.yml").read_text()
ci = (ROOT / ".github/workflows/ci.yml").read_text()
netlify = (ROOT / "netlify.toml").read_text()

for token in (
    "SYNESTHESIA_GODOT_EDITOR_CACHE=HIT",
    "WEB_TEMPLATE_NAMES=(web_dlink_nothreads_debug.zip web_dlink_nothreads_release.zip)",
    "verify_web_template_manifest_at",
    "write_web_template_manifest",
    'CACHE_TEMPLATE_DIR="${SYNESTHESIA_WEB_TEMPLATE_CACHE_DIR:-$CACHE_DIR/web-templates/$GODOT_RELEASE_VERSION}"',
    "SYNESTHESIA_GODOT_TEMPLATE_INSTALL=PASS",
    'RUST_WEB_REQUIRED="${SYNESTHESIA_RUST_WEB_REQUIRED:-1}"',
):
    if token not in web:
        failures.append(f"Web builder cache/fallback contract missing: {token}")

for token in (
    "Cache verified Godot and Web inputs",
    ".cache/godot-${{ env.GODOT_VERSION }}/editor.zip",
    "web_dlink_nothreads_release.zip",
    "Build production Web artifact once",
    'SYNESTHESIA_RUST_WEB_REQUIRED: "0"',
    'SYNESTHESIA_SKIP_SOURCE_VALIDATION: "1"',
):
    if token not in ci:
        failures.append(f"CI Web cache/build contract missing: {token}")

for forbidden in (
    "Cache Cargo dependency sources",
    "rustup toolchain install",
    "cargo build",
    "cargo ndk",
    "emsdk",
    "native/target",
    "rust-artifacts",
    "templates.tpz",
    'SYNESTHESIA_RUST_WEB_REQUIRED: "1"',
    "build-web-preview.sh",
    "actions/checkout@",
):
    if forbidden in deploy:
        failures.append(f"deploy promotion contains avoidable build work: {forbidden}")

for token in (
    "cargo +1.97.1 test --manifest-path native/Cargo.toml --package synesthesia-core",
    "./scripts/build-rust-native.sh host",
    'GODOT_BIN="${GODOT_BIN}" ./validate.sh',
):
    if token not in ci:
        failures.append(f"CI must retain Rust/Godot proof before Web promotion: {token}")

if 'ignore = "exit 0"' not in netlify:
    failures.append("Netlify Git builds must fail closed to ignored")
for forbidden in ("command =", "[[plugins]]", "synesthesia-build-cache", "SYNESTHESIA_NETLIFY_FAST"):
    if forbidden in netlify:
        failures.append(f"Netlify must be publish-only, found: {forbidden}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_BUILD_CACHE=FAIL count={len(failures)}")

print("SYNESTHESIA_BUILD_CACHE=PASS build=ci-once cache=godot-web deploy=promotion-only netlify=zero-build")
