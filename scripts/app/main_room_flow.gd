extends Node

const EchoArchive := preload("res://scripts/app/echo_archive.gd")
const RoomCinematicRuntime := preload("res://scripts/app/room_cinematic_runtime.gd")
const ViryaWorld := preload("res://scripts/app/virya_world.gd")

var app: Node
var cinematic_runtime: Node

func bind(owner: Node) -> void:
    app = owner
    cinematic_runtime = RoomCinematicRuntime.new(); cinematic_runtime.bind(app); add_child(cinematic_runtime)

func _load_room(index: int, show_intro: bool) -> void:
    if index < 0 or index >= app.release_entries.size():
        app._show_fatal_error("Próba wejścia do nieznanego pokoju.")
        return
    app._remove_modal(app.intro_panel)
    app.intro_panel = null
    app._remove_modal(app.completion_panel)
    app.completion_panel = null
    _clear_room_runtime()
    app.current_room_index = index
    app.album_state["current_room_index"] = app.current_room_index
    app._save_album_state()
    var entry_value: Variant = app.release_entries[app.current_room_index]
    if not entry_value is Dictionary:
        app._show_fatal_error("Nieprawidłowy wpis pokoju.")
        return
    var entry: Dictionary = entry_value
    app.manifest = app.ReleaseReader.load_json(str(entry.get("manifest", "")))
    if app.manifest.is_empty():
        app._show_fatal_error("Nie udało się wczytać pokoju: %s" % str(entry.get("id", "?")))
        return
    var room_value: Variant = app.manifest.get("room", {})
    var room_data: Dictionary = room_value if room_value is Dictionary else {}
    var collectible_value: Variant = app.manifest.get("collectibles", [])
    var collectible_entries: Array = collectible_value if collectible_value is Array else []
    app.room = _instantiate_room(room_data)
    app.room.name = "RoomStage"
    app.room_layer.add_child(app.room)
    app.room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    app.room.configure(room_data, collectible_entries, app.manifest.get("sensory", {}), app.quality, app.asset_preloader)
    app.room.set_interaction_enabled(false)
    if app.adaptive_performance != null:
        app.room.set_runtime_budget(float(app.adaptive_performance.get_scale()))
    var room_accent: Color = Color.from_string(str(room_data.get("accent_color", "#72AFFF")), Color("72afff"))
    if app.transition_director != null and app.transition_director.has_method("set_accent"):
        app.transition_director.set_accent(room_accent)
    app.room.coverage_changed.connect(_on_coverage_changed)
    app.room.collectible_found.connect(_on_collectible_found)
    app.room.paint_pulse.connect(_on_paint_pulse)
    app.room.special_interaction.connect(_on_special_interaction)
    app.room.interaction_feedback.connect(func(message: String) -> void: app.hud.update_discovery(message))
    app.room.interaction_started.connect(func() -> void: app.hud.set_painting(true))
    app.room.interaction_ended.connect(func() -> void: app.hud.set_painting(false))
    app.room.act_changed.connect(_on_act_changed)
    app.audio_director = app.AudioDirectorScript.new()
    app.audio_director.name = "AudioDirector"
    app.add_child(app.audio_director)
    app.audio_director.configure(app.manifest.get("sensory", {}), app.manifest.get("audio", {}), maxi(1, collectible_entries.size()), app.asset_preloader, str(room_data.get("visual_style", "uncertainty")))
    app.audio_director.set_user_levels(app.music_level, app.noise_level)
    app.haptics = app.HapticsScript.new()
    app.haptics.name = "Haptics"
    app.add_child(app.haptics)
    app.haptics.configure(app.manifest.get("sensory", {}), str(room_data.get("visual_style", "paint")))
    var feedback_bridge = app.PlayerFeedbackBridgeScript.new()
    app.room.add_child(feedback_bridge)
    feedback_bridge.bind(app.room, app.hud, app.haptics, app.audio_director)
    app.completion_announced = false
    app.current_coverage = 0.0
    var elapsed_value: Variant = app.album_state.get("room_elapsed_ms", {})
    var elapsed: Dictionary = elapsed_value if elapsed_value is Dictionary else {}
    app.room_elapsed_before_start_ms = maxi(0, int(elapsed.get(str(app.manifest.get("release_id", "")), 0)))
    app.room_started_ms = Time.get_ticks_msec()
    app.room_timer_running = false
    if app.gameplay_telemetry != null:
        app.gameplay_telemetry.begin_room(str(app.manifest.get("release_id", "")))
    app.hud.configure_room(
        str(app.manifest.get("title", "VIRYA: Synestezja")),
        str(app.manifest.get("subtitle", "")),
        app.current_room_index,
        app.release_entries.size(),
        float(app.current_room_index) / float(maxi(1, app.release_entries.size() - 1)),
        room_data,
    )
    # configure_room establishes generic interaction chrome. Apply the room-owned
    # semantic verb afterwards so the first thing a player reads is actually
    # specific to this mechanic instead of being overwritten during setup.
    if app.room.has_method("get_interaction_hint"):
        app.hud.update_instruction(app.room.get_interaction_hint())
    app._apply_sensory_mode()
    _preload_next_room()
    app.call_deferred("_restore_room_after_layout", show_intro)

