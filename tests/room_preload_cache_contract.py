#!/usr/bin/env python3
"""Guard room-transition I/O: cached manifests + deferred audio prewarm."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

reader = (ROOT / "scripts/app/release_reader.gd").read_text()
preloader = (ROOT / "scripts/app/asset_preloader.gd").read_text()
audio = (ROOT / "scripts/audio_director.gd").read_text()

for token in (
    "static var _json_cache: Dictionary = {}",
    "if _json_cache.has(path):",
    "_json_cache[path] = document",
):
    if token not in reader:
        failures.append(f"release manifest cache missing: {token}")

if "ReleaseReader.load_json(manifest_path)" not in preloader:
    failures.append("asset preloader reparses release manifests instead of using ReleaseReader cache")
for token in (
    '_queue(str(audio.get("ambience", "")), false)',
    '_queue(str(audio.get("completion_excerpt", "")), false)',
):
    if token not in preloader:
        failures.append(f"deferred audio prewarm missing: {token}")

for token in (
    'audio.get("ambience", AMBIENCE_PATHS.get(_visual_style, ""))',
    "_pending_ambience_path = path",
    "_pending_asset_source.take_if_ready(_pending_ambience_path)",
    "_resolve_pending_ambience()",
    "_release_pending_asset_source_if_idle()",
    "if resource is AudioStreamOggVorbis:",
    "ogg_stream.loop = true",
):
    if token not in audio:
        failures.append(f"deferred ambience lifecycle missing: {token}")

manifest_count = 0
for manifest_path in sorted((ROOT / "data/releases").glob("*/manifest.json")):
    manifest = json.loads(manifest_path.read_text())
    ambience = str(manifest.get("audio", {}).get("ambience", ""))
    if not ambience:
        failures.append(f"{manifest_path.relative_to(ROOT)} has no audio.ambience")
        continue
    if not ambience.startswith("res://"):
        failures.append(f"{manifest_path.relative_to(ROOT)} ambience is not a res:// path")
        continue
    if not ambience.endswith(".ogg"):
        failures.append(f"{manifest_path.relative_to(ROOT)} ambience is not compressed Ogg/Vorbis")
        continue
    target = ROOT / ambience.removeprefix("res://")
    if not target.is_file():
        failures.append(f"missing ambience asset: {ambience}")
    manifest_count += 1

if manifest_count < 10:
    failures.append(f"unexpectedly small release manifest coverage: {manifest_count}")

runner = (ROOT / "run-macos.sh").read_text()
if "ambience/uncertainty.ogg" not in runner or "ambience/uncertainty.wav" in runner:
    failures.append("macOS dev runner sensory whitelist is not aligned with Ogg ambience")
if list((ROOT / "assets/audio/ambience").glob("*.wav*")):
    failures.append("stale WAV ambience/import files remain after Ogg migration")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_ROOM_PRELOAD_CACHE=FAIL count={len(failures)}")

print(
    "SYNESTHESIA_ROOM_PRELOAD_CACHE=PASS "
    f"manifests={manifest_count} json=process-cache audio=threaded+deferred transition=critical-only-wait"
)
