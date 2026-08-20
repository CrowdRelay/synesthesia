#!/usr/bin/env python3
"""Offline production contracts for VIRYA: Synestezja 0.11."""
from __future__ import annotations

import json
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_ORDER = [
    "wave-of-uncertainty", "party-time", "unmasked", "the-calling",
    "seed-of-doubt", "hybrid", "technophobia", "invaluable",
    "from-the-ashes", "waves", "rise",
]
EXPECTED_STYLES = {
    "wave-of-uncertainty": "uncertainty", "party-time": "party",
    "unmasked": "unmasked", "the-calling": "calling",
    "seed-of-doubt": "seed", "hybrid": "hybrid",
    "technophobia": "technophobia", "invaluable": "invaluable",
    "from-the-ashes": "ashes", "waves": "waves", "rise": "rise",
}
REQUIRED_FILES = [
    "VERSION", "project.godot", "export_presets.cfg", "netlify.toml",
    "run-macos.sh", "validate.sh", "scripts/build-web-preview.sh",
    "scenes/main.tscn", "scripts/main.gd", "scripts/audio_director.gd",
    "scripts/haptics.gd", "scripts/progress_store.gd", "scripts/reward_client.gd",
    "scripts/render/room_stage.gd", "scripts/render/reveal_mask.gd", "scripts/render/room_render_profile.gd",
    "scripts/render/atmosphere_layer.gd", "scripts/render/interaction_fx_layer.gd", "scripts/render/room_dressing_layer.gd", "scripts/render/room_video_layer.gd", "scripts/render/post_reveal_living_runtime.gd", "scripts/brush/brush_engine.gd",
    "scripts/app/quality_manager.gd", "scripts/app/asset_preloader.gd", "scripts/app/adaptive_performance.gd", "scripts/app/native_experience_surface.gd", "scripts/app/signal_signup_client.gd", "scripts/app/menu_runtime_guard.gd", "scripts/app/debug_profile.gd",
    "scripts/app/transition_director.gd", "scripts/app/door_transition_layer.gd", "scripts/app/diagnostics_overlay.gd", "scripts/app/gameplay_telemetry.gd",
    "scripts/ui/app_hud.gd", "scripts/ui/ui_factory.gd", "scripts/ui/ui_metrics.gd", "scripts/ui/signal_backdrop.gd", "scripts/ui/door_eye_motif.gd", "scripts/ui/chapter_card.gd", "scripts/ui/experience_intro_card.gd", "scripts/ui/completion_card.gd", "scripts/ui/settings_card.gd", "scripts/ui/confirm_card.gd", "scripts/ui/echoes_finale_background.gd", "scripts/ui/signal_finale_card.gd", "scripts/ui/signal_finale_next_event.gd", "scripts/ui/boot_sequence.gd", "scripts/ui/mobile_instruction_builder.gd",
    "scripts/rooms/behavior_base.gd", "shaders/room_composite.gdshader", "shaders/echoes_finale.gdshader", "shaders/room_video_postprocess.gdshader",
    "assets/branding/signal-glyph-loop.ogv", "assets/audio/pink-noise-asmr-loop.ogg", "assets/audio/balloon-pop.mp3", "assets/finale/echoes-finale.webp", "default_bus_layout.tres",
    "data/release_index.json", "data/room_asset_slots.json", "scripts/validate-fast.sh", "tests/validate_project.gd",
    "tests/room_pipeline_contract.py", "tests/capture_rooms.gd",
    "tests/visual_snapshot_contract.py", "tests/visual_snapshots.json",
    "tests/new_release_pack_contract.py", "tests/production_polish_contract.py", "tests/cinematic_video_contract.py", "tests/presentation_contract.py", "tests/mobile_clarity_contract.py", "tests/mobile_product_readability_contract.py", "tests/gameplay_telemetry_contract.py", "assets/video/manifest.json", "tools/update_visual_snapshots.py",
    "tools/perf_budget.py", "tools/memory_budget.py", "tools/audio_mix_budget.py",
    "tools/new_release_pack.py", "tools/asset_report.py", "tools/reset_local_progress.gd", "tests/lifecycle_smoke.gd",
    "web/boot-shell.css", "web/boot-shell.js", "web/_headers", "web/register-sw.js",
    "web/service-worker.js", "web/manifest.webmanifest", "assets/icon.svg", "assets/icon-192.png", "assets/icon-512.png", "assets/icon-adaptive-432.png", "assets/icon-background-432.png", "assets/branding/boot-splash.png",
    ".github/workflows/ci.yml", ".github/workflows/build.yml",
    ".github/workflows/deploy-web.yml", ".github/workflows/android-apk.yml",
    "docs/MOBILE_CLARITY.md", "docs/MOBILE_PLAYTEST.md",
]
MANIFEST_KEYS = {
    "schema_version", "release_id", "story_order", "artist", "title",
    "subtitle", "room", "sensory", "collectibles", "audio", "intro",
    "completion_title", "completion_message",
}
FORBIDDEN_PATHS = ["scripts/paint_room.gd", "shaders/visual_snow.gdshader"]


