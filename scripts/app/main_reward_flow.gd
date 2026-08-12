extends Node

var app: Node

func bind(owner: Node) -> void:
    app = owner

func _configure_reward_client() -> void:
    var config_value: Variant = app.index_document.get("reward", {})
    if not config_value is Dictionary:
        return
    var config: Dictionary = config_value
    if not bool(config.get("enabled", false)):
        return
    app.reward_client = app.RewardClientScript.new()
    app.reward_client.name = "SynesthesiaRewardClient"
    app.add_child(app.reward_client)
    app.reward_client.configure(
        str(config.get("api_url", "")),
        str(app.index_document.get("campaign_slug", "")),
        app.ReleaseReader.read_text(app.VERSION_PATH, "0.12.8"),
        app.ProgressStoreScript.get_install_id(),
        str(app.album_state.get("journey_id", "legacy")),
    )
    app.reward_client.restore_run(app.ProgressStoreScript.load_run())
    app.reward_client.run_started.connect(_on_run_started)
    app.reward_client.room_recorded.connect(_on_room_recorded)
    app.reward_client.album_recorded.connect(_on_album_recorded)
    app.reward_client.draw_entered.connect(_on_draw_entered)
    app.reward_client.leaderboard_loaded.connect(_on_leaderboard_loaded)
    app.reward_client.leaderboard_published.connect(_on_leaderboard_published)
    app.reward_client.request_failed.connect(_on_reward_request_failed)
    app.reward_client.retry_scheduled.connect(_on_reward_retry_scheduled)
    app.reward_client.run_invalidated.connect(_on_reward_run_invalidated)

func _prepare_finale_background() -> void:
    if app.finale_background != null and is_instance_valid(app.finale_background):
        return
    app.finale_background = app.EchoesFinaleBackgroundScript.new()
    app.finale_background.name = "EchoesFinaleBackground"
    app.experience_surface.add_child(app.finale_background)
    app.finale_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    app.finale_background.configure(app.reduced_motion, app.quiet_visuals)
    app.experience_surface.move_child(app.finale_background, app.game_surface.get_index() + 1)

func _show_reward_panel() -> void:
    if app.reward_panel != null:
        return
    _prepare_finale_background()
    app.SoundscapeRuntime.enter_outro(app.menu_soundscape, app.music_level, app.noise_level, app.quiet_mode)
    app.hud.visible = false
    app.reward_panel = app.SignalFinaleCardScript.new()
    app.reward_panel.name = "SignalFinaleCard"
    app.ui_root.attach(app.reward_panel, 40)
    if app.gameplay_telemetry != null:
        var summary: Dictionary = app.ProgressMetrics.completion_summary(app.release_entries, app.album_state)
        app.gameplay_telemetry.complete_journey(
            int(summary.get("elapsed_ms", 0)),
            int(summary.get("echoes_found", 0)),
            int(summary.get("echoes_total", 0)),
        )
    app.reward_panel.configure(
        bool(app.album_state.get("server_album_completed", false)),
        app.ProgressStoreScript.load_reward(),
        app.ProgressMetrics.completion_summary(app.release_entries, app.album_state),
        app.completion_context,
    )
    if bool(app.album_state.get("server_album_completed", false)) and app.reward_client != null and app.completion_context.is_empty():
        # Refresh the short-lived handoff/event context without changing completion state.
        app.reward_client.complete_album(int(app.album_state.get("total_elapsed_ms", 0)))
    app.reward_panel.draw_entry_requested.connect(_submit_reward_claim_values)
    app.reward_panel.leaderboard_publish_requested.connect(_publish_leaderboard)
    app.reward_panel.leaderboard_refresh_requested.connect(_refresh_leaderboard)
    app.reward_panel.reset_requested.connect(app._confirm_reset_album)
    app.reward_panel.album_mode_requested.connect(app._show_album_archive)
    _refresh_leaderboard()

func _refresh_leaderboard() -> void:
    if app.reward_panel != null and is_instance_valid(app.reward_panel):
        app.reward_panel.set_leaderboard_status("Ładuję TOP 10…")
    if app.reward_client != null:
        app.reward_client.fetch_leaderboard(10)

