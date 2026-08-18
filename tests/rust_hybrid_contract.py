from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"SYNESTHESIA_RUST_HYBRID=FAIL missing={label}")


def main() -> None:
    core = (ROOT / "native/synesthesia-core/src/lib.rs").read_text()
    adapter = (ROOT / "native/synesthesia-gdext/src/lib.rs").read_text()
    adapter_manifest = (ROOT / "native/synesthesia-gdext/Cargo.toml").read_text()
    cargo_config = (ROOT / "native/.cargo/config.toml").read_text()
    bridge = (ROOT / "scripts/native/rust_gesture_backend.gd").read_text()
    router = (ROOT / "scripts/input/interaction_router.gd").read_text()
    export = (ROOT / "export_presets.cfg").read_text()
    build = (ROOT / "scripts/build-rust-native.sh").read_text()
    web_build = (ROOT / "scripts/build-web-preview.sh").read_text()
    netlify = (ROOT / "netlify.toml").read_text()
    web_deploy = (ROOT / ".github/workflows/deploy-web.yml").read_text()
    ignore = (ROOT / ".gitignore").read_text()
    ci = (ROOT / ".github/workflows/ci.yml").read_text()
    android_ci = (ROOT / ".github/workflows/android-apk.yml").read_text()
    android_build = (ROOT / "scripts/build-android-apk.sh").read_text()
    native_manifest = (ROOT / "native/Cargo.toml").read_text()
    template = (ROOT / "native/synesthesia_rust.gdextension.template").read_text()

    require(native_manifest, 'rust-version = "1.94"', "rust-msrv")
    require(adapter_manifest, 'features = ["api-4-6"]', "native-godot-api-level")
    require(adapter_manifest, '"api-custom", "experimental-wasm", "lazy-function-tables"', "web-godot-features")
    require(adapter_manifest, 'nothreads = ["godot/experimental-wasm-nothreads"]', "web-nothreads-feature")
    require(cargo_config, 'link-args=-sSIDE_MODULE=2', "wasm-side-module")
    require(cargo_config, 'emscripten-wasm-eh=false', "wasm-panic-eh-disabled")

    require(core, "pub struct GestureEngine", "pure-gesture-engine")
    require(core, "#![forbid(unsafe_code)]", "core-unsafe-forbidden")
    if "godot::" in core or "use godot" in core:
        raise SystemExit("SYNESTHESIA_RUST_HYBRID=FAIL pure-core-depends-on-godot")
    for kind in ("Tap", "Hold", "Drag", "Swipe", "TwoFinger"):
        require(core, kind, f"gesture-{kind}")

    require(adapter, "SynesthesiaGestureCore", "gdextension-class")
    require(adapter, "unsafe impl ExtensionLibrary", "gdextension-entrypoint")
    require(bridge, 'ClassDB.class_exists("SynesthesiaGestureCore")', "runtime-feature-detect")
    require(bridge, 'SYNESTHESIA_RUST_RUNTIME=PASS backend=%s', "runtime-marker")
    require(bridge, 'backend = "web-wasm"', "web-runtime-marker")
    require(bridge, 'backend = "android-native"', "android-runtime-marker")
    require(router, "_native_backend.available()", "router-native-fast-path")
    require(router, "_pointers: Dictionary", "gdscript-emergency-fallback-retained")

    require(export, "variant/extensions_support=true", "web-extensions-on")
    require(export, "variant/thread_support=false", "web-threads-off")
    require(template, 'web.debug.wasm32 = "res://native/bin/web/debug/synesthesia_gdext.wasm"', "web-debug-library")
    require(template, 'web.release.wasm32 = "res://native/bin/web/release/synesthesia_gdext.wasm"', "web-release-library")
    require(template, 'compatibility_minimum = "4.7"', "godot-47-boundary")

    require(build, "wasm32-unknown-emscripten", "web-rust-target")
    require(build, "-Zbuild-std", "web-build-std")
    require(build, "--features nothreads", "web-single-thread")
    require(build, "GDRUST_GODOT_BIN", "web-api-custom-godot")
    require(build, "cargo ndk", "android-native-build")
    require(build, "disable_native", "native-disable-path")
    require(build, "sign_macos_dylib_for_local_godot", "macos-local-sign-helper")
    require(build, "codesign --force --sign - --timestamp=none", "macos-adhoc-codesign")
    require(build, "codesign --verify --strict --verbose=2", "macos-codesign-verify")
    sign_pos = build.find('sign_macos_dylib_for_local_godot "$destination"')
    descriptor_pos = build.find("install_descriptor", sign_pos)
    if sign_pos < 0 or descriptor_pos < 0 or sign_pos > descriptor_pos:
        raise SystemExit("SYNESTHESIA_RUST_HYBRID=FAIL macos-signing-must-precede-descriptor")
    require(web_build, 'RUST_WEB_REQUIRED="${SYNESTHESIA_RUST_WEB_REQUIRED:-1}"', "web-rust-default-required")
    # Extensions and dynamic linking travel together: the Rust-primary path
    # takes the dlink template, the extension-free production path must not.
    require(web_build, "web_dlink_nothreads_release.zip", "web-dlink-template")
    require(web_build, "web_nothreads_release.zip", "web-plain-template")
    require(web_build, "WEB_EXTENSIONS_SUPPORT=true", "web-extensions-with-dlink")
    require(web_build, "WEB_EXTENSIONS_SUPPORT=false", "web-no-extensions-without-dlink")
    require(web_build, "restore_export_preset", "web-preset-restored")
    require(web_build, "SYNESTHESIA_RUST_WEB_EXPORT=PASS", "web-export-verification")
    require(netlify, 'ignore = "exit 0"', "netlify-build-stop-guard")
    if "command =" in netlify or "[[plugins]]" in netlify:
        raise SystemExit("SYNESTHESIA_RUST_HYBRID=FAIL netlify-build-path-still-enabled")
    if re.search(r"(?m)^\s*SYNESTHESIA_RUST_WEB_REQUIRED:\s*(?:0|\"0\"|'0')\s*(?:#.*)?$", ci) is None:
        raise SystemExit("SYNESTHESIA_RUST_HYBRID=FAIL missing=ci-web-gdscript-production-fallback")
    if "build-web-preview.sh" in web_deploy:
        raise SystemExit("SYNESTHESIA_RUST_HYBRID=FAIL deploy-rebuilds-web")
    require(web_deploy, "netlify-cli@26.2.0 deploy", "github-netlify-cli-promotion")
    require(web_deploy, "--no-build", "github-netlify-no-build")

    require(android_build, 'SYNESTHESIA_DISABLE_RUST_NATIVE:-0', "android-rust-default-required")
    require(android_build, "./scripts/build-rust-native.sh android-arm64", "android-native-package")
    require(android_build, "SYNESTHESIA_RUST_ANDROID_APK=PASS", "android-apk-library-verification")
    require(android_ci, 'SYNESTHESIA_DISABLE_RUST_NATIVE: "0"', "android-ci-rust-required")
    require(ci, "cargo +1.97.1 test --manifest-path native/Cargo.toml --package synesthesia-core", "ci-core-test")
    require(ci, "./scripts/build-rust-native.sh host", "ci-native-engine-smoke")
    require(ignore, "synesthesia_rust.gdextension", "generated-descriptor-ignored")

    # A generated descriptor is expected after a local/native build; only a tracked
    # descriptor is a repository hygiene failure.
    if (ROOT / "synesthesia_rust.gdextension").exists() and (ROOT / ".git").exists() and shutil.which("git"):
        tracked = subprocess.run(
            ["git", "ls-files", "--error-unmatch", "synesthesia_rust.gdextension"],
            cwd=ROOT,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        ).returncode == 0
        if tracked:
            raise SystemExit("SYNESTHESIA_RUST_HYBRID=FAIL generated-descriptor-tracked")

    # Keep GDScript and Rust threshold semantics mirrored for the emergency fallback.
    fallback_constants = dict(re.findall(r"const ([A-Z_]+): (?:int|float) = ([0-9.]+)", router))
    rust_constants = dict(re.findall(r"pub const ([A-Z_]+): (?:i64|f32) = ([0-9.]+);", core))
    for key in ("TAP_MAX_MS", "HOLD_MS", "TAP_DISTANCE", "HOLD_DISTANCE", "SWIPE_DISTANCE", "SWIPE_MAX_MS", "DRAG_MIN_STEP"):
        if fallback_constants.get(key) != rust_constants.get(key):
            raise SystemExit(f"SYNESTHESIA_RUST_HYBRID=FAIL threshold-drift={key}")

    print(
        "SYNESTHESIA_RUST_HYBRID=PASS core=pure-rust "
        "web=wasm-verified+gdscript-production android=native-primary fallback=explicit"
    )


if __name__ == "__main__":
    main()
