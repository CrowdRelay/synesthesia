#!/usr/bin/env python3
"""Create a local Synestezja release pack without touching the game core."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Scaffold a Synestezja release pack")
    parser.add_argument("release_id", help="lowercase slug, e.g. brak-sygnalu")
    parser.add_argument("--title", required=True, help="visible release title")
    parser.add_argument("--room", default="Nowy pokój", help="room name")
    parser.add_argument("--activate", action="store_true", help="make it the active local release")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not SLUG_RE.fullmatch(args.release_id):
        print("release_id must be a lowercase hyphenated slug", file=sys.stderr)
        return 2

    root = Path(__file__).resolve().parents[1]
    pack_dir = root / "data" / "releases" / args.release_id
    manifest_path = pack_dir / "manifest.json"
    index_path = root / "data" / "release_index.json"

    if manifest_path.exists():
        print(f"release pack already exists: {manifest_path}", file=sys.stderr)
        return 3

    pack_dir.mkdir(parents=True)
    (pack_dir / "audio").mkdir()
    (pack_dir / "textures").mkdir()

    manifest = {
        "schema_version": 1,
        "release_id": args.release_id,
        "artist": "Virya",
        "title": args.title,
        "subtitle": "Wejdź na chwilę. Możesz wyjść w dowolnym momencie.",
        "room": {
            "name": args.room,
            "base_color": "#101827",
            "floor_color": "#080C14",
            "accent_color": "#71AFFF",
            "paint_palette": ["#72AFFF", "#B99CFF", "#7FD8C9", "#F3A7C3"],
            "completion_coverage": 0.44,
        },
        "sensory": {
            "default_mode": "calm",
            "visual_snow_calm": 0.02,
            "visual_snow_full": 0.05,
            "haptics_calm": 0.16,
            "haptics_full": 0.34,
            "safe_audio_ceiling_db": -7.0,
        },
        "audio": {"mode": "procedural", "stems": []},
        "collectibles": [
            {
                "id": "trace-1",
                "title": "Ślad pierwszy",
                "message": "Tu pojawi się fragment historii wydania.",
                "position": [0.25, 0.36],
                "symbol": "○",
            },
            {
                "id": "trace-2",
                "title": "Ślad drugi",
                "message": "Tu pojawi się kolejna warstwa.",
                "position": [0.73, 0.48],
                "symbol": "⌁",
            },
            {
                "id": "trace-3",
                "title": "Ślad trzeci",
                "message": "Tu pojawi się domknięcie pokoju.",
                "position": [0.48, 0.69],
                "symbol": "◇",
            },
        ],
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")

    index = json.loads(index_path.read_text())
    index["releases"].append(
        {
            "id": args.release_id,
            "manifest": f"res://data/releases/{args.release_id}/manifest.json",
            "available": True,
        }
    )
    if args.activate:
        index["active_release"] = args.release_id
    index_path.write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n")

    (pack_dir / "README.md").write_text(
        f"# {args.title}\n\n"
        "Włóż stemy do `audio/`, tekstury do `textures/` i uzupełnij `manifest.json`.\n"
    )
    print(f"created={manifest_path.relative_to(root)}")
    print(f"active={str(args.activate).lower()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
