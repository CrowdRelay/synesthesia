#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

def read(rel: str) -> str:
    return (ROOT / rel).read_text(errors="replace")

poster = ROOT / "assets/branding/menu-eye-poster.webp"
splash = ROOT / "assets/branding/boot-splash.png"
boot_loop = ROOT / "assets/branding/menu-eye-boot-loop.mp4"
if not poster.is_file() or not (20_000 <= poster.stat().st_size <= 180_000):
    failures.append("authored menu-eye poster missing/outside startup budget")
if not splash.is_file() or not (100_000 <= splash.stat().st_size <= 2_000_000):
    failures.append("native boot splash missing/outside startup budget")
if not boot_loop.is_file() or not (80_000 <= boot_loop.stat().st_size <= 220_000):
    failures.append("adaptive Web boot loop missing/outside 80-220KB budget")

project = read("project.godot")
eye = read("scripts/ui/door_eye_motif.gd")
boot = read("scripts/ui/boot_sequence.gd")
web_css = read("web/boot-shell.css")
web_post = read("tools/postprocess_web.py")
web_js = read("web/boot-shell.js")
builder = read("scripts/build-web-preview.sh")
worker = read("web/service-worker.js")
main = read("scripts/main.gd")
intro = read("scripts/ui/experience_intro_card.gd")

checks = [
    ('boot_splash/image="res://assets/branding/boot-splash.png"', project, "native boot image"),
    ('MENU_EYE_POSTER_PATH: String = "res://assets/branding/menu-eye-poster.webp"', eye, "Godot poster"),
    ('(_profile == "menu" or _profile == "splash")', eye, "authored menu+splash profile"),
    ('_authored_video_armed = profile == "menu"', eye, "first-frame decoder gate"),
    ('await RenderingServer.frame_post_draw', boot, "first-frame presentation gate"),
    ('_motif.arm_authored_animation(true)', boot, "post-frame authored animation"),
    ('_motif.suspend_authored_animation(true)', boot, "single-decoder menu handoff"),
    ('<video class="synesthesia-boot__eye-art" id="synesthesia-boot-eye" muted loop playsinline preload="none" poster="/menu-eye-poster.webp"', web_post, "web authored poster+video shell"),
    ('.synesthesia-boot__eye-art', web_css, "web poster styling"),
    ('video.src = "/menu-eye-boot-loop.mp4"', web_js, "delayed authored Web loop"),
    ('bootVideoTimer = window.setTimeout(armBootVideo, 350)', web_js, "fast-boot loop deferral"),
    ('connection?.saveData', web_js, "data-saver boot guard"),
    ('prefers-reduced-motion: reduce', web_js, "reduced-motion boot guard"),
    ('window.synesthesiaBootPrepareHandoff = stopBootVideo', web_js, "browser decoder handoff"),
    ('window.synesthesiaBootPrepareHandoff && window.synesthesiaBootPrepareHandoff();', boot, "Godot browser-decoder stop"),
    ('cp assets/branding/menu-eye-poster.webp assets/branding/menu-eye-boot-loop.mp4 build/web/', builder, "web poster+loop deploy"),
    ('"/menu-eye-poster.webp"', worker, "offline poster shell"),
    ('experience_surface.get_render_label() if DebugProfile.is_local_desktop_debug() else ""', main, "debug-only render label"),
    ('if not _render_label.is_empty():', intro, "debug label conditional rendering"),
]
for token, source, label in checks:
    if token not in source:
        failures.append(label)


try:
    release_at = boot.index("released.emit()")
    fade_at = boot.index('fade.tween_property(self, "modulate:a"')
    if release_at > fade_at:
        failures.append("menu is still created only after splash fade (black-frame handoff)")
except ValueError:
    failures.append("splash/menu handoff ordering markers missing")

try:
    browser_stop_at = boot.index("window.synesthesiaBootPrepareHandoff")
    godot_arm_at = boot.index("_motif.arm_authored_animation(true)")
    if browser_stop_at > godot_arm_at:
        failures.append("browser boot decoder stops only after Godot decoder is armed")
except ValueError:
    failures.append("browser/Godot decoder handoff markers missing")

# Public boot copy should be experiential rather than render-debug jargon.
if 'ADAPTIVE NATIVE' in boot:
    failures.append("production Godot boot still exposes adaptive-native debug jargon")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_BOOT_VISUAL_CONTINUITY=FAIL count={len(failures)}")
print("SYNESTHESIA_BOOT_VISUAL_CONTINUITY=PASS native=authored-poster web=poster->deferred-loop godot=poster->same-loop decoder=single-handoff debug-chrome=hidden")
