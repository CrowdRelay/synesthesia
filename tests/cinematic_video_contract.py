#!/usr/bin/env python3
"""Contract for finale-only authored video and procedural gameplay-room motion."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VIDEO_DIR = ROOT / "assets/video"
failures: list[str] = []

manifest_path = VIDEO_DIR / "manifest.json"
manifest = json.loads(manifest_path.read_text()) if manifest_path.is_file() else {}
clips = manifest.get("clips", {}) if isinstance(manifest, dict) else {}

if manifest.get("codec") != "Ogg Theora":
    failures.append("cinematic codec must be Ogg Theora")
if manifest.get("source_resolution") != "720x1280":
    failures.append("cinematic source provenance must remain 720x1280")
if manifest.get("resolution") != "720x1280" or manifest.get("fps") != 24:
    failures.append("finale cinematic must stay at native 720x1280 / 24 fps")
if manifest.get("runtime_profile") != "native-source-resolution-theora-q5":
    failures.append("cinematic runtime profile drifted")
if manifest.get("loop_endpoint_policy") != "forward-full+reverse-without-duplicated-endpoints":
    failures.append("cinematic loop endpoint policy drifted")
if sorted(clips) != ["finale"]:
    failures.append(f"only finale may ship authored runtime video; got={sorted(clips)}")

finale = VIDEO_DIR / "finale.ogv"
total_bytes = finale.stat().st_size if finale.is_file() else 0
if not finale.is_file():
    failures.append("missing finale.ogv")
else:
    data = finale.read_bytes()
    meta = clips.get("finale", {})
    if data[:4] != b"OggS":
        failures.append("finale.ogv is not an Ogg stream")
    if not 300_000 <= len(data) <= 3_000_000:
        failures.append(f"finale video outside 0.3..3.0 MiB budget: {len(data)}")
    if meta.get("width") != 720 or meta.get("height") != 1280 or meta.get("fps") != 24:
        failures.append("finale manifest geometry/fps mismatch")
    if meta.get("source") != "echoes.mp4":
        failures.append("finale source provenance mismatch")
    if meta.get("bytes") != len(data):
        failures.append("finale manifest byte count mismatch")
    if meta.get("sha256") != hashlib.sha256(data).hexdigest():
        failures.append("finale manifest sha256 mismatch")

legacy = ["uncertainty", "unmasked", "seed", "technophobia", "invaluable"]
for style in legacy:
    if (VIDEO_DIR / f"{style}.ogv").exists():
        failures.append(f"legacy room video returned: {style}.ogv")
if list(VIDEO_DIR.glob("*.mp4")):
    failures.append("runtime pack must not contain MP4")

layer = (ROOT / "scripts/render/room_video_layer.gd").read_text()
for token in (
    '"finale": "res://assets/video/finale.ogv"',
    "PROCEDURAL_LIVING_STYLES",
    "func _ensure_player() -> bool:",
    'if _style != "finale"',
    "VideoStreamPlayer.new()",
    "VideoStreamTheora.new()",
    "theora.file = _video_path",
    "_player.stream = null",
    'load(POST_PROCESS_SHADER_PATH)',
):
    if token not in layer:
        failures.append(f"room video layer missing lazy-finale token: {token}")
if 'preload("res://shaders/room_video_postprocess.gdshader")' in layer:
    failures.append("video postprocess shader must stay lazy until finale")

if "_player.loop = true" not in layer:
    failures.append("finale skull video must loop behind the form")
if "FINALE_VIEW_SCALE" in layer:
    failures.append("finale must use full-bleed cover, not inset aspect-fit")
fit = layer.split("func _fit_finale_player()", 1)[1].split("func _on_finale_video_finished()", 1)[0]
if "cover_size" not in fit or "FINALE_SOURCE_ASPECT" not in fit:
    failures.append("finale skull video must use aspect-cover geometry")
finished = layer.split("func _on_finale_video_finished()", 1)[1].split("func configure(", 1)[0]
if "visible = false" in finished or "_player.stream = null" in finished:
    failures.append("finale skull video must not disappear after one playback")

stage = (ROOT / "scripts/render/room_stage.gd").read_text()
for dead in ("AtmosphereLayerScript", "InteractionFxLayerScript", "RoomDressingLayerScript", "RoomVideoLayerScript", "InteractionHintLayerScript", "CompositeShader"):
    if dead in stage:
        failures.append(f"room stage resurrected duplicate/dead preload: {dead}")
visual_setup = (ROOT / "scripts/render/room_visual_setup.gd").read_text()
if "RoomVideoLayerScript.new()" not in visual_setup or "video_layer.configure" not in visual_setup + (ROOT / "scripts/render/room_stage.gd").read_text():
    failures.append("room video integration missing from visual setup/runtime")

exports = (ROOT / "export_presets.cfg").read_text()
if exports.count('include_filter="assets/video/*.ogv"') < 3:
    failures.append("all export presets must explicitly include runtime OGV files")

finale_bg = (ROOT / "scripts/ui/echoes_finale_background.gd").read_text()
finale_card = (ROOT / "scripts/ui/signal_finale_card.gd").read_text()
finale_layout = (ROOT / "scripts/ui/signal_finale_layout.gd").read_text()
ui = (ROOT / "scripts/ui/ui_factory.gd").read_text()
if 'configure("finale"' not in finale_bg or "set_max_alpha(0.94)" not in finale_bg:
    failures.append("finale video is not blended over the original skull")
if "UIFactory.menu_style(_accent)" not in finale_card or "820.0" not in finale_layout or "0.975" not in ui:
    failures.append("final Signal form must cover lower finale art with adaptive menu panel")

if failures:
    for failure in failures:
        print("FAIL:", failure)
    raise SystemExit(f"SYNESTHESIA_CINEMATIC_VIDEO=FAIL count={len(failures)}")

print(
    "SYNESTHESIA_CINEMATIC_VIDEO=PASS "
    f"clips=1 finale_bytes={total_bytes} gameplay=procedural-only decoder=finale-lazy shader=finale-lazy"
)
