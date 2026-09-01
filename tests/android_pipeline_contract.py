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


toolchain_values = {}
for raw in toolchains.splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    if "=" not in line:
        failures.append(f"Malformed canonical toolchain line: {line}")
        continue
    key, value = line.split("=", 1)
    toolchain_values[key] = value

for key in (
    "GODOT_VERSION",
    "GODOT_EDITOR_SHA256",
    "GODOT_TEMPLATES_SHA256",
    "ANDROID_BUILD_TOOLS_VERSION",
    "ANDROID_PLATFORM_VERSION",
    "ANDROID_NDK_VERSION",
    "ANDROID_CMAKE_VERSION",
):
    if not toolchain_values.get(key):
        failures.append(f"Canonical toolchain config missing key: {key}")

for sha_key in ("GODOT_EDITOR_SHA256", "GODOT_TEMPLATES_SHA256"):
    value = toolchain_values.get(sha_key, "")
    if len(value) != 64 or any(ch not in "0123456789abcdef" for ch in value):
        failures.append(f"Canonical toolchain checksum malformed: {sha_key}")

if "templates-unpack" in script or 'cp -R "$unpack_dir/templates/."' in script or 'sha256sum --check --strict' in script:
    failures.append("Android builder must install only selected templates with portable checksum verification")
if "\nyes |" in script:
    failures.append("Android license acceptance must not use yes|sdkmanager under pipefail")

rust_builder = (ROOT / "scripts/build-rust-native.sh").read_text()
native_cargo_config = (ROOT / "native/.cargo/config.toml").read_text()
for token in (
    "[target.aarch64-linux-android]",
    "max-page-size=16384",
    "common-page-size=16384",
):
    if token not in native_cargo_config:
        failures.append(f"Android Rust 16 KiB linker contract missing: {token}")

play_builder_path = ROOT / "scripts/play-build.fish"
alignment_checker_path = ROOT / "scripts/check-android-elf-alignment.py"
play_builder = play_builder_path.read_text() if play_builder_path.is_file() else ""
alignment_checker = alignment_checker_path.read_text() if alignment_checker_path.is_file() else ""
for token in (
    "SYNESTHESIA_RUST_PROFILE=debug",
    "./scripts/build-rust-native.sh host",
    "SYNESTHESIA_RUST_PROFILE=release",
    "./scripts/build-rust-native.sh android-arm64",
    'scripts/check-android-elf-alignment.py "$AAB" "$ANDROID_NDK_HOME"',
):
    if token not in play_builder:
        failures.append(f"Play AAB builder missing native bridge contract: {token}")
if play_builder.find("./scripts/build-rust-native.sh host") > play_builder.find("./scripts/build-rust-native.sh android-arm64"):
    failures.append("Play AAB builder must prepare the host debug bridge before Android release native")
for builder_name in ("build-android-play-aab.sh", "build-android-apk.sh"):
    builder = (ROOT / "scripts" / builder_name).read_text()
    host = builder.find("./scripts/build-rust-native.sh host")
    android = builder.find("./scripts/build-rust-native.sh android-arm64")
    if host < 0 or android < 0 or host > android:
        failures.append(f"{builder_name} must prepare the host debug bridge before Android native")
for token in ("PT_LOAD", "16K_PAGE_ALIGNMENT=FAIL", "SYNESTHESIA_AAB_16K=PASS"):
    if token not in alignment_checker:
        failures.append(f"AAB ELF alignment checker missing token: {token}")

play_release_builder_path = ROOT / "scripts/build-android-play-aab.sh"
play_workflow_path = ROOT / ".github/workflows/android-play.yml"
play_release_builder = play_release_builder_path.read_text() if play_release_builder_path.is_file() else ""
play_workflow = play_workflow_path.read_text() if play_workflow_path.is_file() else ""
for token in (
    'export ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"',
    'for template_name in android_debug.apk android_release.apk android_source.zip; do',
    'godot_export_args+=(--install-android-build-template)',
    "godot_export_args+=(--export-release 'Android Release' \"$AAB_PATH\")",
    '"$GODOT_BIN" "${godot_export_args[@]}"',
    'android-play-export.log',
    'Android Gradle build template was not installed',
):
    if token not in play_release_builder:
        failures.append(f"Play release builder missing Gradle-template hardening: {token}")
if '"$GODOT_BIN" --headless --path "$ROOT" --install-android-build-template\n' in play_release_builder:
    failures.append("Play release builder must not invoke template installation as a standalone Godot editor command")
if "~/.local/share/godot/export_templates/4.7.1.stable/android_source.zip" not in play_workflow:
    failures.append("Play workflow must cache the Android Gradle source template")

# Godot turns package/show_as_launcher_app into android.intent.category.HOME, which offers the
# app as a home-screen launcher replacement. Synesthesia is an audio experience, not a launcher.
if "package/show_as_launcher_app=true" in preset:
    failures.append("Android presets must not publish Synesthesia as a home-screen launcher app")

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
    'package/show_as_launcher_app=false',
    'permissions/internet=true',
    'permissions/vibrate=true',
    'include_filter="assets/video/*.ogv"',
):
    if token not in preset:
        failures.append(f"Android export preset missing token: {token}")

if 'textures/vram_compression/import_etc2_astc=true' not in project:
    failures.append("Android export requires rendering/textures/vram_compression/import_etc2_astc=true")

# Google Play large-screen recommendation: do not lock orientation to portrait.
# Android 16+ ignores screenOrientation on large screens anyway; setting sensor
# avoids the Play Console warning and lets tablets/foldables rotate freely.
if 'handheld/orientation=6' not in project:
    failures.append("project.godot must set handheld/orientation=6 (sensor) for large-screen support")

# R8 minification: Google Play recommends enabling R8 to reduce memory and
# improve performance. The release AAB builder pre-extracts the Gradle source
# template, patches build.gradle to enable minifyEnabled + shrinkResources, and
# copies proguard-rules.pro with keep rules for Godot JNI classes.
proguard_path = ROOT / "proguard-rules.pro"
if not proguard_path.is_file():
    failures.append("proguard-rules.pro missing — R8 keep rules required for release AAB")
else:
    proguard = proguard_path.read_text()
    for token in (
        "-keep class org.godotengine.** { *; }",
        "-keep class com.godot.** { *; }",
        "native <methods>;",
    ):
        if token not in proguard:
            failures.append(f"proguard-rules.pro missing keep rule: {token}")

for token in (
    'minifyEnabled true',
    'shrinkResources true',
    "proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'",
    'cp proguard-rules.pro android/build/proguard-rules.pro',
    'SYNESTHESIA_R8=ENABLED',
    'android/.build_version',
):
    if token not in play_release_builder:
        failures.append(f"Play release builder missing R8 token: {token}")

play_fish_path = ROOT / "scripts/play-build.fish"
play_fish = play_fish_path.read_text() if play_fish_path.is_file() else ""
for token in (
    'minifyEnabled true',
    'shrinkResources true',
    'SYNESTHESIA_R8=ENABLED',
):
    if token not in play_fish:
        failures.append(f"play-build.fish missing R8 token: {token}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_ANDROID_PIPELINE=FAIL count={len(failures)}")

print("SYNESTHESIA_ANDROID_PIPELINE=PASS target=arm64 rust=required apk=verified play-aab=16k-verified r8=enabled orientation=sensor toolchains=central-config")
