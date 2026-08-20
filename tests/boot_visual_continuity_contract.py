#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []


def read(rel: str) -> str:
    return (ROOT / rel).read_text(errors="replace")


ward = ROOT / "assets/v2/branding/menu-world.webp"
if not ward.is_file() or not (20_000 <= ward.stat().st_size <= 160_000):
    failures.append("ward boot artwork missing/outside startup budget")
native_splash = ROOT / "assets/branding/boot-splash.png"
if not native_splash.is_file() or not (500_000 <= native_splash.stat().st_size <= 2_000_000):
    failures.append("native ward PNG missing/outside startup budget")

project = read("project.godot")
boot = read("scripts/ui/boot_sequence.gd")
web_css = read("web/boot-shell.css")
web_post = read("tools/postprocess_web.py")
web_js = read("web/boot-shell.js")
builder = read("scripts/build-web-preview.sh")
worker = read("web/service-worker.js")
main = read("scripts/main.gd")
intro = read("scripts/ui/experience_intro_card.gd")

checks = [
    ('boot_splash/image="res://assets/branding/boot-splash.png"', project, "native ward boot image"),
    ('MENU_WORLD_PATH: String = "res://assets/v2/branding/menu-world.webp"', boot, "Godot ward boot image"),
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
    if "menu-eye" in source or "BootAuthoredEye" in source:
        failures.append(f"{label} still references retired eye splash")

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
print("SYNESTHESIA_BOOT_VISUAL_CONTINUITY=PASS art=ward-corridor native=web=godot=menu handoff=single-frame debug-chrome=hidden")
