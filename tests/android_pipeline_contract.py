#!/usr/bin/env python3
"""Static contract for the reproducible Rust-primary Android APK pipeline."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

workflow_path = ROOT / ".github/workflows/android-apk.yml"
build_script_path = ROOT / "scripts/build-android-apk.sh"
preset_path = ROOT / "export_presets.cfg"
project_path = ROOT / "project.godot"
toolchains_path = ROOT / "config/toolchains.env"

workflow = workflow_path.read_text() if workflow_path.is_file() else ""
script = build_script_path.read_text() if build_script_path.is_file() else ""
preset = preset_path.read_text()
project = project_path.read_text()
toolchains = toolchains_path.read_text() if toolchains_path.is_file() else ""

if not workflow:
    failures.append(".github/workflows/android-apk.yml missing")
if not script:
    failures.append("scripts/build-android-apk.sh missing")

for token in (
    "workflow_run:",
    'workflows: ["CI"]',
    "github.event.workflow_run.conclusion == 'success'",
    "github.event.workflow_run.event == 'push'",
    "github.event.workflow_run.head_branch == 'main'",
    "github.event.workflow_run.actor.login || github.actor",
    "github.event.workflow_run.head_sha || github.sha",
    "SOURCE_SHA:",
    "ref: ${{ env.SOURCE_SHA }}",
    "workflow_dispatch:",
    'java-version: "17"',
    "android-actions/setup-android@",
    "./scripts/build-android-apk.sh",
    "actions/upload-artifact@",
    "build/android/synesthesia-debug.apk",
    "ANDROID_DEBUG_KEYSTORE_BASE64",
    "SYNESTHESIA_ANDROID_VERSION_CODE",
    "synesthesia-android-godot-logs-",
    "if: always()",
    'SYNESTHESIA_DISABLE_RUST_NATIVE: "0"',
    "Validate canonical source contracts for manual builds",
    "if: github.event_name == 'workflow_dispatch'",
    "SYNESTHESIA_ANDROID_SOURCE_PROVENANCE=CI_VALIDATED",
):
    if token not in workflow:
        failures.append(f"Android workflow missing token: {token}")

for token in (
    'source "$ROOT/config/toolchains.env"',
    'BUILD_TOOLS_VERSION="$ANDROID_BUILD_TOOLS_VERSION"',
    'PLATFORM_VERSION="$ANDROID_PLATFORM_VERSION"',
    'NDK_VERSION="$ANDROID_NDK_VERSION"',
    'CMAKE_VERSION="$ANDROID_CMAKE_VERSION"',
    'editor_settings-4.7.tres',
    'export/android/android_sdk_path',
    'export/android/java_sdk_path',
    'GODOT_ANDROID_KEYSTORE_DEBUG_PATH',
    '--export-debug "Android Debug"',
    'apksigner',
    'aapt2',
    'music.virya.synesthesia',
    'SYNESTHESIA_GODOT_RUNTIME=PASS',
    'shared Synesthesia validation failed before Android export',
    'SYNESTHESIA_GODOT_LOG_DIR',
    'SYNESTHESIA_DISABLE_RUST_NATIVE:-0',
    './scripts/build-rust-native.sh android-arm64',
    'libsynesthesia_gdext\\.so$',
    'SYNESTHESIA_RUST_ANDROID_APK=PASS',
    'godot-runtime-data-dir.sh',
    'unzip -p "$template_archive" "templates/$template_name"',
    'SYNESTHESIA_ANDROID_TEMPLATES=PASS scope=android-only',
    'write_sha256',
    "license_answers=\"$(printf 'y\\n%.0s' {1..100})\"",
    '--licenses <<<\"$license_answers\"',
):
    if token not in script:
        failures.append(f"Android build script missing token: {token}")


for token in (
    "GODOT_VERSION=4.7.1-stable",
    "GODOT_EDITOR_SHA256=c7ff14fd28472c8d4f193043de30278dcf7e5241a1dcf7566b02e27addaa33ba",
    "GODOT_TEMPLATES_SHA256=86409db6200b6f8fd3230989c2d2002851f3dd18acf11d7bdbafddf5a0dd0f72",
    "ANDROID_BUILD_TOOLS_VERSION=35.0.1",
    "ANDROID_PLATFORM_VERSION=android-35",
    "ANDROID_NDK_VERSION=28.1.13356709",
    "ANDROID_CMAKE_VERSION=3.10.2.4988404",
):
    if token not in toolchains:
        failures.append(f"Canonical toolchain config missing token: {token}")

if "templates-unpack" in script or 'cp -R "$unpack_dir/templates/."' in script or 'sha256sum --check --strict' in script:
    failures.append("Android builder must install only selected templates with portable checksum verification")
if "\nyes |" in script:
    failures.append("Android license acceptance must not use yes|sdkmanager under pipefail")

rust_builder = (ROOT / "scripts/build-rust-native.sh").read_text()
for token in (
    '(cd "$NATIVE" && cargo ndk --version',
    '(cd "$NATIVE" && cargo ndk "${args[@]}")',
):
    if token not in rust_builder:
        failures.append(f"Android Rust builder must run cargo-ndk from native workspace: {token}")
if "if ! (cd native && cargo ndk --version" not in workflow:
    failures.append("Android workflow cargo-ndk probe must run from native workspace")

if "SYNESTHESIA_ENABLE_RUST_NATIVE" in script or "SYNESTHESIA_ENABLE_RUST_NATIVE" in workflow:
    failures.append("Android Rust must be default-on, not opt-in")

for token in (
    'name="Android Debug"',
    'platform="Android"',
    'architectures/arm64-v8a=true',
    'architectures/armeabi-v7a=false',
    'package/unique_name="music.virya.synesthesia"',
    'package/show_as_launcher_app=true',
    'permissions/internet=true',
    'permissions/vibrate=true',
    'include_filter="assets/video/*.ogv"',
):
    if token not in preset:
        failures.append(f"Android export preset missing token: {token}")

if 'textures/vram_compression/import_etc2_astc=true' not in project:
    failures.append("Android export requires rendering/textures/vram_compression/import_etc2_astc=true")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_ANDROID_PIPELINE=FAIL count={len(failures)}")

print("SYNESTHESIA_ANDROID_PIPELINE=PASS target=arm64 rust=required apk=verified sdk=35 artifact=after-green-main-ci")
