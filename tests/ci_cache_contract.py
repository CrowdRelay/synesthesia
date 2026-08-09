#!/usr/bin/env python3
"""CI cache stays bounded to dependencies/tool inputs; compiled targets never persist."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []
ci = (ROOT / ".github/workflows/ci.yml").read_text()
android = (ROOT / ".github/workflows/android-apk.yml").read_text()
release = (ROOT / ".github/workflows/build.yml").read_text()

for source in (ci, android):
    if "actions/cache@1bd1e32a3bdc45362d1e726936510720a7c30a57" not in source:
        failures.append("pinned actions/cache v4.2.0 missing")
    if "native/target" in source:
        failures.append("native/target must never be persisted in GitHub Actions cache")

for token in ("~/.cargo/registry", "~/.cargo/git", "editor-${{ env.GODOT_VERSION }}.zip"):
    if token not in ci:
        failures.append(f"CI bounded dependency cache missing: {token}")
for token in ("~/.cargo/bin/cargo-ndk", "android_debug.apk", "android_release.apk"):
    if token not in android:
        failures.append(f"Android bounded tool cache missing: {token}")
for token in (
    ".cache/godot-4.7.1-stable/web-templates/4.7.1.stable/.synesthesia-web-templates.sha256",
    ".cache/godot-4.7.1-stable/web-templates/4.7.1.stable/web_dlink_nothreads_debug.zip",
    ".cache/godot-4.7.1-stable/web-templates/4.7.1.stable/web_dlink_nothreads_release.zip",
):
    if token not in release:
        failures.append(f"tagged Web cache must persist bounded selected-template cache: {token}")
if 'linux_release.x86_64' not in release:
    failures.append("tagged desktop cache should retain only the selected Linux release template")
if 'firebelley/godot-export' in release:
    failures.append("tagged desktop build must not re-download the full multi-platform template pack")
if 'push:\n    branches: [main]' not in ci or '\n  pull_request:' not in ci:
    failures.append("CI should run branch pushes only for main; PR event covers feature branches")
if ci.find("./scripts/validate-source.sh") > ci.find("Cache Rust dependency sources"):
    failures.append("CI source validation must run before cache restore")
if release.find("./scripts/validate-source.sh") > release.find("Cache bounded Web build inputs"):
    failures.append("tagged Web source validation must run before cache restore")

if 'SYNESTHESIA_RUST_PROFILE=debug ./scripts/build-rust-native.sh host' not in ci:
    failures.append("CI Godot editor smoke must build the debug host GDExtension selected by linux.debug")
if 'SYNESTHESIA_RUST_PROFILE=release ./scripts/build-rust-native.sh host' in ci:
    failures.append("CI editor smoke must not build release-only host GDExtension")
if "if ! (cd native && cargo ndk --version" not in android:
    failures.append("Android CI cargo-ndk probe must run from native workspace")
if "if ! (cd native && cargo ndk --version" not in release:
    failures.append("Tagged Android cargo-ndk probe must run from native workspace")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_CI_CACHE=FAIL count={len(failures)}")

print("SYNESTHESIA_CI_CACHE=PASS cargo=sources-only godot=verified-inputs android=selected-templates target=uncached duplicate-pr-push=removed")
