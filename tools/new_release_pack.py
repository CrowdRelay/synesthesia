#!/usr/bin/env python3
"""Scaffold one schema-v4 production room pack.

The generator creates the manifest, a dedicated room PackedScene, a room behaviour
script and lightweight vertical SVG placeholders. Replace the placeholders with
final 9:16 art without changing the manifest paths.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
STYLE_CHOICES = (
    "uncertainty", "party", "unmasked", "calling", "seed", "hybrid",
    "technophobia", "invaluable", "ashes", "waves", "rise",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Scaffold a Synestezja production room pack")
    parser.add_argument("release_id", help="lowercase slug, e.g. brak-sygnalu")
    parser.add_argument("--title", required=True, help="visible release title")
    parser.add_argument("--room", default="Nowy pokój", help="room name")
    parser.add_argument("--style", choices=STYLE_CHOICES, default="uncertainty")
    parser.add_argument("--excerpt", default="", help="res:// path to the room music excerpt")
    parser.add_argument("--position", type=int, help="0-based insertion position in the album")
    parser.add_argument("--activate", action="store_true", help="make it the active local room")
    return parser.parse_args()


def write_svg(path: Path, title: str, foreground: str, background: str, blurred: bool) -> None:
    width, height = (540, 960) if blurred else (810, 1440)
    title_safe = (title.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))
    blur = '<filter id="b"><feGaussianBlur stdDeviation="36"/></filter>' if blurred else ""
    filter_attr = ' filter="url(#b)"' if blurred else ""
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
<defs>{blur}<linearGradient id="g" x2="0" y2="1"><stop stop-color="{background}"/><stop offset="1" stop-color="#03050a"/></linearGradient></defs>
<rect width="100%" height="100%" fill="url(#g)"/>
<circle cx="{width * 0.5:.0f}" cy="{height * 0.46:.0f}" r="{width * 0.32:.0f}" fill="{foreground}" opacity="0.24"{filter_attr}/>
<path d="M0 {height * 0.68:.0f} Q {width * 0.26:.0f} {height * 0.54:.0f} {width * 0.52:.0f} {height * 0.68:.0f} T {width:.0f} {height * 0.64:.0f} V {height} H0Z" fill="{foreground}" opacity="0.16"/>
<text x="50%" y="88%" text-anchor="middle" fill="#f4f6ff" opacity="0.72" font-family="sans-serif" font-size="{max(18, width // 22)}">{title_safe}</text>
</svg>'''
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(svg)


def main() -> int:
    args = parse_args()
    if not SLUG_RE.fullmatch(args.release_id):
        print("release_id must be a lowercase hyphenated slug", file=sys.stderr)
        return 2

    root = Path(__file__).resolve().parents[1]
    pack_dir = root / "data" / "releases" / args.release_id
    manifest_path = pack_dir / "manifest.json"
    index_path = root / "data" / "release_index.json"
    behavior_path = root / "scripts" / "rooms" / "behaviors" / f"{args.release_id}.gd"
    scene_path = root / "scenes" / "rooms" / f"{args.release_id}.tscn"
    scene_art_path = root / "assets" / "rooms" / "vertical" / f"{args.release_id}-scene.svg"
    background_art_path = root / "assets" / "rooms" / "vertical" / f"{args.release_id}-bg.svg"
    subject_art_path = root / "assets" / "rooms" / "vertical" / f"{args.release_id}-subject.svg"
    foreground_art_path = root / "assets" / "rooms" / "vertical" / f"{args.release_id}-foreground.svg"

    conflicts = [p for p in (manifest_path, behavior_path, scene_path, scene_art_path, background_art_path, subject_art_path, foreground_art_path) if p.exists()]
    if conflicts:
        print(f"release pack already exists: {conflicts[0]}", file=sys.stderr)
        return 3

    index = json.loads(index_path.read_text())
    releases = index.get("releases")
    if not isinstance(releases, list):
        print("release index has no releases array", file=sys.stderr)
        return 4
    if any(isinstance(item, dict) and item.get("id") == args.release_id for item in releases):
        print("release_id already exists in the index", file=sys.stderr)
        return 5
    if args.position is not None and not 0 <= args.position <= len(releases):
        print("--position is outside the current album range", file=sys.stderr)
        return 6

    pack_dir.mkdir(parents=True)
    behavior_path.parent.mkdir(parents=True, exist_ok=True)
    scene_path.parent.mkdir(parents=True, exist_ok=True)
    excerpt = args.excerpt.strip() or f"res://assets/audio/{args.release_id}-room-outro.mp3"

    manifest = {
        "schema_version": 4,
        "release_id": args.release_id,
        "story_order": 0,
        "artist": "VIRYA",
        "title": args.title,
        "subtitle": "Odkrywaj bez pośpiechu. Możesz uspokoić pokój w każdej chwili.",
        "room": {
            "id": args.release_id,
            "name": args.room,
            "scene_path": f"res://scenes/rooms/{args.release_id}.tscn",
            "behavior_script": f"res://scripts/rooms/behaviors/{args.release_id}.gd",
            "render_pipeline": "mask-gpu-v1",
            "visual_style": args.style,
            "interaction": "paint",
            "base_color": "#101827",
            "floor_color": "#080C14",
            "accent_color": "#71AFFF",
            "secondary_color": "#B99CFF",
            "paint_palette": ["#72AFFF", "#B99CFF", "#7FD8C9", "#F3A7C3"],
            "completion_coverage": 0.48,
            "cinematic_reveal_at": 0.99,
            "brush": {
                "profile": "soft", "min_width": 28, "max_width": 60,
                "opacity": 0.78, "texture": 0.48, "outline": 0.62, "spacing": 0.66,
            },
            "art_direction": {
                "style": "dark_comic",
                "caption": args.room.upper(),
                "ink_strength": 0.70,
                "halftone_strength": 0.22,
                "scene_image": f"res://assets/rooms/vertical/{args.release_id}-scene.svg",
                "background_image": f"res://assets/rooms/vertical/{args.release_id}-bg.svg",
                "subject_image": f"res://assets/rooms/vertical/{args.release_id}-subject.svg",
                "foreground_image": f"res://assets/rooms/vertical/{args.release_id}-foreground.svg",
                "scene_opacity": 1.0,
                "scene_parallax": 0.009,
                "background_parallax": 0.004,
                "subject_parallax": 0.014,
                "foreground_parallax": 0.022,
                "layers": ["background", "scene", "subject", "foreground", "atmosphere"],
                "material_pass": "production-2.5d",
            },
        },
        "sensory": {
            "default_mode": "calm", "visual_snow_calm": 0.022, "visual_snow_full": 0.055,
            "visual_snow_tint": "#C6DEFF", "scanline_strength": 0.32,
            "roll_strength": 0.18, "sparkle_density": 0.24, "horizontal_jitter": 0.08,
            "static_motion_calm": 0.16, "static_motion_full": 0.42,
            "haptics_calm": 0.16, "haptics_full": 0.34, "safe_audio_ceiling_db": -7.0,
        },
        "audio": {
            "mode": "pink_noise_reveal_mix", "title": args.title,
            "completion_excerpt": excerpt,
            "noise_loop": "res://assets/audio/pink-noise-asmr-loop.ogg",
            "pink_noise_start_db": -5.0, "hidden_music_db": -44.0,
            "completion_volume_db": -8.0, "lowpass_start_hz": 1000.0,
            "lowpass_final_hz": 19500.0, "stereo_reveal": True,
            "dynamic_space_reveal": True, "source": "VIRYA",
            "note": "Painting reveals volume, frequency range and stereo space; at 99% noise and filtering are gone.",
        },
        "collectibles": [
            {"id": "trace-1", "title": "Ślad pierwszy", "message": "Pierwsza warstwa historii pokoju.", "position": [0.25, 0.36], "symbol": "○"},
            {"id": "trace-2", "title": "Ślad drugi", "message": "Druga warstwa historii pokoju.", "position": [0.73, 0.48], "symbol": "⌁"},
            {"id": "trace-3", "title": "Ślad trzeci", "message": "Domknięcie pokoju.", "position": [0.48, 0.69], "symbol": "◇"},
        ],
        "intro": "Maluj bez pośpiechu. Pokój odpowie kolorem, ruchem i dźwiękiem.",
        "completion_title": "Pokój został odsłonięty",
        "completion_message": "Filtr ustąpił. Posłuchaj finału i przejdź dalej, gdy będziesz gotowy.",
    }

    behavior_path.write_text(f'''extends "res://scripts/rooms/behavior_base.gd"\n\nfunc configure(data: Dictionary) -> void:\n    super.configure(data)\n\nfunc acts() -> Array[String]:\n    return ["WEJŚCIE", "PRZEMIANA", "ODSŁONIĘCIE"]\n''')
    scene_path.write_text(f'''[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/render/room_stage.gd" id="1"]\n\n[node name="{args.release_id}" type="Control"]\nlayout_mode = 3\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2\nscript = ExtResource("1")\nroom_id = "{args.release_id}"\n''')
    write_svg(scene_art_path, args.title, "#71AFFF", "#101827", False)
    write_svg(background_art_path, args.title, "#B99CFF", "#080C14", True)
    write_svg(subject_art_path, "", "#71AFFF", "#00000000", False)
    write_svg(foreground_art_path, "", "#B99CFF", "#00000000", False)

    entry = {"id": args.release_id, "manifest": f"res://data/releases/{args.release_id}/manifest.json", "available": True}
    if args.position is None:
        releases.append(entry)
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
        elif indexed_path.is_file():
            indexed_data = json.loads(indexed_path.read_text())
            if isinstance(indexed_data, dict):
                indexed_data["story_order"] = position
                indexed_path.write_text(json.dumps(indexed_data, ensure_ascii=False, indent=2) + "\n")

    index["schema_version"] = 4
    if args.activate:
        index["active_release"] = args.release_id
    index_path.write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n")

    print(f"created={manifest_path.relative_to(root)}")
    print(f"scene={scene_path.relative_to(root)}")
    print(f"behavior={behavior_path.relative_to(root)}")
    print(f"excerpt={excerpt}")
    print(f"active={str(args.activate).lower()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
