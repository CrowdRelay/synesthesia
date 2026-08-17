extends Node

const REWARD_CLIENT_PATH := "res://scripts/reward_client.gd"
const FINALE_BACKGROUND_PATH := "res://scripts/ui/echoes_finale_background.gd"
const SIGNAL_FINALE_CARD_PATH := "res://scripts/ui/signal_finale_card.gd"
const SIGNAL_FINALE_FALLBACK_PATH := "res://scripts/ui/signal_finale_fallback_card.gd"
const WebE2EProbe := preload("res://scripts/app/web_e2e_probe.gd")

var app: Node
var _runtime_scripts: Dictionary = {}

func bind(owner: Node) -> void:
    app = owner

func _runtime_script(path: String) -> Script:
    if _runtime_scripts.has(path):
        return _runtime_scripts[path] as Script
    if not ResourceLoader.exists(path):
        push_error("Reward runtime script unavailable: %s" % path)
        return null
    var resource: Resource = load(path)
    if resource is Script:
        _runtime_scripts[path] = resource
        return resource as Script
    return null

func _configure_reward_client() -> void:
    var config_value: Variant = app.index_document.get("reward", {})
    if not config_value is Dictionary:
        return
    var config: Dictionary = config_value
    if not bool(config.get("enabled", false)):
        return
    var RewardClientScript: Script = _runtime_script(REWARD_CLIENT_PATH)
    if RewardClientScript == null:
        return
    app.reward_client = RewardClientScript.new()
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
    var EchoesFinaleBackgroundScript: Script = _runtime_script(FINALE_BACKGROUND_PATH)
    if EchoesFinaleBackgroundScript == null:
        return
    app.finale_background = EchoesFinaleBackgroundScript.new()
    app.finale_background.name = "EchoesFinaleBackground"
    app.experience_surface.add_child(app.finale_background)
    app.finale_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    app.finale_background.configure(app.reduced_motion, app.quiet_visuals)
    app.experience_surface.move_child(app.finale_background, app.game_surface.get_index() + 1)

func arm_finale_guard() -> void:
    # The final menu is an invariant. Hide the room HUD immediately and schedule
    # an independent fallback so a stalled door/render coroutine cannot strand
    # the player on a dimmed last-room frame.
    if app.hud != null and is_instance_valid(app.hud):
        app.hud.suspend_for_menu()
    _prepare_finale_background()
    var guard := get_tree().create_timer(0.80)
    guard.timeout.connect(func() -> void:
        if app.reward_panel == null or not is_instance_valid(app.reward_panel):
            _show_reward_panel()
    )

func _reward_panel_ready() -> bool:
    return (
        app.reward_panel != null
        and is_instance_valid(app.reward_panel)
        and app.reward_panel.has_method("is_ready_for_input")
        and bool(app.reward_panel.is_ready_for_input())
    )