func refresh_link_context_after_resume() -> void:
    if app.reward_panel == null or not is_instance_valid(app.reward_panel):
        return
    if app.reward_client == null or not bool(app.album_state.get("server_album_completed", false)):
        return
    if bool(app.completion_context.get("linked_to_fan", false)):
        return
    # Returning from My Signal is the natural non-polling moment to discover
    # that a short-lived handoff has been consumed by another surface.
    app.reward_client.complete_album(int(app.album_state.get("total_elapsed_ms", 0)))

func _publish_leaderboard() -> void:
    if app.reward_panel == null or not is_instance_valid(app.reward_panel):
        return
    if app.reward_client == null or not bool(app.album_state.get("server_album_completed", false)):
        app.reward_panel.set_leaderboard_status("Najpierw kończę synchronizację wyniku z CrowdRelay.")
        return
    app.reward_panel.set_leaderboard_publish_enabled(false)
    app.reward_panel.set_leaderboard_status("Zapisuję najlepszy czas…")
    app.reward_client.publish_leaderboard()

func _on_leaderboard_loaded(items: Array) -> void:
    if app.reward_panel != null and is_instance_valid(app.reward_panel):
        app.reward_panel.set_leaderboard_items(items)

func _on_leaderboard_published(context: Dictionary) -> void:
    if app.reward_panel != null and is_instance_valid(app.reward_panel):
        app.reward_panel.set_leaderboard_publish_result(context)
        app.reward_panel.set_leaderboard_publish_enabled(bool(app.completion_context.get("linked_to_fan", false)))
    if app.reward_client != null:
        app.reward_client.fetch_leaderboard(10)

func _submit_reward_claim_values(email: String) -> void:
    if app.reward_client == null:
        app.reward_panel.set_status("Sygnał jest chwilowo niedostępny. Ukończenie pozostało zapisane lokalnie.")
        return
    if not bool(app.album_state.get("server_album_completed", false)):
        app.reward_panel.set_status("Najpierw kończę synchronizację jedenastu pokojów.")
        app.reward_panel.set_claim_enabled(false)
        _sync_completed_rooms_to_server(int(app.reward_client.get_run_state().get("next_room_index", 0)))
        return
    if not app.ProgressMetrics.looks_like_email(email):
        app.reward_panel.set_status("Podaj poprawny adres e-mail.")
        return
    var config_value: Variant = app.index_document.get("reward", {})
    var config: Dictionary = config_value if config_value is Dictionary else {}
    app.reward_panel.set_claim_enabled(false)
    app.reward_panel.set_status("Dodaję ukończenie do losowania…")
    app.reward_client.enter_draw(email, str(config.get("policy_version", "virya-signal-2026-08")))

func _on_run_started(_run_id: String, _run_token: String, next_room_index: int) -> void:
    app.ProgressStoreScript.save_run(app.reward_client.get_run_state())
    _sync_completed_rooms_to_server(next_room_index)

func _sync_completed_rooms_to_server(next_room_index: int) -> void:
    if app.reward_client == null or not app.reward_client.has_run():
        return
    var completed_ids: Array = app._array_value(app.album_state.get("completed_room_ids", []))
    var recorded_ids: Array = app._array_value(app.album_state.get("server_recorded_room_ids", []))
    if next_room_index >= app.release_entries.size():
        if bool(app.album_state.get("album_completed", false)) and not bool(app.album_state.get("server_album_completed", false)):
            app.reward_client.complete_album(int(app.album_state.get("total_elapsed_ms", 0)))
        return
    for index in range(next_room_index, app.release_entries.size()):
        var entry_value: Variant = app.release_entries[index]
        if not entry_value is Dictionary:
            continue
        var room_id_value: String = str(entry_value.get("id", ""))
        if completed_ids.has(room_id_value) and not recorded_ids.has(room_id_value):
            var elapsed_value: Variant = app.album_state.get("room_elapsed_ms", {})
            var elapsed: Dictionary = elapsed_value if elapsed_value is Dictionary else {}
            var elapsed_ms: int = maxi(0, int(elapsed.get(room_id_value, 0)))
            if elapsed_ms <= 0:
                break
            app.reward_client.record_room(room_id_value, index, elapsed_ms)
        else:
            break

