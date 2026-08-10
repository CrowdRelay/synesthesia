#!/usr/bin/env python3
"""Lock the accepted VIRYA Signal/Synesthesia production UI direction."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

roster = json.loads((ROOT / "data/virya_roster.json").read_text())
expected = [
    ("GŁOS", "Yanusin", "yanusin-v1.webp"),
    ("GITARA", "Mr R", "mr-r-v1.webp"),
    ("BAS", "Lubek", "lubek-v1.webp"),
    ("PERA", "Koobosky", "koobosky-v1.webp"),
]
members = roster.get("members", [])
if len(members) != 4:
    failures.append("roster must contain exactly four VIRYA signals")
else:
    for member, (role, alias, asset_name) in zip(members, expected):
        if member.get("role") != role or member.get("alias") != alias:
            failures.append(f"roster mismatch for {role}/{alias}")
        asset = ROOT / "assets/avatars" / asset_name
        if not asset.is_file() or not 20_000 <= asset.stat().st_size <= 120_000:
            failures.append(f"avatar asset missing/outside budget: {asset_name}")

for rel, tokens in {
    "scripts/ui/virya_design_tokens.gd": ("SIGNAL", "ROSE", "HAIRLINE", "RADIUS_SMALL"),
    "scripts/ui/signal_avatar.gd": ("_draw_waveform", "draw_arc", "draw_texture_rect"),
    "scripts/ui/virya_roster_strip.gd": ("ROSTER_PATH", "SignalAvatar", "show_aliases"),
    "scripts/ui/experience_intro_card.gd": ("product_surface_style", "product_button", "ViryaRosterStrip", "ZESPÓŁ VIRYA · ŚWIAT"),
    "scripts/ui/signal_finale_card.gd": ("product_surface_style", "product_button", "FinaleViryaRoster"),
    "scripts/ui/album_archive_card.gd": ("product_surface_style", "product_inset_style", "product_button"),
    "scripts/ui/completion_card.gd": ("product_surface_style", "product_button"),
    "scripts/ui/app_hud.gd": ("product_inset_style", "product_surface_style"),
}.items():
    text = (ROOT / rel).read_text(errors="replace")
    for token in tokens:
        if token not in text:
            failures.append(f"{rel}: missing Signal-system token {token}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_SIGNAL_DESIGN_SYSTEM=FAIL count={len(failures)}")

print("SYNESTHESIA_SIGNAL_DESIGN_SYSTEM=PASS ui=menu+finale+corridor+hud avatars=Yanusin+MrR+Lubek+Koobosky")
