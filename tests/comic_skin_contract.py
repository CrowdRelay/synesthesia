#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []
legacy = ROOT / "assets/comic"
if legacy.exists() and any(p.is_file() for p in legacy.rglob("*")):
    failures.append("legacy assets/comic payload must not ship in Signal V2")
ui = (ROOT / "scripts/ui/ui_factory.gd").read_text(errors="replace")
for forbidden in ("COMIC_PANEL_TEXTURE_PATH", "COMIC_BUTTON_TEXTURE_PATH", "StyleBoxTexture.new()", "res://assets/comic/"):
    if forbidden in ui:
        failures.append(f"UIFactory resurrected legacy token {forbidden!r}")
for required in ("ViryaDesign.surface", "product_button", "SignalGrain", "add_signal_backdrop"):
    if required not in ui:
        failures.append(f"UIFactory missing Signal token {required!r}")
motif = (ROOT / "scripts/ui/door_eye_motif.gd").read_text(errors="replace")
for required in ("res://assets/branding/signal-glyph.webp", "res://assets/branding/signal-glyph-loop.ogv", "_draw_texture_glitch", "_sync_processing"):
    if required not in motif:
        failures.append(f"signal motif missing {required!r}")
for rel, limit in (("assets/branding/signal-glyph.webp",180_000),("assets/branding/signal-glyph-loop.ogv",500_000)):
    q=ROOT/rel
    if not q.is_file() or not 0 < q.stat().st_size <= limit:
        failures.append(f"missing/out-of-budget signal motif asset {rel}")
if failures:
    for x in failures: print("FAIL: "+x)
    raise SystemExit(f"SYNESTHESIA_COMIC_SKIN=FAIL count={len(failures)}")
print("SYNESTHESIA_COMIC_SKIN=PASS legacy-assets=removed signal-v2=active surfaces=flat motif=branding grain=procedural")