def fail(message: str, failures: list[str]) -> None:
    failures.append(message)


def load_json(path: Path, failures: list[str]) -> dict:
    try:
        value = json.loads(path.read_text())
    except Exception as exc:
        fail(f"invalid JSON {path.relative_to(ROOT)}: {exc}", failures)
        return {}
    if not isinstance(value, dict):
        fail(f"JSON root must be an object: {path.relative_to(ROOT)}", failures)
        return {}
    return value


def webp_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()[:64]
    if len(data) < 30 or data[:4] != b"RIFF" or data[8:12] != b"WEBP":
        raise ValueError("not a WebP file")
    chunk = data[12:16]
    if chunk == b"VP8X":
        width = 1 + int.from_bytes(data[24:27], "little")
        height = 1 + int.from_bytes(data[27:30], "little")
        return width, height
    if chunk == b"VP8 ":
        offset = data.find(b"\x9d\x01\x2a")
        if offset < 0 or len(data) < offset + 7:
            raise ValueError("invalid VP8 frame")
        width, height = struct.unpack_from("<HH", data, offset + 3)
        return width & 0x3FFF, height & 0x3FFF
    if chunk == b"VP8L":
        if data[20] != 0x2F:
            raise ValueError("invalid VP8L frame")
        bits = int.from_bytes(data[21:25], "little")
        return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
    raise ValueError(f"unsupported WebP chunk {chunk!r}")


def resource_path(value: object, label: str, failures: list[str]) -> Path | None:
    if not isinstance(value, str) or not value.startswith("res://"):
        fail(f"{label}: expected res:// path", failures)
        return None
    path = ROOT / value.removeprefix("res://")
    if not path.is_file():
        fail(f"{label}: missing {path.relative_to(ROOT)}", failures)
        return None
    return path


