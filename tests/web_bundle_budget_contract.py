#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "tools/web_bundle_budget.py").read_text()
failures = []
for token in (
    'MAX_RUST_WASM = 2 * 1024 * 1024',
    'path.name == "synesthesia_gdext.wasm"',
    'path.name != "synesthesia_gdext.wasm"',
    'expected exactly one Godot PCK',
    'expected exactly one Rust GDExtension WASM',
    'MAX_TOTAL = 96 * 1024 * 1024',
):
    if token not in source:
        failures.append(token)
if 'for path in wasms:' in source and 'MAX_RUST_WASM' in source:
    failures.append('generic engine WASM is still subject to Rust side-module limit')
if failures:
    raise SystemExit('SYNESTHESIA_WEB_BUNDLE_BUDGET_CONTRACT=FAIL missing=' + ','.join(failures))
print('SYNESTHESIA_WEB_BUNDLE_BUDGET_CONTRACT=PASS pck=single rust-wasm<=2MiB engine-wasm=total-budget total<=96MiB')
