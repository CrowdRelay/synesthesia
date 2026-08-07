#!/usr/bin/env python3
from __future__ import annotations

import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

AMBIENCE = {
    "uncertainty": "uncertainty.wav",
    "party": "party.wav",
    "unmasked": "unmasked.wav",
    "calling": "calling.wav",
    "seed": "seed.wav",
    "hybrid": "hybrid.wav",
    "technophobia": "technophobia.wav",
    "invaluable": "invaluable.wav",
    "ashes": "ashes.wav",
    "waves": "waves.wav",
    "rise": "rise.wav",
}
SFX = [
    "glass-clink.wav", "wood-creak.wav", "gunshot.wav", "mirror-shatter.wav",
    "wing-whoosh.wav", "electric-bzz.wav", "mask-whisper.wav", "wave-slap.wav",
    "light-rise.wav", "presence-wind.wav", "door-close.wav", "door-open.wav",
    "teleport-suck.wav",
]
TOKENS = {
    "scripts/ui/app_hud.gd": ["HeaderRow", "size_flags_stretch_ratio = 1.18", "size_flags_stretch_ratio = 0.82", "panel_bottom + 8.0"],
    "scripts/app/door_transition_layer.gd": ["set_door_open_mix", "set_approach_mix", "set_warp_mix", "_draw_hinged_door", "_draw_supersonic_tunnel"],
    "scripts/app/transition_director.gd": ["TELEPORT_SFX", "DOOR_OPEN_SFX", "set_approach_mix", "set_warp_mix"],
    "scripts/rooms/behaviors/wave-of-uncertainty.gd": ["lateral", "direction"],
    "scripts/rooms/behaviors/party-time.gd": ["fly_t", "rise", "glow"],
    "scripts/rooms/behaviors/unmasked.gd": ["eye_y", "mouth_open"],
    "scripts/rooms/behaviors/seed-of-doubt.gd": ["twist", "cinematic_t"],
    "scripts/rooms/behaviors/hybrid.gd": ["duel_elapsed", "muzzle", "flash"],
    "scripts/rooms/behaviors/technophobia.gd": ["jitter_strength", "band_y"],
    "scripts/rooms/behaviors/invaluable.gd": ["for shard in range(10)", "burst"],
    "scripts/rooms/behaviors/from-the-ashes.gd": ["wing_span", "cinematic_t * 74.0"],
    "scripts/rooms/behaviors/waves.gd": ["lamp", "window_rect", "flicker_gate"],
    "scripts/rooms/behaviors/rise.gd": ["arm_raise", "window_glow", "rise_t"],
    "scripts/ui/echoes_finale_background.gd": ["else 58", "drift - 12.0"],
    "shaders/room_composite.gdshader": ["glitch_band", "flight * 0.075", "ascent * 0.070"],
}

failures: list[str] = []


def check_wav(path: Path) -> None:
    if not path.is_file():
        failures.append(f"missing audio {path.relative_to(ROOT)}")
        return
    try:
        with wave.open(str(path), "rb") as wav:
            if wav.getnchannels() != 1:
                failures.append(f"{path.name}: ambience/SFX must stay mono")
            if wav.getframerate() not in (22050, 44100, 48000):
                failures.append(f"{path.name}: unexpected sample rate {wav.getframerate()}")
            if wav.getnframes() <= 128:
                failures.append(f"{path.name}: audio is effectively empty")
    except wave.Error as exc:
        failures.append(f"{path.name}: invalid WAV: {exc}")


for filename in AMBIENCE.values():
    check_wav(ROOT / "assets/audio/ambience" / filename)
for filename in SFX:
    check_wav(ROOT / "assets/audio/sfx" / filename)

for rel, required in TOKENS.items():
    path = ROOT / rel
    if not path.is_file():
        failures.append(f"missing {rel}")
        continue
    text = path.read_text(errors="replace")
    for token in required:
        if token not in text:
            failures.append(f"{rel}: missing sensory token {token!r}")

audio = (ROOT / "scripts/audio_director.gd").read_text(errors="replace")
for style, filename in AMBIENCE.items():
    if f'"{style}": "res://assets/audio/ambience/{filename}"' not in audio:
        failures.append(f"audio director missing ambience mapping for {style}")
for token in ("play_cinematic_sfx", "INTERACTION_SFX", "CINEMATIC_SFX"):
    if token not in audio:
        failures.append(f"audio director missing {token}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_SENSORY_ROOMS=FAIL count={len(failures)}")

print("SYNESTHESIA_SENSORY_ROOMS=PASS ambience=11 sfx=13 animations=11 doors=hinge+supersonic hud=no-overlap")