func _instantiate_room(room_data: Dictionary):
    var scene_path: String = str(room_data.get("scene_path", ""))
    var resource: Resource = null
    if app.asset_preloader != null:
        resource = app.asset_preloader.take(scene_path)
    if resource == null and ResourceLoader.exists(scene_path):
        resource = load(scene_path)
    if resource is PackedScene:
        return (resource as PackedScene).instantiate()
    push_warning("Falling back to generic app.room stage: %s" % scene_path)
    return app.RoomStageScript.new()

func _preload_next_room() -> void:
    if app.asset_preloader == null or app.current_room_index + 1 >= app.release_entries.size():
        return
    var next_value: Variant = app.release_entries[app.current_room_index + 1]
    if next_value is Dictionary:
        app.asset_preloader.prepare(str(next_value.get("manifest", "")))
func _clear_room_runtime() -> void:
    if app.gameplay_telemetry != null and app.room != null and is_instance_valid(app.room) and app.room_timer_running:
        var elapsed_ms: int = app.ProgressMetrics.current_room_elapsed_ms(app.room_started_ms, app.room_elapsed_before_start_ms, true)
        var guidance: Dictionary = app.hud.guidance_stats() if app.hud != null and app.hud.has_method("guidance_stats") else {}
        app.gameplay_telemetry.abandon_room(elapsed_ms, guidance)
    if app.hud != null and is_instance_valid(app.hud):
        app.hud.clear_transient_overlays()
    if app.save_timer != null and not app.save_timer.is_stopped():
        app.save_timer.stop()
    if app.room != null and is_instance_valid(app.room):
        app.room.free()
    if app.audio_director != null and is_instance_valid(app.audio_director):
        app.audio_director.free()
    if app.haptics != null and is_instance_valid(app.haptics):
        app.haptics.free()
    app.room = null
    app.audio_director = null
    app.haptics = null

func _restore_room_after_layout(show_intro: bool) -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    if app.room == null or not is_instance_valid(app.room):
        return
    var release_id: String = str(app.manifest.get("release_id", ""))
    var saved: Dictionary = app.ProgressStoreScript.load_release(release_id)
    app.restoring_progress = true
    var restored: bool = false
    if not saved.is_empty():
        var room_state_value: Variant = saved.get("room", {})
        if room_state_value is Dictionary:
            restored = bool(app.room.restore_state(room_state_value))
        app.completion_announced = bool(saved.get("completed", false))
        app.room_elapsed_before_start_ms = maxi(app.room_elapsed_before_start_ms, int(saved.get("elapsed_ms", 0)))
    app._apply_sensory_mode()
    if app.album_mode_controller != null and app.album_mode_controller.is_listening():
        app.completion_announced = true
        app.room_timer_running = false
        app.room.set_cinematic_reveal(true, true)
        app.room.set_door_open(false)
        app.room.set_post_reveal_interaction(true)
        var listen_progress: float = float(app.room.get_normalized_progress())
        var listen_found: int = int(app.room.get_found_count())
        app.audio_director.set_progress(listen_progress, listen_found)
        app.audio_director.reveal_release_excerpt()
        app.hud.visible = false
        app.restoring_progress = false
        return
    app.room.set_post_reveal_interaction(app.completion_announced)
    app.room.set_interaction_enabled(true)
    if restored:
        app.current_coverage = float(app.room.get_coverage())
        var normalized: float = float(app.room.get_normalized_progress())
        var found: int = int(app.room.get_found_count())
        app.audio_director.set_progress(normalized, found)
        if app.hud != null and is_instance_valid(app.hud):
            app.hud.update_reveal(normalized)
            app.hud.update_discovery("ECHA %d/%d · pokój pamięta poprzedni dotyk" % [found, _collectible_total()])
            app.hud.prime_hint_after_resume()
    app.room_timer_running = not app.completion_announced
    if app.completion_announced:
        app.room.set_cinematic_reveal(true)
        app.room.set_door_open(true)
        app.audio_director.reveal_release_excerpt()
        if app.experience_intro_panel == null:
            app.call_deferred("_show_completion_panel")
    elif saved.is_empty() and show_intro:
        _show_intro()
    else:
        app.room.set_interaction_enabled(app.experience_intro_panel == null)
    app.restoring_progress = false

