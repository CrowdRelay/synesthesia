from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
README = (ROOT / "README.md").read_text()
DOC = (ROOT / "docs/RUST_HYBRID_ARCHITECTURE.md").read_text()

for token in (
    "Native production builds are Rust-primary",
    "Web production uses the behavior-compatible GDScript recognizer on the critical startup path",
    "GitHub Actions builds and verifies the Web artifact",
    "synesthesia_gdext.wasm",
):
    assert token in README, token

for token in (
    "| Android | Rust GDExtension",
    "| Web | GDScript recognizer",
    "Web production: GitHub Actions runs `build-web-preview.sh` with `SYNESTHESIA_RUST_WEB_REQUIRED=0`",
    "GitHub Actions is the sole Web build authority",
    "deploys it to Netlify with `--no-build`",
    "Netlify connected-Git source builds must remain stopped",
    "never `native/target`",
):
    assert token in DOC, token

for stale in (
    "Production builds are Rust-primary on all supported targets",
    "| Web / Netlify | Rust GDExtension side-module",
    "Netlify connected-Git integration is the sole automatic Web deployment authority",
    "production Netlify build",
    "Web: `build-web-preview.sh` must produce and export `synesthesia_gdext.wasm`",
):
    assert stale not in README + DOC, stale

print("SYNESTHESIA_RUST_ARCH_DOC=PASS web=gdscript-production+wasm-verification android=native-primary docs=current")
