#!/usr/bin/env python3
"""Fail if generated build/cache artifacts become tracked source."""
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAX_TRACKED_BYTES = 16 * 1024 * 1024
FORBIDDEN_PREFIXES = (
    ".cache/",
    ".godot/",
    "build/",
    "builds/",
    "exports/",
    "native/target/",
    "native/bin/",
    "native/android-out/",
)
FORBIDDEN_SUFFIXES = (".rlib", ".rmeta", ".dylib", ".so", ".apk", ".aab", ".tpz", ".orig", ".rej", "~")
FORBIDDEN_EXACT = ("synesthesia_rust.gdextension", "synesthesia_rust.gdextension.uid")
REQUIRED_IGNORES = (
    ".godot/",
    "build/",
    "/.cache/",
    "/native/target/",
    "/native/bin/",
    "synesthesia_rust.gdextension",
    "synesthesia_rust.gdextension.uid",
    "assets/fonts/generated/*.ttf",
    "*.backup-*",
    "*.orig",
    "*.rej",
)

failures: list[str] = []
ignore = (ROOT / ".gitignore").read_text().splitlines()
ignore_set = {line.strip() for line in ignore if line.strip() and not line.lstrip().startswith("#")}
for required in REQUIRED_IGNORES:
    if required not in ignore_set:
        failures.append(f"required .gitignore rule missing: {required}")

tracked: list[str] = []
if (ROOT / ".git").exists() and shutil.which("git"):
    result = subprocess.run(
        ["git", "-C", str(ROOT), "ls-files", "-z"],
        check=True,
        stdout=subprocess.PIPE,
    )
    tracked = [item.decode() for item in result.stdout.split(b"\0") if item]
    for rel in tracked:
        normalized = rel.replace("\\", "/")
        if normalized.startswith(FORBIDDEN_PREFIXES):
            failures.append(f"generated path is tracked: {normalized}")
        if normalized.endswith(FORBIDDEN_SUFFIXES):
            failures.append(f"generated binary is tracked: {normalized}")
        if normalized in FORBIDDEN_EXACT:
            failures.append(f"generated descriptor state is tracked: {normalized}")
        path = ROOT / rel
        if path.is_file() and path.stat().st_size > MAX_TRACKED_BYTES:
            failures.append(
                f"tracked file exceeds {MAX_TRACKED_BYTES // (1024 * 1024)} MiB source budget: "
                f"{normalized} ({path.stat().st_size} bytes)"
            )

# Backups/rejects are source-tree debris even when this archive has no .git metadata.
for path in ROOT.rglob("*"):
    if not path.is_file():
        continue
    rel = path.relative_to(ROOT).as_posix()
    name = path.name
    if ".backup-" in name or name.endswith((".orig", ".rej", "~")):
        failures.append(f"source debris present: {rel}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_SOURCE_HYGIENE=FAIL count={len(failures)}")

mode = "tracked-files" if tracked else "ignore-contract"
print(
    "SYNESTHESIA_SOURCE_HYGIENE=PASS "
    f"mode={mode} tracked={len(tracked)} max_file_mib={MAX_TRACKED_BYTES // (1024 * 1024)} "
    "generated=excluded"
)