func _show_reward_panel() -> void:
    # Finale is an invariant, not a one-shot side effect. Replay/restore can keep
    # a valid Node reference whose form was never configured (or was detached by
    # a transition). Reuse only an input-ready panel; otherwise rebuild it.
    if _reward_panel_ready():
        app.reward_panel.show()
        return
    if app.reward_panel != null and is_instance_valid(app.reward_panel):
        app._remove_modal(app.reward_panel)
    app.reward_panel = null
    # The finale can be opened directly from a persisted 11/11 journey. In that
    # path _begin_experience() intentionally skips gameplay startup, so the
    # reward client may not exist yet. Bring it online here as well and let the
    # normal run-start callback reconcile all locally completed rooms.
    if app.reward_client == null:
        _configure_reward_client()
    _prepare_finale_background()
    app.SoundscapeRuntime.enter_outro(app.menu_soundscape, app.music_level, app.noise_level, app.quiet_mode)
    # Persisted 11/11 journeys intentionally skip gameplay runtime. The finale
    # must therefore never assume HUD exists: otherwise the animated background
    # survives while the actual final menu aborts before it is constructed.
    if app.hud != null and is_instance_valid(app.hud):
        app.hud.visible = false
    var SignalFinaleCardScript: Script = _runtime_script(SIGNAL_FINALE_CARD_PATH)
    if SignalFinaleCardScript == null:
        _install_reward_fallback("Pełny finał nie załadował się poprawnie. Wynik pozostaje zapisany.")
        return
    app.reward_panel = SignalFinaleCardScript.new()
    app.reward_panel.name = "SignalFinaleCard"
    app.ui_root.attach(app.reward_panel, 40)
    # Verify across several rendered frames. A single deferred check can race
    # desktop layout/focus construction; the fallback itself also contains the
    # e-mail form, so every completed/replay path remains actionable.
    call_deferred("_verify_reward_panel_ready")
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
        # Refresh mutable handoff/link context with a fresh idempotency key.
        app.reward_client.refresh_completion_context(int(app.album_state.get("total_elapsed_ms", 0)))
    app.reward_panel.draw_entry_requested.connect(_submit_reward_claim_values)
    app.reward_panel.leaderboard_publish_requested.connect(_publish_leaderboard)
    app.reward_panel.leaderboard_refresh_requested.connect(_refresh_leaderboard)
    app.reward_panel.signal_context_refresh_requested.connect(_refresh_signal_context)
    app.reward_panel.signal_handoff_requested.connect(_issue_signal_handoff)
    app.reward_panel.reset_requested.connect(app._confirm_reset_album)
    app.reward_panel.album_mode_requested.connect(app._show_album_archive)
    # UI first, network second. start_run() is idempotent for a restored run and
    # _on_run_started() reconciles every locally completed room before complete.
    # This makes replay/persisted completion registration independent of HUD/menu
    # runtime and keeps a visible finale even when CrowdRelay is temporarily down.
    if app.reward_client != null:
        app.reward_client.start_run()
    _refresh_leaderboard()

func _verify_reward_panel_ready() -> void:
    # Allow the Control tree, layout and focus chain to settle. This is especially
    # important on desktop replay, where a final transition and two-column layout
    # complete on adjacent frames.
    for _attempt in range(6):
        await get_tree().process_frame
        if _reward_panel_ready():
            WebE2EProbe.emit("finale", {"ready":true,"fallback":false})
            return
    _install_reward_fallback("Finał przełączył się w tryb bezpieczny. Wynik jest zachowany lokalnie i może zostać zsynchronizowany.")

func _install_reward_fallback(message: String) -> void:
    if app.reward_panel != null and is_instance_valid(app.reward_panel):
        app._remove_modal(app.reward_panel)
        app.reward_panel = null
    var FallbackScript: Script = _runtime_script(SIGNAL_FINALE_FALLBACK_PATH)
    if FallbackScript == null:
        app._show_fatal_error(message)
        return
    app.reward_panel = FallbackScript.new()
    app.reward_panel.name = "SignalFinaleFallbackCard"
    app.ui_root.attach(app.reward_panel, 40)
    app.reward_panel.configure(
        bool(app.album_state.get("server_album_completed", false)),
        app.ProgressStoreScript.load_reward(),
        app.ProgressMetrics.completion_summary(app.release_entries, app.album_state),
        app.completion_context,
        message,
    )
    app.reward_panel.draw_entry_requested.connect(_submit_reward_claim_values)
    app.reward_panel.signal_context_refresh_requested.connect(_refresh_signal_context)
    app.reward_panel.signal_handoff_requested.connect(_issue_signal_handoff)
    app.reward_panel.reset_requested.connect(app._confirm_reset_album)
    app.reward_panel.album_mode_requested.connect(app._show_album_archive)
    WebE2EProbe.emit("finale", {"ready":true,"fallback":true})

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
    app.reward_client.refresh_completion_context(int(app.album_state.get("total_elapsed_ms", 0)))

func _refresh_signal_context() -> void:
    if app.reward_panel == null or not is_instance_valid(app.reward_panel):
        return
    if app.reward_client == null or not bool(app.album_state.get("server_album_completed", false)):
        app.reward_panel.set_status("Ukończenie nie jest jeszcze zsynchronizowane z CrowdRelay.")
        return
    app.reward_client.refresh_completion_context(int(app.album_state.get("total_elapsed_ms", 0)))


