#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

hud = (ROOT / "scripts/ui/app_hud.gd").read_text(errors="replace")
intro = (ROOT / "scripts/ui/experience_intro_card.gd").read_text(errors="replace")
main = (ROOT / "scripts/main.gd").read_text(errors="replace")
transition = (ROOT / "scripts/app/transition_director.gd").read_text(errors="replace")
video = (ROOT / "scripts/render/room_video_layer.gd").read_text(errors="replace")

for token in (
    'header_row = HBoxContainer.new()',
    'top_panel.custom_minimum_size = Vector2(0.0, 146.0)',
    'bottom_panel.custom_minimum_size = Vector2(0.0, 146.0)',
    'instruction_label.text = "ODSŁANIAJ SCENĘ · SZUM → MUZYKA"',
    'subtitle_label.visible = true',
    'palette_row.visible = true',
    'brush_label.visible = true',
    'UIFactory.story_style(_accent, 0.88, false)',
    'progress_bar.name = "RevealProgress"',
    'func _repair_runtime_refs() -> void:',
    'if is_instance_valid(progress_bar):',
    'progress_bar.value = clampf(normalized, 0.0, 1.0)',
):
    if token not in hud:
        failures.append(f"HUD presentation token missing: {token}")

for token in (
    'VIRYA · SYNESTEZJA · 11 POKOJÓW',
    'WEJDŹ DO ŚRODKA',
    'Nie rozwiązujesz zagadek — odsłaniasz scenę',
    'To nie test i nie diagnoza',
    'WEJDŹ W SYNESTEZJĘ',
    'begin_requested.emit()',
):
    if token not in intro:
        failures.append(f"experience intro token missing: {token}")

for token in (
    'ExperienceIntroCardScript',
    'experience_intro_seen',
    'call_deferred("_show_experience_intro")',
    'await transition_director.travel_out()',
    'await transition_director.travel_in()',
):
    if token not in main:
        failures.append(f"main intro/door flow token missing: {token}")

for token in ('overlay.z_index = 930', 'door_layer.z_index = 940'):
    if token not in transition:
        failures.append(f"transition layering token missing: {token}")

if 'UnmaskedEyeGlow' in video or 'unmasked_eye_glow_layer' in video:
    failures.append("Unmasked synthetic eye glow must stay removed; use supplied source video")

coverage_start = main.find('func _on_coverage_changed')
coverage_end = main.find('func _on_collectible_found', coverage_start)
coverage_block = main[coverage_start:coverage_end]
if coverage_block.find('audio_director.set_progress') > coverage_block.find('hud.update_reveal'):
    failures.append("audio progress must update before HUD so UI failures cannot mute music")
complete_start = main.find('func _complete_current_room')
complete_end = main.find('var release_id:', complete_start)
complete_block = main[complete_start:complete_end]
if complete_block.find('audio_director.reveal_release_excerpt') > complete_block.find('hud.update_reveal'):
    failures.append("completion music must start before HUD updates")


lifecycle = (ROOT / "tests/lifecycle_smoke.gd").read_text()
for token in (
    '_require_button_width(experience, "WEJDŹ W SYNESTEZJĘ"',
    "func _find_button_with_prefix",
    "func _dispose_node",
):
    if token not in lifecycle:
        failures.append(f"lifecycle smoke missing intro/cleanup regression token: {token}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_PRESENTATION=FAIL count={len(failures)}")

print("SYNESTHESIA_PRESENTATION=PASS intro=door-entry hud=two-panel+content unmasked=source-video")
