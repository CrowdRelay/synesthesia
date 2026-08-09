#!/usr/bin/env python3
"""Contract for lazy native-resolution cinematic loops and bounded Web payload."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VIDEO_DIR = ROOT / "assets/video"
STYLES = [
    "uncertainty", "party", "unmasked", "calling", "seed", "hybrid",
    "technophobia", "invaluable", "ashes", "waves", "rise", "finale",
]
SOURCE_NAMES = {
    "uncertainty": "wave.mp4", "party": "party.mp4", "unmasked": "unmasked.mp4",
    "calling": "calling.mp4", "seed": "seed.mp4", "hybrid": "hybrid.mp4",
    "technophobia": "technophobia.mp4", "invaluable": "invaluable.mp4",
    "ashes": "fromtheashes.mp4", "waves": "waves.mp4", "rise": "rise.mp4",
    "finale": "echoes.mp4",
}
failures: list[str] = []

manifest_path = VIDEO_DIR / "manifest.json"
if not manifest_path.is_file():
    failures.append("assets/video/manifest.json missing")
    manifest = {}
else:
    manifest = json.loads(manifest_path.read_text())

clips = manifest.get("clips", {}) if isinstance(manifest, dict) else {}
if manifest.get("codec") != "Ogg Theora":
    failures.append("cinematic codec must be Ogg Theora")
if manifest.get("source_resolution") != "720x1280":
    failures.append("cinematic source provenance must remain 720x1280")
if manifest.get("resolution") != "720x1280" or manifest.get("fps") != 24:
    failures.append("cinematics must stay at native 720x1280 source resolution and 24 fps")
if manifest.get("runtime_profile") != "native-source-resolution-theora-q5":
    failures.append("cinematic runtime profile must explicitly forbid the old FHD upscale")
if manifest.get("loop_endpoint_policy") != "forward-full+reverse-without-duplicated-endpoints":
    failures.append("cinematic loop endpoint policy must prevent ping-pong turn-around stutter")
if sorted(clips) != sorted(STYLES):
    failures.append("cinematic manifest must contain exact 11 rooms + finale")
total_bytes = 0
for style in STYLES:
    meta = clips.get(style, {})
    path = VIDEO_DIR / f"{style}.ogv"
    if not path.is_file():
        failures.append(f"missing cinematic: {style}.ogv")
        continue
    data = path.read_bytes()
    total_bytes += len(data)
    if data[:4] != b"OggS":
        failures.append(f"{style}.ogv is not an Ogg stream")
    if len(data) < 300_000:
        failures.append(f"{style}.ogv unexpectedly tiny: {len(data)}")
    if len(data) > 4_000_000:
        failures.append(f"{style}.ogv exceeds per-clip budget: {len(data)}")
    if meta.get("width") != 720 or meta.get("height") != 1280 or meta.get("fps") != 24:
        failures.append(f"{style}: manifest geometry/fps mismatch")
    if meta.get("source") != SOURCE_NAMES[style]:
        failures.append(f"{style}: original 720p source provenance mismatch")
    if meta.get("bytes") != len(data):
        failures.append(f"{style}: manifest byte count mismatch")
    if meta.get("sha256") != hashlib.sha256(data).hexdigest():
        failures.append(f"{style}: manifest sha256 mismatch")
    duration = float(meta.get("duration_seconds", 0.0))
    if not 3.2 <= duration <= 8.1:
        failures.append(f"{style}: duration outside 3.2..8.1s: {duration}")

if total_bytes > 24 * 1024 * 1024:
    failures.append(f"cinematic pack exceeds 24 MiB: {total_bytes}")
if list(VIDEO_DIR.glob("*.mp4")):
    failures.append("runtime pack must not contain MP4; Godot uses Ogg Theora")

layer = (ROOT / "scripts/render/room_video_layer.gd").read_text()
for token in (
    "VideoStreamPlayer.new()", "_player.loop = true", "VideoStreamTheora.new()",
    "theora.file = _video_path", "_player.stream = null", "func set_cinematic", "entry_strength",
    "buffering_msec = 220", "set_runtime_scale", "set_reduced_motion",
):
    if token not in layer:
        failures.append(f"room video layer missing lazy lifecycle token: {token}")

exports = (ROOT / "export_presets.cfg").read_text()
if exports.count('include_filter="assets/video/*.ogv"') < 3:
    failures.append("all export presets must explicitly include runtime OGV files")

stage = (ROOT / "scripts/render/room_stage.gd").read_text()
for token in ("RoomVideoLayerScript", "video_layer.configure", "video_layer.set_cinematic"):
    if token not in stage:
        failures.append(f"room stage missing video integration: {token}")

shader = (ROOT / "shaders/room_video_postprocess.gdshader").read_text()
for token in ("profile == 6", "entry_strength", "bloom_gate", "scan_strength", "scar_gain", "texture(TEXTURE"):
    if token not in shader:
        failures.append(f"video postprocess missing art-direction token: {token}")
if "vec3 soft_bloom" in shader:
    failures.append("video postprocess must keep TEXTURE sampling in fragment scope on Godot 4.7.1")

if "UnmaskedEyeGlow" in layer or "unmasked_eye_glow_layer" in layer:
    failures.append("Unmasked must use the supplied video without synthetic eye-glow overlay")

finale = (ROOT / "scripts/ui/echoes_finale_background.gd").read_text()
finale_card = (ROOT / "scripts/ui/signal_finale_card.gd").read_text()
ui = (ROOT / "scripts/ui/ui_factory.gd").read_text()
if 'configure("finale"' not in finale or "set_max_alpha(0.94)" not in finale:
    failures.append("finale video is not blended over the original skull")
if "UIFactory.menu_style(_accent)" not in finale_card or "820.0" not in finale_card or "0.975" not in ui:
    failures.append("final Signal form must strongly cover the lower skull/teeth with the adaptive menu panel")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_CINEMATIC_VIDEO=FAIL count={len(failures)}")

print(
    "SYNESTHESIA_CINEMATIC_VIDEO=PASS "
    f"clips=12 resolution=720x1280 source=720x1280 fps=24 bytes={total_bytes} "
    "lazy=load+unload post=themed unmasked=source-video finale=covered"
)
