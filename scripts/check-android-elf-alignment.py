#!/usr/bin/env python3
"""Verify that arm64 native libraries inside an Android App Bundle support 16 KiB pages."""
from __future__ import annotations

import argparse
import re
import subprocess
import tempfile
import zipfile
from pathlib import Path

MIN_ALIGN = 16 * 1024


def find_readelf(ndk: Path) -> Path:
    candidates = sorted((ndk / "toolchains" / "llvm" / "prebuilt").glob("*/bin/llvm-readelf"))
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    raise SystemExit(f"llvm-readelf not found under NDK: {ndk}")


def load_alignments(readelf: Path, binary: Path) -> list[int]:
    proc = subprocess.run(
        [str(readelf), "-lW", str(binary)],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    alignments: list[int] = []
    for line in proc.stdout.splitlines():
        stripped = line.strip()
        if not stripped.startswith("LOAD "):
            continue
        fields = stripped.split()
        try:
            alignments.append(int(fields[-1], 0))
        except (IndexError, ValueError) as exc:
            raise SystemExit(f"cannot parse LOAD alignment from: {line}") from exc
    if not alignments:
        raise SystemExit(f"no PT_LOAD segments found in {binary.name}")
    return alignments


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("aab", type=Path)
    parser.add_argument("ndk", type=Path)
    args = parser.parse_args()

    if not args.aab.is_file():
        parser.error(f"AAB not found: {args.aab}")
    readelf = find_readelf(args.ndk)

    with zipfile.ZipFile(args.aab) as archive:
        names = [
            name for name in archive.namelist()
            if re.search(r"(^|/)lib/arm64-v8a/[^/]+\.so$", name)
        ]
        if not names:
            raise SystemExit("AAB contains no arm64-v8a shared libraries")
        if not any(name.endswith("/libsynesthesia_gdext.so") for name in names):
            raise SystemExit("AAB is missing arm64 libsynesthesia_gdext.so")

        with tempfile.TemporaryDirectory(prefix="synesthesia-aab-elf-") as tmp:
            tmpdir = Path(tmp)
            for index, name in enumerate(names):
                target = tmpdir / f"{index}-{Path(name).name}"
                target.write_bytes(archive.read(name))
                alignments = load_alignments(readelf, target)
                bad = [value for value in alignments if value < MIN_ALIGN]
                if bad:
                    rendered = ", ".join(hex(value) for value in alignments)
                    raise SystemExit(
                        f"16K_PAGE_ALIGNMENT=FAIL entry={name} PT_LOAD={rendered}"
                    )
                print(
                    f"16K_PAGE_ALIGNMENT=PASS entry={name} "
                    f"min={hex(min(alignments))}"
                )

    print(f"SYNESTHESIA_AAB_16K=PASS libraries={len(names)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