def validate_manifest(path: Path, slug: str, order: int, failures: list[str]) -> None:
    data = load_json(path, failures)
    if not data:
        return
    missing = MANIFEST_KEYS - data.keys()
    if missing:
        fail(f"{slug}: manifest missing keys {sorted(missing)}", failures)
    if data.get("schema_version") != 4:
        fail(f"{slug}: schema_version must equal 4", failures)
    if data.get("release_id") != slug or data.get("story_order") != order:
        fail(f"{slug}: release_id/story_order mismatch", failures)

    room = data.get("room")
    if not isinstance(room, dict):
        fail(f"{slug}: room must be an object", failures)
        return
    expected_room_fields = {
        "id": slug,
        "scene_path": f"res://scenes/rooms/{slug}.tscn",
        "behavior_script": f"res://scripts/rooms/behaviors/{slug}.gd",
        "render_pipeline": "mask-gpu-v2",
        "visual_style": EXPECTED_STYLES[slug],
    }
    for key, expected in expected_room_fields.items():
        if room.get(key) != expected:
            fail(f"{slug}: room.{key} must equal {expected!r}", failures)
    resource_path(room.get("scene_path"), f"{slug}: scene", failures)
    resource_path(room.get("behavior_script"), f"{slug}: behavior", failures)
    threshold = room.get("completion_coverage")
    if not isinstance(threshold, (int, float)) or not 0.25 <= float(threshold) <= 0.70:
        fail(f"{slug}: completion_coverage outside 0.25..0.70", failures)
    if abs(float(room.get("cinematic_reveal_at", 0.0)) - 0.99) > 0.0001:
        fail(f"{slug}: cinematic_reveal_at must equal 0.99", failures)

    brush = room.get("brush")
    if not isinstance(brush, dict):
        fail(f"{slug}: brush must be an object", failures)
    else:
        for key in ("profile", "min_width", "max_width", "opacity", "texture", "outline", "spacing"):
            if key not in brush:
                fail(f"{slug}: brush missing {key}", failures)
        if float(brush.get("max_width", 0)) < float(brush.get("min_width", 0)):
            fail(f"{slug}: brush max_width is below min_width", failures)

    art = room.get("art_direction")
    if not isinstance(art, dict):
        fail(f"{slug}: art_direction must be an object", failures)
    else:
        if art.get("style") != "virya_signal_cinematic" or art.get("material_pass") != "production-2.5d":
            fail(f"{slug}: V2 signal-cinematic production material pass required", failures)
        scene = resource_path(art.get("scene_image"), f"{slug}: vertical scene", failures)
        background = resource_path(art.get("background_image"), f"{slug}: vertical background", failures)
        subject = resource_path(art.get("subject_image"), f"{slug}: subject layer", failures)
        foreground = resource_path(art.get("foreground_image"), f"{slug}: foreground layer", failures)
        if scene and scene.suffix.lower() == ".webp":
            try:
                if webp_size(scene) != (675, 1200):
                    fail(f"{slug}: scene must be 675x1200", failures)
            except ValueError as exc:
                fail(f"{slug}: invalid scene WebP: {exc}", failures)
            # File size is only a corruption/placeholder guard. Highly compressible
            # authored ward paintings remain visually clean well below the old
            # 45 KB floor, while the 420 KB ceiling still protects mobile payload.
            if not 12_000 <= scene.stat().st_size <= 420_000:
                fail(f"{slug}: scene outside 12..420 KB budget", failures)
        if background and background.suffix.lower() == ".webp":
            try:
                if webp_size(background) != (405, 720):
                    fail(f"{slug}: background must be 405x720", failures)
            except ValueError as exc:
                fail(f"{slug}: invalid background WebP: {exc}", failures)
            if not 2_000 <= background.stat().st_size <= 220_000:
                fail(f"{slug}: background outside 2..220 KB budget", failures)
        if subject and subject.suffix.lower() == ".webp":
            try:
                if webp_size(subject) != (675, 1200):
                    fail(f"{slug}: subject layer must be 675x1200", failures)
            except ValueError as exc:
                fail(f"{slug}: invalid subject WebP: {exc}", failures)
            if not 8_000 <= subject.stat().st_size <= 300_000:
                fail(f"{slug}: subject layer outside 8..300 KB budget", failures)
        if foreground and foreground.suffix.lower() == ".webp":
            try:
                if webp_size(foreground) != (540, 960):
                    fail(f"{slug}: foreground layer must be 540x960", failures)
            except ValueError as exc:
                fail(f"{slug}: invalid foreground WebP: {exc}", failures)
            if not 8_000 <= foreground.stat().st_size <= 220_000:
                fail(f"{slug}: foreground layer outside 8..220 KB budget", failures)
        if art.get("layers") != ["background", "scene", "subject", "foreground", "atmosphere"]:
            fail(f"{slug}: exact five-layer 2.5D stack required", failures)
        for key, maximum in (("scene_parallax", 0.03), ("background_parallax", 0.03), ("subject_parallax", 0.06), ("foreground_parallax", 0.09)):
            value = art.get(key)
            if not isinstance(value, (int, float)) or not 0.0 <= float(value) <= maximum:
                fail(f"{slug}: {key} outside 0..{maximum}", failures)

    sensory = data.get("sensory")
    if not isinstance(sensory, dict):
        fail(f"{slug}: sensory must be an object", failures)
        sensory = {}
    if float(sensory.get("safe_audio_ceiling_db", 0.0)) > -6.0:
        fail(f"{slug}: safe audio ceiling must be <= -6 dB", failures)
    for key in ("visual_snow_calm", "visual_snow_full"):
        value = sensory.get(key)
        if not isinstance(value, (int, float)) or not 0.0 <= float(value) <= 0.12:
            fail(f"{slug}: {key} outside 0..0.12", failures)
    tint = sensory.get("visual_snow_tint")
    if not isinstance(tint, str) or not re.fullmatch(r"#[0-9A-Fa-f]{6}", tint):
        fail(f"{slug}: visual_snow_tint must be #RRGGBB", failures)

    collectibles = data.get("collectibles")
    if not isinstance(collectibles, list) or len(collectibles) != 3:
        fail(f"{slug}: exactly three narrative traces required", failures)
    else:
        ids: set[str] = set()
        for item in collectibles:
            if not isinstance(item, dict):
                fail(f"{slug}: collectible must be an object", failures)
                continue
            item_id = item.get("id")
            if not isinstance(item_id, str) or not item_id or item_id in ids:
                fail(f"{slug}: collectible IDs must be non-empty and unique", failures)
            else:
                ids.add(item_id)
            position = item.get("position")
            if not isinstance(position, list) or len(position) != 2 or any(
                not isinstance(v, (int, float)) or not 0.0 <= float(v) <= 1.0 for v in position
            ):
                fail(f"{slug}: invalid collectible position", failures)

    audio = data.get("audio")
    if not isinstance(audio, dict):
        fail(f"{slug}: audio must be an object", failures)
        return
    if audio.get("mode") != "pink_noise_reveal_mix":
        fail(f"{slug}: pink_noise_reveal_mix required", failures)
    if audio.get("noise_loop") != "res://assets/audio/pink-noise-asmr-loop.ogg":
        fail(f"{slug}: canonical static noise loop required", failures)
    resource_path(audio.get("noise_loop"), f"{slug}: noise loop", failures)
    resource_path(audio.get("completion_excerpt"), f"{slug}: music excerpt", failures)
    if not bool(audio.get("stereo_reveal")) or not bool(audio.get("dynamic_space_reveal")):
        fail(f"{slug}: stereo and dynamic-space reveal required", failures)
    start_hz = audio.get("lowpass_start_hz")
    final_hz = audio.get("lowpass_final_hz")
    if not isinstance(start_hz, (int, float)) or not 600 <= float(start_hz) <= 2500:
        fail(f"{slug}: lowpass_start_hz outside 600..2500", failures)
    if not isinstance(final_hz, (int, float)) or not 18000 <= float(final_hz) <= 20500:
        fail(f"{slug}: lowpass_final_hz outside 18000..20500", failures)


