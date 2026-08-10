from pathlib import Path

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
    "GODOT_VERSION": "4.7.1-stable",
    "RUST_NATIVE_TOOLCHAIN": "1.97.1",
    "RUST_WEB_TOOLCHAIN": "nightly-2026-08-07",
    "EMSDK_VERSION": "3.1.74",
    "CARGO_NDK_VERSION": "4.1.2",
}
for key, expected in required.items():
    assert pins.get(key) == expected, (key, pins.get(key))

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

# Workflows may repeat pins because action/cache keys are declarative, but must
# not introduce a second version. This makes config/toolchains.env the review
# source of truth while CI fails on drift.
workflow_text = "\n".join(p.read_text() for p in (ROOT / ".github/workflows").glob("*.yml"))
for forbidden in ("4.7.0", "1.96.", "1.98.", "3.1.73", "3.1.75", "cargo-ndk 4.0", "cargo-ndk 4.2"):
    assert forbidden not in workflow_text, forbidden

print(
    "SYNESTHESIA_TOOLCHAIN_PIN=PASS "
    f"godot={pins['GODOT_VERSION']} rust-native={pins['RUST_NATIVE_TOOLCHAIN']} "
    f"rust-web={pins['RUST_WEB_TOOLCHAIN']} emsdk={pins['EMSDK_VERSION']} ndk={pins['CARGO_NDK_VERSION']}"
)
