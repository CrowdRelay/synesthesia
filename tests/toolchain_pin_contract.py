from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PINS = ROOT / "config/toolchains.env"
assert PINS.is_file()

pins = {}
for raw in PINS.read_text().splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    key, value = line.split("=", 1)
    pins[key] = value

required = {
    "GODOT_VERSION",
    "RUST_NATIVE_TOOLCHAIN",
    "RUST_WEB_TOOLCHAIN",
    "EMSDK_VERSION",
    "CARGO_NDK_VERSION",
    "ANDROID_BUILD_TOOLS_VERSION",
    "ANDROID_PLATFORM_VERSION",
    "ANDROID_NDK_VERSION",
    "ANDROID_CMAKE_VERSION",
}
missing = sorted(required - pins.keys())
assert not missing, missing

assert re.fullmatch(r"4\.\d+(?:\.\d+)?-stable", pins["GODOT_VERSION"]), pins["GODOT_VERSION"]
assert re.fullmatch(r"\d+\.\d+\.\d+", pins["RUST_NATIVE_TOOLCHAIN"]), pins["RUST_NATIVE_TOOLCHAIN"]
assert re.fullmatch(r"nightly-\d{4}-\d{2}-\d{2}", pins["RUST_WEB_TOOLCHAIN"]), pins["RUST_WEB_TOOLCHAIN"]
assert re.fullmatch(r"\d+\.\d+\.\d+", pins["EMSDK_VERSION"]), pins["EMSDK_VERSION"]
assert re.fullmatch(r"\d+\.\d+\.\d+", pins["CARGO_NDK_VERSION"]), pins["CARGO_NDK_VERSION"]
assert re.fullmatch(r"android-\d+", pins["ANDROID_PLATFORM_VERSION"]), pins["ANDROID_PLATFORM_VERSION"]

for rel in (
    "scripts/build-web-preview.sh",
    "scripts/build-linux-release.sh",
    "scripts/build-android-apk.sh",
    "scripts/build-rust-native.sh",
):
    source = (ROOT / rel).read_text()
    assert 'source "$ROOT/config/toolchains.env"' in source, rel

web = (ROOT / "scripts/build-web-preview.sh").read_text()
native_config = (ROOT / "native/.cargo/config.toml").read_text()
assert pins["EMSDK_MANAGER_COMMIT"] in (ROOT / "config/toolchains.env").read_text()
assert 'git clone --depth 1 --branch "$EMSDK_VERSION"' in web
assert "SYNESTHESIA_EMSDK_MANAGER=PASS" in web
assert "-sSIDE_MODULE=2" in native_config
assert "emscripten-wasm-eh=false" in native_config

# Workflows may repeat pins for cache keys, but this contract intentionally
# does not blacklist neighbouring versions. Central config remains authoritative;
# consumers are checked for sourcing/agreeing with it rather than freezing upgrades.
workflow_text = "\n".join(p.read_text() for p in (ROOT / ".github/workflows").glob("*.yml"))
for line in workflow_text.splitlines():
    lower = line.lower()
    if "rust-toolchain" in lower or "cargo-ndk" in lower:
        assert "latest" not in lower, line

print(
    "SYNESTHESIA_TOOLCHAIN_PIN=PASS "
    f"godot={pins['GODOT_VERSION']} rust-native={pins['RUST_NATIVE_TOOLCHAIN']} "
    f"rust-web={pins['RUST_WEB_TOOLCHAIN']} emsdk={pins['EMSDK_VERSION']} ndk={pins['CARGO_NDK_VERSION']}"
)
