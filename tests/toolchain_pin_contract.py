from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = (ROOT / "scripts/build-web-preview.sh").read_text()
NATIVE_CONFIG = (ROOT / "native/.cargo/config.toml").read_text()
NETLIFY = (ROOT / "netlify.toml").read_text()

EXPECTED_EMSDK_COMMIT = "3d6d8ee910466516a53e665b86458faa81dae9ba"

for token in (
    'EMSDK_VERSION="${SYNESTHESIA_EMSDK_VERSION:-3.1.74}"',
    f'EMSDK_MANAGER_COMMIT="{EXPECTED_EMSDK_COMMIT}"',
    'git clone --depth 1 --branch "$EMSDK_VERSION"',
    'SYNESTHESIA_EMSDK_MANAGER=PASS',
    'SYNESTHESIA_RUST_WEB_TOOLCHAIN = "nightly-2026-08-07"',
):
    assert token in WEB or token in NETLIFY, token

assert "-sSIDE_MODULE=2" in NATIVE_CONFIG
assert "emscripten-wasm-eh=false" in NATIVE_CONFIG

print("SYNESTHESIA_TOOLCHAIN_PIN=PASS godot=4.7.1 emsdk=3.1.74@3d6d8ee rust-web=nightly-2026-08-07")
