#!/usr/bin/env python3
"""Static guard for the cheap-first-frame startup architecture."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text()
room_flow = (ROOT / "scripts/app/main_room_flow.gd").read_text()
reward_flow = (ROOT / "scripts/app/main_reward_flow.gd").read_text()
boot = (ROOT / "scripts/ui/boot_sequence.gd").read_text()
warmup = (ROOT / "scripts/app/main_warmup_flow.gd").read_text()
eye = (ROOT / "scripts/ui/door_eye_motif.gd").read_text()
failures: list[str] = []

ready = main[main.index("func _ready()"):main.index("func _build_application_shell()")]
intro = main[main.index("func _show_experience_intro()"):main.index("func _show_album_archive()")]
begin = main[main.index("func _begin_experience()"):main.index("func _enter_main_menu_mode()")]
reward_config = reward_flow[reward_flow.index("func _configure_reward_client()"):reward_flow.index("func _prepare_finale_background()")]
if "_load_room(" in ready:
    failures.append("_ready still constructs a room before the first usable frame")
if "reward_client.start_run()" in reward_config:
    failures.append("reward networking still starts during boot configuration")
if 'warmup_flow.call_deferred("warm_under_main_menu")' not in intro:
    failures.append("menu does not schedule its post-presentation warmup")
for token in ("await RenderingServer.frame_post_draw", "asset_preloader.prepare", "asset_preloader.prime_runtime_support", "begin_menu_soundscape"):
    if token not in warmup:
        failures.append(f"post-menu warmup contract missing: {token}")
if "asset_preloader.prepare" in intro:
    failures.append("room warmup starts before the main menu is presented")
if "_load_room(current_room_index, false)" not in begin:
    failures.append("first room is not instantiated behind the begin transition")
if "await asset_preloader.wait_for_queued()" not in begin:
    failures.append("first-room threaded warmup is not given a covered transition grace period")
if begin.index("await transition_director.travel_out()") > begin.index("_load_room(current_room_index, false)"):
    failures.append("first room is constructed before the door transition covers the screen")
if "reward_client.start_run()" not in begin:
    failures.append("reward networking is not gated on explicit experience start")
if "app.room.set_interaction_enabled(false)" not in room_flow:
    failures.append("new room can receive input before restore/layout completion")
if '_authored_video_armed = profile == "menu"' not in eye:
    failures.append("splash authored video must remain disarmed during first-frame construction")
if 'func arm_authored_animation(restart: bool = true)' not in eye:
    failures.append("authored eye lacks explicit post-first-frame arming gate")
if 'await RenderingServer.frame_post_draw' not in boot or '_motif.arm_authored_animation(true)' not in boot:
    failures.append("splash eye is not armed strictly after the first rendered Godot frame")
for token in (
    "const BOOT_HOLD: float = 0.28",
    "const EYE_REVEAL_DURATION: float = 0.50",
    "const FADE_DURATION: float = 0.20",
):
    if token not in boot:
        failures.append(f"bounded branded boot timing missing: {token}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_STARTUP_LATENCY=FAIL count={len(failures)}")
print("SYNESTHESIA_STARTUP_LATENCY=PASS first-frame=poster-only menu=present-then-warm room=thread-warm+runtime-support+door-wait network=interaction-gated audio=post-menu-threaded branded-boot=0.98s")
