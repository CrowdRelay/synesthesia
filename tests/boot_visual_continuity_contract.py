#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []


def read(rel: str) -> str:
    return (ROOT / rel).read_text(errors="replace")


ward = ROOT / "assets/v2/branding/menu-world.webp"
if not ward.is_file() or not (20_000 <= ward.stat().st_size <= 160_000):
    failures.append("ward boot artwork missing/outside startup budget")
legacy_native_splash = ROOT / "assets/branding/boot-splash.png"
if not legacy_native_splash.is_file():
    failures.append("legacy validator compatibility splash source missing")

project = read("project.godot")
exports = read("export_presets.cfg")
boot = read("scripts/ui/boot_sequence.gd")
web_css = read("web/boot-shell.css")
web_post = read("tools/postprocess_web.py")
web_js = read("web/boot-shell.js")
builder = read("scripts/build-web-preview.sh")
worker = read("web/service-worker.js")
main = read("scripts/main.gd")
intro = read("scripts/ui/experience_intro_card.gd")

checks = [
    ('boot_splash/image="res://assets/v2/branding/menu-world.webp"', project, "native ward boot image"),
    ('boot_splash/use_filter=true', project, "native splash scaling filter"),
    ('assets/branding/boot-splash*', exports, "legacy compatibility splash excluded from exports"),
    ('MENU_WORLD_PATH: String = "res://assets/v2/branding/menu-world.webp"', boot, "Godot ward boot image"),
    ('const ViryaDesign := preload("res://scripts/ui/virya_design_tokens.gd")', boot, "boot design token convergence"),
    ('VIRYA // ODDZIAŁ SYNESTHESIA', boot, "ward boot eyebrow"),
    ('ECHOES OF THE MODERN MIND // SESJA 01', boot, "ward boot session identity"),
    ('PRZYGOTOWUJĘ ODDZIAŁ', boot, "ward loading copy"),
    ('await RenderingServer.frame_post_draw', boot, "first-frame presentation gate"),
    ('<div class="synesthesia-boot__ward" aria-hidden="true"></div>', web_post, "Web ward shell"),
    ('background: url("/menu-world.webp") center center / cover no-repeat;', web_css, "Web ward styling"),
    ('prefers-reduced-motion: reduce', web_css, "reduced-motion boot guard"),
    ('window.synesthesiaBootReady = removeBoot', web_js, "Godot/Web handoff"),
    ('cp assets/v2/branding/menu-world.webp build/web/', builder, "Web ward deploy"),
    ('"/menu-world.webp"', worker, "offline ward shell"),
    ('experience_surface.get_render_label() if DebugProfile.is_local_desktop_debug() else ""', main, "debug-only render label"),
    ('if not _render_label.is_empty():', intro, "debug label conditional rendering"),
]
for token, source, label in checks:
    if token not in source:
        failures.append(label)

for source, label in (
    (boot, "Godot boot"),
    (web_post, "Web markup"),
    (web_css, "Web style"),
    (web_js, "Web runtime"),
):
    if "menu-eye" in source or "BootAuthoredEye" in source or "boot-splash.png" in source:
        failures.append(f"{label} still references retired splash language")

for legacy_color in ("a895b8", "f4eef8", "66778d"):
    if legacy_color in boot.lower():
        failures.append(f"Godot boot still contains legacy purple/blue chrome: {legacy_color}")

try:
    release_at = boot.index("released.emit()")
    fade_at = boot.index('fade.tween_property(self, "modulate:a"')
    if release_at > fade_at:
        failures.append("menu is still created only after splash fade (black-frame handoff)")
except ValueError:
    failures.append("splash/menu handoff ordering markers missing")

if 'ADAPTIVE NATIVE' in boot:
    failures.append("production Godot boot still exposes adaptive-native debug jargon")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_BOOT_VISUAL_CONTINUITY=FAIL count={len(failures)}")
print("SYNESTHESIA_BOOT_VISUAL_CONTINUITY=PASS art=ward-world native=web=godot=menu compatibility-source=export-excluded chrome=clinical-mint")