func _collectible_total() -> int:
    var value: Variant = app.manifest.get("collectibles", [])
    if value is Array:
        return maxi(1, value.size())
    return 1

func _show_intro() -> void:
    if app.room == null:
        return
    app.intro_panel = app.ChapterCardScript.new()
    app.intro_panel.name = "ChapterCard"
    app.ui_root.attach(app.intro_panel, 20)
    var room_value: Variant = app.manifest.get("room", {})
    var room_data: Dictionary = room_value if room_value is Dictionary else {}
    var art_value: Variant = room_data.get("art_direction", {})
    var art: Dictionary = art_value if art_value is Dictionary else {}
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#72AFFF")), Color("72afff"))
    var intro_text := str(app.manifest.get("intro", "Maluj bez pośpiechu. Obraz odpowie kolorem i dźwiękiem."))
    if app.current_room_index > 0:
        var previous_echo: Dictionary = EchoArchive.latest_echo(app.album_state, str(app.manifest.get("release_id", "")))
        var echo_message := str(previous_echo.get("message", "")).strip_edges()
        if not echo_message.is_empty():
            intro_text += "\n\nECHO Z POPRZEDNIEGO POKOJU · %s" % echo_message
    app.intro_panel.configure(
        app.current_room_index,
        app.release_entries.size(),
        str(room_data.get("name", "Pokój")),
        intro_text,
        str(art.get("caption", "VIRYA · SYNESTEZJA")),
        accent,
        ViryaWorld.manifest_identity(app.manifest),
    )
    app.intro_panel.dismissed.connect(_dismiss_intro)

func _dismiss_intro() -> void:
    app._remove_modal(app.intro_panel)
    app.intro_panel = null
    if app.room != null:
        app.room.set_interaction_enabled(true)
    app._schedule_save()

func _on_coverage_changed(value: float) -> void:
    if app.room == null:
        return
    app.current_coverage = value
    var normalized: float = float(app.room.get_normalized_progress())
    if app.audio_director != null:
        app.audio_director.set_progress(normalized, int(app.room.get_found_count()))
    if app.hud != null and is_instance_valid(app.hud):
        app.hud.update_reveal(normalized)
    var room_value: Variant = app.manifest.get("room", {})
    var room_data: Dictionary = room_value if room_value is Dictionary else {}
    var reveal_at: float = float(room_data.get("cinematic_reveal_at", app.FINAL_REVEAL_RATIO))
    if normalized >= reveal_at:
        _complete_current_room()
    app._schedule_save()

func _on_collectible_found(item: Dictionary) -> void:
    if app.room == null:
        return
    var count: int = int(app.room.get_found_count())
    EchoArchive.remember(app.album_state, str(app.manifest.get("release_id", "")), item, count)
    app.hud.update_discovery("ECHO %d/%d · %s — %s" % [count, _collectible_total(), str(item.get("title", "Echo")), str(item.get("message", ""))])
    if app.haptics != null:
        app.haptics.discovery()
    if app.audio_director != null:
        app.audio_director.set_progress(float(app.room.get_normalized_progress()), count)
    if count >= _collectible_total():
        app.hud.update_discovery("ECHA 3/3 · pełna pamięć pokoju zapisana w Korytarzu")
        if app.haptics != null:
            app.haptics.special("echo_complete")
        if app.audio_director != null and app.audio_director.has_method("play_interaction_sfx"):
            app.audio_director.play_interaction_sfx("echo_complete", count)
    app._schedule_save()

