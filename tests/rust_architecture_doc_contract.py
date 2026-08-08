from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
README = (ROOT / "README.md").read_text()
DOC = (ROOT / "docs/RUST_HYBRID_ARCHITECTURE.md").read_text()

for token in (
    "Native production builds are Rust-primary",
    "Web/Netlify deliberately uses the behavior-compatible GDScript recognizer in production",
    "synesthesia_gdext.wasm",
    "SYNESTHESIA_RUST_WEB_REQUIRED=1",
):
    assert token in README, token

for token in (
    "| Android | Rust GDExtension",
    "| Web / Netlify | GDScript recognizer",
    "Web production: Netlify sets `SYNESTHESIA_RUST_WEB_REQUIRED=0`",
    "Netlify connected-Git integration is the sole automatic Web deployment authority",
    "never `native/target`",
):
    assert token in DOC, token

for stale in (
    "Production builds are Rust-primary on all supported targets",
    "| Web / Netlify | Rust GDExtension side-module",
    "Web: `build-web-preview.sh` must produce and export `synesthesia_gdext.wasm`",
):
    assert stale not in README + DOC, stale

print("SYNESTHESIA_RUST_ARCH_DOC=PASS web=gdscript-production+wasm-verification android=native-primary docs=current")
