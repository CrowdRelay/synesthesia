#!/usr/bin/env python3
"""Regression contract for the stage-aware Godot log gate."""
from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GATE = ROOT / "tools/godot_log_gate.py"
ENGINE = "Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org\n"
PASS = "SYNESTHESIA_LIFECYCLE_SMOKE=PASS audio=music+pink+pop\n"


def run(text: str, *extra: str) -> subprocess.CompletedProcess[str]:
    with tempfile.NamedTemporaryFile("w", suffix=".log", delete=False) as handle:
        handle.write(text)
        path = Path(handle.name)
    try:
        return subprocess.run(
            ["python3", str(GATE), "--stage", "lifecycle", "--log", str(path),
             "--expected-marker", "SYNESTHESIA_LIFECYCLE_SMOKE=PASS", *extra],
            text=True, capture_output=True,
        )
    finally:
        path.unlink(missing_ok=True)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"SYNESTHESIA_GODOT_LOG_GATE_CONTRACT=FAIL {message}")


allowed = run(
    ENGINE + PASS
    + "WARNING: 11 ObjectDB instances were leaked at exit (run with `--verbose` for details).\n"
    + "   at: cleanup (core/object/object.cpp:2536)\n"
    + "ERROR: 4 resources still in use at exit (run with --verbose for details).\n"
    + "   at: clear (core/io/resource.cpp:822)\n",
    "--allow-471-shutdown-noise",
)
require(allowed.returncode == 0, f"known 4.7.1 post-PASS noise rejected: {allowed.stderr}")
require("SYNESTHESIA_GODOT_SHUTDOWN_NOISE=ALLOW" in allowed.stdout, "allow marker missing")
require("objectdb=11/16" in allowed.stdout and "resources=4/8" in allowed.stdout, "shutdown budgets not reported precisely")

prepass = run(ENGINE + "ERROR: real runtime failure\n" + PASS, "--allow-471-shutdown-noise")
require(prepass.returncode != 0, "pre-PASS ERROR must fail")

script_error = run(ENGINE + PASS + "SCRIPT ERROR: bad thing\n", "--allow-471-shutdown-noise")
require(script_error.returncode != 0, "post-PASS SCRIPT ERROR must fail")

huge = run(ENGINE + PASS + "ERROR: 99 resources still in use at exit\n", "--allow-471-shutdown-noise")
require(huge.returncode != 0, "shutdown noise over budget must fail")

wrong_engine = run(
    "Godot Engine v4.8.0.stable\n" + PASS + "ERROR: 4 resources still in use at exit\n",
    "--allow-471-shutdown-noise",
)
require(wrong_engine.returncode != 0, "shutdown allowlist must be pinned to Godot 4.7.1")

missing = run(ENGINE)
require(missing.returncode != 0, "missing PASS marker must fail")

print("SYNESTHESIA_GODOT_LOG_GATE_CONTRACT=PASS strict=errors marker=required shutdown=4.7.1-budgeted")
