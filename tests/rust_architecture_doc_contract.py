from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
README = (ROOT / "README.md").read_text()
DOC = (ROOT / "docs/RUST_HYBRID_ARCHITECTURE.md").read_text()

for token in (
    "Production builds are Rust-primary on all supported targets",
    "synesthesia_gdext.wasm",
    "explicit emergency fallback",
):
    assert token in README, token

for token in (
    "| Android | Rust GDExtension",
    "| Web / Netlify | Rust GDExtension side-module",
    "Netlify connected-Git integration is the sole automatic Web deployment authority",
    "never `native/target`",
):
    assert token in DOC, token

for stale in (
    "Web remains independent from experimental GDExtension/WASM support",
    "Web CI never generates the descriptor",
    "Web keeps the proven GDScript fallback",
):
    assert stale not in README + DOC, stale

print("SYNESTHESIA_RUST_ARCH_DOC=PASS web=wasm-primary android=native-primary fallback=explicit docs=current")
