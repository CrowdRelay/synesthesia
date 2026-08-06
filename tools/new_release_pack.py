#!/usr/bin/env python3
"""Scaffold one local Synestezja room pack using the schema v3 contract."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
STYLE_CHOICES = (
    "uncertainty",
    "party",
    "unmasked",
    "calling",
    "seed",
    "hybrid",
    "technophobia",
    "invaluable",
    "ashes",
    "waves",
    "rise",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Scaffold a Synestezja room pack")
    parser.add_argument("release_id", help="lowercase slug, e.g. brak-sygnalu")
    parser.add_argument("--title", required=True, help="visible release title")
    parser.add_argument("--room", default="Nowy pokój", help="room name")
    parser.add_argument("--style", choices=STYLE_CHOICES, default="uncertainty")
    parser.add_argument("--excerpt", default="", help="res:// path to a completion MP3")
    parser.add_argument("--position", type=int, help="0-based insertion position in the album")
    parser.add_argument("--activate", action="store_true", help="make it the active local room")
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

    index = json.loads(index_path.read_text())
    releases = index.get("releases")
    if not isinstance(releases, list):
        print("release index has no releases array", file=sys.stderr)
        return 4
    if any(isinstance(item, dict) and item.get("id") == args.release_id for item in releases):
        print("release_id already exists in the index", file=sys.stderr)
        return 5

    pack_dir.mkdir(parents=True)
    excerpt = args.excerpt.strip() or f"res://assets/audio/{args.release_id}-room-outro.mp3"
    manifest = {
        "schema_version": 3,
        "release_id": args.release_id,
        "story_order": 0,
        "artist": "VIRYA",
        "title": args.title,
        "subtitle": "Odkrywaj bez pośpiechu. Możesz uspokoić pokój w każdej chwili.",
        "room": {
            "name": args.room,
            "visual_style": args.style,
            "base_color": "#101827",
            "floor_color": "#080C14",
            "accent_color": "#71AFFF",
            "secondary_color": "#B99CFF",
            "paint_palette": ["#72AFFF", "#B99CFF", "#7FD8C9", "#F3A7C3"],
            "completion_coverage": 0.48,
            "cinematic_reveal_at": 0.99,
            "interaction": "paint",
        },
        "sensory": {
            "default_mode": "calm",
            "visual_snow_calm": 0.022,
            "visual_snow_full": 0.055,
            "haptics_calm": 0.16,
            "haptics_full": 0.34,
            "safe_audio_ceiling_db": -7.0,
        },
        "audio": {
            "mode": "procedural_then_excerpt",
            "title": args.title,
            "completion_excerpt": excerpt,
            "completion_volume_db": -12.0,
            "source": "VIRYA — Echoes Of The Modern Mind",
        },
        "collectibles": [
            {
                "id": "trace-1",
                "title": "Ślad pierwszy",
                "message": "Pierwsza warstwa historii pokoju.",
                "position": [0.25, 0.36],
                "symbol": "○",
            },
            {
                "id": "trace-2",
                "title": "Ślad drugi",
                "message": "Druga warstwa historii pokoju.",
                "position": [0.73, 0.48],
                "symbol": "⌁",
            },
            {
                "id": "trace-3",
                "title": "Ślad trzeci",
                "message": "Domknięcie pokoju.",
                "position": [0.48, 0.69],
                "symbol": "◇",
            },
        ],
        "intro": "Maluj bez pośpiechu. Pokój odpowie kolorem, ruchem i dźwiękiem.",
        "completion_title": "Pokój został odsłonięty",
        "completion_message": "Filtr ustąpił. Posłuchaj finału i przejdź dalej, gdy będziesz gotowy.",
    }
    entry = {
        "id": args.release_id,
        "manifest": f"res://data/releases/{args.release_id}/manifest.json",
        "available": True,
    }
    if args.position is None:
        releases.append(entry)
    elif not 0 <= args.position <= len(releases):
        print("--position is outside the current album range", file=sys.stderr)
        pack_dir.rmdir()
        return 6
    else:
        releases.insert(args.position, entry)

    for position, indexed_entry in enumerate(releases):
        if not isinstance(indexed_entry, dict):
            continue
        indexed_manifest = indexed_entry.get("manifest")
        if not isinstance(indexed_manifest, str) or not indexed_manifest.startswith("res://"):
            continue
        indexed_path = root / indexed_manifest.removeprefix("res://")
        if indexed_path == manifest_path:
            manifest["story_order"] = position
            indexed_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
            continue
        if not indexed_path.is_file():
            continue
        indexed_data = json.loads(indexed_path.read_text())
        if isinstance(indexed_data, dict):
            indexed_data["story_order"] = position
            indexed_path.write_text(json.dumps(indexed_data, ensure_ascii=False, indent=2) + "\n")

    if args.activate:
        index["active_release"] = args.release_id
    index_path.write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n")

    print(f"created={manifest_path.relative_to(root)}")
    print(f"excerpt={excerpt}")
    print(f"active={str(args.activate).lower()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
