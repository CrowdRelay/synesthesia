#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

checks = {
    "scripts/ui/experience_intro_card.gd": [
        "mouse_filter = Control.MOUSE_FILTER_STOP",
        "mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED",
        "focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED",
        "UIFactory.add_signal_backdrop(self, MENU_WORLD_PATH",
        "_panel.mouse_filter = Control.MOUSE_FILTER_PASS",
    ],
    "scripts/ui/settings_card.gd": [
        "mouse_filter = Control.MOUSE_FILTER_STOP",
        "mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED",
        "dim.mouse_filter = Control.MOUSE_FILTER_IGNORE",
        "panel.mouse_filter = Control.MOUSE_FILTER_PASS",
        "scroll.mouse_filter = Control.MOUSE_FILTER_PASS",
    ],
    "scripts/ui/confirm_card.gd": [
        "mouse_filter = Control.MOUSE_FILTER_STOP",
        "mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED",
        "dim.mouse_filter = Control.MOUSE_FILTER_IGNORE",
    ],
    "scripts/ui/signal_finale_card.gd": [
        "mouse_filter = Control.MOUSE_FILTER_STOP",
        "mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED",
        "dim.mouse_filter = Control.MOUSE_FILTER_IGNORE",
        "_panel.mouse_filter = Control.MOUSE_FILTER_PASS",
    ],
    "scripts/ui/completion_card.gd": [
        "mouse_filter = Control.MOUSE_FILTER_IGNORE",
        "mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED",
        "_sheet.mouse_filter = Control.MOUSE_FILTER_PASS",
    ],
}

failures: list[str] = []
for rel, tokens in checks.items():
    text = (ROOT / rel).read_text()
    for token in tokens:
        if token not in text:
            failures.append(f"{rel}: missing {token}")

# Modal roots are allowed to STOP because Godot targets the deepest eligible
# child first, then bubbles toward the parent. The root STOP is the boundary
# that prevents unused clicks from leaking into the paint room. Decorative
# fullscreen backdrops must IGNORE so they can never win hit-testing.
for rel in checks:
    text = (ROOT / rel).read_text()
    if rel == "scripts/ui/completion_card.gd":
        if "mouse_filter = Control.MOUSE_FILTER_IGNORE" not in text:
            failures.append(f"{rel}: bottom sheet host must pass clicks outside the sheet")
    elif "MOUSE_FILTER_STOP" not in text:
        failures.append(f"{rel}: modal root does not own background clicks")

ui_root_source = (ROOT / "scripts/app/interactive_ui_root.gd").read_text()
for token in (
    'name = "InteractiveUiRoot"',
    "mouse_filter = Control.MOUSE_FILTER_IGNORE",
    "mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED",
    "focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED",
    "func attach(control: Control, layer: int)",
):
    if token not in ui_root_source:
        failures.append(f"interactive_ui_root.gd: missing dedicated UI boundary {token}")

main = (ROOT / "scripts/main.gd").read_text()
for token in (
    "InteractiveUiRootScript.new()",
    "ui_root.attach(experience_intro_panel, 20)",
    "boot.released.connect(_show_experience_intro)",
):
    if token not in main:
        failures.append(f"main.gd: missing dedicated interactive UI attachment {token}")

for rel, token in (
    ("scripts/app/main_settings_flow.gd", "app.ui_root.attach(app.settings_panel, 60)"),
    ("scripts/app/main_reward_flow.gd", "app.ui_root.attach(app.reward_panel, 40)"),
):
    if token not in (ROOT / rel).read_text():
        failures.append(f"{rel}: missing dedicated interactive UI attachment {token}")

boot = (ROOT / "scripts/ui/boot_sequence.gd").read_text()
for token in (
    "mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED",
    "focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED",
    "released.emit()",
    "queue_free()",
):
    if token not in boot:
        failures.append(f"boot_sequence.gd: boot does not release input: {token}")

transition = (ROOT / "scripts/app/transition_director.gd").read_text()
if "overlay.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED" not in transition:
    failures.append("transition_director.gd: hidden overlay can retain mouse ownership")

door = (ROOT / "scripts/app/door_transition_layer.gd").read_text()
if "MOUSE_BEHAVIOR_ENABLED if active else Control.MOUSE_BEHAVIOR_DISABLED" not in door:
    failures.append("door_transition_layer.gd: hidden door layer can retain mouse ownership")

lifecycle = (ROOT / "tests/lifecycle_smoke.gd").read_text()
for token in (
    '_click_button(experience, "WEJDŹ DO ŚRODKA"',
    "_exercise_live_ui_stack()",
    "gui_get_hovered_control()",
    "live-ui-stack pointer click did not reach menu Button.pressed",
):
    if token not in lifecycle:
        failures.append(f"lifecycle_smoke.gd: missing live input assertion {token}")

if failures:
    for failure in failures:
        print(f"ERROR: {failure}")
    raise SystemExit(1)

print("SYNESTHESIA_UI_INPUT=PASS ui-root=dedicated modal-boundary=stop completion-host=ignore decorative=ignore boot=release transitions=inactive runtime=live-stack-pointer")
