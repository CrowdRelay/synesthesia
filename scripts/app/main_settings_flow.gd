extends Node

const SETTINGS_CARD_PATH: String = "res://scripts/ui/settings_card.gd"
const CONFIRM_CARD_PATH: String = "res://scripts/ui/confirm_card.gd"

var _runtime_scripts: Dictionary = {}

var app: Node

func bind(owner: Node) -> void:
    app = owner

func _runtime_script(path: String) -> Script:
    if _runtime_scripts.has(path):
        return _runtime_scripts[path] as Script
    if not ResourceLoader.exists(path):
        return null
    var resource: Resource = load(path)
    if resource is Script:
        _runtime_scripts[path] = resource
        return resource as Script
    return null

func _show_settings() -> void:
    if app.settings_panel != null:
        return
    if app.room != null:
        if app.room_flow != null:
            app.room_flow.pause_room_timer()
        app.room.set_interaction_enabled(false)
    var SettingsCardScript: Script = _runtime_script(SETTINGS_CARD_PATH)
    if SettingsCardScript == null:
        app._show_fatal_error("Nie udało się otworzyć ustawień.")
        return
    app.settings_panel = SettingsCardScript.new()
    app.settings_panel.name = "SettingsCard"
    app.ui_root.attach(app.settings_panel, 60)
    app.settings_panel.configure({
        "calm": app.calm_mode,
        "quiet": app.quiet_mode,
        "quiet_visuals": app.quiet_visuals,
        "reduced_motion": app.reduced_motion,
        "high_readability": app.high_readability,
        "haptics": app.haptics_enabled,
        "music": app.music_level,
        "noise": app.noise_level,
        "has_room": app.room != null and is_instance_valid(app.room),
        "album_completed": bool(app.album_state.get("album_completed", false)),
    }, str(app.quality.get("label", "Zbalansowana")), app.ReleaseReader.read_text(app.VERSION_PATH, "0.12.8"))
    app.settings_panel.close_requested.connect(_close_settings)
    app.settings_panel.reload_requested.connect(func() -> void:
        _close_settings()
        _reload_current_room()
    )
    app.settings_panel.reset_requested.connect(func() -> void:
        _close_settings()
        _confirm_reset_room()
    )
    app.settings_panel.reset_album_requested.connect(func() -> void:
        _close_settings()
        _confirm_reset_album()
    )
    app.settings_panel.calm_changed.connect(func(value: bool) -> void:
        app.calm_mode = value
        _apply_sensory_mode()
        app._mark_settings_dirty()
    )
    app.settings_panel.quiet_changed.connect(func(value: bool) -> void:
        app.quiet_mode = value
        _apply_sensory_mode()
        app._mark_settings_dirty()
    )
    app.settings_panel.visuals_changed.connect(func(value: bool) -> void:
        app.quiet_visuals = value
        _apply_sensory_mode()
        app._mark_settings_dirty()
    )
    app.settings_panel.motion_changed.connect(func(value: bool) -> void:
        app.reduced_motion = value
        _apply_sensory_mode()
        app._mark_settings_dirty()
    )
    app.settings_panel.readability_changed.connect(func(value: bool) -> void:
        app.high_readability = value
        _apply_sensory_mode()
        app._mark_settings_dirty()
    )
    app.settings_panel.haptics_changed.connect(func(value: bool) -> void:
        app.haptics_enabled = value
        _apply_sensory_mode()
        app._mark_settings_dirty()
    )
    app.settings_panel.quality_cycle_requested.connect(func() -> void:
        app.quality_profile = app.QualityManager.next(app.quality_profile)
        app.quality = app.QualityManager.resolve(app.quality_profile)
        app.settings_panel.set_quality_label(str(app.quality.get("label", "Zbalansowana")), true)
        app._mark_settings_dirty()
    )
    app.settings_panel.music_changed.connect(func(value: float) -> void:
        app.music_level = value
        _apply_audio_levels()
        app._mark_settings_dirty()
    )
    app.settings_panel.noise_changed.connect(func(value: float) -> void:
        app.noise_level = value
        _apply_audio_levels()
        app._mark_settings_dirty()
    )

