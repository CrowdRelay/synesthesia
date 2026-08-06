#!/usr/bin/env python3
"""Regression budget for pink-noise, music gain, filter and space reveal."""
from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
THRESHOLD = 0.99
SILENCE_DB = -60.0


def smoothstep(a: float, b: float, value: float) -> float:
    x = max(0.0, min(1.0, (value - a) / (b - a)))
    return x * x * (3.0 - 2.0 * x)


def levels(coverage: float, pink: float, hidden: float, completion: float, start_hz: float, final_hz: float) -> tuple[float, float, float, float]:
    reveal = smoothstep(0.0, THRESHOLD, coverage)
    noise = pink - 5.0 + (SILENCE_DB - (pink - 5.0)) * math.pow(reveal, 1.35)
    music = hidden + (completion - hidden) * math.pow(reveal, 1.46)
    cutoff = start_hz + (final_hz - start_hz) * math.pow(reveal, 0.72)
    wet = 0.22 + (0.035 - 0.22) * reveal
    if coverage >= THRESHOLD:
        return SILENCE_DB, completion, final_hz, 0.035
    return noise, music, cutoff, wet


def main() -> int:
    loop = ROOT / "assets/audio/pink-noise-asmr-loop.ogg"
    if not loop.is_file() or not 60_000 <= loop.stat().st_size <= 500_000:
        raise SystemExit("SYNESTHESIA_AUDIO_MIX_BUDGET=FAIL reason=noise-loop")
    paths = sorted((ROOT / "data/releases").glob("*/manifest.json"))
    if len(paths) != 11:
        raise SystemExit("SYNESTHESIA_AUDIO_MIX_BUDGET=FAIL reason=room-count")
    for path in paths:
        audio = json.loads(path.read_text())["audio"]
        values = [float(audio[k]) for k in ("pink_noise_start_db", "hidden_music_db", "completion_volume_db", "lowpass_start_hz", "lowpass_final_hz")]
        pink, hidden, completion, start_hz, final_hz = values
        start = levels(0.0, pink, hidden, completion, start_hz, final_hz)
        mid = levels(0.5, pink, hidden, completion, start_hz, final_hz)
        late = levels(0.75, pink, hidden, completion, start_hz, final_hz)
        final = levels(0.99, pink, hidden, completion, start_hz, final_hz)
        room = path.parent.name
        if start[0] - start[1] < 24.0:
            raise SystemExit(f"SYNESTHESIA_AUDIO_MIX_BUDGET=FAIL room={room} reason=start-ratio")
        if abs(mid[0] - mid[1]) > 7.0:
            raise SystemExit(f"SYNESTHESIA_AUDIO_MIX_BUDGET=FAIL room={room} reason=mid-crossfade")
        if late[0] - late[1] > -13.0:
            raise SystemExit(f"SYNESTHESIA_AUDIO_MIX_BUDGET=FAIL room={room} reason=late-music")
        if not start_hz <= mid[2] < late[2] < final_hz:
            raise SystemExit(f"SYNESTHESIA_AUDIO_MIX_BUDGET=FAIL room={room} reason=filter-reveal")
        if not start[3] > mid[3] > late[3] > final[3] - 1e-6:
            raise SystemExit(f"SYNESTHESIA_AUDIO_MIX_BUDGET=FAIL room={room} reason=space-reveal")
        if final != (SILENCE_DB, completion, final_hz, 0.035):
            raise SystemExit(f"SYNESTHESIA_AUDIO_MIX_BUDGET=FAIL room={room} reason=final")
    print("SYNESTHESIA_AUDIO_MIX_BUDGET=PASS gain=crossfade filter=opens space=dries reveal99=music-only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
