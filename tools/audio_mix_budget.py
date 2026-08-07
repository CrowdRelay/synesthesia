#!/usr/bin/env python3
"""Regression budget for the reveal-proportional pink-noise/music mix."""
from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
THRESHOLD = 0.99
SILENCE_DB = -60.0


def ratio(coverage: float) -> tuple[float, float]:
    if coverage >= THRESHOLD:
        return 0.0, 1.0
    music = max(0.0, min(1.0, coverage))
    return 1.0 - music, music


def db_from_ratio(base_db: float, amount: float) -> float:
    if amount <= 0.0001:
        return SILENCE_DB
    return base_db + 20.0 * math.log10(amount)


def levels(coverage: float, pink: float, completion: float, start_hz: float, final_hz: float) -> tuple[float, float, float, float, float, float]:
    noise_ratio, music_ratio = ratio(coverage)
    noise_db = db_from_ratio(pink - 5.0, noise_ratio)
    music_db = db_from_ratio(completion, music_ratio)
    if coverage >= THRESHOLD:
        return SILENCE_DB, completion, final_hz, 0.035, 0.0, 1.0
    filter_curve = math.pow(music_ratio, 0.72)
    cutoff = start_hz + (final_hz - start_hz) * filter_curve
    wet = 0.22 + (0.035 - 0.22) * music_ratio
    return noise_db, music_db, cutoff, wet, noise_ratio, music_ratio


def main() -> int:
    loop = ROOT / "assets/audio/pink-noise-asmr-loop.ogg"
    pop = ROOT / "assets/audio/balloon-pop.mp3"
    if not loop.is_file() or not 60_000 <= loop.stat().st_size <= 500_000:
        raise SystemExit("SYNESTHESIA_AUDIO_MIX_BUDGET=FAIL reason=noise-loop")
    if not pop.is_file() or not 3_000 <= pop.stat().st_size <= 80_000:
        raise SystemExit("SYNESTHESIA_AUDIO_MIX_BUDGET=FAIL reason=balloon-pop")
    paths = sorted((ROOT / "data/releases").glob("*/manifest.json"))
    if len(paths) != 11:
        raise SystemExit("SYNESTHESIA_AUDIO_MIX_BUDGET=FAIL reason=room-count")
    for path in paths:
        audio = json.loads(path.read_text())["audio"]
        pink = float(audio["pink_noise_start_db"])
        completion = float(audio["completion_volume_db"])
        start_hz = float(audio["lowpass_start_hz"])
        final_hz = float(audio["lowpass_final_hz"])
        room = path.parent.name
        for reveal, expected_noise, expected_music in ((0.20, 0.80, 0.20), (0.50, 0.50, 0.50), (0.80, 0.20, 0.80)):
            values = levels(reveal, pink, completion, start_hz, final_hz)
            if abs(values[4] - expected_noise) > 1e-9 or abs(values[5] - expected_music) > 1e-9:
                raise SystemExit(f"SYNESTHESIA_AUDIO_MIX_BUDGET=FAIL room={room} reason=linear-ratio-{reveal}")
        start = levels(0.0, pink, completion, start_hz, final_hz)
        mid = levels(0.5, pink, completion, start_hz, final_hz)
        late = levels(0.8, pink, completion, start_hz, final_hz)
        final = levels(0.99, pink, completion, start_hz, final_hz)
        if start[5] != 0.0 or start[4] != 1.0:
            raise SystemExit(f"SYNESTHESIA_AUDIO_MIX_BUDGET=FAIL room={room} reason=start")
        if not start_hz <= mid[2] < late[2] < final_hz:
            raise SystemExit(f"SYNESTHESIA_AUDIO_MIX_BUDGET=FAIL room={room} reason=filter-reveal")
        if not start[3] > mid[3] > late[3] > final[3] - 1e-6:
            raise SystemExit(f"SYNESTHESIA_AUDIO_MIX_BUDGET=FAIL room={room} reason=space-reveal")
        if final[0] != SILENCE_DB or final[1] != completion or final[4:] != (0.0, 1.0):
            raise SystemExit(f"SYNESTHESIA_AUDIO_MIX_BUDGET=FAIL room={room} reason=final")
    print("SYNESTHESIA_AUDIO_MIX_BUDGET=PASS reveal20=80/20 reveal50=50/50 reveal80=20/80 reveal99=music-only pop=loaded")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