func _on_act_changed(index: int, title: String) -> void:
    app.hud.update_act(index, title)
    if app.room != null and app.room.has_method("get_interaction_hint"):
        app.hud.update_instruction(app.room.get_interaction_hint())
    if app.haptics != null and index > 0:
        app.haptics.discovery()

func _on_paint_pulse(speed_normalized: float) -> void:
    if app.haptics != null:
        app.haptics.paint_tick(speed_normalized)

func _on_special_interaction(kind: String, index: int) -> void:
    if app.haptics != null:
        app.haptics.special(kind)
    if app.audio_director != null and app.audio_director.has_method("play_interaction_sfx"):
        app.audio_director.play_interaction_sfx(kind, index)
    if app.room != null and app.room.has_method("get_interaction_hint"):
        app.hud.update_instruction(app.room.get_interaction_hint())

func _complete_current_room() -> void:
    if app.completion_announced or app.room == null:
        return
    var elapsed_at_completion: int = app.ProgressMetrics.current_room_elapsed_ms(app.room_started_ms, app.room_elapsed_before_start_ms, app.room_timer_running)
    app.completion_announced = true
    app.room_timer_running = false
    if app.gameplay_telemetry != null:
        var guidance: Dictionary = app.hud.guidance_stats() if app.hud != null and app.hud.has_method("guidance_stats") else {}
        app.gameplay_telemetry.complete_room(elapsed_at_completion, guidance)
    app.room.set_post_reveal_interaction(true)
    app.room.set_cinematic_reveal(true)
    # Echoes remain optional discoveries. Opening the door never grants them for
    # free; players can stay, search, or revisit the room later in Album Mode.
    app.room.set_door_open(true)
    app.current_coverage = float(app.room.get_coverage())
    if app.audio_director != null:
        app.audio_director.set_progress(1.0, _collectible_total())
        app.audio_director.reveal_release_excerpt()
        app.audio_director.play_cinematic_sfx()
    if app.hud != null and is_instance_valid(app.hud):
        app.hud.update_reveal(1.0)
        app.hud.enter_completion_beat()
        var found_echoes := int(app.room.get_found_count())
        var total_echoes := _collectible_total()
        if found_echoes < total_echoes:
            app.hud.update_discovery("DRZWI OTWARTE · ECHA %d/%d · możesz zostać i szukać" % [found_echoes, total_echoes])
        else:
            app.hud.update_discovery("DRZWI OTWARTE · ECHA %d/%d · pokój odsłonięty" % [found_echoes, total_echoes])
    if app.haptics != null:
        app.haptics.cinematic_reveal()
    var release_id: String = str(app.manifest.get("release_id", ""))
    var completed_ids: Array = app._array_value(app.album_state.get("completed_room_ids", []))
    if not completed_ids.has(release_id):
        completed_ids.append(release_id)
    app.album_state["completed_room_ids"] = completed_ids
    app.transition_director.set_memory_count(completed_ids.size())
    var elapsed_value: Variant = app.album_state.get("room_elapsed_ms", {})
    var elapsed: Dictionary = elapsed_value if elapsed_value is Dictionary else {}
    elapsed[release_id] = maxi(int(elapsed.get(release_id, 0)), elapsed_at_completion)
    app.album_state["room_elapsed_ms"] = elapsed
    app.album_state["total_elapsed_ms"] = app.ProgressMetrics.sum_elapsed_ms(elapsed)
    app.room_elapsed_before_start_ms = elapsed_at_completion
    app.room_started_ms = Time.get_ticks_msec()
    if app.current_room_index == app.release_entries.size() - 1:
        app.album_state["album_completed"] = true
    app._save_progress()
    if app.current_room_index == 5 and not bool(app.album_state.get("signal_breach_seen", false)):
        app.album_state["signal_breach_seen"] = true
        app._save_album_state()
        cinematic_runtime.play_signal_breach()
    if app.reward_client != null and app.reward_client.has_run():
        app.reward_client.record_room(release_id, app.current_room_index, elapsed_at_completion)
        if app.current_room_index == app.release_entries.size() - 1:
            app.reward_client.complete_album(int(app.album_state.get("total_elapsed_ms", 0)))
    app.call_deferred("_show_completion_panel")

