#!/usr/bin/env python3
"""Exercise the room scaffolder in an isolated miniature repository."""
from __future__ import annotations
import json, shutil, subprocess, sys, tempfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="synesthesia-pack-") as temp:
    target = Path(temp) / "project"
    for rel in (
        "tools/new_release_pack.py", "data/release_index.json", "data/releases",
        "scripts/rooms/behavior_base.gd", "scripts/rooms/behaviors",
        "scenes/rooms", "assets/rooms/vertical",
    ):
        source = ROOT / rel
        destination = target / rel
        destination.parent.mkdir(parents=True, exist_ok=True)
        if source.is_dir():
            shutil.copytree(source, destination)
        else:
            shutil.copy2(source, destination)
    command = [
        sys.executable, str(target / "tools/new_release_pack.py"), "contract-room",
        "--title", "VIRYA: Contract Room", "--room", "Sala kontraktu",
        "--style", "uncertainty", "--position", "2",
    ]
    result = subprocess.run(command, cwd=target, text=True, capture_output=True)
    if result.returncode != 0:
        print(result.stdout, end="")
        print(result.stderr, end="", file=sys.stderr)
        raise SystemExit(result.returncode)
    index = json.loads((target / "data/release_index.json").read_text())
    releases = index["releases"]
    assert len(releases) == 12, len(releases)
    assert releases[2]["id"] == "contract-room"
    for position, entry in enumerate(releases):
        path = target / entry["manifest"].removeprefix("res://")
        manifest = json.loads(path.read_text())
        assert manifest["story_order"] == position, (entry["id"], manifest["story_order"], position)
    manifest = json.loads((target / "data/releases/contract-room/manifest.json").read_text())
    art = manifest["room"]["art_direction"]
    assert art["layers"] == ["background", "scene", "subject", "foreground", "atmosphere"]
    expected_sizes = {
        "scene_image": (675, 1200),
        "background_image": (405, 720),
        "subject_image": (675, 1200),
        "foreground_image": (540, 960),
    }
    for key, (width, height) in expected_sizes.items():
        art_path = target / art[key].removeprefix("res://")
        assert art_path.is_file(), key
        svg = art_path.read_text()
        assert f'width="{width}" height="{height}"' in svg, (key, width, height)
    behavior = (target / "scripts/rooms/behaviors/contract-room.gd").read_text()
    assert "func configure(data: Dictionary)" in behavior
    assert "func acts() -> Array[String]" in behavior
    assert "host_node" not in behavior
    scene = (target / "scenes/rooms/contract-room.tscn").read_text()
    assert 'room_id = "contract-room"' in scene
print("SYNESTHESIA_RELEASE_PACK_CONTRACT=PASS inserted=2 rooms=12")
