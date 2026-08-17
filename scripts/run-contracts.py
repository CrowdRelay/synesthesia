#!/usr/bin/env python3
"""Run independent read-only Python contracts concurrently with stable output.

Historically every tiny source contract started its own Python process in a long
serial shell pipeline. We keep the useful independent invariants while making
the canonical gate bounded and deterministic.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import os
import pathlib
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]


def run_one(path: str, timeout: float) -> tuple[str, int, float, str]:
    started = time.monotonic()
    proc = subprocess.run(
        [sys.executable, path],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
        check=False,
        timeout=timeout,
    )
    return path, proc.returncode, time.monotonic() - started, proc.stdout.rstrip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--jobs", type=int, default=min(4, os.cpu_count() or 2))
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()
    if args.jobs < 1 or args.jobs > 8:
        parser.error("--jobs must be in 1..8")
    missing = [path for path in args.paths if not (ROOT / path).is_file()]
    if missing:
        raise SystemExit("missing contract files: " + ", ".join(missing))

    started = time.monotonic()
    results: dict[str, tuple[int, float, str]] = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(run_one, path, args.timeout): path for path in args.paths}
        for future in concurrent.futures.as_completed(futures):
            requested = futures[future]
            try:
                path, code, elapsed, output = future.result()
            except subprocess.TimeoutExpired:
                path, code, elapsed, output = requested, 124, args.timeout, f"CONTRACT_TIMEOUT path={requested} timeout_s={args.timeout:g}"
            results[path] = (code, elapsed, output)

    failed = 0
    for path in args.paths:
        code, elapsed, output = results[path]
        if output:
            print(output)
        if code != 0:
            failed += 1
            print(f"CONTRACT_FAIL path={path} exit={code} elapsed_ms={int(elapsed*1000)}", file=sys.stderr)
    elapsed_ms = int((time.monotonic() - started) * 1000)
    if failed:
        print(f"SYNESTHESIA_CONTRACT_BATCH=FAIL failed={failed} total={len(args.paths)} elapsed_ms={elapsed_ms}", file=sys.stderr)
        return 1
    print(f"SYNESTHESIA_CONTRACT_BATCH=PASS total={len(args.paths)} jobs={args.jobs} elapsed_ms={elapsed_ms}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
