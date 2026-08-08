#!/usr/bin/env python3
"""Guard Web deploy size and fail predictable source bloat before expensive builds."""
from pathlib import Path
import argparse
import os

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build" / "web"
MAX_PCK = 72 * 1024 * 1024
MAX_RUST_WASM = 2 * 1024 * 1024
MAX_TOTAL = 128 * 1024 * 1024
MAX_SOURCE_RUNTIME = 64 * 1024 * 1024

RUNTIME_SOURCE_ROOTS = ("assets", "scenes", "scripts", "shaders")
RUNTIME_SOURCE_FILES = ("project.godot", "default_bus_layout.tres")

def source_runtime_bytes() -> int:
    files: set[Path] = set()
    for name in RUNTIME_SOURCE_ROOTS:
        root = ROOT / name
        if root.is_dir():
            files.update(path for path in root.rglob("*") if path.is_file())
    for name in RUNTIME_SOURCE_FILES:
        path = ROOT / name
        if path.is_file():
            files.add(path)
    return sum(path.stat().st_size for path in files)

def preflight() -> None:
    total = source_runtime_bytes()
    if total > MAX_SOURCE_RUNTIME:
        raise SystemExit(
            "SYNESTHESIA_WEB_BUNDLE_PREFLIGHT=FAIL "
            f"source_runtime_bytes={total} limit_bytes={MAX_SOURCE_RUNTIME}"
        )
    print(
        "SYNESTHESIA_WEB_BUNDLE_PREFLIGHT=PASS "
        f"source_runtime_mib={total / 1048576:.2f} limit_mib={MAX_SOURCE_RUNTIME / 1048576:.0f}"
    )

def postbuild() -> None:
    if not BUILD.is_dir():
        raise SystemExit("SYNESTHESIA_WEB_BUNDLE_BUDGET=FAIL reason=missing-build-web")

    files = [path for path in BUILD.rglob("*") if path.is_file()]
    total = sum(path.stat().st_size for path in files)
    pcks = [path for path in files if path.suffix == ".pck"]
    wasms = [path for path in files if path.suffix == ".wasm"]
    rust_wasms = [path for path in wasms if path.name == "synesthesia_gdext.wasm"]
    engine_wasms = [path for path in wasms if path.name != "synesthesia_gdext.wasm"]
    failures: list[str] = []
    rust_required = os.environ.get("SYNESTHESIA_RUST_WEB_REQUIRED", "1") == "1"

    if len(pcks) != 1:
        failures.append(f"expected exactly one Godot PCK, got {len(pcks)}")
    if rust_required and len(rust_wasms) != 1:
        failures.append(f"expected exactly one Rust GDExtension WASM, got {len(rust_wasms)}")
    if not rust_required and rust_wasms:
        failures.append(f"GDScript Web fallback must not ship Rust side-module WASM, got {len(rust_wasms)}")
    for path in pcks:
        if path.stat().st_size > MAX_PCK:
            failures.append(f"PCK exceeds 72 MiB: {path.name}={path.stat().st_size}")
    for path in rust_wasms:
        if path.stat().st_size > MAX_RUST_WASM:
            failures.append(f"Rust GDExtension WASM exceeds 2 MiB: {path.name}={path.stat().st_size}")
    if total > MAX_TOTAL:
        failures.append(f"Web artifact exceeds 128 MiB: total={total}")

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}")
        raise SystemExit(f"SYNESTHESIA_WEB_BUNDLE_BUDGET=FAIL count={len(failures)}")

    print(
        "SYNESTHESIA_WEB_BUNDLE_BUDGET=PASS "
        f"files={len(files)} total_mib={total / 1048576:.2f} "
        f"pck_mib={max((p.stat().st_size for p in pcks), default=0) / 1048576:.2f} "
        f"rust_required={str(rust_required).lower()} "
        f"rust_wasm_kib={max((p.stat().st_size for p in rust_wasms), default=0) / 1024:.1f} "
        f"engine_wasm_mib={sum(p.stat().st_size for p in engine_wasms) / 1048576:.2f}"
    )

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--preflight", action="store_true")
    args = parser.parse_args()
    if args.preflight:
        preflight()
    else:
        postbuild()

if __name__ == "__main__":
    main()
