#!/usr/bin/env python3
"""Static contract for the reproducible Android APK GitHub Actions pipeline."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

workflow_path = ROOT / ".github/workflows/android-apk.yml"
build_script_path = ROOT / "scripts/build-android-apk.sh"
preset_path = ROOT / "export_presets.cfg"
project_path = ROOT / "project.godot"

if not workflow_path.is_file():
    failures.append(".github/workflows/android-apk.yml missing")
    workflow = ""
else:
    workflow = workflow_path.read_text()

if not build_script_path.is_file():
    failures.append("scripts/build-android-apk.sh missing")
    script = ""
else:
    script = build_script_path.read_text()

preset = preset_path.read_text()
project = project_path.read_text()

for token in (
    "branches: [main]",
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
):
    if token not in workflow:
        failures.append(f"Android workflow missing token: {token}")

for token in (
    'GODOT_VERSION="4.7.1-stable"',
    'GODOT_EDITOR_SHA256="c7ff14fd28472c8d4f193043de30278dcf7e5241a1dcf7566b02e27addaa33ba"',
    'GODOT_TEMPLATES_SHA256="86409db6200b6f8fd3230989c2d2002851f3dd18acf11d7bdbafddf5a0dd0f72"',
    'BUILD_TOOLS_VERSION="35.0.1"',
    'PLATFORM_VERSION="android-35"',
    'NDK_VERSION="28.1.13356709"',
    'CMAKE_VERSION="3.10.2.4988404"',
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
):
    if token not in script:
        failures.append(f"Android build script missing token: {token}")

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

print("SYNESTHESIA_ANDROID_PIPELINE=PASS target=arm64 apk=debug sdk=35 signing=ephemeral-or-secret artifact=on-main")
