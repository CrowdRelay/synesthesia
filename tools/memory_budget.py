#!/usr/bin/env python3
"""Estimate decoded runtime memory for authored ward scenes without third-party dependencies."""
from __future__ import annotations

from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
ROOMS = ROOT / "assets" / "rooms" / "vertical"
EXPECTED_SCENE_SIZE = (675, 1200)
SCENE_CHANNELS = 3
MAX_ACTIVE_SCENE_BYTES = 4 * 1024 * 1024
MAX_CURRENT_PLUS_NEXT = 8 * 1024 * 1024
MAX_FINALE_BYTES = 5 * 1024 * 1024
VIDEO_FRAME_BYTES = 1080 * 1920 * 4
MAX_ACTIVE_WITH_VIDEO = 13 * 1024 * 1024
MAX_FINALE_WITH_VIDEO = 13 * 1024 * 1024


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


failures: list[str] = []
scene_bytes: dict[str, int] = {}
for path in sorted(ROOMS.glob("*-scene.webp")):
    slug = path.name.removesuffix("-scene.webp")
    try:
        size = webp_size(path)
    except (OSError, ValueError, struct.error) as exc:
        failures.append(f"{path.name}: unreadable WebP ({exc})")
        continue
    if size != EXPECTED_SCENE_SIZE:
        failures.append(f"{path.name}: {size} != {EXPECTED_SCENE_SIZE}")
    scene_bytes[slug] = size[0] * size[1] * SCENE_CHANNELS

if len(scene_bytes) != 11:
    failures.append(f"expected 11 authoritative room scenes, got {len(scene_bytes)}")

peak = max(scene_bytes.values(), default=0)
current_plus_next = peak * 2
if peak > MAX_ACTIVE_SCENE_BYTES:
    failures.append(
        f"decoded active scene {peak / 1048576:.2f} MiB exceeds "
        f"{MAX_ACTIVE_SCENE_BYTES / 1048576:.2f} MiB"
    )
if current_plus_next > MAX_CURRENT_PLUS_NEXT:
    failures.append(
        f"current+next scenes {current_plus_next / 1048576:.2f} MiB exceeds "
        f"{MAX_CURRENT_PLUS_NEXT / 1048576:.2f} MiB"
    )
active_with_video = peak + VIDEO_FRAME_BYTES
if active_with_video > MAX_ACTIVE_WITH_VIDEO:
    failures.append(f"active scene + one FHD RGBA video frame exceeds {MAX_ACTIVE_WITH_VIDEO / 1048576:.2f} MiB")

# Legacy bg/subject/foreground files remain source-level pack compatibility only.
# They must not be counted as live decoded room memory after scene_image became
# authoritative; export_surface_contract separately ensures they do not ship.
exports = (ROOT / "export_presets.cfg").read_text()
for pattern in (
    "assets/rooms/vertical/*-bg.webp",
    "assets/rooms/vertical/*-subject.webp",
    "assets/rooms/vertical/*-foreground.webp",
):
    if pattern not in exports:
        failures.append(f"legacy room layer is not excluded from production exports: {pattern}")

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
    f"rooms={len(scene_bytes)} authoritative=scene-only peak_decoded={peak / 1048576:.2f}MiB "
    f"current_plus_next={current_plus_next / 1048576:.2f}MiB active_plus_video={active_with_video / 1048576:.2f}MiB "
    f"finale={finale_bytes / 1048576:.2f}MiB legacy-layers=source-only parser=stdlib-webp"
)
