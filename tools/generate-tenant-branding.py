#!/usr/bin/env python3
"""Generate tenant-branded Synesthesia Android icons + boot splash from palette.

Reads a tenant config JSON (from fetch-tenant-config.py) and produces:
  - Android app icons at required sizes (192x192, 512x512)
  - A boot splash background image using the tenant's surface color

If the tenant has no branding palette, the default Virya Synesthesia colors
are used.

Requires Pillow (PIL). Install: pip install Pillow

Usage:
  python3 tools/generate-tenant-branding.py \
      --config tenant-config.json \
      --output-dir assets/branding/tenant
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("ERROR: Pillow is required. Install with: pip install Pillow", file=sys.stderr)
    raise SystemExit(1)


# Godot Android export requires these icon sizes
ICON_SIZES = [
    (192, 192, "icon-192.png"),
    (512, 512, "icon-512.png"),
]

# Boot splash dimensions (Godot default: 1920x1080 landscape, but Synesthesia
# is portrait-oriented; we generate a simple solid-color splash)
SPLASH_SIZE = (1080, 1920)

DEFAULT_PALETTE = {
    "primary": "#8b5cf6",
    "primaryContrast": "#ffffff",
    "accent": "#22d3ee",
    "surface": "#070908",
    "surfaceElevated": "#15171c",
    "text": "#f7f7f8",
    "textMuted": "#9ca3af",
    "success": "#22c55e",
    "warning": "#f59e0b",
    "danger": "#ef4444",
}


def hex_to_rgb(hex_color: str) -> tuple[int, int, int]:
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i : i + 2], 16) for i in (0, 2, 4))


def draw_synesthesia_icon(size: int, palette: dict[str, str]) -> Image.Image:
    """Draw a simplified Synesthesia icon: a circular gradient on surface."""
    surface = hex_to_rgb(palette.get("surface", "#070908"))
    primary = hex_to_rgb(palette.get("primary", "#8b5cf6"))
    accent = hex_to_rgb(palette.get("accent", "#22d3ee"))

    img = Image.new("RGBA", (size, size), surface)
    draw = ImageDraw.Draw(img)

    # Concentric circles: outer primary, inner accent
    margin = size // 8
    draw.ellipse(
        [margin, margin, size - margin, size - margin],
        fill=primary,
    )
    inner_margin = size // 4
    draw.ellipse(
        [inner_margin, inner_margin, size - inner_margin, size - inner_margin],
        fill=accent,
    )
    # Center dot
    center_margin = size * 2 // 5
    draw.ellipse(
        [center_margin, center_margin, size - center_margin, size - center_margin],
        fill=surface,
    )

    return img


def generate_splash(palette: dict[str, str], output_dir: Path) -> None:
    """Generate a solid-color boot splash using the surface color."""
    surface = hex_to_rgb(palette.get("surface", "#070908"))
    img = Image.new("RGB", SPLASH_SIZE, surface)
    img.save(output_dir / "boot-splash-tenant.png", "PNG")
    print(f"Generated boot-splash-tenant.png ({SPLASH_SIZE[0]}x{SPLASH_SIZE[1]})", file=sys.stderr)


def generate_branding(config: dict, output_dir: Path) -> None:
    palette = config.get("brandingPalette") or DEFAULT_PALETTE
    output_dir.mkdir(parents=True, exist_ok=True)

    for width, height, filename in ICON_SIZES:
        img = draw_synesthesia_icon(max(width, height), palette)
        if width != height:
            img = img.resize((width, height), Image.LANCZOS)
        img.save(output_dir / filename, "PNG")
        print(f"Generated {filename} ({width}x{height})", file=sys.stderr)

    generate_splash(palette, output_dir)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--config", required=True, help="Path to tenant config JSON")
    parser.add_argument("--output-dir", default="assets/branding/tenant", help="Output directory")
    args = parser.parse_args()

    config = json.loads(Path(args.config).read_text(encoding="utf-8"))
    output_dir = Path(args.output_dir)
    generate_branding(config, output_dir)
    print(f"Branding assets written to {output_dir}", file=sys.stderr)


if __name__ == "__main__":
    main()
