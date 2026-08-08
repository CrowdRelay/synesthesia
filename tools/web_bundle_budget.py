#!/usr/bin/env python3
"""Guard Web deploy size so generated/cache artifacts can never hide in the PWA."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build" / "web"
MAX_PCK = 72 * 1024 * 1024
MAX_RUST_WASM = 2 * 1024 * 1024
MAX_TOTAL = 96 * 1024 * 1024

if not BUILD.is_dir():
    raise SystemExit("SYNESTHESIA_WEB_BUNDLE_BUDGET=FAIL reason=missing-build-web")

files = [path for path in BUILD.rglob("*") if path.is_file()]
total = sum(path.stat().st_size for path in files)
pcks = [path for path in files if path.suffix == ".pck"]
wasms = [path for path in files if path.suffix == ".wasm"]
rust_wasms = [path for path in wasms if path.name == "synesthesia_gdext.wasm"]
engine_wasms = [path for path in wasms if path.name != "synesthesia_gdext.wasm"]
failures: list[str] = []

if len(pcks) != 1:
    failures.append(f"expected exactly one Godot PCK, got {len(pcks)}")
if len(rust_wasms) != 1:
    failures.append(f"expected exactly one Rust GDExtension WASM, got {len(rust_wasms)}")
for path in pcks:
    if path.stat().st_size > MAX_PCK:
        failures.append(f"PCK exceeds 72 MiB: {path.name}={path.stat().st_size}")
for path in rust_wasms:
    if path.stat().st_size > MAX_RUST_WASM:
        failures.append(f"Rust GDExtension WASM exceeds 2 MiB: {path.name}={path.stat().st_size}")
if total > MAX_TOTAL:
    failures.append(f"Web artifact exceeds 96 MiB: total={total}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_WEB_BUNDLE_BUDGET=FAIL count={len(failures)}")

print(
    "SYNESTHESIA_WEB_BUNDLE_BUDGET=PASS "
    f"files={len(files)} total_mib={total / 1048576:.2f} "
    f"pck_mib={max((p.stat().st_size for p in pcks), default=0) / 1048576:.2f} "
    f"rust_wasm_kib={max((p.stat().st_size for p in rust_wasms), default=0) / 1024:.1f} "
    f"engine_wasm_mib={sum(p.stat().st_size for p in engine_wasms) / 1048576:.2f}"
)
