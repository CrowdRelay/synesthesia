#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "tools/web_bundle_budget.py").read_text()
builder = (ROOT / "scripts/build-web-preview.sh").read_text()
failures = []
for token in (
    'MAX_RUST_WASM = 2 * 1024 * 1024',
    'MAX_PCK = 72 * 1024 * 1024',
    'MAX_TOTAL = 128 * 1024 * 1024',
    'MAX_SOURCE_RUNTIME = 64 * 1024 * 1024',
    'path.name == "synesthesia_gdext.wasm"',
    'path.name != "synesthesia_gdext.wasm"',
    'expected exactly one Godot PCK',
    'expected exactly one Rust GDExtension WASM',
    'SYNESTHESIA_WEB_BUNDLE_PREFLIGHT=PASS',
):
    if token not in source:
        failures.append(token)
if 'python3 tools/web_bundle_budget.py --preflight' not in builder:
    failures.append('builder-preflight-before-expensive-work')
if 'for path in wasms:' in source and 'MAX_RUST_WASM' in source:
    failures.append('generic engine WASM is still subject to Rust side-module limit')
if failures:
    raise SystemExit('SYNESTHESIA_WEB_BUNDLE_BUDGET_CONTRACT=FAIL missing=' + ','.join(failures))
print('SYNESTHESIA_WEB_BUNDLE_BUDGET_CONTRACT=PASS preflight<=64MiB pck<=72MiB rust-wasm<=2MiB total<=128MiB')
