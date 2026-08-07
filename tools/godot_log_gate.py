#!/usr/bin/env python3
"""Strict, stage-aware gate for Godot headless logs.

Godot 4.7.1 can emit shutdown-only ObjectDB/Resource leak diagnostics after a
successful --script run even when the smoke test has explicitly disposed its
runtime graph. We tolerate only that exact post-PASS signature, on that exact
engine line, under a small numeric budget. All runtime/parser/shader/load errors
remain fatal.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

HARD_PATTERNS = (
    re.compile(r"(?:^|\s)SCRIPT ERROR:"),
    re.compile(r"(?:^|\s)ERROR:"),
    re.compile(r"Parse Error:"),
    re.compile(r"Parser Error:"),
    re.compile(r"Compile Error:"),
    re.compile(r"Failed to load script"),
    re.compile(r"Failed loading resource:"),
    re.compile(r"Shader error:"),
    re.compile(r"Warning treated as error"),
    re.compile(r"Pink-noise.*missing", re.I),
    re.compile(r"Room music.*missing", re.I),
    re.compile(r"Room ambience.*missing", re.I),
    re.compile(r"Cinematic video.*missing", re.I),
)

ENGINE_471 = re.compile(r"^Godot Engine v4\.7\.1(?:\.|-)")
OBJECTDB_NOISE = re.compile(r"^WARNING: (\d+) ObjectDB instances were leaked at exit")
RESOURCE_NOISE = re.compile(r"^ERROR: (\d+) resources still in use at exit")
NOISE_CONTEXT = (
    re.compile(r"^\s*at: cleanup \(core/object/object\.cpp:\d+\)"),
    re.compile(r"^\s*at: clear \(core/io/resource\.cpp:\d+\)"),
)


def is_hard(line: str) -> bool:
    return any(pattern.search(line) for pattern in HARD_PATTERNS)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage", required=True)
    parser.add_argument("--log", required=True, type=Path)
    parser.add_argument("--expected-marker", default="")
    parser.add_argument("--allow-471-shutdown-noise", action="store_true")
    parser.add_argument("--max-objectdb", type=int, default=16)
    parser.add_argument("--max-resources", type=int, default=8)
    return parser.parse_args()


def fail(stage: str, reason: str, line: str | None = None) -> int:
    suffix = f" line={line!r}" if line else ""
    print(f"SYNESTHESIA_GODOT_LOG_GATE=FAIL stage={stage} reason={reason}{suffix}", file=sys.stderr)
    return 1


def main() -> int:
    args = parse_args()
    lines = args.log.read_text(encoding="utf-8", errors="replace").splitlines()

    marker_index = -1
    if args.expected_marker:
        for i, line in enumerate(lines):
            if args.expected_marker in line:
                marker_index = i
        if marker_index < 0:
            return fail(args.stage, "missing-pass-marker")

    engine_471 = any(ENGINE_471.search(line) for line in lines)
    objectdb_count: int | None = None
    resource_count: int | None = None

    for i, line in enumerate(lines):
        after_pass = marker_index >= 0 and i > marker_index
        m_obj = OBJECTDB_NOISE.match(line)
        if m_obj:
            objectdb_count = int(m_obj.group(1))
            if args.allow_471_shutdown_noise and after_pass and engine_471:
                if objectdb_count <= args.max_objectdb:
                    continue
                return fail(args.stage, f"objectdb-shutdown-budget-exceeded:{objectdb_count}>{args.max_objectdb}")
            return fail(args.stage, "unexpected-objectdb-shutdown-diagnostic", line)

        m_res = RESOURCE_NOISE.match(line)
        if m_res:
            resource_count = int(m_res.group(1))
            if args.allow_471_shutdown_noise and after_pass and engine_471:
                if resource_count <= args.max_resources:
                    continue
                return fail(args.stage, f"resource-shutdown-budget-exceeded:{resource_count}>{args.max_resources}")
            return fail(args.stage, "unexpected-resource-shutdown-diagnostic", line)

        if is_hard(line):
            return fail(args.stage, "hard-error-log", line)

    if args.allow_471_shutdown_noise and (objectdb_count is not None or resource_count is not None):
        print(
            "SYNESTHESIA_GODOT_SHUTDOWN_NOISE=ALLOW "
            f"stage={args.stage} engine=4.7.1 "
            f"objectdb={objectdb_count or 0}/{args.max_objectdb} "
            f"resources={resource_count or 0}/{args.max_resources}"
        )

    print(f"SYNESTHESIA_GODOT_LOG_GATE=PASS stage={args.stage}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