func _show_completion_panel() -> void:
    await get_tree().create_timer(cinematic_runtime.hero_beat_delay()).timeout
    if app.completion_panel != null or app.transition_running or app.reward_panel != null or app.experience_intro_panel != null or not app.room_layer.visible:
        return
    var room_value: Variant = app.manifest.get("room", {})
    var room_data: Dictionary = room_value if room_value is Dictionary else {}
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#72AFFF")), Color("72afff"))
    var next_label: String
    var next_index: int = app.current_room_index + 1
    if app.current_room_index < app.release_entries.size() - 1:
        var next_value: Variant = app.release_entries[next_index]
        var next_name: String = "kolejnego pokoju"
        if next_value is Dictionary:
            var next_manifest: Dictionary = app.ReleaseReader.load_json(str(next_value.get("manifest", "")))
            var next_room_value: Variant = next_manifest.get("room", {})
            if next_room_value is Dictionary:
                next_name = str(next_room_value.get("name", next_name))
        next_label = "Dalej · %s" % next_name
    else:
        next_label = "Przejdź przez ostatnie drzwi"
    app.completion_panel = app.CompletionCardScript.new()
    app.completion_panel.name = "CompletionCard"
    app.ui_root.attach(app.completion_panel, 30)
    var completion_message := str(app.manifest.get("completion_message", "Obraz i muzyka zostały odsłonięte."))
    var found_echoes := int(app.room.get_found_count()) if app.room != null else 0
    var total_echoes := _collectible_total()
    if found_echoes < total_echoes:
        completion_message += "\n\nEcha %d/%d · %d nadal %s w pokoju. Możesz zostać i poszukać albo wrócić tu później w Album Mode." % [
            found_echoes, total_echoes, total_echoes - found_echoes, "czekają" if total_echoes - found_echoes > 1 else "czeka",
        ]
    app.completion_panel.configure(
        str(app.manifest.get("completion_title", "Pokój się otworzył")),
        completion_message,
        next_label,
        accent,
        ViryaWorld.manifest_identity(app.manifest),
    )
    if app.current_room_index < app.release_entries.size() - 1:
        app.completion_panel.continue_requested.connect(func() -> void: _transition_to_room(next_index))
    else:
        app.completion_panel.continue_requested.connect(_transition_to_reward)
    app.completion_panel.stay_requested.connect(func() -> void:
        # Keep a persistent DALEJ action while the listener stays in the revealed app.room.
        if app.room != null and is_instance_valid(app.room):
            app.room.set_interaction_enabled(false)
    )

func _transition_to_room(next_index: int) -> void:
    if app.transition_running:
        return
    app.transition_running = true
    if app.haptics != null:
        app.haptics.door_open()
    if app.audio_director != null and app.audio_director.has_method("begin_transition_out"): app.audio_director.begin_transition_out()
    app._remove_modal(app.completion_panel)
    app.completion_panel = null
    if app.transition_director != null:
        app.transition_director.set_next_accent(app._accent_for_release(next_index))
        await app.transition_director.travel_out()
    if app.asset_preloader != null: await app.asset_preloader.wait_for_queued()
    _load_room(next_index, true)
    await get_tree().process_frame
    if app.audio_director != null and app.audio_director.has_method("begin_transition_in"): app.audio_director.begin_transition_in()
    if app.transition_director != null:
        await app.transition_director.travel_in()
    if app.audio_director != null and app.audio_director.has_method("end_transition_in"): app.audio_director.end_transition_in()
    app.transition_running = false
func _transition_to_reward() -> void:
    if app.transition_running:
        return
    app.transition_running = true
    if app.haptics != null:
        app.haptics.door_open()
    app._remove_modal(app.completion_panel)
    app.completion_panel = null
    if app.transition_director != null:
        app.transition_director.set_next_accent(Color("e35f83"))
        await app.transition_director.travel_out()
    _clear_room_runtime()
    app.room_layer.visible = false
    app._prepare_finale_background()
    if app.transition_director != null:
        await app.transition_director.travel_in()
    app.transition_running = false
    app._show_reward_panel()
