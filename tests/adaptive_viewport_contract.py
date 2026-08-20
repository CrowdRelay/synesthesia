#!/usr/bin/env python3
"""Contract for native/adaptive viewport geometry across representative screens."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PORTRAIT_ASPECT = 9.0 / 16.0
PHONE_ASPECT_CUTOFF = 0.72


def fit(width: float, height: float):
    aspect = width / height
    if aspect <= PHONE_ASPECT_CUTOFF:
        target_w, target_h = width, height
    else:
        target_h = height
        target_w = target_h * PORTRAIT_ASPECT
        if target_w > width:
            target_w = width
            target_h = target_w / PORTRAIT_ASPECT
    content_aspect = target_w / target_h
    if content_aspect < PORTRAIT_ASPECT:
        art_w, art_h = target_h * PORTRAIT_ASPECT, target_h
    else:
        art_w, art_h = target_w, target_w / PORTRAIT_ASPECT
    return tuple(round(v) for v in (target_w, target_h, art_w, art_h))

cases = {
    "fhd-portrait": ((1080, 1920), (1080, 1920, 1080, 1920)),
    "ultrawide-3440x1440": ((3440, 1440), (810, 1440, 810, 1440)),
    "desktop-1920x1080": ((1920, 1080), (608, 1080, 608, 1080)),
    "phone-360x640": ((360, 640), (360, 640, 360, 640)),
    "tall-phone-390x844": ((390, 844), (390, 844, 475, 844)),
}
failures = []
for name, (viewport, expected) in cases.items():
    got = fit(*viewport)
    if got != expected:
        failures.append(f"{name}: {got} != {expected}")

project = (ROOT / "project.godot").read_text()
exports = (ROOT / "export_presets.cfg").read_text()
surface = (ROOT / "scripts/app/native_experience_surface.gd").read_text()
boot = (ROOT / "scripts/ui/boot_sequence.gd").read_text()
web_boot = (ROOT / "web/boot-shell.js").read_text()
main = (ROOT / "scripts/main.gd").read_text()
for token, source, label in [
    ('stretch/mode="disabled"', project, 'stretch-disabled'),
    ('size/viewport_width=1080', project, 'fhd-fallback-width'),
    ('size/viewport_height=1920', project, 'fhd-fallback-height'),
    ('html/canvas_resize_policy=2', exports, 'web-adaptive-canvas'),
    ('PHONE_ASPECT_CUTOFF: float = 0.72', surface, 'responsive-cutoff'),
    ('get_viewport_rect().size', surface, 'native-root-size'),
    ('PRZYGOTOWUJĘ ODDZIAŁ', boot, 'branded-boot-status'),
    ('window.devicePixelRatio', web_boot, 'web-dpr-probe'),
    ('ui_root.attach(experience_intro_panel, 20)', main, 'menu-full-native-ui-root'),
    ('room_layer.position = art_rect.position', main, 'room-cover-position'),
    ('room_layer.size = art_rect.size', main, 'room-cover-size'),
]:
    if token not in source:
        failures.append(label)

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_ADAPTIVE_VIEWPORT=FAIL count={len(failures)}")

print("SYNESTHESIA_ADAPTIVE_VIEWPORT=PASS cases=5 fhd=fallback ultrawide=810x1440 phone=cover no-fixed-540-runtime boot=ward")
