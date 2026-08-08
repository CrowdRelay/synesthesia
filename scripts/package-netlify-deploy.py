#!/usr/bin/env python3
from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import os
import re
from pathlib import Path
import stat
import zipfile

PRECOMPRESSED = {
    ".wasm", ".pck", ".webp", ".png", ".jpg", ".jpeg", ".gif", ".avif",
    ".ogg", ".ogv", ".mp3", ".mp4", ".zip", ".gz", ".br", ".woff", ".woff2",
}
CHUNK_SIZE = 1024 * 1024



def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(CHUNK_SIZE), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create a deterministic, provenance-carrying artifact ready for Netlify's deploy API."
    )
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--source-sha", default=os.environ.get("GITHUB_SHA", "unknown"))
    parser.add_argument("--require", action="append", default=[])
    parser.add_argument("--require-glob", action="append", default=[])
    parser.add_argument("--max-files", type=int, default=25_000)
    parser.add_argument("--max-total-mib", type=int, default=160)
    parser.add_argument("--max-file-mib", type=int, default=128)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    source = args.source.resolve()
    output = args.output.resolve()
    if not source.is_dir():
        raise SystemExit(f"deploy source is not a directory: {source}")
    if not re.fullmatch(r"[0-9a-fA-F]{40}", args.source_sha):
        raise SystemExit("--source-sha must be a full 40-character Git commit SHA")
    args.source_sha = args.source_sha.lower()
    if args.max_files <= 0 or args.max_total_mib <= 0 or args.max_file_mib <= 0:
        raise SystemExit("deploy limits must be positive")

    discovered: list[tuple[str, Path, int]] = []
    for path in sorted(source.rglob("*"), key=lambda item: item.as_posix()):
        if path.is_symlink():
            raise SystemExit(f"refusing symlink in deploy tree: {path.relative_to(source)}")
        if not path.is_file():
            continue
        rel = path.relative_to(source).as_posix()
        if rel.startswith("/") or rel == ".." or rel.startswith("../") or "/../" in rel:
            raise SystemExit(f"unsafe deploy path: {rel}")
        size = path.stat().st_size
        if size > args.max_file_mib * 1024 * 1024:
            raise SystemExit(
                f"deploy file exceeds {args.max_file_mib} MiB: {rel} ({size} bytes)"
            )
        discovered.append((rel, path, size))

    if not discovered:
        raise SystemExit("deploy tree is empty")
    if len(discovered) > args.max_files:
        raise SystemExit(
            f"deploy has {len(discovered)} files; Netlify ZIP extraction limit is {args.max_files}"
        )

    total_bytes = sum(item[2] for item in discovered)
    if total_bytes > args.max_total_mib * 1024 * 1024:
        raise SystemExit(
            f"deploy tree exceeds {args.max_total_mib} MiB: {total_bytes} bytes"
        )

    paths = {item[0] for item in discovered}
    for required in args.require:
        if required not in paths:
            raise SystemExit(f"required deploy file is missing: {required}")
    for pattern in args.require_glob:
        if not any(fnmatch.fnmatch(path, pattern) for path in paths):
            raise SystemExit(f"required deploy glob has no match: {pattern}")

    output.parent.mkdir(parents=True, exist_ok=True)
    tmp = output.with_name(output.name + ".tmp")
    tmp.unlink(missing_ok=True)
    file_manifest: list[dict[str, object]] = []
    with zipfile.ZipFile(tmp, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for rel, path, size in discovered:
            info = zipfile.ZipInfo(rel, date_time=(1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            info.file_size = size
            info.compress_type = (
                zipfile.ZIP_STORED if path.suffix.lower() in PRECOMPRESSED else zipfile.ZIP_DEFLATED
            )
            sha1 = hashlib.sha1(usedforsecurity=False)
            sha256 = hashlib.sha256()
            written = 0
            with path.open("rb") as source_handle, archive.open(info, "w") as zip_handle:
                for chunk in iter(lambda: source_handle.read(CHUNK_SIZE), b""):
                    zip_handle.write(chunk)
                    sha1.update(chunk)
                    sha256.update(chunk)
                    written += len(chunk)
            if written != size:
                raise SystemExit(
                    f"deploy source changed while packaging: {rel} expected={size} actual={written}"
                )
            file_manifest.append(
                {"path": rel, "bytes": size, "sha1": sha1.hexdigest(), "sha256": sha256.hexdigest()}
            )
    tmp.replace(output)

    archive_sha = sha256_file(output)
    manifest = {
        "schema": 2,
        "source_sha": args.source_sha,
        "file_count": len(discovered),
        "uncompressed_bytes": total_bytes,
        "archive": output.name,
        "archive_bytes": output.stat().st_size,
        "archive_sha256": archive_sha,
        "files": file_manifest,
    }
    manifest_path = output.with_name(output.name + ".manifest.json")
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    sha_path = output.with_name(output.name + ".sha256")
    sha_path.write_text(f"{archive_sha}  {output.name}\n", encoding="utf-8")

    print(
        "NETLIFY_DEPLOY_PACKAGE=PASS "
        f"schema=2 source_sha={args.source_sha} files={len(discovered)} "
        f"uncompressed_bytes={total_bytes} zip_bytes={output.stat().st_size} sha256={archive_sha}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