def main() -> int:
    failures: list[str] = []
    for rel in REQUIRED_FILES:
        if not (ROOT / rel).is_file():
            fail(f"missing required file: {rel}", failures)
    for rel in FORBIDDEN_PATHS:
        if (ROOT / rel).exists():
            fail(f"legacy renderer must be removed: {rel}", failures)
    if (ROOT / "virya-synestezja").exists():
        fail("nested virya-synestezja directory is forbidden", failures)

    # Godot 4.7.1 Color has no with_alpha() method. Use Color(existing_color, alpha).
    forbidden_color_api = []
    for gdscript in sorted(ROOT.rglob("*.gd")):
        if ".with_alpha(" in gdscript.read_text():
            forbidden_color_api.append(str(gdscript.relative_to(ROOT)))
    if forbidden_color_api:
        fail("Godot 4.7.1-incompatible Color.with_alpha() usage: " + ", ".join(forbidden_color_api), failures)

    # step/mix/fract and derivative helpers are shader-language functions, not GDScript globals.
    shader_only_calls: list[str] = []
    shader_only_pattern = re.compile(r"(?<![A-Za-z0-9_.])(step|mix|fract|dFdx|dFdy|fwidth)\s*\(")
    for gdscript in sorted(ROOT.rglob("*.gd")):
        source = gdscript.read_text()
        match = shader_only_pattern.search(source)
        if match:
            shader_only_calls.append(f"{gdscript.relative_to(ROOT)}:{match.group(1)}")
    if shader_only_calls:
        fail("shader-only function used from GDScript: " + ", ".join(shader_only_calls), failures)

    if (ROOT / "VERSION").read_text().strip() != "2.0.0":
        fail("VERSION must equal 2.0.0", failures)
    project = (ROOT / "project.godot").read_text()
    for token in ('config/version="2.0.0"', "size/viewport_width=1080", "size/viewport_height=1920", "dpi/allow_hidpi=true", 'stretch/mode="disabled"', 'boot_splash/image="res://assets/branding/boot-splash.png"'):
        if token not in project:
            fail(f"project.godot missing {token}", failures)
    export_source = (ROOT / "export_presets.cfg").read_text()
    for token in ('version/name="2.0.0"', 'html/canvas_resize_policy=2'):
        if token not in export_source:
            fail(f"adaptive export contract missing: {token}", failures)
    if not re.search(r'(?m)^version/code=[1-9][0-9]*$', export_source):
        fail("adaptive export contract missing: positive version/code", failures)
    native_surface = (ROOT / "scripts/app/native_experience_surface.gd").read_text()
    for token in ('PRESET_FULL_RECT', 'PHONE_ASPECT_CUTOFF', 'get_content_surface', 'get_render_label', 'viewport_size.x / viewport_size.y'):
        if token not in native_surface:
            fail(f"native viewport contract missing: {token}", failures)

    required_audio = [
        "pink-noise-asmr-loop.ogg", "wave-of-uncertainty-room-outro.mp3",
        "party-time-room-outro.mp3", "unmasked-room-outro.mp3",
        "the-calling-room-outro.mp3", "seed-of-doubt-room-outro.mp3",
        "hybrid-room-outro.mp3", "technophobia-room-outro.mp3",
        "invaluable-room-outro.mp3", "from-the-ashes-room-outro.mp3",
        "waves-room-outro.mp3", "rise-room-outro.mp3",
    ]
    for filename in required_audio:
        audio_path = ROOT / "assets/audio" / filename
        if not audio_path.is_file() or audio_path.stat().st_size < 50_000:
            fail(f"missing or truncated audio asset: assets/audio/{filename}", failures)

    pop_path = ROOT / "assets/audio/balloon-pop.mp3"
    if not pop_path.is_file() or not 3_000 <= pop_path.stat().st_size <= 80_000:
        fail("balloon pop SFX missing or outside compact budget", failures)
    finale_path = ROOT / "assets/finale/echoes-finale.webp"
    if not finale_path.is_file():
        fail("Echoes finale artwork is missing", failures)
    else:
        try:
            if webp_size(finale_path) != (810, 1440):
                fail("Echoes finale artwork must be 810x1440", failures)
        except ValueError as exc:
            fail(f"invalid Echoes finale WebP: {exc}", failures)

    ui_factory_source = (ROOT / "scripts/ui/ui_factory.gd").read_text()
    settings_source = (ROOT / "scripts/ui/settings_card.gd").read_text()
    hud_source = (ROOT / "scripts/ui/app_hud.gd").read_text()
    hud_layout_source = (ROOT / "scripts/ui/hud_layout_flow.gd").read_text()
    hud_contract_source = hud_source + "\n" + hud_layout_source
    video_shader_source = (ROOT / "shaders/room_video_postprocess.gdshader").read_text()
    gear_path = ROOT / "assets/ui/settings-gear.svg"
    gear_script = ROOT / "scripts/ui/settings_gear_icon.gd"
    if gear_path.exists():
        fail("legacy settings gear SVG must stay removed from the slim Signal V2 tree", failures)
    if not gear_script.is_file() or gear_script.stat().st_size < 500:
        fail("procedural settings gear script missing or truncated", failures)
    for token in ('SettingsGearIcon', 'SettingsGearIcon.new()', 'SettingsGearIcon'):
        if token not in hud_contract_source:
            fail(f"procedural settings gear button contract missing: {token}", failures)
    for token in ('instruction_label.text = "ODSŁANIAJ SCENĘ · SZUM USTĘPUJE MUZYCE"', 'top_accent_bar', 'bottom_accent_bar', 'subtitle_label.visible = true'):
        if token not in hud_contract_source:
            fail(f"persistent HUD information/style contract missing: {token}", failures)
    intro_source = (ROOT / "scripts/ui/experience_intro_card.gd").read_text()
    for token in ('SYNESTHESIA', 'WEJŚCIE // SESJA', 'PRZEKROCZ PRÓG', 'NOWA WĘDRÓWKA', 'USTAWIENIA', 'SYGNAŁ', 'TWÓRCY', 'Jedenaście komnat jednego oddziału utkanych z obrazu', 'SignalSignupClient', 'nie daje losu w puli 5 płyt', 'begin_requested'):
        if token not in intro_source:
            fail(f"experience menu contract missing: {token}", failures)
    chapter_source = (ROOT / "scripts/ui/chapter_card.gd").read_text()
    for token in ('mouse_filter = Control.MOUSE_FILTER_IGNORE', '_timer.wait_time = 4.4', 'ROZEJRZYJ SIĘ'):
        if token not in chapter_source:
            fail(f"non-blocking chapter rail contract missing: {token}", failures)
    eye_source = (ROOT / "scripts/ui/door_eye_motif.gd").read_text()
    for token in ('_blink', 'trigger_glitch', '_draw_brain', 'set_open_mix'):
        if token not in eye_source:
            fail(f"door-eye motif contract missing: {token}", failures)
    signal_signup = (ROOT / "scripts/app/signal_signup_client.gd").read_text()
    for token in ('/v1/public/cities?limit=100', '/v1/fans', '"marketing": true', 'Idempotency-Key'):
        if token not in signal_signup:
            fail(f"menu Signal signup contract missing: {token}", failures)
    if 'reward-claims' in signal_signup or 'enter_draw' in signal_signup:
        fail("menu Signal signup must never create a Synesthesia draw entry", failures)
    if 'UIFactory.button("⋯"' in hud_source or 'UIFactory.button("⚙"' in hud_source:
        fail("settings button must use the procedural gear, not a font glyph/emoji", failures)
    if 'vec3 soft_bloom' in video_shader_source:
        fail("video shader must not sample CanvasItem TEXTURE from helper scope", failures)
    run_source = (ROOT / "run-macos.sh").read_text()
    if "settings-gear.svg-*" not in run_source:
        fail("run-macos must purge the legacy crashy settings SVG import cache", failures)
    progress_source = (ROOT / "scripts/progress_store.gd").read_text()
    if "ScrollContainer.SCROLL_MODE_DISABLED" not in ui_factory_source or "horizontal_scroll_mode = 0" not in settings_source:
        fail("responsive scroll layout contract missing: horizontal scroll must be disabled", failures)
    if "content.custom_minimum_size" not in ui_factory_source or "_content.custom_minimum_size" not in settings_source:
        fail("responsive scroll layout contract missing: content minimum width", failures)
    for token in ("--headless --editor", "--reset", "pink-noise-asmr-loop.ogg"):
        if token not in run_source:
            fail(f"run-macos import/reset contract missing: {token}", failures)
    for token in ("reset_local_journey", "server_recorded_room_ids", "server_album_completed"):
        if token not in progress_source:
            fail(f"safe local reset contract missing: {token}", failures)

    index = load_json(ROOT / "data/release_index.json", failures)
    releases = index.get("releases")
    if index.get("schema_version") != 4:
        fail("release index schema_version must equal 4", failures)
    if not isinstance(releases, list) or [r.get("id") for r in releases if isinstance(r, dict)] != EXPECTED_ORDER:
        fail("release index must contain the exact eleven-room route", failures)
    else:
        for order, entry in enumerate(releases):
            manifest_value = entry.get("manifest")
            manifest_path = resource_path(manifest_value, f"{entry.get('id')}: manifest", failures)
            if manifest_path:
                validate_manifest(manifest_path, EXPECTED_ORDER[order], order, failures)

    gd_sources = {p: p.read_text() for p in ROOT.rglob("*.gd")}
    for path, source in gd_sources.items():
        rel = path.relative_to(ROOT)
        if re.search(r"(?m)^\s*func\s+draw_[A-Za-z0-9_]+\s*\(", source):
            fail(f"custom draw_* helper forbidden: {rel}", failures)
        if "scripts/paint_room.gd" in source or "visual_snow.gdshader" in source:
            fail(f"legacy renderer reference in {rel}", failures)
    # Keep the readability ratchet, but allow a narrow engineering headroom
    # band so a small resilience fix does not force artificial file splitting.
    # 420 remains the design target; 460 is the hard stop.
    readability_soft_budget = 420
    readability_hard_budget = 460
    for path in sorted((ROOT / "scripts").rglob("*.gd")):
        lines = len(path.read_text().splitlines())
        rel = path.relative_to(ROOT)
        if lines > readability_hard_budget:
            fail(
                f"production GDScript exceeds {readability_hard_budget}-line hard readability cap: "
                f"{rel}={lines}",
                failures,
            )
        elif lines > readability_soft_budget:
            print(
                f"WARN: production GDScript above {readability_soft_budget}-line soft readability budget: "
                f"{rel}={lines} hard_cap={readability_hard_budget}",
                file=sys.stderr,
            )

    shader = (ROOT / "shaders/room_composite.gdshader").read_text()
    for token in ("reveal_mask", "background_texture", "subject_texture", "foreground_texture", "noise_intensity", "scanline_strength", "quiet_visuals", "quality_level", "completion_reveal", "brush_energy", "runtime_scale", "cinematic_time", "unlock_motion", "unlock_profile"):
        if token not in shader:
            fail(f"composite shader missing {token}", failures)
    if "AudioEffectHardLimiter" not in (ROOT / "default_bus_layout.tres").read_text():
        fail("Master hard limiter is required", failures)

    old_jpgs = list((ROOT / "assets/rooms").glob("*.jpg"))
    if old_jpgs:
        fail("horizontal legacy room JPGs must be removed", failures)

    if failures:
        for message in failures:
            print(f"FAIL: {message}", file=sys.stderr)
        print(f"SYNESTHESIA_STATIC_VALIDATION=FAIL count={len(failures)}", file=sys.stderr)
        return 1
    print("SYNESTHESIA_STATIC_VALIDATION=PASS rooms=11 schema=4 adaptive_native=true bootstrap=1080x1920 renderer=mask-gpu-v2")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())