func _on_room_recorded(room_id_value: String, next_room_index: int) -> void:
    var recorded_ids: Array = app._array_value(app.album_state.get("server_recorded_room_ids", []))
    if not recorded_ids.has(room_id_value):
        recorded_ids.append(room_id_value)
    app.album_state["server_recorded_room_ids"] = recorded_ids
    app._save_album_state()
    app.ProgressStoreScript.save_run(app.reward_client.get_run_state())
    _sync_completed_rooms_to_server(next_room_index)

func _on_album_recorded(context: Dictionary = {}) -> void:
    app.completion_context = context.duplicate(true)
    app.album_state["server_album_completed"] = true
    app._save_album_state()
    app.ProgressStoreScript.save_run(app.reward_client.get_run_state())
    if app.reward_panel != null and is_instance_valid(app.reward_panel):
        app.reward_panel.apply_signal_context(app.completion_context)
        app.reward_panel.set_status("Ukończenie potwierdzone. Możesz połączyć podróż z Sygnałem lub dołączyć do losowania 5 płyt.")
        app.reward_panel.set_claim_enabled(true)
        app.reward_panel.set_leaderboard_publish_enabled(bool(app.completion_context.get("linked_to_fan", false)))

func _on_draw_entered(status: String, message: String) -> void:
    app.ProgressStoreScript.save_reward({"status": status, "message": message, "claimed_at_unix": int(Time.get_unix_time_from_system())})
    if app.reward_panel != null and is_instance_valid(app.reward_panel):
        app.reward_panel.set_status(message)
        app.reward_panel.set_claim_enabled(false)
    # Reward entry durably links the run to the fan. Refresh completion context
    # so a now-consumed handoff never remains as a stale CTA in the finale.
    if app.reward_client != null and bool(app.album_state.get("server_album_completed", false)):
        app.reward_client.complete_album(int(app.album_state.get("total_elapsed_ms", 0)))

func _on_reward_request_failed(operation: String, message: String) -> void:
    if operation == "enter_draw" and app.reward_panel != null and is_instance_valid(app.reward_panel):
        app.reward_panel.set_status(message)
        app.reward_panel.set_claim_enabled(true)
    elif operation.begins_with("leaderboard_") and app.reward_panel != null and is_instance_valid(app.reward_panel):
        app.reward_panel.set_leaderboard_status(message)
        app.reward_panel.set_leaderboard_publish_enabled(bool(app.completion_context.get("linked_to_fan", false)))
    else:
        app.hud.update_discovery("Postęp jest bezpieczny lokalnie · synchronizacja wróci później")

func _on_reward_retry_scheduled(operation: String, attempt: int) -> void:
    var text_value: String = "Ponawiam połączenie z Sygnałem · próba %d/3" % attempt
    if operation == "enter_draw" and app.reward_panel != null and is_instance_valid(app.reward_panel):
        app.reward_panel.set_status(text_value)
    elif operation.begins_with("leaderboard_") and app.reward_panel != null and is_instance_valid(app.reward_panel):
        app.reward_panel.set_leaderboard_status(text_value)
    else:
        app.hud.update_discovery(text_value)

func _on_reward_run_invalidated() -> void:
    app.ProgressStoreScript.clear_run()
    app.album_state["server_recorded_room_ids"] = []
    app.album_state["server_album_completed"] = false
    app.completion_context = {}
    app._save_album_state()
    if app.reward_panel != null and is_instance_valid(app.reward_panel):
        app.reward_panel.set_status("Odnawiam bezpieczne połączenie z Sygnałem…")
        app.reward_panel.set_claim_enabled(false)
        app.reward_panel.set_leaderboard_publish_enabled(false)
    if app.reward_client != null:
        app.reward_client.start_run()
