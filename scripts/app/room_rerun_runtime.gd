extends Node

# Owns a rerun: one already finished room, replayed from the Korytarz to beat the
# record it is holding. A rerun is real, timed play — not the passive Album Mode
# listening visit — but it is deliberately consequence-free. Only a better result
# is written; the run that closed the album keeps its completed rooms, its album
# clock, its local run counter and everything already recorded in CrowdRelay.

const RuntimeFactory := preload("res://scripts/app/room_runtime_factory.gd")
const RoomObjective := preload("res://scripts/app/room_objective.gd")

var app: Node

func bind(owner: Node) -> void:
    app = owner

func is_active() -> bool:
    return app.album_mode_controller != null and app.album_mode_controller.is_rerunning()

func prepare() -> void:
    # The room comes back with its own runtime, HUD and clock. Nothing of the
    # previous attempt is restored: a rerun is scored on what is painted now.
    app._resume_room_runtime()
    app._apply_sensory_mode()
    if app.hud != null and is_instance_valid(app.hud):
        app.hud.resume_for_room()
        app.hud.update_discovery("POWTÓRKA · zapisujemy tylko lepszy wynik")
    if app.room != null and is_instance_valid(app.room):
        app.room.set_post_reveal_interaction(false)
        app.room.set_interaction_enabled(true)
    # Start the clock on the first gesture instead of here, so the door travel and
    # the first look around are never counted against the attempt.
    app.room_flow.reset_room_timer(false)

func finish(release_id: String, elapsed_ms: int, guidance: Dictionary, found_echoes: int, total_echoes: int) -> void:
    var performance: Dictionary = app.ProgressMetrics.record_rerun_attempt(
        app.album_state, release_id, elapsed_ms, found_echoes, total_echoes, guidance
    )
    # Only album_state travels to disk. The room checkpoint belongs to the journey
    # run: rewriting it here would let a rerun that skipped the echoes erase them
    # from the finale summary.
    app.ProgressStoreScript.save_album(app.album_state)
    _show_result(performance)

func leave() -> void:
    app._remove_modal(app.completion_panel)
    app.completion_panel = null
    app._show_album_archive()

func _show_result(performance: Dictionary) -> void:
    if app.ui_root == null:
        return
    # The result card owns the return affordance; hide the corridor button so
    # both paths back don't compete on screen.
    if app.album_mode_controller != null:
        app.album_mode_controller.hide_return()
    var improved: bool = bool(performance.get("rerun_improved", false))
    var room_value: Variant = app.manifest.get("room", {})
    var room_data: Dictionary = room_value if room_value is Dictionary else {}
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#72AFFF")), Color("72afff"))
    var message: String = "Ten przebieg jest lepszy od poprzedniego. Zapisujemy go jako nowy rekord pokoju." if improved else "Ten przebieg nie pobił poprzedniego, więc twój zapisany rekord zostaje nietknięty. Możesz spróbować jeszcze raz."
    app.completion_panel = RuntimeFactory.completion_card(app.asset_preloader)
    app.completion_panel.name = "CompletionCard"
    app.ui_root.attach(app.completion_panel, 30)
    app.completion_panel.configure(
        "Rekord poprawiony" if improved else "Rekord zostaje",
        message,
        "WRÓĆ DO KORYTARZA",
        accent,
        {},
        performance,
        RoomObjective.goal(room_data),
        "Zostań w pokoju",
        "Zostań w pokoju — odsłonięta przestrzeń czeka",
    )
    app.completion_panel.continue_requested.connect(leave)
    app.completion_panel.stay_requested.connect(func() -> void:
        if app.room != null and is_instance_valid(app.room):
            app.room.set_interaction_enabled(false)
    )
