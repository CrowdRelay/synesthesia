#!/usr/bin/env python3
"""Replaying a single finished room may only ever improve what is stored.

A rerun is played from the Korytarz after the album is closed. It is real, timed
play, but it is deliberately consequence-free: the run that actually finished the
album keeps its completed rooms, its album clock, its local run counter, its room
checkpoints and everything already recorded in CrowdRelay. The only writes a
rerun is allowed to make are a faster room time and a higher mastery score.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []


def text(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(path: str, *tokens: str) -> str:
    source = text(path)
    for token in tokens:
        if token not in source:
            failures.append(f"{path}: missing {token!r}")
    return source


def code_only(source: str) -> str:
    """Drop GDScript comments so a prose explanation never trips a forbid check."""
    return "\n".join(line.split("#", 1)[0] for line in source.splitlines())


def forbid(label: str, source: str, *tokens: str) -> None:
    body = code_only(source)
    for token in tokens:
        if token in body:
            failures.append(f"{label}: must not reach {token!r}")


metrics = require(
    "scripts/app/progress_metrics.gd",
    "static func record_rerun_attempt(",
    "rerun_improved",
)

# Scoring: strictly better, or nothing is written.
if "static func record_rerun_attempt(" in metrics:
    attempt = metrics.split("static func record_rerun_attempt(", 1)[1].split("\nstatic func ", 1)[0]
    for token in (
        "room_elapsed_ms < previous_room_best",
        "if room_personal_best:",
        # Mastery keeps the higher of the two scores; the rerun reuses that rule
        # instead of writing its own grade.
        "record_room_mastery(",
    ):
        if token not in attempt:
            failures.append(f"record_rerun_attempt: missing {token!r}")
    # Everything below describes the journey, not this attempt.
    forbid(
        "record_rerun_attempt", attempt,
        "completed_room_ids",
        "total_elapsed_ms",
        "room_elapsed_ms\"]",
        "completed_runs_local",
        "album_completed",
        "personal_best_total_ms",
    )

rerun = require(
    "scripts/app/room_rerun_runtime.gd",
    "func is_active()",
    "album_mode_controller.is_rerunning()",
    "ProgressMetrics.record_rerun_attempt(",
    "ProgressStoreScript.save_album(app.album_state)",
    # The clock starts on the first gesture, so door travel is never measured.
    "app.room_flow.reset_room_timer(false)",
    # A rerun is played, not watched: the room's own runtime and HUD come back.
    "app._resume_room_runtime()",
    "app.room.set_interaction_enabled(true)",
    # The result is presented, whether or not it beat the record.
    "rerun_improved",
    "WRÓĆ DO KORYTARZA",
)
forbid(
    "room_rerun_runtime", rerun,
    "save_checkpoint", "save_release", "_save_progress", "_save_album_state",
    "record_room", "complete_album", "arm_finale_guard", "reward_client",
)

flow = require(
    "scripts/app/main_room_flow.gd",
    "rerun_runtime = RoomRerunRuntime.new()",
)

# A rerun leaves _complete_current_room before any journey bookkeeping runs: no
# completion id, no album clock, no finale watchdog, no CrowdRelay record.
completion = flow.split("func _complete_current_room()", 1)[1].split("func pause_room_timer", 1)[0]
if "rerun_runtime.finish(" not in completion:
    failures.append("_complete_current_room: a rerun is scored through RoomRerunRuntime")
elif "\n        return\n" not in completion.split("rerun_runtime.finish(", 1)[1][:400]:
    failures.append("_complete_current_room: a rerun must return before journey bookkeeping")
else:
    handoff = completion.index("rerun_runtime.finish(")
    for token in (
        'app.album_state["completed_room_ids"] = completed_ids',
        'call_deferred("_arm_finale_after_grace")',
        "app.reward_client.record_room(",
        "record_completion_performance",
    ):
        if token in completion and completion.index(token) < handoff:
            failures.append(f"_complete_current_room: {token!r} runs before the rerun hand-off")

# A rerun is scored on what is painted now, so nothing of the stored attempt is
# restored into the room.
restore = flow.split("func _restore_room_after_layout", 1)[1].split("func _collectible_total", 1)[0]
if "rerun_runtime.prepare()" not in restore:
    failures.append("_restore_room_after_layout: a rerun must take the clean-room path")
elif restore.index("rerun_runtime.prepare()") > restore.index("ProgressStoreScript.load_release"):
    failures.append("_restore_room_after_layout: a rerun restores the previous attempt's painting")

# The finale watchdog must not seize the screen from a live attempt.
watchdog = flow.split("func _arm_finale_after_grace()", 1)[1].split("\nfunc ", 1)[0]
if "is_visiting(): return" not in watchdog:
    failures.append("_arm_finale_after_grace: the finale can still interrupt a corridor visit or a rerun")

# Revisiting a finished room never rewrites what the journey run saved: not the
# room checkpoint, not album_state, not the index the journey resumes from.
settings = require("scripts/app/main_settings_flow.gd", "album_mode_controller.is_visiting()")
if settings.count("album_mode_controller.is_visiting():\n        return") != 3:
    failures.append("main_settings_flow: _schedule_save/_save_progress/_save_album_state must all skip a visit")
# The HUD gear stays reachable while replaying, so "restart this room" must reset
# the attempt without un-finishing the room for the album.
reset = settings.split("func _reset_room()", 1)[1].split("\nfunc ", 1)[0]
if "is_visiting():" not in reset:
    failures.append("_reset_room: a rerun restart is not separated from clearing the journey's room")
else:
    guarded = reset.split("is_visiting():", 1)[1].split("\n    app.completion_announced", 1)[0]
    for token in ("clear_release", "completed_ids.erase(release_id)", 'app.album_state["room_elapsed_ms"] = elapsed'):
        if token not in guarded:
            failures.append(f"_reset_room: {token!r} escaped the journey-only branch")
require(
    "scripts/app/main_room_flow.gd",
    "if app.album_mode_controller == null or not app.album_mode_controller.is_visiting():",
)

# Both ways back into a finished room, and the mode that tells them apart.
require(
    "scripts/app/album_mode_controller.gd",
    "signal room_rerun_requested(index: int)",
    "func enter_room(index: int, finale_background, load_room: Callable, rerun: bool = false)",
    "func is_rerunning()",
    "func is_visiting()",
    # Only the listening visit hides the instrument panel.
    "if _hud != null and _listening:",
)
require(
    "scripts/ui/album_archive_card.gd",
    "signal room_rerun_requested(index: int)",
    "POWTÓRKA · POPRAW WYNIK",
    # The record a rerun is played against is readable before committing to one.
    "TWÓJ REKORD · %s",
    "REZONANS %s %d/100",
)
require("scripts/app/main_runtime_flow.gd", "room_rerun_requested.connect")
main = require(
    "scripts/main.gd",
    "func _enter_album_mode_room(index: int, rerun: bool = false)",
    'album_mode_controller.enter_room(index, finale_background, Callable(self, "_load_room"), rerun)',
    # Back/ESC out of a visit returns to the corridor, but a result card on screen
    # is dismissed first instead of being left orphaned behind the archive.
    "album_mode_controller.is_visiting() and completion_panel == null",
)
back = main.split("func _handle_back_request()", 1)[1].split("\n    return false", 1)[0]
for higher in ("settings_panel != null", "confirmation_panel != null"):
    if back.index(higher) > back.index("if completion_panel != null:"):
        failures.append(f"_handle_back_request: {higher} must still be dismissed before the completion card")

# The finale is a real entry point: its corridor CTA says so on both surfaces.
for surface in ("scripts/ui/signal_finale_card.gd", "scripts/ui/signal_finale_fallback_card.gd"):
    require(surface, "KORYTARZ · POWTÓRKA POKOJU")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_ROOM_RERUN=FAIL count={len(failures)}")

print("SYNESTHESIA_ROOM_RERUN=PASS scope=single-room writes=better-only journey=untouched entry=corridor+finale clock=first-gesture")
