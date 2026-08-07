#!/usr/bin/env python3
"""Estimate decoded room-layer memory without third-party dependencies."""
from __future__ import annotations

from collections import defaultdict
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
ROOMS = ROOT / "assets" / "rooms" / "vertical"
MAX_ACTIVE_BYTES = 9 * 1024 * 1024
MAX_CURRENT_PLUS_NEXT = 19 * 1024 * 1024
MAX_FINALE_BYTES = 5 * 1024 * 1024
VIDEO_FRAME_BYTES = 1080 * 1920 * 4
MAX_ACTIVE_WITH_VIDEO = 18 * 1024 * 1024
MAX_FINALE_WITH_VIDEO = 13 * 1024 * 1024
EXPECTED = {
    "bg": ((405, 720), 3),
    "scene": ((675, 1200), 3),
    "subject": ((675, 1200), 4),
    "foreground": ((540, 960), 4),
}


def _u24_le(raw: bytes) -> int:
    return raw[0] | (raw[1] << 8) | (raw[2] << 16)


def webp_size(path: Path) -> tuple[int, int]:
    """Read VP8/VP8L/VP8X canvas dimensions directly from a WebP container."""
    raw = path.read_bytes()
    if len(raw) < 20 or raw[:4] != b"RIFF" or raw[8:12] != b"WEBP":
        raise ValueError("not a WebP RIFF container")

    offset = 12
    while offset + 8 <= len(raw):
        kind = raw[offset : offset + 4]
        size = struct.unpack_from("<I", raw, offset + 4)[0]
        start = offset + 8
        end = start + size
        if end > len(raw):
            raise ValueError("truncated WebP chunk")
        payload = raw[start:end]

        if kind == b"VP8X":
            if len(payload) < 10:
                raise ValueError("short VP8X chunk")
            return 1 + _u24_le(payload[4:7]), 1 + _u24_le(payload[7:10])

        if kind == b"VP8 ":
            marker = payload.find(b"\x9d\x01\x2a")
            if marker < 0 or marker + 7 > len(payload):
                raise ValueError("VP8 frame header missing")
            width = struct.unpack_from("<H", payload, marker + 3)[0] & 0x3FFF
            height = struct.unpack_from("<H", payload, marker + 5)[0] & 0x3FFF
            return width, height

        if kind == b"VP8L":
            if len(payload) < 5 or payload[0] != 0x2F:
                raise ValueError("invalid VP8L header")
            b1, b2, b3, b4 = payload[1:5]
            width = 1 + (((b2 & 0x3F) << 8) | b1)
            height = 1 + (((b4 & 0x0F) << 10) | (b3 << 2) | ((b2 & 0xC0) >> 6))
            return width, height

        offset = end + (size & 1)

    raise ValueError("WebP dimensions not found")


per_room: dict[str, int] = defaultdict(int)
failures: list[str] = []
seen_layers: dict[str, set[str]] = defaultdict(set)

for path in sorted(ROOMS.glob("*.webp")):
    suffix = next((name for name in EXPECTED if path.name.endswith(f"-{name}.webp")), None)
    if suffix is None:
        continue
    slug = path.name[: -len(f"-{suffix}.webp")]
    expected_size, channels = EXPECTED[suffix]
    try:
        size = webp_size(path)
    except (OSError, ValueError, struct.error) as exc:
        failures.append(f"{path.name}: unreadable WebP ({exc})")
        continue
    if size != expected_size:
        failures.append(f"{path.name}: {size} != {expected_size}")
    per_room[slug] += size[0] * size[1] * channels
    seen_layers[slug].add(suffix)

if len(per_room) != 11:
    failures.append(f"expected 11 rooms, got {len(per_room)}")
for slug, layers in sorted(seen_layers.items()):
    missing = sorted(set(EXPECTED) - layers)
    if missing:
        failures.append(f"{slug}: missing layers {','.join(missing)}")

peak = max(per_room.values(), default=0)
if peak > MAX_ACTIVE_BYTES:
    failures.append(
        f"decoded active room {peak / 1048576:.2f} MiB exceeds "
        f"{MAX_ACTIVE_BYTES / 1048576:.2f} MiB"
    )
if peak * 2 > MAX_CURRENT_PLUS_NEXT:
    failures.append(
        f"current+next {peak * 2 / 1048576:.2f} MiB exceeds "
        f"{MAX_CURRENT_PLUS_NEXT / 1048576:.2f} MiB"
    )
active_with_video = peak + VIDEO_FRAME_BYTES
if active_with_video > MAX_ACTIVE_WITH_VIDEO:
    failures.append(f"active room + one FHD RGBA video frame exceeds {MAX_ACTIVE_WITH_VIDEO / 1048576:.2f} MiB")

finale_path = ROOT / "assets" / "finale" / "echoes-finale.webp"
finale_bytes = 0
if not finale_path.is_file():
    failures.append("missing Echoes finale image")
else:
    try:
        finale_size = webp_size(finale_path)
        finale_bytes = finale_size[0] * finale_size[1] * 3
        if finale_size != (810, 1440):
            failures.append(f"finale: {finale_size} != (810, 1440)")
        if finale_bytes > MAX_FINALE_BYTES:
            failures.append(f"finale decoded {finale_bytes / 1048576:.2f} MiB exceeds {MAX_FINALE_BYTES / 1048576:.2f} MiB")
        if finale_bytes + VIDEO_FRAME_BYTES > MAX_FINALE_WITH_VIDEO:
            failures.append("finale image + one FHD video frame exceeds finale video budget")
    except (OSError, ValueError, struct.error) as exc:
        failures.append(f"finale unreadable WebP ({exc})")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_MEMORY_BUDGET=FAIL count={len(failures)}")

print(
    "SYNESTHESIA_MEMORY_BUDGET=PASS "
    f"rooms={len(per_room)} peak_decoded={peak / 1048576:.2f}MiB "
    f"current_plus_next={peak * 2 / 1048576:.2f}MiB active_plus_video={active_with_video / 1048576:.2f}MiB finale={finale_bytes / 1048576:.2f}MiB parser=stdlib-webp"
)
