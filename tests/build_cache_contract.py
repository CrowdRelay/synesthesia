#!/usr/bin/env python3
"""Keep production Web builds cheap in GitHub and impossible in Netlify."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []
web = (ROOT / "scripts/build-web-preview.sh").read_text()
workflow = (ROOT / ".github/workflows/deploy-web.yml").read_text()
ci = (ROOT / ".github/workflows/ci.yml").read_text()
netlify = (ROOT / "netlify.toml").read_text()

for token in (
    "SYNESTHESIA_GODOT_EDITOR_CACHE=HIT",
    "WEB_TEMPLATE_NAMES=(web_dlink_nothreads_debug.zip web_dlink_nothreads_release.zip)",
    "verify_web_template_manifest_at",
    "write_web_template_manifest",
    'CACHE_TEMPLATE_DIR="${SYNESTHESIA_WEB_TEMPLATE_CACHE_DIR:-$CACHE_DIR/web-templates/$GODOT_RELEASE_VERSION}"',
    "install_web_templates_for_godot",
    "SYNESTHESIA_GODOT_TEMPLATE_INSTALL=PASS",
    'RUST_WEB_REQUIRED="${SYNESTHESIA_RUST_WEB_REQUIRED:-1}"',
):
    if token not in web:
        failures.append(f"Web builder cache/fallback contract missing: {token}")

for token in (
    "Cache verified Godot Web inputs",
    ".cache/godot-4.7.1-stable/editor.zip",
    ".cache/godot-4.7.1-stable/web-templates/4.7.1.stable/.synesthesia-web-templates.sha256",
    ".cache/godot-4.7.1-stable/web-templates/4.7.1.stable/web_dlink_nothreads_release.zip",
    "synesthesia-godot-web-4.7.1-v4",
    'SYNESTHESIA_RUST_WEB_REQUIRED: "0"',
    'SYNESTHESIA_SKIP_SOURCE_VALIDATION:',
):
    if token not in workflow:
        failures.append(f"GitHub Web workflow cache/fallback missing: {token}")

# The production Web workflow must not spend time compiling Rust or persisting
# heavyweight toolchains. Native/core Rust is already a required CI gate.
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
):
    if forbidden in workflow:
        failures.append(f"GitHub production Web workflow contains avoidable heavyweight work: {forbidden}")

for token in (
    "cargo +1.97.1 test --manifest-path native/Cargo.toml --package synesthesia-core",
    "./scripts/build-rust-native.sh host",
    "GODOT_BIN=\"${GODOT_BIN}\" ./validate.sh",
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

print(
    "SYNESTHESIA_BUILD_CACHE=PASS "
    "github=godot-only+selected-template-cache rust=ci-only netlify=zero-build"
)