func _close_settings() -> void:
    app._remove_modal(app.settings_panel)
    app.settings_panel = null
    if app.settings_dirty:
        _save_album_state()
        app.settings_dirty = false
    if app.room != null and not app.completion_announced and app.experience_intro_panel == null:
        app.room.set_interaction_enabled(true)
        if app.room_flow != null:
            app.room_flow.resume_room_timer()

func _reload_current_room() -> void:
    if app.room_flow != null:
        app.room_flow.pause_room_timer()
    _save_progress()
    Engine.max_fps = app.QualityManager.frame_cap(app.quality_profile)
    if app.adaptive_performance != null:
        app.adaptive_performance.configure(app.quality_profile)
    var index: int = app.current_room_index
    await app.transition_director.fade_out(0.28)
    app._load_room(index, false)
    await get_tree().process_frame
    await app.transition_director.fade_in(0.28)
    if app.room_flow != null:
        app.room_flow.resume_room_timer()

func _confirm_reset_room() -> void:
    _show_confirmation("Zacząć pokój od nowa?", "Zniknie tylko lokalny postęp bieżącego pokoju. Pozostałe rozdziały albumu zostają bez zmian.", "Tak, wyczyść ten pokój", Callable(app, "_reset_room"))

func _reset_room() -> void:
    if app.room == null:
        return
    var release_id: String = str(app.manifest.get("release_id", ""))
    app.ProgressStoreScript.clear_release(release_id)
    var completed_ids: Array = app._array_value(app.album_state.get("completed_room_ids", []))
    completed_ids.erase(release_id)
    app.album_state["completed_room_ids"] = completed_ids
    app.transition_director.set_memory_count(completed_ids.size())
    app.completion_announced = false
    var elapsed_value: Variant = app.album_state.get("room_elapsed_ms", {})
    var elapsed: Dictionary = elapsed_value if elapsed_value is Dictionary else {}
    elapsed[release_id] = 0
    app.album_state["room_elapsed_ms"] = elapsed
    app.album_state["total_elapsed_ms"] = app.ProgressMetrics.sum_elapsed_ms(elapsed)
    app.room_elapsed_before_start_ms = 0
    app.room_timer_running = false
    app._remove_modal(app.completion_panel)
    app.completion_panel = null
    app.room.reset_room()
    app.room.set_interaction_enabled(true)
    app.current_coverage = 0.0
    app.room_started_ms = 0
    if app.room_flow != null:
        app.room_flow.reset_room_timer(true)
    app.hud.update_reveal(0.0)
    app.hud.update_discovery("ECHA 0/%d · odkrywaj scenę spod szumu" % app._collectible_total())
    if app.audio_director != null:
        app.audio_director.set_progress(0.0, 0)
        app.audio_director.reset_release_excerpt()
    _apply_sensory_mode()
    _save_album_state()

func _confirm_reset_album() -> void:
    var replay_unlocked: bool = bool(app.album_state.get("replay_unlocked", false)) or bool(app.album_state.get("album_completed", false))
    var title: String = "Uruchomić Replay Mode?" if replay_unlocked else "Zagrać od nowa?"
    var message: String = "Startujesz świeży, szybszy przebieg. Chapter cards i część przejść zostaną skrócone, a lokalne PB oraz splity zostają zachowane." if replay_unlocked else "Wyczyścimy lokalne malowanie, odkrycia i czasy wszystkich 11 pokojów. Ustawienia zostają. Nagroda i stan po stronie Sygnału nie są cofane."
    var confirm: String = "Tak, uruchom Replay Mode" if replay_unlocked else "Tak, zacznij świeżą podróż"
    _show_confirmation(title, message, confirm, Callable(app, "_reset_album_local"))

func _show_confirmation(title: String, message: String, confirm_text: String, action: Callable) -> void:
    if app.room_flow != null:
        app.room_flow.pause_room_timer()
    var ConfirmCardScript: Script = _runtime_script(CONFIRM_CARD_PATH)
    if ConfirmCardScript == null:
        app._show_fatal_error("Nie udało się otworzyć potwierdzenia.")
        return
    var card = ConfirmCardScript.new()
    app.confirmation_panel = card
    app.ui_root.attach(card, 80)
    card.configure(title, message, confirm_text)
    card.confirmed.connect(action)
    card.tree_exited.connect(func() -> void:
        app.confirmation_panel = null
        if app.room_flow != null:
            app.room_flow.resume_room_timer()
    )

