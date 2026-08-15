#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
finale = (ROOT / "scripts/ui/signal_finale_card.gd").read_text()
settings = (ROOT / "scripts/ui/settings_card.gd").read_text()
main = (ROOT / "scripts/main.gd").read_text()
runtime = (ROOT / "scripts/app/main_runtime_flow.gd").read_text()
reward_flow = (ROOT / "scripts/app/main_reward_flow.gd").read_text()
failures: list[str] = []

def need(source: str, token: str, label: str) -> None:
    if token not in source:
        failures.append(f"{label}: missing {token!r}")

need(finale, "_form.visible = true", "finale")
need(finale, "_claim.disabled = not server_completed or not _ritual_complete", "finale")
need(finale, "_claim.disabled = not value or not _ritual_complete", "finale")
if "_form.visible = _ritual_complete" in finale:
    failures.append("finale: form is still hidden behind resonance ritual")

# Persisted/replay completion can enter finale without gameplay runtime/HUD.
need(reward_flow, "if app.hud != null and is_instance_valid(app.hud):", "finale-runtime")
need(reward_flow, "app.hud.visible = false", "finale-runtime")
show_reward = reward_flow.split("func _show_reward_panel", 1)[1].split("func _refresh_leaderboard", 1)[0]
if show_reward.index("app.reward_panel.configure(") > show_reward.index("app.reward_client.start_run()"):
    failures.append("finale-runtime: network reconciliation runs before the final menu is visible")
need(show_reward, "_on_run_started() reconciles every locally completed room before complete", "finale-runtime")

for token in (
    '_close_x.name = "CloseSettingsX"',
    "_close_x.z_index = 100",
    "_close_x.mouse_filter = Control.MOUSE_FILTER_STOP",
    "_close_x.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED",
    "_close_x.focus_mode = Control.FOCUS_ALL",
    "_close_x.custom_minimum_size = Vector2(56.0, 56.0) * _ui_scale",
    "UiMetrics.safe_insets(viewport)",
):
    need(settings, token, "settings")
if "panel.add_child(_close_x)" in settings or "scroll.add_child(_close_x)" in settings:
    failures.append("settings: close X regressed inside a scroll/panel input boundary")
for forbidden in (
    'preload("res://scripts/ui/app_hud.gd")',
    'preload("res://scripts/app/transition_director.gd")',
    'preload("res://scripts/app/asset_preloader.gd")',
    'preload("res://scripts/app/adaptive_performance.gd")',
    'preload("res://scripts/app/gameplay_telemetry.gd")',
    'preload("res://scripts/app/album_mode_controller.gd")',
):
    if forbidden in main:
        failures.append(f"startup: heavy preload returned to main: {forbidden}")
for token in (
    "await RenderingServer.frame_post_draw",
    "await _script(ASSET_PRELOADER_PATH)",
    "_prime_first_room()",
    "app.asset_preloader.prepare",
    "app.asset_preloader.prime_runtime_support",
):
    need(runtime, token, "startup")
if failures:
    print("\n".join("FAIL: " + item for item in failures))
    raise SystemExit(f"SYNESTHESIA_REPORTED_REGRESSIONS=FAIL count={len(failures)}")
print("SYNESTHESIA_REPORTED_REGRESSIONS=PASS finale=form-visible+hudless-safe+ui-first-sync settings=x-clickable startup=menu-first+first-room-priority")
