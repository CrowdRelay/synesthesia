#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
flow = (ROOT / "scripts/app/main_runtime_flow.gd").read_text()
main = (ROOT / "scripts/main.gd").read_text()

required = [
    "RUNTIME_SCRIPT_LOAD_TIMEOUT_MS",
    "Time.get_ticks_msec() < deadline_ms",
    'push_error("Runtime script load timed out: %s" % path)',
    "return null",
]
for needle in required:
    if needle not in flow:
        raise SystemExit(f"RUNTIME_LOADER_DEADLINE=FAIL missing={needle}")

if "while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:" in flow:
    raise SystemExit("RUNTIME_LOADER_DEADLINE=FAIL unbounded_wait=true")
if 'not await runtime_flow.ensure_ready()' not in main or '_show_fatal_error("Nie udało się przygotować runtime Synesthesii.")' not in main:
    raise SystemExit("RUNTIME_LOADER_DEADLINE=FAIL fatal_path_missing=true")
print("RUNTIME_LOADER_DEADLINE=PASS timeout_ms=1500 fatal=true")
