extends Node

# Owns active-play timing, replay splits and PB deltas. UI cards, transitions,
# settings and app backgrounding pause this clock, so leaderboard time reflects
# interaction rather than loading or reading time.
var app: Node
var act_splits: Dictionary = {}

func bind(owner: Node) -> void:
    app = owner

func pause() -> void:
    if not app.room_timer_running:
        return
    app.room_elapsed_before_start_ms = app.ProgressMetrics.current_room_elapsed_ms(
        app.room_started_ms, app.room_elapsed_before_start_ms, true
    )
    app.room_started_ms = 0
    app.room_timer_running = false

func resume() -> void:
    if app.room == null or app.completion_announced or app.transition_running:
        return
    if app.album_mode_controller != null and app.album_mode_controller.is_listening():
        return
    if app.settings_panel != null or app.intro_panel != null or app.experience_intro_panel != null or app.confirmation_panel != null:
        return
    if app.room_timer_running:
        return
    app.room_started_ms = Time.get_ticks_msec()
    app.room_timer_running = true

func reset(start_now: bool = true) -> void:
    app.room_elapsed_before_start_ms = 0
    app.room_started_ms = 0
    app.room_timer_running = false
    act_splits = {}
    if start_now:
        resume()

func reset_splits() -> void:
    act_splits = {}

func capture_split(index: int) -> void:
    if index <= 0 or not app.room_timer_running:
        return
    var split_ms: int = app.ProgressMetrics.current_room_elapsed_ms(app.room_started_ms, app.room_elapsed_before_start_ms, true)
    act_splits[str(index)] = split_ms
    _show_split_delta(index, split_ms)

func record_pb_splits(release_id: String, is_personal_best: bool) -> void:
    if not is_personal_best:
        return
    var all_value: Variant = app.album_state.get("personal_best_act_splits_ms", {})
    var all_splits: Dictionary = all_value if all_value is Dictionary else {}
    all_splits[release_id] = act_splits.duplicate(true)
    app.album_state["personal_best_act_splits_ms"] = all_splits

func is_replay_mode() -> bool:
    return bool(app.album_state.get("replay_mode", false))

func _show_split_delta(index: int, split_ms: int) -> void:
    if app.hud == null or not app.hud.has_method("show_split_delta"):
        return
    var release_id: String = str(app.manifest.get("release_id", ""))
    var all_value: Variant = app.album_state.get("personal_best_act_splits_ms", {})
    var all_splits: Dictionary = all_value if all_value is Dictionary else {}
    var room_value: Variant = all_splits.get(release_id, {})
    var room_splits: Dictionary = room_value if room_value is Dictionary else {}
    var previous: int = maxi(0, int(room_splits.get(str(index), 0)))
    if previous > 0:
        app.hud.show_split_delta(split_ms - previous)