func _reset_album_local() -> void:
    if app.save_timer != null and not app.save_timer.is_stopped():
        app.save_timer.stop()
    if app.reward_client != null and is_instance_valid(app.reward_client) and app.reward_client.has_method("shutdown"):
        app.reward_client.shutdown()
    if app.ProgressStoreScript.reset_local_journey():
        get_tree().reload_current_scene()
    else:
        app.hud.update_discovery("Nie udało się wyczyścić lokalnego postępu")

func _apply_sensory_mode() -> void:
    if app.room != null and is_instance_valid(app.room):
        app.room.set_calm_mode(app.calm_mode)
        app.room.set_reduced_motion(app.reduced_motion)
        app.room.set_quiet_visuals(app.quiet_visuals)
        if app.room.has_method("set_high_readability"):
            app.room.set_high_readability(app.high_readability)
    if app.audio_director != null:
        app.audio_director.set_calm_mode(app.calm_mode)
        app.audio_director.set_quiet(app.quiet_mode)
    app.SoundscapeRuntime.apply_audio_levels(app.menu_soundscape, app.audio_director, app.music_level, app.noise_level, app.quiet_mode)
    if app.haptics != null:
        app.haptics.set_calm_mode(app.calm_mode)
        app.haptics.set_enabled(app.haptics_enabled and not app.quiet_mode)
    if app.transition_director != null and app.transition_director.has_method("set_reduced_motion"):
        app.transition_director.set_reduced_motion(app.reduced_motion)
    if app.finale_background != null and is_instance_valid(app.finale_background):
        app.finale_background.configure(app.reduced_motion, app.quiet_visuals)

func _apply_audio_levels() -> void:
    app.SoundscapeRuntime.apply_audio_levels(app.menu_soundscape, app.audio_director, app.music_level, app.noise_level, app.quiet_mode)

func _on_runtime_budget_changed(scale: float, _reason: String) -> void:
    if app.room != null and is_instance_valid(app.room):
        app.room.set_runtime_budget(scale)

func _schedule_save() -> void:
    if app.album_mode_controller != null and app.album_mode_controller.is_listening():
        return
    if not app.restoring_progress and app.save_timer != null:
        app.save_timer.start()

func _save_progress() -> void:
    if app.album_mode_controller != null and app.album_mode_controller.is_listening():
        return
    if app.room == null or app.manifest.is_empty():
        return
    var release_id: String = str(app.manifest.get("release_id", ""))
    var elapsed_value: Variant = app.album_state.get("room_elapsed_ms", {})
    var elapsed: Dictionary = elapsed_value if elapsed_value is Dictionary else {}
    var elapsed_ms: int = app.ProgressMetrics.current_room_elapsed_ms(app.room_started_ms, app.room_elapsed_before_start_ms, app.room_timer_running)
    elapsed[release_id] = maxi(int(elapsed.get(release_id, 0)), elapsed_ms)
    app.album_state["room_elapsed_ms"] = elapsed
    app.album_state["total_elapsed_ms"] = app.ProgressMetrics.sum_elapsed_ms(elapsed)
    _populate_settings_state()
    app.ProgressStoreScript.save_checkpoint(release_id, {
        "completed": app.completion_announced,
        "elapsed_ms": elapsed_ms,
        "room": app.room.export_state(),
    }, app.album_state)

func _populate_settings_state() -> void:
    app.album_state["current_room_index"] = app.current_room_index
    app.album_state["calm_mode"] = app.calm_mode
    app.album_state["quiet_mode"] = app.quiet_mode
    app.album_state["quiet_visuals"] = app.quiet_visuals
    app.album_state["reduced_motion"] = app.reduced_motion
    app.album_state["high_readability"] = app.high_readability
    app.album_state["haptics_enabled"] = app.haptics_enabled
    app.album_state["quality_profile"] = app.quality_profile
    app.album_state["music_level"] = app.music_level
    app.album_state["noise_level"] = app.noise_level

func _save_album_state() -> void:
    if app.album_mode_controller != null and app.album_mode_controller.is_listening():
        return
    _populate_settings_state()
    app.ProgressStoreScript.save_album(app.album_state)
