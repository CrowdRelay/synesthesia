#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

command -v git >/dev/null 2>&1 || { echo 'ERROR: git is required' >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo 'ERROR: python3 is required' >&2; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo 'ERROR: run from a Git checkout' >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || {
  echo 'ERROR: source export requires a clean Git tree so the archive cannot silently omit local changes' >&2
  exit 1
}

python3 tools/source_hygiene.py

default_name="synesthesia-source-$(git rev-parse --short=12 HEAD).zip"
out="${1:-$ROOT/build/source/$default_name}"
mkdir -p "$(dirname "$out")"
rm -f "$out"

git archive --format=zip --prefix=synesthesia/ HEAD -o "$out"

source_sha="$(git rev-parse HEAD)"
source_ref="$(git symbolic-ref --quiet --short HEAD || printf detached)"
python3 - "$out" "$source_sha" "$source_ref" <<'PY'
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile
import sys

archive = Path(sys.argv[1])
source_sha = sys.argv[2]
source_ref = sys.argv[3]
forbidden = (
    "/.cache/", "/.godot/", "/build/", "/builds/", "/exports/",
    "/native/target/", "/native/bin/", "/native/android-out/",
)
with ZipFile(archive, "a", compression=ZIP_DEFLATED) as zf:
    import json
    zf.writestr(
        "synesthesia/SOURCE_MANIFEST.json",
        json.dumps({"repository": "synesthesia", "ref": source_ref, "sha": source_sha}, sort_keys=True, separators=(",", ":")) + "\n",
    )

with ZipFile(archive) as zf:
    bad = [info.filename for info in zf.infolist() if any(token in f"/{info.filename}" for token in forbidden)]
    huge = [(info.filename, info.file_size) for info in zf.infolist() if info.file_size > 16 * 1024 * 1024]
if bad or huge:
    for path in bad:
        print(f"FAIL generated path in archive: {path}", file=sys.stderr)
    for path, size in huge:
        print(f"FAIL oversized source file: {path} bytes={size}", file=sys.stderr)
    raise SystemExit(2)
PY

sha="$(shasum -a 256 "$out" 2>/dev/null | awk '{print $1}' || sha256sum "$out" | awk '{print $1}')"
printf 'SYNESTHESIA_SOURCE_EXPORT=PASS output=%s bytes=%s sha256=%s\n' \
  "$out" "$(wc -c < "$out" | tr -d ' ')" "$sha"
