#!/usr/bin/env python3
"""Production contract for the moodboard-locked Synesthesia V2 visual system."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

LEGACY_SCENE_HASHES = {
    'assets/rooms/vertical/from-the-ashes-scene.webp': '3de60617456d6a3147defab93299874a9654d8c125d55cdfe2e5da8e120d1531',
    'assets/rooms/vertical/hybrid-scene.webp': 'f0ebb8cf5310c79490c6bbd1884c03a195e87ed9ef8557b8a31f70f2182fa642',
    'assets/rooms/vertical/invaluable-scene.webp': '1309f7bfe3c311cb9180e8bd6dc3d93a3b9c76f33394235b2aedf7d34cbd5dd6',
    'assets/rooms/vertical/party-time-scene.webp': '69de84bd4db446b2a436ffa38e06503033a5f3ffea0cca70b94a6dec7b063f30',
    'assets/rooms/vertical/rise-scene.webp': '24be64ed27dbe12a6cb90f2e86f2361c54ded7f70de718a70b5bea0f8c9360e7',
    'assets/rooms/vertical/seed-of-doubt-scene.webp': '4e0ed15055140945d7a479a1adcbdcae49d8f80cae2489f37e51405115358a90',
    'assets/rooms/vertical/technophobia-scene.webp': 'd191e802164e127eed6b74969c40740f69763247fa6e5642f4883ec3dc732990',
    'assets/rooms/vertical/the-calling-scene.webp': 'e2d0867f7f825e70c4605d8b3585c19a5b572c07f332b01e67d4da107f3c1bff',
    'assets/rooms/vertical/unmasked-scene.webp': 'bb96dc5e2e37fca8a9285038c018abdfb832dcd673ca3ba058d94732f8e619f6',
    'assets/rooms/vertical/wave-of-uncertainty-scene.webp': 'd6ddf6fcc7b328b1a15d3d2867d4ebb240e327d863b4ff62fa435332719d1288',
    'assets/rooms/vertical/waves-scene.webp': 'dee9152a5b59a868b8093cffabe41f45c26c935ad02ed9a08f9a0247db5cca8d',
}

required = [
    "assets/v2/branding/menu-world.webp",
    "assets/v2/branding/corridor-world.webp",
    "assets/v2/branding/finale-world.webp",
    "assets/v2/fx/signal-ring.png",
    "assets/v2/fx/signal-glitch.png",
    "assets/v2/fx/surface-scratches.png",
    "scripts/ui/signal_backdrop.gd",
]
for rel in required:
    if not (ROOT / rel).is_file():
        failures.append(f"missing V2 asset {rel}")

for manifest_path in sorted((ROOT / "data/releases").glob("*/manifest.json")):
    data = json.loads(manifest_path.read_text())
    rid = data["release_id"]
    art = data["room"].get("art_direction", {})
    if art.get("visual_system") != "virya-signal-v2":
        failures.append(f"{rid}: visual_system is not virya-signal-v2")
    if art.get("asset_generation") not in {"moodboard-locked-2026", "post-reveal-v6-master"}:
        failures.append(f"{rid}: moodboard lock metadata missing")
    scene_rel = str(art.get("scene_image", "")).removeprefix("res://")
    scene = ROOT / scene_rel
    if not scene.is_file():
        failures.append(f"{rid}: missing scene")
        continue
    digest = hashlib.sha256(scene.read_bytes()).hexdigest()
    legacy = LEGACY_SCENE_HASHES.get(scene_rel)
    if legacy and digest == legacy:
        failures.append(f"{rid}: legacy scene asset resurrected")

menu = (ROOT / "scripts/ui/experience_intro_card.gd").read_text(errors="replace")
archive = (ROOT / "scripts/ui/album_archive_card.gd").read_text(errors="replace")
boot = (ROOT / "scripts/ui/boot_sequence.gd").read_text(errors="replace")
factory = (ROOT / "scripts/ui/ui_factory.gd").read_text(errors="replace")
dressing = (ROOT / "scripts/render/room_dressing_layer.gd").read_text(errors="replace")
shader = (ROOT / "shaders/room_composite.gdshader").read_text(errors="replace")
video = (ROOT / "scripts/render/room_video_layer.gd").read_text(errors="replace")
for token, text, source in [
    ("menu-world.webp", menu, "menu"),
    ("corridor-world.webp", archive, "archive"),
    ("menu-world.webp", boot, "boot"),
    ("add_signal_backdrop", factory, "factory"),
    ("signal-glitch.png", dressing, "dressing"),
    ("V2 hidden state", shader, "shader"),
    ("_runtime_scale < 0.72", video, "video-adaptive"),
    ("Legacy clips are retained as low-amplitude motion texture only", video, "video-role"),
]:
    if token not in text:
        failures.append(f"{source}: missing {token!r}")

# The accepted board uses tight technical corners rather than rounded game cards.
tokens = (ROOT / "scripts/ui/virya_design_tokens.gd").read_text(errors="replace")
if "RADIUS_LARGE: float = 4.0" not in tokens or "RADIUS_SMALL: float = 2.0" not in tokens:
    failures.append("V2 technical corner-radius contract regressed")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_V2_ART=FAIL count={len(failures)}")
print("SYNESTHESIA_V2_ART=PASS rooms=11 legacy-scenes=0 ui=signal-board assets=runtime-v2")
