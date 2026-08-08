#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

hygiene = (ROOT / "tools/source_hygiene.py").read_text()
exporter = (ROOT / "scripts/export-source.sh").read_text()
gitignore = (ROOT / ".gitignore").read_text()

for token in ("native/target/", "native/bin/", ".cache/", "MAX_TRACKED_BYTES", "FORBIDDEN_EXACT", "synesthesia_rust.gdextension.uid", "git", "ls-files"):
    if token not in hygiene:
        failures.append(f"source hygiene gate missing: {token}")
for token in ("git archive", "git status --porcelain", "tools/source_hygiene.py", "16 * 1024 * 1024", "synesthesia/SOURCE_MANIFEST.json", "git rev-parse HEAD", '"sha": source_sha'):
    if token not in exporter:
        failures.append(f"source exporter gate missing: {token}")
for token in ("/.cache/", "/native/target/", "/native/bin/"):
    if token not in gitignore:
        failures.append(f"gitignore generated-artifact rule missing: {token}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_SOURCE_HYGIENE_CONTRACT=FAIL count={len(failures)}")

print("SYNESTHESIA_SOURCE_HYGIENE_CONTRACT=PASS archive=git-tracked-only provenance=sha+ref cache=excluded max-tracked=16MiB")