func _issue_signal_handoff() -> void:
    if app.reward_panel == null or not is_instance_valid(app.reward_panel):
        return
    if app.reward_client == null or not bool(app.album_state.get("server_album_completed", false)):
        app.reward_panel.set_status("Ukończenie nie jest jeszcze zsynchronizowane z CrowdRelay.")
        return
    app.reward_client.request_handoff()

func _publish_leaderboard() -> void:
    if app.reward_panel == null or not is_instance_valid(app.reward_panel):
        return
    if app.reward_client == null or not bool(app.album_state.get("server_album_completed", false)):
        app.reward_panel.set_leaderboard_status("Najpierw kończę synchronizację wyniku z CrowdRelay.")
        return
    if not app.reward_panel.is_leaderboard_publish_eligible():
        app.reward_panel.set_leaderboard_status("Ten zapis nie ma pełnego pomiaru 11/11. Ranking odblokuje świeży pełny przebieg.")
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
    var local_complete: bool = bool(app.album_state.get("album_completed", false))
    var timing_complete: bool = app.ProgressMetrics.has_complete_journey_timing(app.release_entries, app.album_state)
    if local_complete and not timing_complete and not bool(app.album_state.get("server_album_completed", false)):
        # Compatibility for saves produced by the historical timing-capture bug:
        # link/reward continuity is recoverable, but no elapsed time is invented
        # and the leaderboard stays locked until a fresh competitive 11/11 run.
        app.reward_client.recover_album(app._array_value(app.album_state.get("completed_room_ids", [])))
        return
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
        app.reward_panel.set_server_completed(true)
        app.reward_panel.apply_signal_context(app.completion_context)
        var linked: bool = bool(app.completion_context.get("linked_to_fan", false))
        app.reward_panel.set_status("Wynik połączony z Sygnałem. Możesz teraz opublikować PB w rankingu." if linked else "Ukończenie potwierdzone. Aby wejść do rankingu, połącz wynik z Sygnałem lub e-mailem, a potem opublikuj PB.")
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
        app.reward_client.refresh_completion_context(int(app.album_state.get("total_elapsed_ms", 0)))

func _on_reward_request_failed(operation: String, message: String) -> void:
    if operation == "enter_draw" and app.reward_panel != null and is_instance_valid(app.reward_panel):
        app.reward_panel.set_status(message)
        app.reward_panel.set_claim_enabled(true)
    elif operation.begins_with("leaderboard_") and app.reward_panel != null and is_instance_valid(app.reward_panel):
        app.reward_panel.set_leaderboard_status(message)
        app.reward_panel.set_leaderboard_publish_enabled(bool(app.completion_context.get("linked_to_fan", false)))
    elif operation in ["recover_album", "completion_context_refresh", "handoff_issue"] and app.reward_panel != null and is_instance_valid(app.reward_panel):
        app.reward_panel.set_status(message)
        app.reward_panel.apply_signal_context(app.completion_context)
    elif app.hud != null and is_instance_valid(app.hud):
        app.hud.update_discovery("Postęp jest bezpieczny lokalnie · synchronizacja wróci później")

func _on_reward_retry_scheduled(operation: String, attempt: int) -> void:
    var text_value: String = "Ponawiam połączenie z Sygnałem · próba %d/3" % attempt
    if operation == "enter_draw" and app.reward_panel != null and is_instance_valid(app.reward_panel):
        app.reward_panel.set_status(text_value)
    elif operation.begins_with("leaderboard_") and app.reward_panel != null and is_instance_valid(app.reward_panel):
        app.reward_panel.set_leaderboard_status(text_value)
    elif operation in ["recover_album", "completion_context_refresh", "handoff_issue"] and app.reward_panel != null and is_instance_valid(app.reward_panel):
        app.reward_panel.set_status(text_value)
    elif app.hud != null and is_instance_valid(app.hud):
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
